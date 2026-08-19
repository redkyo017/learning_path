# Day 9 lab — Response automation

Closes Day 8's break. Wires two detective→corrective pipelines against
the persistent `labs/base` workload:

1. **GuardDuty finding → EventBridge → Lambda** that auto-quarantines
   the compromised ECS task role (deny-all permission boundary +
   token-time-scoped session revoke).
2. **AWS Config rule → built-in automatic remediation** that re-locks a
   deliberately-public demo S3 bucket the moment Config flags it.

> **Authorized testing only.** Every technique here targets only your
> own AWS account and your own Terraform-deployed workload
> (`labs/base` and this module). See
> [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement).

## Objective

Prove that a live finding/violation results in the offending principal
or resource being demonstrably contained — automatically, with no
human typing the fix — and record the before/after evidence in
`SOLUTION.md`.

## Prerequisites

- `labs/base` is applied and its outputs are readable at
  `../base/terraform.tfstate` (this module reads `task_role_arn` from
  it via `terraform_remote_state`; it never edits `labs/base`).
- Day 8's detection stack (GuardDuty, Security Hub, Macie) is enabled
  and has generated at least the credential-theft finding this lab
  reacts to. If Day 8 hasn't run yet, this module still applies
  cleanly — GuardDuty findings simply won't exist to trigger the rule
  until it does.
- Terraform >= 1.6, AWS provider >= 5.0, `hashicorp/archive` provider
  (for zipping the Lambda) — both declared in `main.tf`.
- **Terraform is not run by this document's author.** You run
  `terraform init/plan/apply/destroy` and every AWS CLI command below
  yourself. This lab's Terraform was validated by manual HCL review,
  not by `terraform apply` — read `main.tf` before you run it.

```bash
cd labs/day09
cp terraform.tfvars.example terraform.tfvars
# edit region/project to match labs/base
terraform init
terraform plan
terraform apply
```

## THE BREAK (recap — already live from Day 8)

Day 8's lab used the app's `/fetch?url=` SSRF to steal the ECS task
role's temporary credentials from the task credential endpoint, then
used them from outside the workload — generating GuardDuty findings
such as (illustrative; your exact finding type string depends on what
GuardDuty actually saw) `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
and a crypto-mining-flavored `CryptoCurrency:*` finding. Those stolen
credentials are still valid and usable right now — that's the
open break this lab closes.

**Expected state before you apply this module** — confirm the stolen
credential still works (this is the "before" half of today's signal):

```bash
# Using the credentials Day 8 exfiltrated via /fetch (see that lab's
# SOLUTION.md for how they were captured):
AWS_ACCESS_KEY_ID=<stolen> AWS_SECRET_ACCESS_KEY=<stolen> AWS_SESSION_TOKEN=<stolen> \
  aws s3 ls "s3://$(cd ../base && terraform output -raw app_bucket_name)"
# Expected: succeeds (200 / a listing), because nothing has revoked
# this role yet.
```

## THE HARDEN

### Step 1 — apply this module

`terraform apply` (above) creates the EventBridge rule, the quarantine
Lambda, the deny-all boundary policy, and the Config rule +
remediation + demo bucket.

### Step 2 — fire the GuardDuty pipeline

Two ways to trigger it, in order of preference:

**A. Real finding (best, if Day 8's finding is still active):** do
nothing — GuardDuty already published the finding to EventBridge when
it first fired. If your rule was applied *after* the finding first
fired, GuardDuty will re-publish an update event the next time it
observes the same activity pattern; re-run Day 8's `/fetch`-based theft
from an external caller to force a fresh event under the new rule.

**B. Synthetic finding (fallback — always works, safe, no live
attack needed):** GuardDuty can generate one sample finding of each
type into your own account:

```bash
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
aws guardduty create-sample-findings --detector-id "$DETECTOR_ID" \
  --finding-types "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS"
```

Sample findings carry a fixed sample severity and a synthetic resource
block that won't name your real task role — which is exactly why the
Lambda's safety guardrail (see `lambda_src/quarantine.py`) checks the
extracted principal's **name** against `TASK_ROLE_NAME` before acting.
**Any finding whose principal doesn't match gets logged as
`"action": "refused"`, not `"action": "quarantined"`** — that's
correct behavior, not a bug, and it's what makes firing sample findings
freely safe. To actually exercise the full containment path end to
end, invoke the Lambda directly with a crafted test event naming the
real task role (safe — this only ever touches the one role your
Lambda's execution policy is scoped to):

```bash
TASK_ROLE_NAME=$(basename "$(cd ../base && terraform output -raw task_role_arn)")
cat > /tmp/test-finding.json <<EOF
{
  "detail": {
    "id": "test-finding-0001",
    "type": "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS",
    "severity": 8.5,
    "resource": {
      "resourceType": "AccessKey",
      "accessKeyDetails": {
        "userName": "$TASK_ROLE_NAME"
      }
    }
  }
}
EOF
aws lambda invoke \
  --function-name "$(terraform output -raw quarantine_lambda_arn)" \
  --payload file:///tmp/test-finding.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/quarantine-result.json
