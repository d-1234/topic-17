data "aws_region" "current" {}

# ── GuardDuty ─────────────────────────────────────────────────────────────────
# Managed by org administrator — read only
data "aws_guardduty_detector" "main" {}

# Security Hub, IAM Access Analyzer omitted — no data sources available in
# hashicorp/aws provider and both are centrally managed by the org administrator.
