# Foundation stack

This is the one Terraform stack that every other lab in this path depends
on. It creates a VPC with two public subnets (spread across two
availability zones) and an ECR repository, and nothing else. Every day lab
(`labs/day01/` … `labs/day05/`) reads its outputs via a `terraform_remote_state`
data source rather than recreating its own networking or its own registry.

## Why this exists as its own stack

If every day lab created its own VPC and its own ECR repository, the image
you built on Day 1 would not be the same image Day 3 deploys, and the
network Day 3's ALB lives in would not be the network Day 4's `kind` cluster
talks to when it pulls that image. The whole point of this path is that you
build one artifact once and carry it — and the infrastructure it runs in —
through five days of labs. A foundation stack that outlives any single lab
is what makes that chain of custody (source → image → registry → running
task) a fact you can trace in `terraform show`, not a story you have to take
on faith.

Concretely, this stack owns:

- **VPC** (`aws_vpc.this`, `10.42.0.0/16`) with DNS hostnames and DNS support
  enabled.
- **Internet Gateway**, attached to the VPC.
- **Two public subnets** (`aws_subnet.public`, one per AZ,
  `10.42.0.0/24` / `10.42.1.0/24`), each with `map_public_ip_on_launch = true`.
- **One route table**, `0.0.0.0/0` → the Internet Gateway, associated with
  both subnets.
- **One ECR repository** (`aws_ecr_repository.sample`, immutable tags, scan
  on push) plus a lifecycle policy that keeps the 10 most recent images.

## Run order

```bash
cd labs/foundation
cp terraform.tfvars.example terraform.tfvars   # optional — defaults already match
terraform init
terraform plan
terraform apply
```

The outputs you'll need for every later lab:

| Output                 | Type          | Used for |
|-------------------------|---------------|----------|
| `vpc_id`                | string        | Security groups, ECS/kind networking |
| `public_subnet_ids`     | list(string)  | Fargate `network_configuration`, ALB subnets |
| `ecr_repository_url`    | string        | `docker push` / `docker pull` target |
| `ecr_repository_arn`    | string        | IAM policies (Day 1, Day 2) |
| `ecr_repository_name`   | string        | CodeBuild buildspec, Day 3 task definitions |

Day labs read these through:

```hcl
data "terraform_remote_state" "foundation" {
  backend = "local"
  config  = { path = "../foundation/terraform.tfstate" }
}
```

## Cost: approximately $0/month

Broken down line by line:

- **VPC, Internet Gateway, subnets, route table, route table associations** —
  all free. AWS does not charge for these resources by themselves.
- **ECR storage** — the sample image is roughly 15 MB. The lifecycle policy
  keeps at most 10 tagged images, so worst case is ~150 MB, which at ECR's
  per-GB-month storage price rounds to well under a cent per month.
- **Image scanning** — basic scanning (`scan_on_push = true`) is free.
  (Enhanced scanning, which this stack does not enable, is not.)
- **Data transfer** — pulling the image into Fargate or `kind` a handful of
  times a day during the course of the labs is negligible.

The one line item that would actually cost money — a NAT gateway, at roughly
$0.045/hour plus per-GB data processing, which adds up to real money over a
week left running — is **not present anywhere in this stack, or anywhere in
this path.**

## Public subnets: a cost decision, not a security recommendation

Every subnet in this stack is public, and Day 3's Fargate tasks run in them
directly with `assign_public_ip = true`. **This is deliberate, and it is a
tradeoff made for lab cost, not a pattern to copy into production.**

In a real production environment, application workloads like these belong in
**private subnets**, reachable only through a load balancer in a public
subnet, with outbound internet access (for pulling images, calling AWS APIs,
hitting third-party endpoints) provided by either:

- **A NAT gateway** — roughly $0.045/hour (~$32/month per gateway, and you
  typically want one per AZ for high availability, so ~$65/month for two)
  plus ~$0.045/GB of data processed. What it buys: outbound-only internet
  access for private-subnet resources, so your compute is never directly
  reachable from the internet even by misconfiguration, and every outbound
  flow is a single choke point you can log and monitor (VPC Flow Logs on the
  NAT ENI).
- **VPC endpoints** (Gateway endpoints for S3/DynamoDB are free; Interface
  endpoints for services like ECR, CloudWatch Logs, and Secrets Manager run
  roughly $0.01/hour per endpoint per AZ plus data processing) — what they
  buy is AWS API traffic that never leaves the AWS network at all, which is
  both a cost optimization versus NAT data-processing charges at scale and a
  tighter security boundary.

You should be able to state, out loud, what running this stack's Fargate
tasks in private subnets behind a NAT gateway would cost per month and what
it would buy you (no direct inbound reachability from the internet to task
ENIs) versus what the public-subnet lab setup buys you (zero dollars, one
fewer moving part while you're learning the rest of the pipeline). That
tradeoff, made explicitly, is the point — not the specific numbers, which
change over time and by region.

## When to destroy this

**Not between labs.** This stack is meant to stay up all week — see
`teardown.md` for the correct destroy order, which is: destroy the day labs
first, this stack last, after Day 5.
