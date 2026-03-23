# Centralized Detection & Automated Incident Response on AWS
## Presentation Content — 10 Slides

---

## Slide 1 — Title

**Title:** Centralized Detection & Automated Incident Response on AWS

**Subtitle:** A Production-Grade SOAR POC Using Native AWS Services

**Presenter:** [Your Name]
**Date:** [Date]
**Tags:** Security Hub · GuardDuty · Step Functions · EventBridge · Lambda

---
**Speaker Notes:**
Welcome. Today I'll walk through a fully automated security operations architecture built entirely on AWS native services. This POC demonstrates how a single-account setup can achieve enterprise-grade detection and response capabilities at minimal cost — no third-party SIEM required.

---

## Slide 2 — Problem Statement

**Title:** The Security Operations Challenge

**Bullets:**
- 🔴 Security teams face alert fatigue — thousands of findings per day
- 🔴 Manual triage is slow — mean time to respond (MTTR) averages 24+ hours
- 🔴 Siloed tools — GuardDuty, Config, IAM findings not correlated
- 🔴 Inconsistent response — playbooks exist on paper, not in code
- 🔴 Evidence collection is manual and unreliable
- ✅ **Goal:** Detect → Correlate → Respond → Notify in under 60 seconds, automatically

---
**Speaker Notes:**
The core problem is that most organizations have detection tools but lack automated response. A GuardDuty HIGH finding might sit unactioned for hours. This POC closes that gap by wiring detection directly to automated playbooks via Step Functions, with full evidence collection and notification built in.

---

## Slide 3 — Architecture Overview

**Title:** Single-Account SOAR Architecture

**Bullets:**
- Single AWS account — no cross-account complexity for POC
- Detection Layer: GuardDuty + Security Hub + IAM Access Analyzer
- All findings centralized in Security Hub (single pane of glass)
- EventBridge rules filter by severity and route to Step Functions
- Step Functions orchestrates Lambda playbooks
- Evidence stored in encrypted S3 with lifecycle management
- Notifications via SNS + Slack webhook

**Diagram Reference:** See architecture.drawio

```
GuardDuty ──┐
IAM Analyzer─┤→ Security Hub → EventBridge → Step Functions → Lambda Actions
             │                                                      ↓
             └──────────────────────────────────────────────── S3 + SNS
```

---
**Speaker Notes:**
The architecture follows a linear event-driven pipeline. Every finding flows through Security Hub as the aggregation point. EventBridge acts as the router — only MEDIUM and above findings trigger automation. Step Functions provides the orchestration logic with branching based on severity and resource type.

---

## Slide 4 — AWS Services Used

**Title:** AWS Services — Roles & Cost Profile

| Service | Role | Cost Profile |
|---|---|---|
| GuardDuty | Threat detection (ML-based) | Free tier 30 days; ~$1-4/mo after |
| Security Hub | Finding aggregation & standards | Free tier 30 days; ~$0.001/finding |
| IAM Access Analyzer | External access analysis | Free |
| EventBridge | Event routing & filtering | Free (custom events) |
| Step Functions | SOAR orchestration | Free tier 4,000 transitions/mo |
| Lambda | Playbook execution | Free tier 1M requests/mo |
| S3 | Evidence storage | ~$0.023/GB/mo |
| SNS | Alert notifications | Free tier 1M publishes/mo |
| KMS | Encryption | $1/key/mo |
| CloudWatch Logs | Audit trail | Free tier 5GB/mo |

**Total estimated POC cost: < $5/month**

---
**Speaker Notes:**
Cost optimization was a key design constraint. By using native AWS services and staying within free tier limits for Lambda, Step Functions, and SNS, the monthly cost for this POC is under $5. GuardDuty is the primary cost driver but is essential for threat detection. No WAF, no Inspector, no third-party tools.

---

## Slide 5 — Event Flow

**Title:** End-to-End Event Flow

