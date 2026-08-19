# AWS Security Mastery — 12-Day Workspace

A 12-day, hands-on program to reach production-credible competence in AWS
security: identity, encryption, edge defense, detection, response
automation, governance, and incident response — taught against **one
real workload you attack and defend, daily**, in your own AWS account.
Every lab is Terraform, every break has an observable signal, every
harden re-proves that signal flipped, and the whole sprint is designed
to cost **under $15**.

## The two spine principles

Everything in this path is built on two ideas, spelled out in full in
[`content/STRATEGY.md`](content/STRATEGY.md):

1. **One engine, many doors.** AWS authorization is a single evaluation
   order — explicit Deny → Organizations SCP/RCP → resource-based policy →
   identity-based policy → permission boundary → session policy. Learn
   that order once on Day 1, and every service after that (KMS, WAF,
   GuardDuty, SCPs...) is just a new *door* onto the same engine, not a
   new thing to memorize from scratch.
2. **Break → harden, provably.** Every lab has a concrete, observable
   signal for both the break (the attack lands — an HTTP 200, a
   successful decrypt, a reachable resource) and the harden (the attack
   is now blocked — an `AccessDenied`, an HTTP 403, a finding ID). If you
   can't point at the signal that flipped, you haven't finished the day.

Read `content/STRATEGY.md` before Day 1 — it also covers what to
over-index on and what to skip on a first pass, and how to keep the
whole sprint cheap.

**First time here?** Start with
[`content/day00-setup.md`](content/day00-setup.md) — the billing
guardrail, standing up `labs/base` once, and the daily rhythm all live
there as a single checklist, before you touch Day 1.

## Prerequisites

