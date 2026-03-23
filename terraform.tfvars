aws_region  = "us-east-1"
name_prefix = "sec-poc"

# Set via environment variable or CI secret — do not commit a real value
# TF_VAR_slack_webhook_url=https://hooks.slack.com/services/XXX/YYY/ZZZ
slack_webhook_url = ""

common_tags = {
  Project     = "SecurityPOC"
  Environment = "poc"
  ManagedBy   = "Terraform"
}
