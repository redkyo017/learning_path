# Day 0 — Setup

## Why this matters

Every day of this sprint assumes `labs/base` is already up, reachable,
and billing-guarded. Do that work once, here, instead of re-discovering
it mid-Day-1. Work this checklist top to bottom, in order — the billing
guardrail comes before anything else touches AWS, on purpose.

## Prerequisites

- [ ] An **isolated personal/sandbox AWS account** — not production, not
      shared with anything else you care about. This path deploys a
      workload with a deliberate, unauthenticated SSRF endpoint
      (`/fetch?url=`) and a task role that is intentionally over-broad
      within its own bucket (see `labs/base/README.md`'s warning banner).
      "Scoped to this workload" is only a real safety boundary if this
      workload is the only thing of value in the account.
- [ ] AWS CLI v2, configured (`aws configure` or an SSO profile) —
      confirm with `aws sts get-caller-identity`.
- [ ] Terraform **≥ 1.6**, AWS provider **≥ 5.0** — confirm with
      `terraform version`.
- [ ] `python3`, `jq`, `curl` available on your PATH.
- [ ] Docker, and an ECR repo you can push to (needed to build/push the
      app image below).
- [ ] A region picked for the whole sprint and noted in your own
      `terraform.tfvars` (never in a file that ships in git) — a
      second-AZ, single-region setup keeps cost and complexity down.
      `labs/base` defaults to `us-east-1`; every day-lab module must use
      the same region as base.

## Step 0 — Billing guardrail (do this before anything else)

This path targets **under $15 for the entire 12-day sprint**. The
guardrail below must be in place **before your first `terraform apply`**,
and it must stay up for the **whole sprint** — never tear it down along
with a day's workload.

- [ ] Create the AWS Budget from README.md's STEP 0 (`aws budgets
      create-budget ...`), filling in your account ID
      (`aws sts get-caller-identity --query Account --output text`), a
      budget limit a little above $15 (e.g. `20`), and an email you
      actually check.
- [ ] In the Billing Console, under **Billing preferences**, check
      **"Receive Billing Alerts"** (this one step cannot be done via
      Terraform or the CLI — it's a manual prerequisite for the alarm
      below).
- [ ] Apply the CloudWatch billing alarm + SNS topic from README.md's
      STEP 0 (the `us-east-1`-aliased provider block, `aws_sns_topic`,
      `aws_sns_topic_subscription`, `aws_cloudwatch_metric_alarm`) —
      outside `labs/`, in its own small `.tf` you don't commit, since
      it's account-level and must outlive every `terraform destroy` you
      run inside `labs/`.
- [ ] Confirm the SNS email subscription (check your inbox for the
      confirmation link).

## Safety acknowledgement

- [ ] Read the **Authorized-testing statement** in
      [`content/ANTIPATTERNS.md`](ANTIPATTERNS.md#authorized-testing-statement):
      every offensive technique in this path — every "break" half of a
      break→harden lab, the Day 11–12 IR capstone included — targets
      only your own AWS account and your own Terraform-deployed
      workload. Nothing here runs against any account or resource you
      don't own and aren't explicitly authorized to test.
- [ ] Confirm the account you configured above is that isolated,
      learner-owned account — not one you share with a team or that
      holds anything you'd mind losing.

## Deploy the base workload once

`labs/base` is the one persistent 3-tier workload every day of this
sprint attacks and hardens. Stand it up once, here, and leave it up for
the whole session/sprint (see "Understand the rhythm" below).

- [ ] Build and push the app image (skip only if you plan to apply
      everything else first and come back — the ECS service will just
      sit at 0/1 `RUNNING` until a real image exists):
      ```bash
      cd labs/base/app
      aws ecr create-repository --repository-name aws-sec-lab-app   # once
      aws ecr get-login-password --region <region> \
        | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
      docker build -t aws-sec-lab-app .
      docker tag aws-sec-lab-app:latest <account_id>.dkr.ecr.<region>.amazonaws.com/aws-sec-lab-app:latest
      docker push <account_id>.dkr.ecr.<region>.amazonaws.com/aws-sec-lab-app:latest
      ```
- [ ] `cd labs/base && cp terraform.tfvars.example terraform.tfvars` and
      edit it — `region`, `project`, and `app_image` (the URI you just
      pushed) at minimum.
- [ ] `terraform init`
- [ ] `terraform plan` — review what's about to come up (VPC, ALB, ECS
      Fargate service, CloudFront, S3, DynamoDB, Secrets Manager secret,
      KMS CMK, the task + task-execution IAM roles).
- [ ] `terraform apply`
- [ ] Set the Secrets Manager secret's value out-of-band (it's created
      with no value — never put a real value in Terraform):
      ```bash
      aws secretsmanager put-secret-value \
        --secret-id "$(terraform output -raw secret_arn)" \
        --secret-string 'whatever-placeholder-value-you-want'
      ```
- [ ] Reach the app directly via the ALB (bypasses CloudFront, fastest
      while iterating):
      ```bash
      curl "http://$(terraform output -raw alb_dns_name)/"
      curl "http://$(terraform output -raw alb_dns_name)/whoami"
      ```
      Confirm both return a response.
- [ ] Reach the app through CloudFront (matches what a real viewer
      sees) — **CloudFront distributions take several minutes to reach
      `Deployed` after apply**, so this may not succeed immediately:
      ```bash
      aws cloudfront get-distribution --id "$(terraform output -raw cloudfront_distribution_id)" \
        --query 'Distribution.DomainName' --output text
      curl "https://<that-domain>/"
      ```

## Understand the rhythm

- [ ] I understand `labs/base` comes up **once per session** and stays
      up while I work — it is not torn down and rebuilt daily.
- [ ] I understand each `labs/dayNN/` module is layered **on top of**
      `labs/base` — it reads base's outputs (`vpc_id`, `alb_listener_arn`,
      `task_role_arn`, `app_bucket_arn`, and so on) via
      `terraform_remote_state` pointed at `../base/terraform.tfstate`,
      rather than redeclaring anything.
- [ ] I understand the daily loop: apply the day's module → break → harden
      → journal → `terraform destroy` *that day's module only* (base
      stays up).

## Daily teardown model (end of a session)

`labs/base` itself is **not** destroyed daily. Only the hourly-billing
pieces come down between sessions — the persistent data resources stay
up for the whole sprint:

- [ ] Any day-lab module layered on top of base is destroyed **first**
      (check that day's own teardown checklist) before touching base.
- [ ] Tear down base's hourly pieces with `-target`:
      ```bash
      cd labs/base
      terraform destroy \
        -target=aws_ecs_service.app \
        -target=aws_lb_listener.http \
        -target=aws_lb_target_group.app \
        -target=aws_lb.app \
        -target=aws_cloudfront_distribution.app
      ```
- [ ] Confirm: no running ECS tasks/services; no ALB or CloudFront
      distribution left `Active`/`Deployed` (CloudFront deletion can take
      several minutes — expected); `terraform plan` afterward shows only
      those 5 resources (plus dependents) needing re-creation, with the
      KMS key, S3 bucket, DynamoDB table, and secret showing **no
      changes**.
- [ ] Leave the KMS CMK, S3 bucket, DynamoDB table, and Secrets Manager
      secret **up** for the whole sprint. Why: destroying/recreating the
      CMK daily doesn't stop its charge — it enters a mandatory 7-day
      `PendingDeletion` window that keeps billing regardless, and doing
      that 12 times can stack several overlapping pending-deletion keys
      billing at once. Leaving the cheap, flat-rate data resources up the
      whole sprint avoids that churn and keeps cost tiny.
- [ ] To resume next session: `terraform apply` in `labs/base` (recreates
      just the targeted pieces; the data tier is untouched, so no new
      `PendingDeletion` entries accumulate).

**Special case:** the detection stack (GuardDuty, Security Hub, Macie,
Detective) enabled on Day 8 runs on a single 30-day free-trial clock and
is the one exception to "destroy daily" — it stays on overnight into Day
9, which turns it off, and is re-enabled only for the Days 11–12
capstone. That rhythm is covered in `labs/day08/README.md` and
`labs/day09/README.md`, not here.

## End-of-sprint

- [ ] Not today's job — noted here so you know it's coming. Day 12 runs
      the exhaustive final sweep: `terraform destroy` across base and
      every day module, confirmation that all four detection services
      are off, a scheduled-deletion check for every CMK created along
      the way, and a cross-region check. See
      [`content/day12-ir-capstone-defend.md`](day12-ir-capstone-defend.md)
      and `labs/base/README.md`'s end-of-sprint teardown section.

## Ready check — you're ready for Day 1 when

- [ ] `labs/base` is applied and `terraform state list` shows its
      resources.
- [ ] The app responds on both the direct ALB URL and (once `Deployed`)
      the CloudFront URL, on `/` and `/whoami`.
- [ ] The AWS Budget and CloudWatch billing alarm are live and the SNS
      email subscription is confirmed.
- [ ] You understand the apply → break → harden → teardown rhythm above,
      and that base itself is a once-per-session, not once-per-day,
      concern.

Next: [`content/day01-iam-engine.md`](day01-iam-engine.md).