**Steps:**
1. **Detect** — GuardDuty generates finding (e.g., UnauthorizedAccess:EC2/SSHBruteForce)
2. **Aggregate** — Finding flows to Security Hub via native integration
3. **Filter** — EventBridge rule matches: severity ≥ MEDIUM, status = NEW
4. **Transform** — EventBridge input transformer normalizes the event payload
5. **Trigger** — Step Functions execution starts with normalized JSON
6. **Parse** — `parse_finding` Lambda extracts: severity, resource_type, resource_id
7. **Branch** — Choice state routes: HIGH→Playbook, MEDIUM→Evidence, LOW→Log
8. **Act** — Appropriate Lambda executes (quarantine / block IP / disable key)
9. **Collect** — `collect_evidence` Lambda stores JSON + metadata to S3
10. **Notify** — `notify` Lambda publishes to SNS + Slack webhook

**SLA Target:** Detection to notification < 60 seconds

---
**Speaker Notes:**
The input transformer in EventBridge is critical — it normalizes both GuardDuty and Security Hub event formats into a single schema before Step Functions receives it. This means the SOAR workflow doesn't need to handle two different event structures. The parse_finding Lambda does final normalization and severity scoring.

---

## Slide 6 — Playbooks

**Title:** Severity-Based Automated Playbooks

**HIGH Severity:**
- EC2 Compromise → Apply quarantine security group (no inbound/outbound) → Stop instance → Create EBS snapshot → Collect metadata → SNS + Slack alert
- Malicious IP → Add NACL DENY rule (rule 100-199 range) → Log to S3 → Alert
- Credential Compromise → Disable all active IAM access keys → Alert

**MEDIUM Severity:**
- Collect finding JSON + resource metadata to S3
- Send SNS notification (no destructive action)

**LOW Severity:**
- Log to CloudWatch only
- No automated action (avoid false-positive disruption)

**Failure Handling:**
- All Lambda tasks have Catch blocks → route to `NotifyFailure` state
- Errors logged to CloudWatch with full execution context

---
**Speaker Notes:**
The playbook design follows the principle of proportional response. HIGH severity triggers destructive actions (stopping instances, disabling keys) because the risk of inaction outweighs the risk of a false positive. MEDIUM only collects evidence. LOW is logged only — this prevents automation from disrupting legitimate activity based on low-confidence findings.

---

## Slide 7 — Terraform Design

**Title:** Infrastructure as Code — Terraform Module Structure

**Module Structure:**
```
terraform-security-poc/
├── main.tf              # Module wiring + backend config
├── variables.tf         # Input variables
├── outputs.tf           # Key resource outputs
└── modules/
    ├── iam/             # Roles, policies, KMS key
    ├── security_services/ # GuardDuty, Security Hub, Analyzer
    ├── s3_evidence/     # Encrypted evidence bucket
    ├── lambda/          # All 6 Lambda functions + SNS
    ├── step_function/   # State machine + ASL definition
    └── eventbridge/     # Event rules + targets
```

**Design Principles:**
- Remote state in S3 with DynamoDB locking
- Least-privilege IAM — each role scoped to exact actions needed
- All resources tagged via `default_tags` provider block
- Lambda code packaged via `archive_file` data source
- Step Functions ASL uses `templatefile()` for Lambda ARN injection

---
**Speaker Notes:**
The Terraform structure follows a flat module pattern — no nested modules — keeping it simple and deployable. The IAM module is the foundation; all other modules depend on it for role ARNs. The Step Functions definition is a separate template file to keep the Terraform clean and the ASL readable. Remote state uses S3 + DynamoDB for team collaboration.

---

## Slide 8 — Demo Flow

**Title:** Live Demo Walkthrough

**Step 1 — Deploy Infrastructure**
```bash
terraform init && terraform apply
```

