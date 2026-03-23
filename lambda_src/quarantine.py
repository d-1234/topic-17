"""
quarantine.py
EC2 compromise response: quarantine SG + stop + snapshot.
"""
import os
import json
import boto3
from datetime import datetime, timezone

ec2 = boto3.client("ec2")
s3 = boto3.client("s3")
BUCKET = os.environ["EVIDENCE_BUCKET"]


def _get_or_create_quarantine_sg(vpc_id: str, region: str, account: str) -> str:
    name = "quarantine-sg"
    resp = ec2.describe_security_groups(
        Filters=[{"Name": "group-name", "Values": [name]},
                 {"Name": "vpc-id", "Values": [vpc_id]}]
    )
    if resp["SecurityGroups"]:
        return resp["SecurityGroups"][0]["GroupId"]

    sg = ec2.create_security_group(
        GroupName=name,
        Description="Quarantine - no inbound/outbound",
        VpcId=vpc_id,
    )
    sg_id = sg["GroupId"]
    # Remove default outbound rule
    ec2.revoke_security_group_egress(
        GroupId=sg_id,
        IpPermissions=[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}],
    )
    ec2.create_tags(Resources=[sg_id], Tags=[{"Key": "Name", "Value": "quarantine-sg"}])
    return sg_id


def handler(event: dict, _context) -> dict:
    parsed = event.get("parsed", event)
    instance_id = parsed.get("resource_id", "")
    region = parsed.get("region", os.environ.get("AWS_REGION", "us-east-1"))
    account = parsed.get("account", "")
    finding_id = parsed.get("finding_id", "unknown")

    if not instance_id.startswith("i-"):
        return {"status": "skipped", "reason": "not an EC2 instance ID"}

    # Describe instance
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    reservation = resp["Reservations"][0]
    instance = reservation["Instances"][0]
    vpc_id = instance.get("VpcId", "")

    # Apply quarantine SG
    sg_id = _get_or_create_quarantine_sg(vpc_id, region, account)
    ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=[sg_id],
    )

    # Stop instance
    ec2.stop_instances(InstanceIds=[instance_id])

    # Snapshot all EBS volumes
    snapshot_ids = []
    for bdm in instance.get("BlockDeviceMappings", []):
        vol_id = bdm["Ebs"]["VolumeId"]
        snap = ec2.create_snapshot(
            VolumeId=vol_id,
            Description=f"Forensic snapshot - {finding_id}",
            TagSpecifications=[{
                "ResourceType": "snapshot",
                "Tags": [
                    {"Key": "FindingId", "Value": finding_id},
                    {"Key": "InstanceId", "Value": instance_id},
                    {"Key": "Purpose", "Value": "forensic"},
                ]
            }],
        )
        snapshot_ids.append(snap["SnapshotId"])

    # Store metadata in S3
    evidence = {
        "finding_id": finding_id,
        "instance_id": instance_id,
        "vpc_id": vpc_id,
        "quarantine_sg": sg_id,
        "snapshot_ids": snapshot_ids,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "instance_metadata": {
            "state": instance["State"]["Name"],
            "instance_type": instance.get("InstanceType"),
            "launch_time": instance["LaunchTime"].isoformat(),
            "private_ip": instance.get("PrivateIpAddress"),
            "public_ip": instance.get("PublicIpAddress"),
            "tags": instance.get("Tags", []),
        },
    }
    key = f"evidence/{finding_id}/quarantine.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=json.dumps(evidence, default=str))

    return {"status": "quarantined", "instance_id": instance_id,
            "sg_id": sg_id, "snapshots": snapshot_ids, "evidence_key": key}
