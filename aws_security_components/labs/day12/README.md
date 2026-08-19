# Day 12 lab — IR capstone: defend + gap-fill

## Objective

Run contain → eradicate → recover against the Day 11 incident on your
own workload, prove the attacker's path is now blocked end to end, run
the SCS-C02 self-assessment, then execute the **final sweep** —
teardown of everything this 12-day sprint created, in every region you
touched.

**Authorized testing only.** Every action below targets your own AWS
account and your own Terraform-deployed workload (`labs/base/` and its
day modules) — see [`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md)'s
authorized-testing statement. Nothing here is run against any resource
you do not own.

For the full narrative runbook (why each step, in what order, tied
back to the engine), see
[`labs/capstone/defend-runbook.md`](../capstone/defend-runbook.md).
This README is the executable checklist; that file is the reading.

## Prereqs

- `labs/base` is up (`terraform apply` in `labs/base/`, if not already
  applied this session).
- Day 11's attack lab has been run at least once, so there's a real
  incident to defend against. Day 11 deliberately did **not** create a
  real second "leaked key" IAM identity (it narrated that step using
  the deployer's own credentials — see
  `labs/capstone/attack-runbook.md`'s rationale, to avoid its own
  instance of secret sprawl). Leave `create_leaked_user_fixture = true`
  (the default) — this module creates one now, purely so CONTAIN Step 1
  has a real key to deactivate/delete, and destroys it same-day in the
  final sweep.
- Detection (**GuardDuty and Security Hub only** — Day 11 kept Macie
  and Detective off; this incident's artifact list is CloudTrail +
  GuardDuty + Security Hub + Config) is re-enabled per the Days 11–12
  capstone window (`README.md` § Cost & Teardown). If it's not on, turn
  it on manually now (console or CLI) before you start — today's final
  sweep is what turns it off for good.
- `terraform.tfvars` copied from `terraform.tfvars.example` in this
  directory, `project` matching `labs/base`'s value exactly.

**Terraform is not installed in this authoring environment — every
`.tf` file here is validated by manual HCL review, not by `terraform
plan`/`apply`. State that when you actually run this in your own
account with Terraform installed.**

## CONTAIN (do this first — CLI, not Terraform)

An incident in progress can't wait on a plan/apply cycle. These are
manual AWS CLI actions, on purpose — see
[Antipattern #2](../../content/ANTIPATTERNS.md#2-console-clicking-instead-of-terraform)'s
one justified exception, discussed in the day content file.

1. **Deactivate + delete the leaked access key.**
   ```bash
   aws iam update-access-key \
     --user-name <leaked_user_name> \
     --access-key-id <AKIA...> \
     --status Inactive
   aws iam delete-access-key \
     --user-name <leaked_user_name> \
     --access-key-id <AKIA...>
   ```
   Get `<leaked_user_name>`/`<AKIA...>` from `terraform output
   leaked_user_name` / `terraform output leaked_access_key_id` if this
   module created the fixture, or from Day 11's own output/notes if it
   already exists.
   **Expected:** `aws sts get-caller-identity` using the old key now
   fails with `InvalidClientTokenId` (deactivated) then
   `An error occurred (InvalidAccessKeyId)` (deleted).

2. **Break-glass quarantine the task role — attach a `Deny *` inline
   policy immediately, via CLI:**
   ```bash
   cat > /tmp/break-glass-deny-all.json <<'EOF'
   {
     "Version": "2012-10-17",
     "Statement": [
       { "Sid": "BreakGlassDenyAll", "Effect": "Deny", "Action": "*", "Resource": "*" }
     ]
   }
   EOF
   aws iam put-role-policy \
     --role-name <task_role_name> \
     --policy-name emergency-quarantine \
     --policy-document file:///tmp/break-glass-deny-all.json
   ```
   `<task_role_name>` — from `labs/base`'s `task_role_arn` output
   (the part after the final `/`).
   **Expected:** the app's `/whoami` and `/fetch` endpoints now 5xx —
   this is intended; the app is fully down while you work. `aws
   dynamodb scan` / `aws s3 ls` with the (already-stolen, still
   theoretically live) task-role creds now return `AccessDenied`.

3. **(Optional, if you want the compute stopped too, not just
   permission-denied)** scale the ECS service to 0:
   ```bash
   aws ecs update-service \
     --cluster <ecs_cluster_arn> \
     --service <ecs_service_name> \
     --desired-count 0
   ```

Record the exact CLI output (redact the account ID) in
`labs/capstone/defend-SOLUTION.md` under CONTAIN.

## ERADICATE (Terraform — the permanent fix)

```bash
cd labs/day12
terraform init
terraform plan   # review: 1 leaked-user fixture (if enabled), 1 IAM
                  # role-policy Deny layered on the base task role,
                  # 1 WAF Web ACL + association on the base ALB
terraform apply
```

**Expected plan contents** (manual review checklist, since Terraform
isn't installed here — confirm before you'd apply in your own account):

- `aws_iam_role_policy.eradicate_tighten` — targets the **existing**
  base task role by name (not a new role); five `Deny` statements
  (S3 delete-anywhere, S3 read/write outside `app_object_prefix`,
  DynamoDB `Scan`, all EC2 actions, direct-KMS-use-not-via-trusted-service).
- `aws_wafv2_web_acl.capstone_defend` + `aws_wafv2_web_acl_association.alb`
  — `scope = "REGIONAL"`, attached to the base ALB's ARN, one rule
  blocking the metadata substrings in the `url` query parameter.
- (if enabled) `aws_iam_user.leaked` + policy + access key.

Once applied, **remove the break-glass policy** — the permanent
Terraform Deny is now doing the job:
```bash
aws iam delete-role-policy \
  --role-name <task_role_name> \
  --policy-name emergency-quarantine
```

## RECOVER

1. Restore the ECS service if you scaled it to 0:
   ```bash
   aws ecs update-service --cluster <ecs_cluster_arn> \
     --service <ecs_service_name> --desired-count 1
   ```
2. Force a fresh deployment so no task is still holding
   pre-incident-issued credentials in memory longer than necessary:
   ```bash
   aws ecs update-service --cluster <ecs_cluster_arn> \
     --service <ecs_service_name> --force-new-deployment
   ```
3. Confirm the **legitimate allow path still works** (don't just test
   the deny — test both, per
   [Antipattern #3](../../content/ANTIPATTERNS.md#3-never-actually-testing-a-deny)):
   ```bash
   curl -s "http://<alb_dns_name>/whoami"
   curl -s "http://<alb_dns_name>/fetch?url=https://example.com"
   ```
   **Expected:** both return HTTP 200 — the app itself, and its normal
   use of `/fetch` against a legitimate host, are unaffected by
   today's fixes.
4. If the app's own S3/DynamoDB access pattern touches the same
   prefix/keys `app_object_prefix` scopes, confirm it still 200s
   too.

## Success signal — re-run the Day 11 attack, now blocked

Using the **already-stolen** task-role temporary credentials (or a
freshly-simulated theft attempt), re-run the exact Day 11 steps.

**These are STS temporary credentials, not a long-lived key pair** —
an access-key-ID/secret-key pair alone will fail with an invalid-token
error regardless of any policy, because a session token is also
required. Don't use an AWS CLI named profile for this (there's nowhere
that defines one) — reuse Day 11's own pattern from `attack.sh`:
export all three environment variables in the same shell you run these
commands from, exactly as stage 4 of `attack-runbook.md` does:

```bash
export AWS_ACCESS_KEY_ID="<stolen AccessKeyId>"
export AWS_SECRET_ACCESS_KEY="<stolen SecretAccessKey>"
export AWS_SESSION_TOKEN="<stolen SessionToken>"
```

```bash
# 1. Repeat the SSRF request against the hardened ALB:
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://<alb_dns_name>/fetch?url=http://169.254.170.2/v2/credentials/<GUID>"
# Expected: 403 (WAF block) — the request never reaches the app.

# 2. Using the (now-Denied) stolen task-role creds directly (env vars above,
#    no --profile flag needed once exported):
aws s3api delete-object --bucket <app_bucket_name> --key app-data/anything
# Expected: AccessDenied — DenyS3DeleteAnywhereInBucket fires.

aws dynamodb scan --table-name <project>-appdata
# Expected: AccessDenied — DenyDynamoDBBulkScan fires.

aws s3api get-object --bucket <app_bucket_name> --key some/other-prefix/file /tmp/out
# Expected: AccessDenied — DenyS3ReadWriteOutsideAllowedPrefix fires
# (object key outside app_object_prefix).

# 3. The Day 11 EC2 dry-run pivot check, re-run:
aws ec2 run-instances --dry-run --instance-type m5.24xlarge \
  --image-id ami-00000000000000000
# Expected: UnauthorizedOperation — NOT AccessDenied. EC2's dry-run
# convention is its own: DryRunOperation means the call WOULD have
# succeeded (permission check passed), UnauthorizedOperation means the
# permission check failed. Every other service in this checklist
# (S3/DynamoDB/KMS/IAM) returns the generic AccessDenied for a deny —
# EC2 is the one exception, and UnauthorizedOperation here is the
# correct proof that DenyEc2ComputePivot is working, regardless of
# whether your Day 11 attack-SOLUTION.md recorded DryRunOperation or
# UnauthorizedOperation for the pre-fix run.
```

Unset the exported credentials once you're done
(`unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`,
same as `attack.sh` does) — record every one of the outputs above in
`labs/capstone/defend-SOLUTION.md`.

## Exercises

See `content/day12-ir-capstone-defend.md` § Exercises.

## Then: run the CERT-MAP self-assessment

Open [`content/CERT-MAP.md`](../../content/CERT-MAP.md) and score
yourself, honestly, on all six domains — the checklist is there, this
is the day it's meant to be run. Record your scores and any domain
below 3 in `journal.md`.

## Teardown — FINAL SWEEP (exhaustive, this is the last day)

Unlike every prior day, **`labs/base` gets destroyed today too** —
nothing in this sprint is meant to outlive Day 12. Work through every
item below, in order. Don't skip any — this is the single most
expensive place in the whole path to leave something running by
accident.

### 1. Destroy this lab's day-specific resources first

```bash
cd labs/day12
terraform destroy
```
Confirms: the WAF Web ACL + association, the eradicate Deny policy,
and (if created) the leaked-user fixture are all gone.

**Manual cleanup for anything created via CLI during CONTAIN (not
tracked in Terraform state — Terraform doesn't know about it):**
```bash
aws iam delete-role-policy --role-name <task_role_name> \
  --policy-name emergency-quarantine 2>/dev/null || true   # no-op if already removed in RECOVER
aws iam list-access-keys --user-name <leaked_user_name>    # confirm empty/deleted
```

### 2. Destroy every other day module (any you applied and left up)

In any order — none of Days 1–11 depend on each other, only on base:
```bash
for d in day11 day10 day09 day08 day07 day06 day05 day04 day03 day02 day01; do
  (cd "../$d" && terraform destroy) 2>/dev/null || true
done
```
(`|| true` because some days may never have been left applied — that's
fine, `terraform destroy` on an empty/no-state directory is a no-op or
errors harmlessly; don't let one already-clean day stop the loop.)

### 3. Destroy `labs/base` — the persistent workload, for the first and
   only time this sprint

```bash
cd ../base
terraform destroy
```
Confirms: VPC, ALB, ALB listener/target group, ECS Fargate service +
cluster, CloudFront distribution, S3 bucket (app data), DynamoDB
table, Secrets Manager secret, and the base task/execution IAM roles
are all gone.

**CloudFront note:** distribution deletion can take 15–20 minutes
(CloudFront must first move to a fully "Deployed" disabled state
before Terraform can delete it). `terraform destroy` handles this, but
don't `Ctrl-C` out of an apparently-stuck destroy on the CloudFront
resource — let it finish.

### 4. Disable + confirm-off every detection service, this region AND every other region you ever touched

```bash
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  echo "=== $region ==="

  # GuardDuty
  for det_id in $(aws guardduty list-detectors --region "$region" --query 'DetectorIds' --output text); do
    aws guardduty delete-detector --detector-id "$det_id" --region "$region"
    echo "GuardDuty detector $det_id deleted in $region"
  done

  # Security Hub
  aws securityhub disable-security-hub --region "$region" 2>/dev/null \
    && echo "Security Hub disabled in $region"

  # Macie
  aws macie2 disable-macie --region "$region" 2>/dev/null \
    && echo "Macie disabled in $region"

  # Detective (if ever enabled)
  for graph_arn in $(aws detective list-graphs --region "$region" --query 'GraphList[].Arn' --output text); do
    aws detective delete-graph --graph-arn "$graph_arn" --region "$region"
    echo "Detective graph $graph_arn deleted in $region"
  done
done
```
**Confirm-off, don't just trust the command exited 0:**
```bash
aws guardduty list-detectors --region <your-primary-region>   # expect: empty list
aws securityhub describe-hub --region <your-primary-region>   # expect: an error (hub not found/not subscribed)
aws macie2 get-macie-session --region <your-primary-region>   # expect: an error (not enabled)
```

### 5. Schedule deletion for every CMK you created (KMS cannot force-delete immediately)

```bash
aws kms schedule-key-deletion \
  --key-id <app_data_kms_key_id> \
  --pending-window-in-days 7
```
**Note the 7-day window explicitly:** the key still exists and still
bills its small monthly fee (prorated) during the pending-deletion
window — this is *expected*, not a leftover resource to chase down.
Come back after 7 days and confirm:
```bash
aws kms describe-key --key-id <app_data_kms_key_id> \
  --query 'KeyMetadata.KeyState'   # expect: "PendingDeletion" now,
                                     # then eventually the key is gone
                                     # and this command 404s
```
Do this for **every** CMK created across the whole sprint (Day 3/4's
labs may have created additional ones) — check with:
```bash
aws kms list-keys --query 'Keys[].KeyId' | \
  xargs -I{} aws kms describe-key --key-id {} \
  --query '[KeyMetadata.KeyId,KeyMetadata.KeyManager,KeyMetadata.KeyState]'
```
Only schedule deletion for keys with `KeyManager: CUSTOMER` — never
touch `AWS`-managed keys.

### 6. Global cross-region billable-resource sweep

Run this loop across every region in your account (not just the one
you deployed in — a stray resource from an earlier day, created by
accident in the wrong region, is the classic "why is there still a
charge" surprise):

```bash
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  echo "=== $region ==="
  aws ecs list-clusters --region "$region" --query 'clusterArns' --output text
  aws elbv2 describe-load-balancers --region "$region" --query 'LoadBalancers[].LoadBalancerArn' --output text
  aws rds describe-db-instances --region "$region" --query 'DBInstances[].DBInstanceIdentifier' --output text
  aws ec2 describe-instances --region "$region" --filters Name=instance-state-name,Values=running,stopped \
    --query 'Reservations[].Instances[].InstanceId' --output text
  aws ec2 describe-nat-gateways --region "$region" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text
  aws ec2 describe-addresses --region "$region" --query 'Addresses[].AllocationId' --output text
  aws wafv2 list-web-acls --region "$region" --scope REGIONAL --query 'WebACLs[].Name' --output text
  aws dynamodb list-tables --region "$region" --output text
  aws secretsmanager list-secrets --region "$region" --query 'SecretList[].Name' --output text
  aws logs describe-log-groups --region "$region" --query 'logGroups[].logGroupName' --output text
done

# Global (not per-region) services — check once:
aws s3api list-buckets --query 'Buckets[].Name' --output text
aws cloudfront list-distributions --query 'DistributionList.Items[].Id' --output text
aws iam list-users --query 'Users[].UserName' --output text
aws iam list-roles --query 'Roles[?starts_with(RoleName, `aws-sec-lab`)].RoleName' --output text
aws acm list-certificates --query 'CertificateSummaryList[].DomainName' --output text
```

Every list above should come back **empty** (except: the S3 bucket
list may briefly still show the app-data bucket's name until deletion
propagates; global IAM lists should be empty of `aws-sec-lab-*` named
resources once base + all day modules are destroyed and the leaked-user
fixture and any CLI-created break-glass policy are cleaned up).

### 7. Leave in place (do NOT delete)

- The **AWS Budget** and **CloudWatch billing alarm** from README's
  STEP 0 — these are account-level guardrails meant to outlive every
  sprint, not lab resources.
- Anything genuinely unrelated to this path (don't let this sweep
  become a general account audit beyond what you stood up here).

### 8. Final confirmation

Check the AWS Cost Explorer / Billing dashboard once, 24–48 hours
after this sweep, to confirm no unexpected charge is still accruing —
some services (CloudFront, WAF) have a short propagation delay before
their last hour of usage stops appearing.
