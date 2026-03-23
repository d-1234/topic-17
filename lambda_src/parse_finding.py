"""
parse_finding.py
Normalizes GuardDuty / Security Hub events into a standard schema.
"""
import json
import re


SEVERITY_MAP = {
    "CRITICAL": "HIGH",
    "HIGH": "HIGH",
    "MEDIUM": "MEDIUM",
    "LOW": "LOW",
    "INFORMATIONAL": "LOW",
}


def _severity_from_score(score: float) -> str:
    if score >= 7.0:
        return "HIGH"
    if score >= 4.0:
        return "MEDIUM"
    return "LOW"


def _resource_type(raw: str) -> str:
    raw = raw.upper()
    if "EC2" in raw or "INSTANCE" in raw:
        return "EC2"
    if "IAM" in raw or "ACCESSKEY" in raw or "USER" in raw:
        return "IAM"
    if re.match(r"\d{1,3}(\.\d{1,3}){3}", raw):
        return "IP"
    return "OTHER"


def handler(event: dict, _context) -> dict:
    source = event.get("source", "unknown")

    if source == "guardduty":
        severity = _severity_from_score(float(event.get("severity_raw", 0)))
        resource_raw = json.dumps(event.get("resource", {}))
        resource_id = (
            event.get("resource", {})
            .get("instanceDetails", {})
            .get("instanceId", "unknown")
        )
        return {
            "source": source,
            "finding_id": event["finding_id"],
            "severity": severity,
            "type": event.get("type", ""),
            "resource_type": _resource_type(event.get("type", "")),
            "resource_id": resource_id,
            "resource_raw": resource_raw,
            "region": event.get("region", ""),
            "account": event.get("account", ""),
            "description": event.get("description", ""),
        }

    # Security Hub path
    severity = SEVERITY_MAP.get(event.get("severity", "LOW"), "LOW")
    resource_type_raw = event.get("resource_type", "")
    return {
        "source": source,
        "finding_id": event.get("finding_id", ""),
        "severity": severity,
        "type": event.get("title", ""),
        "resource_type": _resource_type(resource_type_raw),
        "resource_id": event.get("resource_id", "unknown"),
        "resource_raw": json.dumps(event),
        "region": event.get("region", ""),
        "account": event.get("account", ""),
        "description": event.get("title", ""),
    }