- An AWS account you are authorized to test in (this path deploys real
  resources and runs real attacks against them — your own account only,
  never anyone else's).
- AWS CLI v2, configured (`aws configure` or an SSO profile) —
  verify with `aws sts get-caller-identity`.
- Terraform **≥ 1.6** — verify with `terraform version`.
- A region you're comfortable running low-cost resources in for two
  weeks. Pick one region and use it for the whole sprint (a second-AZ,
  single-region setup keeps costs and complexity down); note it in your
  own `terraform.tfvars` files, never in a file that ships in git.

## STEP 0 — Billing guardrail (do this before Day 1, ~10 minutes)

Do not start Day 1 until both of these are in place. Every value below
is a placeholder — fill in your own before running anything.

### 1. An AWS Budget (alerts at a % of a monthly cap)

```bash
aws budgets create-budget \
  --account-id <your-account-id> \
  --budget '{
    "BudgetName": "aws-security-mastery-sprint",
    "BudgetLimit": {
      "Amount": "<budget-limit-usd>",
      "Unit": "USD"
    },
    "BudgetType": "COST",
    "TimeUnit": "MONTHLY"
  }' \
  --notifications-with-subscribers '[
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 80,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [
        {
          "SubscriptionType": "EMAIL",
          "Address": "<your-email>"
        }
      ]
    }
  ]'
```

Fill in: `<your-account-id>` (your 12-digit AWS account ID —
`aws sts get-caller-identity --query Account --output text`),
`<budget-limit-usd>` (e.g. `20` — a little above the <$15 target so a
normal day doesn't trip it, but tight enough that a forgotten
`terraform destroy` gets caught fast), `<your-email>` (an address you
actually check — you'll get a confirmation email to accept).

### 2. A CloudWatch billing alarm (near-real-time backstop)

Billing metrics only exist in `us-east-1`, regardless of which region
your workload runs in — this is why the alarm resource below uses an
aliased provider. One-time manual step first: in the Billing Console,
under **Billing preferences**, check **"Receive Billing Alerts"** — this
cannot be set via Terraform or CLI.

```hcl
# Requires a us-east-1 provider alias even if your workload region differs:
# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1"
# }

resource "aws_sns_topic" "billing_alerts" {
  name = "aws-security-mastery-billing-alerts"
}

resource "aws_sns_topic_subscription" "billing_email" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = "<your-email>"   # fill in — confirm the subscription email AWS sends you
}

resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  provider            = aws.us_east_1
  alarm_name          = "aws-security-mastery-billing-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = 20  # <-- your monthly USD budget limit (number, no quotes)
  alarm_actions       = [aws_sns_topic.billing_alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}
```

Put this in its own small `.tf` (outside `labs/`, e.g. a personal
`billing-guardrail/` folder you don't commit, or apply it ad hoc) — it's
account-level, not part of the learning workload, and it should outlive
every `terraform destroy` you run inside `labs/`.

## How the persistent workload works

`labs/base/` stands up one small, real 3-tier workload once: a VPC, an
ALB, an ECS Fargate service, a CloudFront distribution, an S3 bucket, a
Secrets Manager secret, and a starter IAM task role. You bring it up at
the start of a study session and leave it up while you work — it is the
one thing every day shares.

Each `labs/dayNN/` is a small Terraform module **layered on top of**
`labs/base` (it reads `labs/base`'s outputs — VPC ID, ALB listener ARN,
task role ARN, bucket ARN, and so on — rather than redeclaring
anything). You `apply` the day's module, do the break/harden, then
`terraform destroy` *that day's module* — `labs/base` itself stays up
for the rest of the session so tomorrow's day doesn't need to rebuild
the world. See `labs/base/README.md` for the exact commands and the
full outputs list.

Only two days change this rhythm: Day 8 turns on the detection stack
(GuardDuty, Security Hub, Macie) and it's the one thing that survives
overnight into Day 9, which turns it back off. Days 11–12 re-enable it
for the capstone only. See § Cost & Teardown below.

## The daily five-beat loop (~2.5–4 hrs/day, see ROADMAP.md for per-day estimates)

1. **Orient** (~10 min) — read `content/dayNN-*.md` top to bottom. Note
   which door of the evaluation order today attaches to before you
   touch the AWS CLI.
2. **Stand up** (~5–15 min) — bring up `labs/base` if it isn't already
   up this session; `terraform apply` the day's module in `labs/dayNN/`.
3. **Break** (~30–45 min) — run the attack or misconfiguration described
   in `labs/dayNN/README.md`. Capture the "before" signal (the thing
   that shouldn't work, working).
4. **Harden** (~30–45 min) — apply the fix, re-run the same action, and
   capture the "after" signal (the flipped result — `AccessDenied`,
   `403`, a blocked finding). Compare against `labs/dayNN/SOLUTION.md`.
5. **Journal + teardown** (~15 min) — write today's entry in
   `journal.md` (template at the top of that file), then
   `terraform destroy` the day's module. `labs/base` stays up.

## Cost & teardown

**Target: under $15 for the entire 12-day sprint.** This is achievable
because almost nothing runs longer than the session it's used in — the
only standing cost across the whole sprint is `labs/base` itself
(one small ALB + one Fargate task + CloudFront + S3 + Secrets Manager),
and every day module is destroyed before you close the session.

**The detection free-trial window is the one exception to "destroy
daily" — track it explicitly:**

| When | State |
|------|-------|
| Day 8 | GuardDuty, Security Hub, Macie, Detective **enabled** — this starts the single 30-day free-trial clock |
| End of Day 9 | All four **disabled** — this is a required checklist item in `labs/day09/README.md`, not optional |
| Day 10 | Detection stays off |
| Days 11–12 | Detection **re-enabled** for the IR capstone only |
| End of Day 12 | Detection **swept**: confirmed disabled, plus a final cross-region check and CMK scheduled-deletion sweep |

Missing the Day 9 disable step is the single most likely way to blow
past $15 — GuardDuty/Security Hub/Macie left running past the trial
window bill continuously. If you have to stop the sprint for more than
a day between Day 8 and Day 9, disable the detection stack before you
walk away and re-enable it when you resume.

Every `labs/dayNN/README.md` ends with its own teardown checklist.
`labs/base/README.md` has the base workload's teardown. Day 12 runs the
**final sweep** — `terraform destroy` across base and every day module,
confirmation that all detection services are off, and a scheduled
deletion for every CMK created along the way (KMS charges for pending
deletion windows, not after they complete).

## Navigation

| Day | Content | Lab | Focus |
|-----|---------|-----|-------|
| — | [`content/STRATEGY.md`](content/STRATEGY.md) | — | Read before Day 1 |
| — | [`content/ANTIPATTERNS.md`](content/ANTIPATTERNS.md) | — | The 10 seed mistakes + authorized-testing statement |
| — | [`content/GLOSSARY.md`](content/GLOSSARY.md) | — | Plain-English terms, reference as needed |
| — | [`content/CERT-MAP.md`](content/CERT-MAP.md) | — | SCS-C02 domain map + self-scored checklist |
| — | — | [`labs/base/`](labs/base/) | The persistent 3-tier workload — stand up before Day 1 |
| 0 | [`content/day00-setup.md`](content/day00-setup.md) | [`labs/base/`](labs/base/) | Billing guardrail, deploy `labs/base` once, learn the daily rhythm |
| 1 | [`content/day01-iam-engine.md`](content/day01-iam-engine.md) | [`labs/day01/`](labs/day01/) | IAM evaluation order, policy simulator, Access Analyzer |
| 2 | [`content/day02-advanced-identity.md`](content/day02-advanced-identity.md) | [`labs/day02/`](labs/day02/) | Trust policies, confused deputy, permission boundaries |
| 3 | [`content/day03-kms-foundations.md`](content/day03-kms-foundations.md) | [`labs/day03/`](labs/day03/) | KMS key policy, envelope encryption, rotation |
| 4 | [`content/day04-kms-advanced-data-at-rest.md`](content/day04-kms-advanced-data-at-rest.md) | [`labs/day04/`](labs/day04/) | Cross-account KMS, S3/EBS/RDS encryption, grants |
| 5 | [`content/day05-secrets-and-certs.md`](content/day05-secrets-and-certs.md) | [`labs/day05/`](labs/day05/) | Secrets Manager, Parameter Store, ACM |
| 6 | [`content/day06-waf-edge.md`](content/day06-waf-edge.md) | [`labs/day06/`](labs/day06/) | WAF Web ACLs, managed + custom rules |
| 7 | [`content/day07-shield-network-layering.md`](content/day07-shield-network-layering.md) | [`labs/day07/`](labs/day07/) | Shield, CloudFront security, SG/NACL/WAF layering |
| 8 | [`content/day08-detection.md`](content/day08-detection.md) | [`labs/day08/`](labs/day08/) | CloudTrail, GuardDuty, Security Hub, Macie (trial opens) |
| 9 | [`content/day09-response-automation.md`](content/day09-response-automation.md) | [`labs/day09/`](labs/day09/) | EventBridge, Lambda/SSM, Config (trial closes) |
| 10 | [`content/day10-governance-multiaccount.md`](content/day10-governance-multiaccount.md) | [`labs/day10/`](labs/day10/) | SCPs, IAM Identity Center, ABAC |
| 11 | [`content/day11-ir-capstone-attack.md`](content/day11-ir-capstone-attack.md) | [`labs/day11/`](labs/day11/) + [`labs/capstone/`](labs/capstone/) | Full incident storyline (attack) |
| 12 | [`content/day12-ir-capstone-defend.md`](content/day12-ir-capstone-defend.md) | [`labs/day12/`](labs/day12/) + [`labs/capstone/`](labs/capstone/) | Contain → eradicate → recover + final sweep |

For the phase grouping, the dependency graph, and per-day hour
estimates, see [`ROADMAP.md`](ROADMAP.md). For the running war-story
log, see [`journal.md`](journal.md).