cat /tmp/quarantine-result.json
```

### Step 3 — confirm containment (the signal)

```bash
# 1. CloudWatch Logs show the containment record:
aws logs tail "$(terraform output -raw quarantine_lambda_log_group)" --since 5m

# 2. The role now carries a permissions boundary + the audit tags:
aws iam get-role --role-name "$(basename "$(cd ../base && terraform output -raw task_role_arn)")" \
  --query 'Role.[PermissionsBoundary,Tags]'

# 3. The SAME stolen credential that worked in "THE BREAK" above now fails:
AWS_ACCESS_KEY_ID=<stolen> AWS_SECRET_ACCESS_KEY=<stolen> AWS_SESSION_TOKEN=<stolen> \
  aws s3 ls "s3://$(cd ../base && terraform output -raw app_bucket_name)"
# Expected: AccessDenied
```

### Step 4 — fire the Config pipeline

```bash
# Config evaluates on a schedule/on change; force an immediate check:
aws configservice start-config-rules-evaluation \
  --config-rule-names "$(terraform output -raw config_rule_name)"

sleep 30

aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "$(terraform output -raw config_rule_name)" \
  --compliance-types NON_COMPLIANT
# Expected initially: the demo bucket listed NON_COMPLIANT.

# Automatic remediation fires on its own within a few minutes. Confirm:
aws s3api get-public-access-block \
  --bucket "$(terraform output -raw config_demo_bucket_name)"
# Expected: all four booleans true (BlockPublicAcls, IgnorePublicAcls,
# BlockPublicPolicy, RestrictPublicBuckets).

aws configservice get-compliance-details-by-config-rule \
  --config-rule-name "$(terraform output -raw config_rule_name)" \
  --compliance-types COMPLIANT
# Expected: the demo bucket now listed COMPLIANT.
```

See `SOLUTION.md` for the full expected before/after transcript.

## Teardown checklist (CRITICAL — see content/day09 for the full free-trial-window rationale)

1. `terraform destroy` in this directory — removes everything Part 1
   and Part 2 created (EventBridge rule/target, Lambda + log group,
   boundary policy, Config recorder/delivery channel/rule/remediation,
   remediation role, both the delivery bucket and the demo bucket).
   Full destroy is correct — nothing here is part of persistent base.
2. **Disable GuardDuty, Security Hub, Macie, Detective — WITHOUT
   touching CloudTrail.** This is the end of the single free-trial
   window that opened on Day 8. `labs/day08/` contains BOTH the
   detection services AND CloudTrail (`aws_cloudtrail.this` +
   `aws_s3_bucket.trail_logs`), and CloudTrail must stay up through
   Day 12.

   > **⚠️ Do NOT run a bare `terraform destroy` in `labs/day08`.** It
   > would destroy CloudTrail too (and error on the non-empty log
   > bucket). Target only the detection resources by name:
   ```bash
   cd ../day08
   terraform destroy \
     -target=aws_guardduty_detector.this \
     -target=aws_securityhub_standards_subscription.fsbp \
     -target=aws_securityhub_account.this \
     -target=aws_macie2_classification_job.app_data \
     -target=aws_macie2_account.this \
     -target=aws_detective_graph.this
   ```
   If Day 8 wasn't Terraform-managed, use the direct CLI fallback
   instead (also safe, also leaves CloudTrail alone):
   ```bash
   aws guardduty list-detectors --query 'DetectorIds' --output text
   aws guardduty delete-detector --detector-id <id>
   aws securityhub disable-security-hub
   aws macie2 disable-macie
   aws detective list-graphs --query 'GraphList[].Arn' --output text
   aws detective delete-graph --graph-arn <arn>
   ```
3. **Leave CloudTrail running** — it is not part of the trial window
   and stays on, untouched, through Day 12's final sweep.
4. Confirm:
   - [ ] `terraform state list` here (labs/day09) is empty.
   - [ ] `aws guardduty list-detectors` → empty.
   - [ ] `aws securityhub describe-hub` → errors (not subscribed).
   - [ ] `aws macie2 get-macie-session` → disabled/not found.
   - [ ] `aws detective list-graphs` → empty.
   - [ ] CloudTrail's trail is still logging.
   - [ ] `labs/day08`'s `terraform state list` STILL shows
         `aws_cloudtrail.this` and `aws_s3_bucket.trail_logs` — if
         either is missing, CloudTrail was destroyed by mistake and
         must be re-created before you move on.
   - [ ] `labs/base`'s KMS key / S3 bucket / DynamoDB table / secret are
         untouched.
