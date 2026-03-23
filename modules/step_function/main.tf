resource "aws_sfn_state_machine" "soar" {
  name     = "${var.name_prefix}-soar"
  role_arn = var.sfn_role_arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/definition.json.tpl", {
    parse_finding_arn    = var.parse_finding_lambda_arn
    quarantine_arn       = var.quarantine_lambda_arn
    block_ip_arn         = var.block_ip_lambda_arn
    disable_key_arn      = var.disable_key_lambda_arn
    collect_evidence_arn = var.collect_evidence_lambda_arn
    notify_arn           = var.notify_lambda_arn
  })

  logging_configuration {
    level                  = "ERROR"
    include_execution_data = false
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
  }
}

resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/states/${var.name_prefix}-soar"
  retention_in_days = 14
}
