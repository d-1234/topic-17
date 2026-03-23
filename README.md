# Centralized Detection & Automated Incident Response — AWS POC

A production-grade SOAR (Security Orchestration, Automation and Response) POC using native AWS services.

## Architecture

```
GuardDuty ──┐
IAM Analyzer─┤──► Security Hub ──► EventBridge ──► Step Functions
             │                                           │
             └───────────────────────────────────────────┤
                                                         ▼
                                              ┌──────────────────────┐
                                              │  Lambda Playbooks    │
                                              │  ├─ parse_finding    │
                                              │  ├─ quarantine       │
                                              │  ├─ block_ip         │
                                              │  ├─ disable_key      │
                                              │  ├─ collect_evidence │
                                              │  └─ notify           │
                                              └──────────┬───────────┘
                                                         │
                                              ┌──────────▼───────────┐
                                              │  S3 Evidence + SNS   │
                                              └──────────────────────┘
```

## Prerequisites

- AWS CLI configured with admin credentials
- Terraform >= 1.5
- Python 3.12 (for local Lambda testing)
- An S3 bucket for Terraform state: `tf-state-security-poc`
- A DynamoDB table for state locking: `tf-state-lock`

## Quick Start

### 1. Bootstrap Remote State

```bash
aws s3 mb s3://tf-state-security-poc --region us-east-1
aws s3api put-bucket-versioning \
  --bucket tf-state-security-poc \
  --versioning-configuration Status=Enabled
```

### 2. Deploy

```bash
cd terraform-security-poc

terraform init
terraform plan -var="slack_webhook_url=https://hooks.slack.com/services/YOUR/WEBHOOK"
terraform apply
```

### 3. Subscribe to SNS Alerts

```bash
aws sns subscribe \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --protocol email \
  --notification-endpoint your@email.com
```

### 4. Test the Pipeline

```bash
# Get GuardDuty detector ID
DETECTOR_ID=$(terraform output -raw guardduty_detector_id)

# Generate sample HIGH severity finding
aws guardduty create-sample-findings \
  --detector-id $DETECTOR_ID \
  --finding-types "UnauthorizedAccess:EC2/SSHBruteForce"
```

Then watch:
- AWS Console → Step Functions → `sec-poc-soar` → Executions
- S3 → `sec-poc-evidence-<account-id>` → evidence/

## Module Overview

| Module | Resources |
|---|---|
| `iam` | Lambda role, SFN role, EventBridge role, KMS key |
| `security_services` | GuardDuty detector, Security Hub, IAM Access Analyzer |
| `s3_evidence` | Encrypted S3 bucket with versioning + lifecycle |
| `lambda` | 6 Lambda functions + SNS topic + CloudWatch log groups |
| `step_function` | Step Functions state machine + log group |
| `eventbridge` | 2 EventBridge rules (GuardDuty + Security Hub) |

## Playbooks

| Severity | Resource | Actions |
|---|---|---|
| HIGH | EC2 | Quarantine SG + Stop + EBS Snapshot + Evidence + Alert |
| HIGH | IAM | Disable access keys + Alert |
| HIGH | IP | NACL DENY rule + Evidence + Alert |
| MEDIUM | Any | Evidence collection + Notification |
| LOW | Any | Log only |

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Deployment region |
| `name_prefix` | `sec-poc` | Resource name prefix |
| `slack_webhook_url` | `""` | Slack incoming webhook (optional) |
| `common_tags` | See variables.tf | Tags applied to all resources |

## GitHub Actions

Set these repository secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (optional, defaults to us-east-1)
- `SLACK_WEBHOOK_URL` (optional)

Create a GitHub Environment named `production` with required reviewers for manual approval gate.

## Cost Estimate

~$3-6/month for a POC workload. See Slide 9 in PRESENTATION.md for breakdown.

## Cleanup

```bash
terraform destroy
```

> Note: GuardDuty detector deletion has a 30-day cooldown before re-enabling in the same account.
