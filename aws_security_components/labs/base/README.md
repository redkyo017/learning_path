# `labs/base` — the persistent 3-tier workload

This is the ONE workload every day of the AWS Security Mastery sprint attacks
and hardens. It comes up once per session; each `labs/dayNN/` module layers
on top of it (via its outputs) instead of building its own copy. See
**Teardown checklist** below for what to tear down daily vs. at the end of
the whole sprint — it is not a simple "destroy everything every day".

> **⚠️ Deliberately vulnerable — isolated account only.** This workload's
> app has an intentional, unauthenticated SSRF endpoint (`/fetch?url=`) and
> its task role is intentionally over-broad within this workload (see
> `iam.tf`). Deploy this **only in an isolated personal/sandbox AWS
> account that holds nothing else you care about**. Never deploy it into a
> production account or one shared with other real workloads/buckets/data.

## What it is

```
                         internet
                            │
                            ▼
                  ┌───────────────────┐
                  │   CloudFront (CDN)│   viewer HTTPS, default cert
                  └─────────┬─────────┘
                            │ HTTP (origin)
                            ▼
                  ┌───────────────────┐
                  │  ALB  (public subnets, :80)  │
                  └─────────┬─────────┘
                            │ :8080
                            ▼
        public subnets (2 AZ) — NAT-free design
        ┌─────────────────────────────────────┐
        │  ECS Fargate task ("app")            │
        │  Flask app: /, /fetch?url=, /whoami  │───┐
        │  task role (S3 grant broad WITHIN     │   │
        │  this workload's bucket only, not     │   │
        │  account-wide — Day 1 tightens)       │   │
        └─────────────────────────────────────┘   │
                            │                        │
              ┌─────────────┼────────────┐          │
              ▼             ▼             ▼          │
        S3 app-data   DynamoDB table  Secrets Manager │
        (SSE-KMS,     (SSE-KMS CMK,   secret          │
        public-access  DB tier         (value set     │
        block ON)      stand-in)       out-of-band) ◄─┘

        private subnets (2 AZ) — reserved, no default
        internet route; empty until a day-lab adds
        something here.
```

Components and why:

| Tier | Resource | Notes |
|---|---|---|
| Network | 1 VPC, 2 AZ, public + private subnets | **No NAT Gateway** — see "NAT-free design" below |
| Edge | ALB (HTTP:80) + CloudFront | CloudFront gives viewers HTTPS on its default cert; origin to ALB is HTTP |
| Compute | ECS Fargate service, 1 task | Runs the app at `app/` — a tiny Flask app with a deliberate SSRF endpoint (`/fetch`) so the Day 8/11 lab has something real to exploit |
| Data | S3 bucket, DynamoDB table, KMS CMK | S3 = "app data" object storage (public access blocked). DynamoDB = the DB tier stand-in (see below). Both encrypted at rest with one customer-managed KMS key |
| Secrets | Secrets Manager secret | Resource only — **no value in Terraform**, set out-of-band |
| Identity | Task execution role + task role | Task role has one statement that's **broad within this workload's own bucket** (marked in `iam.tf`) — never account-wide — that Day 1's break→harden lab tightens |

### Design decisions (read before you file an issue)

- **NAT-free.** No NAT Gateway (~$32/mo if left running is disproportionate
  for a lab torn down daily). The ALB and the ECS task's ENI both live in
  the public subnets; the task gets a public IP so it can pull its image
  and make outbound calls, but inbound is still gated by its security
  group (only the ALB can reach it). Private subnets exist and are
  exported (`private_subnet_ids`) for any day-lab that wants genuinely
  private placement, but they have no default internet route — add a NAT
  Gateway or VPC endpoint yourself in that day's module if you need one. A
  free S3 gateway endpoint is already attached to both route tables.
