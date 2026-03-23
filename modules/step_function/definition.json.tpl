{
  "Comment": "SOAR Orchestrator - Centralized Incident Response",
  "StartAt": "ParseFinding",
  "States": {
    "ParseFinding": {
      "Type": "Task",
      "Resource": "${parse_finding_arn}",
      "ResultPath": "$.parsed",
      "Next": "EvaluateSeverity",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "NotifyFailure",
        "ResultPath": "$.error"
      }]
    },
    "EvaluateSeverity": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.parsed.severity",
          "StringEquals": "HIGH",
          "Next": "HighSeverityPlaybook"
        },
        {
          "Variable": "$.parsed.severity",
          "StringEquals": "MEDIUM",
          "Next": "MediumSeverityPlaybook"
        }
      ],
      "Default": "LogOnly"
    },
    "HighSeverityPlaybook": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.parsed.resource_type",
          "StringEquals": "EC2",
          "Next": "QuarantineEC2"
        },
        {
          "Variable": "$.parsed.resource_type",
          "StringEquals": "IAM",
          "Next": "DisableIAMKey"
        },
        {
          "Variable": "$.parsed.resource_type",
          "StringEquals": "IP",
          "Next": "BlockMaliciousIP"
        }
      ],
      "Default": "CollectEvidence"
    },
    "QuarantineEC2": {
      "Type": "Task",
      "Resource": "${quarantine_arn}",
      "ResultPath": "$.quarantine_result",
      "Next": "CollectEvidence",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "NotifyFailure",
        "ResultPath": "$.error"
      }]
    },
    "BlockMaliciousIP": {
      "Type": "Task",
      "Resource": "${block_ip_arn}",
      "ResultPath": "$.block_result",
      "Next": "CollectEvidence",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "NotifyFailure",
        "ResultPath": "$.error"
      }]
    },
    "DisableIAMKey": {
      "Type": "Task",
      "Resource": "${disable_key_arn}",
      "ResultPath": "$.disable_result",
      "Next": "CollectEvidence",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "NotifyFailure",
        "ResultPath": "$.error"
      }]
    },
    "MediumSeverityPlaybook": {
      "Type": "Pass",
      "Comment": "Medium: collect evidence and notify only",
      "Next": "CollectEvidence"
    },
    "CollectEvidence": {
      "Type": "Task",
      "Resource": "${collect_evidence_arn}",
      "ResultPath": "$.evidence",
      "Next": "Notify",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "Notify",
        "ResultPath": "$.evidence_error"
      }]
    },
    "Notify": {
      "Type": "Task",
      "Resource": "${notify_arn}",
      "ResultPath": "$.notification",
      "End": true
    },
    "LogOnly": {
      "Type": "Pass",
      "Comment": "LOW severity - log only, no action",
      "End": true
    },
    "NotifyFailure": {
      "Type": "Task",
      "Resource": "${notify_arn}",
      "Parameters": {
        "severity": "HIGH",
        "message": "SOAR automation failed",
        "error.$": "$.error"
      },
      "End": true
    }
  }
}
