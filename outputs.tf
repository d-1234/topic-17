output "evidence_bucket_name" {
  description = "S3 evidence bucket name"
  value       = module.s3_evidence.bucket_name
}

output "sfn_arn" {
  description = "Step Functions state machine ARN"
  value       = module.step_function.sfn_arn
}

output "sns_topic_arn" {
  description = "SNS alert topic ARN"
  value       = module.lambda.sns_topic_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security_services.guardduty_detector_id
}