**Step 2 — Simulate GuardDuty Finding**
```bash
# Generate sample finding via AWS CLI
aws guardduty create-sample-findings \
  --detector-id <detector-id> \
  --finding-types "UnauthorizedAccess:EC2/SSHBruteForce"
```

**Step 3 — Observe Pipeline**
- Security Hub console → Finding appears
- EventBridge → Rule matched (CloudWatch metrics)
- Step Functions → Execution running → View graph
- Lambda → CloudWatch logs for each function
- S3 → evidence/<finding-id>/finding.json created
- SNS/Slack → Alert received

**Step 4 — Verify Response**
- EC2 console → Instance stopped, quarantine SG applied
- S3 → EBS snapshot metadata stored
- IAM → Access key status = Inactive

---
**Speaker Notes:**
The demo uses GuardDuty's built-in sample finding generator — no need to actually attack anything. The create-sample-findings API generates realistic HIGH severity findings that flow through the entire pipeline. The Step Functions visual workflow makes it easy to show the audience exactly which state is executing in real time.

---

## Slide 9 — Cost Optimization

**Title:** Cost Optimization Strategy

**Free Tier Maximization:**
- Lambda: 1M free requests/mo — POC uses < 1,000/mo
- Step Functions: 4,000 free state transitions/mo
- SNS: 1M free publishes/mo
- EventBridge: Custom events are free
- CloudWatch Logs: 5GB free ingestion/mo

**Design Choices to Minimize Cost:**
- GuardDuty: Disabled Kubernetes audit logs and EBS malware scan (high cost)
- S3 Lifecycle: Auto-transition to STANDARD_IA (30d) → GLACIER (90d) → Delete (365d)
- S3 Bucket Key enabled: Reduces KMS API calls by ~99%
- Lambda timeout set conservatively (30-60s) — no runaway executions
- CloudWatch log retention: 14 days (not indefinite)
- No NAT Gateway, no VPC endpoints, no WAF

**Monthly Cost Estimate:**
| Item | Cost |
|---|---|
| GuardDuty | ~$1-4 |
| Security Hub | ~$0.10 |
| KMS Key | $1.00 |
| S3 Storage | ~$0.05 |
| **Total** | **~$3-6/mo** |

---
**Speaker Notes:**
The biggest cost lever is GuardDuty — specifically disabling the EBS malware scanning feature which can cost $0.86/GB scanned. For a POC, basic network and DNS threat detection is sufficient. The S3 lifecycle policy ensures evidence doesn't accumulate indefinitely. Everything else falls within free tier for a POC workload.

---

## Slide 10 — Future Enhancements

**Title:** Production Roadmap

**Phase 2 — Multi-Account:**
- AWS Organizations + Security Hub delegated admin
- GuardDuty organization-level detector
- Centralized evidence bucket with cross-account replication

**Phase 3 — Enhanced Detection:**
- AWS Config rules for compliance findings
- CloudTrail Lake for advanced threat hunting queries
- VPC Flow Logs analysis via Athena

**Phase 4 — Advanced Response:**
- SSM Automation documents for OS-level forensics
- AWS Systems Manager Incident Manager integration
- Automated ticket creation (Jira/ServiceNow via Lambda)
- Step Functions Express Workflows for high-volume findings

**Phase 5 — Observability:**
- Security Hub custom insights and dashboards
- CloudWatch dashboard for MTTR metrics
- AWS Security Lake for long-term analytics

**Key Metrics to Track:**
- MTTD (Mean Time to Detect)
- MTTR (Mean Time to Respond)
- False positive rate per playbook
- Evidence collection success rate

---
**Speaker Notes:**
This POC establishes the core pattern. The natural evolution is to scale it across an AWS Organization using Security Hub's delegated admin feature. The SOAR pattern — EventBridge → Step Functions → Lambda — scales horizontally; adding new playbooks is just adding new Lambda functions and Choice states. The architecture is intentionally extensible without requiring a redesign.

---
*End of Presentation*