- **DB tier = DynamoDB, not RDS.** A `db.t4g.micro` RDS instance bills
  hourly and takes 5-10 minutes to create/destroy — expensive in learner
  *time* across 12 daily up/down cycles, on top of the dollar cost.
  DynamoDB in `PAY_PER_REQUEST` mode has no idle charge, no storage
  minimum, is ready in seconds, and still uses a customer-managed KMS key
  for encryption-at-rest — the actual teaching point transfers directly to
  RDS if a later day wants to swap it in. `db_endpoint` documents this
  stand-in explicitly (it's the regional DynamoDB service endpoint + table
  name, not a per-instance connection string — there is no instance).
- **App image is BYO.** No safe, off-the-shelf public image exposes a
  server-side URL-fetch endpoint, so the base workload ships its own
  minimal source at `app/` (`app.py` + `Dockerfile`, ~65 lines of Flask).
  You build and push it once to your own ECR repo — see below. Until you
  do, `app_image` defaults to a placeholder URI that fails to pull; every
  other resource still applies and the ECS service will just sit at 0/1
  RUNNING until you supply a real image, so this never blocks the rest of
  the workload coming up.
- **HTTPS via CloudFront's default cert**, not ACM+Route53 — a hosted
  zone for a throwaway lab domain would add a recurring $0.50/mo charge
  for no teaching value.

## Prerequisites

- **An isolated personal/sandbox AWS account, not a production or shared
  one.** This is not optional — see the warning above. The task role's
  broad-within-this-workload S3 grant and the app's deliberate SSRF hole
  are scoped to this workload's own resources, but "scoped to this
  workload" is only a meaningful safety boundary if this workload is the
  only thing of value in the account.
- Terraform >= 1.6, AWS provider >= 5.0.
- An AWS account with credentials available via the standard chain (env
  vars, `~/.aws/credentials`, SSO, etc.) and a billing alarm/budget already
  set up (see the top-level `aws_security_components/README.md` STEP-0).
- Docker, and an ECR repo you can push to (for the app image).
- **Terraform is not run by this document's author** — you run
  `terraform init/plan/apply/destroy` yourself. Nothing here runs `git` or
  makes AWS calls on your behalf.

## Build and push the app image

Do this once, before your first `apply` (or apply everything else first and
come back — the ECS service will just wait):

```bash
cd labs/base/app
aws ecr create-repository --repository-name aws-sec-lab-app   # once
aws ecr get-login-password --region <region> \
  | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
docker build -t aws-sec-lab-app .
docker tag aws-sec-lab-app:latest <account_id>.dkr.ecr.<region>.amazonaws.com/aws-sec-lab-app:latest
docker push <account_id>.dkr.ecr.<region>.amazonaws.com/aws-sec-lab-app:latest
```

Set `app_image` in your `terraform.tfvars` to that pushed URI.

## Bring the workload up

```bash
cd labs/base
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: region, project, app_image at minimum
terraform init
terraform plan
terraform apply
```

## Set the secret value (out-of-band, never in Terraform)

The secret resource is created with **no value**. Set one after apply:

```bash
aws secretsmanager put-secret-value \
  --secret-id "$(terraform output -raw secret_arn)" \
  --secret-string 'whatever-placeholder-value-you-want'
```

## Reach the app

```bash
# Direct to the ALB (bypasses CloudFront, fastest to use while iterating):
curl "http://$(terraform output -raw alb_dns_name)/"
curl "http://$(terraform output -raw alb_dns_name)/whoami"

# Through CloudFront (matches what a "real" viewer sees):
aws cloudfront get-distribution --id "$(terraform output -raw cloudfront_distribution_id)" \
  --query 'Distribution.DomainName' --output text
curl "https://<that-domain>/"
```

CloudFront distributions take several minutes to reach `Deployed` after
`apply` — use the direct ALB URL while it's still propagating.

## Outputs contract

Every value in `outputs.tf` is consumed by later day-lab modules (via
`terraform_remote_state` pointed at this state, or a documented data
source). Do not rename these:

`vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `alb_arn`,
`alb_dns_name`, `alb_listener_arn`, `cloudfront_distribution_id`,
`ecs_cluster_arn`, `ecs_service_name`, `task_role_arn`,
`task_execution_role_arn`, `app_bucket_name`, `app_bucket_arn`,
`db_endpoint`, `secret_arn`.

## Cost note

What actually bills while this is up (per-hour components; everything else
below is pay-per-request/negligible for lab traffic volumes):

| Resource | Approx. cost while running |
|---|---|
| ALB | ~$0.0225/hr + a few cents of LCU usage |
| Fargate task (0.25 vCPU / 0.5 GB) | ~$0.012/hr |
| KMS CMK | ~$1/mo, prorated hourly (~$0.0014/hr) — **keeps billing through the mandatory 7-day `PendingDeletion` window after `destroy`, not just while `Enabled`** (see below) |
| CloudFront, S3, DynamoDB, Secrets Manager, CloudWatch Logs | pay-per-request/GB, negligible at lab traffic |
| NAT Gateway | **$0 — not deployed** (see NAT-free design above) |

**Why the KMS line matters for the <$15 target:** destroying and
recreating the CMK every session doesn't stop its charge at `destroy` — it
enters `PendingDeletion` and AWS keeps billing the prorated ~$1/mo fee for
the full 7-day window regardless. Do that 12 times across the sprint and
you can end up with several overlapping pending-deletion keys all billing
at once, which eats into the budget for no teaching benefit (you're not
re-doing the CMK lesson each day). The fix is below: **don't destroy/recreate
the CMK (or the other cheap, non-hourly data resources) daily** — only the
per-hour compute/edge pieces need a daily cycle.

## Teardown: daily vs. end-of-sprint

This is **not** "run `terraform destroy` every day." Split what you tear
down by why it costs money:

- **Bills per-hour while running** (tear these down daily): ALB, the ECS
  Fargate service/task, CloudFront.
- **Bills flat/negligible regardless of uptime, and re-creating it daily
  actively costs more** (leave these up for the whole sprint): the KMS
  CMK, the S3 bucket, the DynamoDB table, the Secrets Manager secret, and
  all the free control-plane resources (VPC, subnets, route tables, IAM
  roles, security groups, ECS cluster).

### Daily teardown (end of a session)

Destroy only the hourly-billing pieces, using `-target`:

```bash
cd labs/base
terraform destroy \
  -target=aws_ecs_service.app \
  -target=aws_lb_listener.http \
  -target=aws_lb_target_group.app \
  -target=aws_lb.app \
  -target=aws_cloudfront_distribution.app
```

Then confirm:

- [ ] AWS Console (or CLI) shows no running ECS tasks/services.
- [ ] No ALB or CloudFront distribution left `Active`/`Deployed` (CloudFront
      deletion can take several minutes to finish — that's expected).
- [ ] `terraform plan` afterward shows only those 5 resources (plus their
      dependents, e.g. the ALB security group rule that references them)
      as needing to be re-created — the KMS key, S3 bucket, DynamoDB
      table, and secret should show **no changes**.

To bring the day's compute/edge back up next session: `terraform apply`
(it recreates just what was targeted for destruction; the persistent data
tier is untouched, so no new KMS `PendingDeletion` entries accumulate).

Any day-lab module layered on top of this workload must be destroyed
**first**, before you run the daily teardown above — check that day's own
teardown checklist.

### End-of-sprint teardown (you are done with the whole thing)

Only now destroy everything:

```bash
cd labs/base
terraform destroy
```

Then confirm:

- [ ] `terraform state list` is empty (or the command errors because the
      state file is gone — either is fine).
- [ ] The KMS key shows `PendingDeletion` (not `Enabled`) — this is
      unavoidable AWS behavior (7-day minimum window) and will keep
      billing the prorated ~$1/mo through that window; that's expected and
      already accounted for in the <$15 sprint budget as a one-time tail
      cost, not a recurring one, because you only did this once.
- [ ] The S3 bucket and DynamoDB table are gone (Terraform deletes both;
      if the bucket delete fails because it has objects in it, empty it
      manually and re-run `destroy`).
- [ ] Your ECR repo/image is untouched by `destroy` (it's outside this
      Terraform state) — leaving it costs pennies of storage; delete it
      manually if you're done with the whole sprint.
