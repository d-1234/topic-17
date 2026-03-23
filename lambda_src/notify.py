"""
notify.py
Sends SNS alert and optional Slack webhook notification.
"""
import os
import json
import urllib.request
import boto3

sns = boto3.client("sns")
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")

SEVERITY_EMOJI = {"HIGH": "🔴", "MEDIUM": "🟡", "LOW": "🟢"}


def _build_message(event: dict) -> tuple[str, str]:
    parsed = event.get("parsed", event)
    severity = parsed.get("severity", "UNKNOWN")
    emoji = SEVERITY_EMOJI.get(severity, "⚪")
    finding_id = parsed.get("finding_id", "N/A")
    resource_type = parsed.get("resource_type", "N/A")
    resource_id = parsed.get("resource_id", "N/A")
    description = parsed.get("description", parsed.get("type", "N/A"))
    account = parsed.get("account", "N/A")
    region = parsed.get("region", "N/A")

    subject = f"{emoji} [{severity}] Security Incident - {resource_type}"
    body = (
        f"Security Incident Detected\n"
        f"{'=' * 40}\n"
        f"Severity:      {severity}\n"
        f"Finding ID:    {finding_id}\n"
        f"Resource Type: {resource_type}\n"
        f"Resource ID:   {resource_id}\n"
        f"Description:   {description}\n"
        f"Account:       {account}\n"
        f"Region:        {region}\n"
    )

    # Append action results if present
    for key in ("quarantine_result", "block_result", "disable_result", "evidence"):
        if key in event:
            body += f"\nAction [{key}]: {json.dumps(event[key], default=str)}"

    return subject, body


def _send_slack(subject: str, body: str) -> None:
    if not SLACK_WEBHOOK_URL:
        return
    payload = json.dumps({
        "text": f"*{subject}*\n```{body}```"
    }).encode()
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    urllib.request.urlopen(req, timeout=5)


def handler(event: dict, _context) -> dict:
    subject, body = _build_message(event)

    sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject[:100], Message=body)

    try:
        _send_slack(subject, body)
    except Exception as e:
        print(f"Slack notification failed (non-fatal): {e}")

    return {"status": "notified", "subject": subject}
