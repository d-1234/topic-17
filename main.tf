provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.common_tags
  }
}

# ── IAM ──────────────────────────────────────────────────────────────────────
module "iam" {
  source      = "./modules/iam"
  name_prefix = var.name_prefix
}

# ── S3 Evidence Bucket ───────────────────────────────────────────────────────
module "s3_evidence" {
  source      = "./modules/s3_evidence"
  name_prefix = var.name_prefix
  kms_key_arn = module.iam.kms_key_arn
}

# ── Security Services ────────────────────────────────────────────────────────
module "security_services" {
  source      = "./modules/security_services"
  name_prefix = var.name_prefix
}

# ── Lambda Functions ─────────────────────────────────────────────────────────
module "lambda" {
  source               = "./modules/lambda"
  name_prefix          = var.name_prefix
  lambda_role_arn      = module.iam.lambda_role_arn
  evidence_bucket_name = module.s3_evidence.bucket_name
  sns_topic_arn        = module.lambda.sns_topic_arn
  slack_webhook_url    = var.slack_webhook_url
  kms_key_arn          = module.iam.kms_key_arn
}

# ── Step Functions ───────────────────────────────────────────────────────────
module "step_function" {
  source                      = "./modules/step_function"
  name_prefix                 = var.name_prefix
  sfn_role_arn                = module.iam.sfn_role_arn
  parse_finding_lambda_arn    = module.lambda.parse_finding_lambda_arn
  quarantine_lambda_arn       = module.lambda.quarantine_lambda_arn
  block_ip_lambda_arn         = module.lambda.block_ip_lambda_arn
  disable_key_lambda_arn      = module.lambda.disable_key_lambda_arn
  collect_evidence_lambda_arn = module.lambda.collect_evidence_lambda_arn
  notify_lambda_arn           = module.lambda.notify_lambda_arn
}

# ── EventBridge ──────────────────────────────────────────────────────────────
module "eventbridge" {
  source               = "./modules/eventbridge"
  name_prefix          = var.name_prefix
  sfn_arn              = module.step_function.sfn_arn
  eventbridge_role_arn = module.iam.eventbridge_role_arn
}
