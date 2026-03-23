output "guardduty_rule_arn" { value = aws_cloudwatch_event_rule.guardduty.arn }
output "securityhub_rule_arn" { value = aws_cloudwatch_event_rule.securityhub.arn }
