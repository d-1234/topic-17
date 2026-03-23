# ── GuardDuty ─────────────────────────────────────────────────────────────────
# If detector already exists, import it:
# terraform import module.security_services.aws_guardduty_detector.main <detector-id>
resource "aws_guardduty_detector" "main" {
  enable = true

  lifecycle {
    # Prevent recreation if detector already exists
    prevent_destroy = false
  }
}

# S3_DATA_EVENTS feature omitted — member accounts cannot manage detector features
# when GuardDuty is centrally managed by the org administrator.

# ── Security Hub ──────────────────────────────────────────────────────────────
# If Security Hub already enabled, import it:
# terraform import module.security_services.aws_securityhub_account.main <account-id>
resource "aws_securityhub_account" "main" {
  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Standards subscription omitted — member accounts cannot manage standards
# when Security Hub is centrally managed by the org administrator.

# Enable GuardDuty → Security Hub integration
resource "aws_securityhub_product_subscription" "guardduty" {
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
}

# ── IAM Access Analyzer ───────────────────────────────────────────────────────
# NOTE: Only one ACCOUNT-type analyzer is allowed per region.
# If one already exists, import it:
# terraform import module.security_services.aws_accessanalyzer_analyzer.main <analyzer-name>
# Or remove this resource and use the existing analyzer.
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.name_prefix}-analyzer"
  type          = "ACCOUNT"

  lifecycle {
    # If creation fails due to quota, import the existing analyzer instead
    ignore_changes = [analyzer_name]
  }
}

data "aws_region" "current" {}
