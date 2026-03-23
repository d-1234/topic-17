"""
collect_evidence.py
Stores finding JSON and EC2 metadata to S3 evidence bucket.
"""
import os
import json
import boto3
from datetime import datetime, timezone

s3 = boto3.client("s3")
ec2 = boto3.client("ec2")
BUCKET = os.environ["EVIDENCE_BUCKET"]


def _get_ec2_metadata(instance_id: str) -> dict:
    try:
        resp = ec2.describe_instances(InstanceIds=[instance_id])
        instance = resp["Reservations"][0]["Instances"][0]
        return {
            "instance_id": instance_id,
            "state": instance["State"]["Name"],
            "instance_type": instance.get("InstanceType"),
            "vpc_id": instance.get("VpcId"),
            "subnet_id": instance.get("SubnetId"),
            "private_ip": instance.get("PrivateIpAddress"),
            "public_ip": instance.get("PublicIpAddress"),
            "security_groups": [sg["GroupId"] for sg in instance.get("SecurityGroups", [])],
            "tags": instance.get("Tags", []),
            "launch_time": instance["LaunchTime"].isoformat(),
        }
    except Exception as e:
        return {"error": str(e)}


def handler(event: dict, _context) -> dict:
    parsed = event.get("parsed", event)
    finding_id = parsed.get("finding_id", "unknown")
    timestamp = datetime.now(timezone.utc).isoformat()

    # Store full finding
    finding_key = f"evidence/{finding_id}/finding.json"
    s3.put_object(
        Bucket=BUCKET,
        Key=finding_key,
        Body=json.dumps({"finding": parsed, "collected_at": timestamp}, default=str),
        ContentType="application/json",
    )

    result = {"finding_key": finding_key, "timestamp": timestamp}

    # Collect EC2 metadata if applicable
    if parsed.get("resource_type") == "EC2":
        instance_id = parsed.get("resource_id", "")
        if instance_id.startswith("i-"):
            metadata = _get_ec2_metadata(instance_id)
            meta_key = f"evidence/{finding_id}/ec2_metadata.json"
            s3.put_object(
                Bucket=BUCKET,
                Key=meta_key,
                Body=json.dumps(metadata, default=str),
                ContentType="application/json",
            )
            result["ec2_metadata_key"] = meta_key

    return result
