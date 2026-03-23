"""
block_ip.py
Blocks a malicious IP via NACL deny rule and logs to S3.
"""
import os
import json
import re
import boto3
from datetime import datetime, timezone

ec2 = boto3.client("ec2")
s3 = boto3.client("s3")
BUCKET = os.environ["EVIDENCE_BUCKET"]

# NACL rule numbers 100-199 reserved for auto-blocks
RULE_START = 100
RULE_END = 199


def _extract_ip(parsed: dict) -> str:
    resource_raw = parsed.get("resource_raw", "")
    # Try to find an IP in the resource data
    match = re.search(r"\b(\d{1,3}(?:\.\d{1,3}){3})\b", resource_raw)
    return match.group(1) if match else ""


def _next_rule_number(nacl_id: str) -> int:
    resp = ec2.describe_network_acls(NetworkAclIds=[nacl_id])
    used = {
        e["RuleNumber"]
        for e in resp["NetworkAcls"][0]["Entries"]
        if RULE_START <= e["RuleNumber"] <= RULE_END
    }
    for n in range(RULE_START, RULE_END + 1):
        if n not in used:
            return n
    raise RuntimeError("No available NACL rule numbers in range 100-199")


def handler(event: dict, _context) -> dict:
    parsed = event.get("parsed", event)
    finding_id = parsed.get("finding_id", "unknown")
    ip = _extract_ip(parsed)

    if not ip:
        return {"status": "skipped", "reason": "no IP found in finding"}

    # Find default NACL for the default VPC
    vpcs = ec2.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])
    if not vpcs["Vpcs"]:
        return {"status": "skipped", "reason": "no default VPC found"}

    vpc_id = vpcs["Vpcs"][0]["VpcId"]
    nacls = ec2.describe_network_acls(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]},
                 {"Name": "default", "Values": ["true"]}]
    )
    nacl_id = nacls["NetworkAcls"][0]["NetworkAclId"]
    rule_number = _next_rule_number(nacl_id)

    # Add DENY rule for inbound traffic from malicious IP
    ec2.create_network_acl_entry(
        NetworkAclId=nacl_id,
        RuleNumber=rule_number,
        Protocol="-1",
        RuleAction="deny",
        Egress=False,
        CidrBlock=f"{ip}/32",
    )

    evidence = {
        "finding_id": finding_id,
        "blocked_ip": ip,
        "nacl_id": nacl_id,
        "rule_number": rule_number,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    key = f"evidence/{finding_id}/block_ip.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=json.dumps(evidence))

    return {"status": "blocked", "ip": ip, "nacl_id": nacl_id,
            "rule_number": rule_number, "evidence_key": key}
