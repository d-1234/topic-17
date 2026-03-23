data "aws_region" "current" {}

# ── GuardDuty ─────────────────────────────────────────────────────────────────
# Managed by org administrator — read only
data "aws_guardduty_detector" "main" {}

# ── Security Hub ──────────────────────────────────────────────────────────────
# Managed by org administrator — read only
data "aws_securityhub_hub" "main" {}

# ── IAM Access Analyzer ───────────────────────────────────────────────────────
# Managed by org administrator — read only
data "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.name_prefix}-analyzer"
}
