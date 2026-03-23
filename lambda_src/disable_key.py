"""
disable_key.py
Disables a compromised IAM access key.
"""
import re
import boto3

iam = boto3.client("iam")


def _extract_key_and_user(parsed: dict):
    resource_id = parsed.get("resource_id", "")
    resource_raw = parsed.get("resource_raw", "")

    # resource_id format: arn:aws:iam::ACCOUNT:user/USERNAME
    username = None
    if "user/" in resource_id:
        username = resource_id.split("user/")[-1]

    # Try to find access key ID (AKIA...)
    match = re.search(r"(AKIA[A-Z0-9]{16})", resource_raw)
    access_key_id = match.group(1) if match else None

    return username, access_key_id


def handler(event: dict, _context) -> dict:
    parsed = event.get("parsed", event)
    finding_id = parsed.get("finding_id", "unknown")
    username, access_key_id = _extract_key_and_user(parsed)

    if not username:
        return {"status": "skipped", "reason": "no IAM username found"}

    disabled_keys = []

    if access_key_id:
        iam.update_access_key(
            UserName=username,
            AccessKeyId=access_key_id,
            Status="Inactive",
        )
        disabled_keys.append(access_key_id)
    else:
        # Disable all active keys for the user
        keys = iam.list_access_keys(UserName=username)["AccessKeyMetadata"]
        for key in keys:
            if key["Status"] == "Active":
                iam.update_access_key(
                    UserName=username,
                    AccessKeyId=key["AccessKeyId"],
                    Status="Inactive",
                )
                disabled_keys.append(key["AccessKeyId"])

    return {
        "status": "disabled",
        "username": username,
        "disabled_keys": disabled_keys,
        "finding_id": finding_id,
    }
