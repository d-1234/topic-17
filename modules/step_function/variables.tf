variable "name_prefix"                { type = string }
variable "sfn_role_arn"               { type = string }
variable "parse_finding_lambda_arn"   { type = string }
variable "quarantine_lambda_arn"      { type = string }
variable "block_ip_lambda_arn"        { type = string }
variable "disable_key_lambda_arn"     { type = string }
variable "collect_evidence_lambda_arn" { type = string }
variable "notify_lambda_arn"          { type = string }
