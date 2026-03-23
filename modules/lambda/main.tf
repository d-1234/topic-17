locals {
  src = "${path.module}/../../lambda_src"
}

# ── SNS Alert Topic ───────────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "${var.name_prefix}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

# ── Lambda packaging helper ───────────────────────────────────────────────────
data "archive_file" "parse_finding" {
  type        = "zip"
  source_file = "${local.src}/parse_finding.py"
  output_path = "${path.module}/zips/parse_finding.zip"
}

data "archive_file" "quarantine" {
  type        = "zip"
  source_file = "${local.src}/quarantine.py"
  output_path = "${path.module}/zips/quarantine.zip"
}

data "archive_file" "block_ip" {
  type        = "zip"
  source_file = "${local.src}/block_ip.py"
  output_path = "${path.module}/zips/block_ip.zip"
}

data "archive_file" "disable_key" {
  type        = "zip"
  source_file = "${local.src}/disable_key.py"
  output_path = "${path.module}/zips/disable_key.zip"
}

data "archive_file" "collect_evidence" {
  type        = "zip"
  source_file = "${local.src}/collect_evidence.py"
  output_path = "${path.module}/zips/collect_evidence.zip"
}

data "archive_file" "notify" {
  type        = "zip"
  source_file = "${local.src}/notify.py"
  output_path = "${path.module}/zips/notify.zip"
}

# ── Lambda factory ────────────────────────────────────────────────────────────
resource "aws_lambda_function" "parse_finding" {
  function_name    = "${var.name_prefix}-parse-finding"
  role             = var.lambda_role_arn
  filename         = data.archive_file.parse_finding.output_path
  source_code_hash = data.archive_file.parse_finding.output_base64sha256
  handler          = "parse_finding.handler"
  runtime          = "python3.12"
  timeout          = 30
}

resource "aws_lambda_function" "quarantine" {
  function_name    = "${var.name_prefix}-quarantine"
  role             = var.lambda_role_arn
  filename         = data.archive_file.quarantine.output_path
  source_code_hash = data.archive_file.quarantine.output_base64sha256
  handler          = "quarantine.handler"
  runtime          = "python3.12"
  timeout          = 60
  environment {
    variables = { EVIDENCE_BUCKET = var.evidence_bucket_name }
  }
}

resource "aws_lambda_function" "block_ip" {
  function_name    = "${var.name_prefix}-block-ip"
  role             = var.lambda_role_arn
  filename         = data.archive_file.block_ip.output_path
  source_code_hash = data.archive_file.block_ip.output_base64sha256
  handler          = "block_ip.handler"
  runtime          = "python3.12"
  timeout          = 30
  environment {
    variables = { EVIDENCE_BUCKET = var.evidence_bucket_name }
  }
}

resource "aws_lambda_function" "disable_key" {
  function_name    = "${var.name_prefix}-disable-key"
  role             = var.lambda_role_arn
  filename         = data.archive_file.disable_key.output_path
  source_code_hash = data.archive_file.disable_key.output_base64sha256
  handler          = "disable_key.handler"
  runtime          = "python3.12"
  timeout          = 30
}

resource "aws_lambda_function" "collect_evidence" {
  function_name    = "${var.name_prefix}-collect-evidence"
  role             = var.lambda_role_arn
  filename         = data.archive_file.collect_evidence.output_path
  source_code_hash = data.archive_file.collect_evidence.output_base64sha256
  handler          = "collect_evidence.handler"
  runtime          = "python3.12"
  timeout          = 60
  environment {
    variables = { EVIDENCE_BUCKET = var.evidence_bucket_name }
  }
}

resource "aws_lambda_function" "notify" {
  function_name    = "${var.name_prefix}-notify"
  role             = var.lambda_role_arn
  filename         = data.archive_file.notify.output_path
  source_code_hash = data.archive_file.notify.output_base64sha256
  handler          = "notify.handler"
  runtime          = "python3.12"
  timeout          = 30
  environment {
    variables = {
      SNS_TOPIC_ARN     = aws_sns_topic.alerts.arn
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambdas" {
  for_each          = toset(["parse-finding", "quarantine", "block-ip", "disable-key", "collect-evidence", "notify"])
  name              = "/aws/lambda/${var.name_prefix}-${each.key}"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}
