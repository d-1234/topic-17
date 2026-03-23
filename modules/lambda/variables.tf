variable "kms_key_arn" {
  description = "KMS key ARN for encrypting CloudWatch log groups"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda execution"
  type        = string
}

variable "evidence_bucket_name" {
  description = "S3 bucket name for evidence storage"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN (unused — topic is created in this module)"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for notifications"
  type        = string
  sensitive   = true
  default     = ""
}
