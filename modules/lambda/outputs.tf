output "sns_topic_arn"              { value = aws_sns_topic.alerts.arn }
output "parse_finding_lambda_arn"   { value = aws_lambda_function.parse_finding.arn }
output "quarantine_lambda_arn"      { value = aws_lambda_function.quarantine.arn }
output "block_ip_lambda_arn"        { value = aws_lambda_function.block_ip.arn }
output "disable_key_lambda_arn"     { value = aws_lambda_function.disable_key.arn }
output "collect_evidence_lambda_arn" { value = aws_lambda_function.collect_evidence.arn }
output "notify_lambda_arn"          { value = aws_lambda_function.notify.arn }
