# ── GuardDuty HIGH/MEDIUM findings ───────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${var.name_prefix}-guardduty-findings"
  description = "Capture GuardDuty MEDIUM and HIGH findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_sfn" {
  rule     = aws_cloudwatch_event_rule.guardduty.name
  arn      = var.sfn_arn
  role_arn = var.eventbridge_role_arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      type        = "$.detail.type"
      region      = "$.region"
      account     = "$.account"
      finding_id  = "$.detail.id"
      resource    = "$.detail.resource"
      description = "$.detail.description"
    }
    input_template = <<-EOT
    {
      "source": "guardduty",
      "finding_id": "<finding_id>",
      "severity_raw": <severity>,
      "type": "<type>",
      "region": "<region>",
      "account": "<account>",
      "resource": <resource>,
      "description": "<description>"
    }
    EOT
  }
}

# ── Security Hub HIGH findings ────────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "securityhub" {
  name        = "${var.name_prefix}-securityhub-findings"
  description = "Capture Security Hub HIGH and CRITICAL findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_sfn" {
  rule     = aws_cloudwatch_event_rule.securityhub.name
  arn      = var.sfn_arn
  role_arn = var.eventbridge_role_arn

  input_transformer {
    input_paths = {
      finding_id   = "$.detail.findings[0].Id"
      severity     = "$.detail.findings[0].Severity.Label"
      title        = "$.detail.findings[0].Title"
      resource_type = "$.detail.findings[0].Resources[0].Type"
      resource_id  = "$.detail.findings[0].Resources[0].Id"
      account      = "$.detail.findings[0].AwsAccountId"
      region       = "$.region"
    }
    input_template = <<-EOT
    {
      "source": "securityhub",
      "finding_id": "<finding_id>",
      "severity": "<severity>",
      "title": "<title>",
      "resource_type": "<resource_type>",
      "resource_id": "<resource_id>",
      "account": "<account>",
      "region": "<region>"
    }
    EOT
  }
}
