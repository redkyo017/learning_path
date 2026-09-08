# AWS Network Mastery — Offline Study Guide

Keep this file open as your daily navigator. Everything you need is in this folder.

---

## File Map

```
aws_network_components/
├── README.md                          ← You are here (open every day)
├── journal.md                         ← Write one entry per day after you finish
├── content/
│   ├── day01.md … day08.md            ← Theory files — read FIRST each day
├── docs/superpowers/
│   ├── specs/2026-07-17-aws-network-mastery-design.md   ← Design decisions (reference)
│   └── plans/2026-07-17-aws-network-mastery-plan.md     ← LAB GUIDE — Console + Terraform steps
├── scripts/
│   └── sweep.sh                       ← Run after EVERY teardown (see Cost Control)
└── terraform/
    ├── modules/
    │   ├── vpc/         ← Pre-written module (answer key for Day 1)
    │   ├── security/    ← Answer key for Day 2
    │   ├── dns/         ← Answer key for Day 3
    │   ├── tgw/         ← Answer key for Day 4
    │   ├── endpoints/   ← Answer key for Day 5
    │   ├── vpn/         ← Answer key for Day 6
    │   ├── ram/         ← Answer key for Day 7
    │   └── ec2_test/    ← Harness: SSM-managed test instances (Days 2-8)
    └── envs/sandbox/
        ├── main.tf           ← YOU EDIT THIS: add one module block per day
        ├── main.complete.tf  ← Answer key: the fully assembled 8-day main.tf
        ├── outputs.tf        ← Uncomment outputs as you add modules
        ├── variables.tf      ← All variables incl. the enable_* day toggles
        ├── terraform.tfvars  ← Your values: region + profile already set
        └── day01…day08.tfvars ← Per-day toggles: which modules that day needs
```

**Each day runs on its own.** Every module except the VPC is gated behind an
`enable_*` flag, and `dayNN.tfvars` turns on exactly what that day needs. You
can run Day 5 on a clean account without having run Day 4:

```bash
terraform apply   -var-file=day05.tfvars -auto-approve
terraform destroy -var-file=day05.tfvars -auto-approve
```

Always pass the **same** `-var-file` to `destroy` that you passed to `apply`.

**Primary guide each day:** `docs/superpowers/plans/2026-07-17-aws-network-mastery-plan.md`
Find the `## Day N` section — it has all Console steps and Terraform code verbatim.

---

## One-Time Setup (before Day 1, ~15 min)

### 1. Verify AWS CLI

```bash
aws sts get-caller-identity --profile sandbox
```

Expected: JSON with `Account`, `UserId`, `Arn`. If it fails, run `aws configure --profile sandbox` and enter your Access Key ID, Secret, region `ap-southeast-1`, output `json`.

### 2. Verify Terraform

```bash
terraform version
```

Expected: `Terraform v1.6.x` or newer. Install from https://developer.hashicorp.com/terraform/install if missing.

### 3. Initialize the sandbox (once)

```bash
cd aws_network_components/terraform/envs/sandbox
terraform init
```

No errors expected — there are no module calls yet, just the provider block. Re-run `terraform init` any time you add a new module block (Terraform will download its provider plugin for that module on the first run after adding it).

### 4. Skim the cost section below

NAT Gateways are the main cost driver. Read "Cost Control" now so it doesn't surprise you.

---

## Daily Routine (every day, ~2–3 hours)

```
Block 1 — Theory        (30–45 min)   content/dayNN.md
Block 2 — Console Lab   (45–60 min)   plan file → "Day N: Console Lab" section
Block 3 — Terraform Lab (30–45 min)   plan file → "Day N: Terraform Lab" section
Block 4 — Break-it      (15 min)      plan file → "Break-It Exercise" subsection
Close   — Teardown + Journal          Console checklist -> terraform destroy
                                      -var-file=dayNN.tfvars -> scripts/sweep.sh
```

**Open two files side-by-side:**
- Left: `content/dayNN.md` (theory — read top to bottom before touching AWS)
- Right: `docs/superpowers/plans/…-mastery-plan.md` (lab guide — follow step by step)

---

## Day-by-Day Navigator

### Day 1 — VPC Anatomy

**Theory:** `content/day01.md` — CIDR, 3-tier subnets (public/private/isolated), IGW, NAT Gateway, route tables, AZs.

**Goal:** Build a working VPC with public internet access, private subnets egressing through NAT, and isolated subnets with no route out.

**Add to `main.tf`** (paste after the provider block):

```hcl
module "shared_services_vpc" {
  source = "../../modules/vpc"

  name                  = "shared-services"
  cidr_block            = "10.0.0.0/16"
  azs                   = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs  = ["10.0.2.0/24", "10.0.3.0/24"]
  isolated_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24"]
}
```

Then uncomment the two outputs in `outputs.tf`.

**Terraform commands:**

```bash
terraform init                                  # pick up the new module source
terraform plan  -var-file=day01.tfvars          # expect exactly 22 to add
terraform apply -var-file=day01.tfvars          # ~3 min
```

22 = 1 VPC + 6 subnets + 1 IGW + 2 EIPs + 2 NAT GWs + 4 route tables
(1 public, **2** private — one per AZ — and 1 isolated) + 6 associations.

**Verify:** Console → VPC → Your VPCs → `shared-services` visible. Check route tables: public RT has `0.0.0.0/0 → igw-xxx`, each private RT has `0.0.0.0/0 → nat-xxx`, isolated RT has no default route.

**Cost:** 2 NAT Gateways @ ~$0.059/hr each ≈ $0.12/hr. Destroy at end of day —
and note that deleting a Console-built VPC does **not** release its NAT Gateway
Elastic IPs. Run `./scripts/sweep.sh` to catch them.

---

### Day 2 — Security Layer

**Theory:** `content/day02.md` — Security Groups (stateful, per-ENI) vs NACLs (stateless, per-subnet), VPC Flow Logs.

**Goal:** Attach tiered security groups (web/app/data), subnet-level NACLs, and enable Flow Logs to CloudWatch.

**Add to `main.tf`** (after Day 1 block):

```hcl
module "shared_services_security" {
  source = "../../modules/security"

  name               = "shared-services"
  vpc_id             = module.shared_services_vpc.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = module.shared_services_vpc.private_subnet_ids
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day02.tfvars   # ~2 min — 19 security + 8 harness = 27
```

**Verify:** Console → VPC → Security Groups — find `shared-services-web-sg`,
`shared-services-app-sg`, `shared-services-data-sg`. Console → CloudWatch → Log
Groups — find `/vpc/shared-services/flow-logs`.

`day02.tfvars` also sets `enable_ec2_test`, giving you two SSM-managed instances
in the private subnets to test the NACL with. Reach one with:

```bash
aws ssm start-session --profile sandbox \
  --target "$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')"
```

**Cost:** Negligible (SGs and NACLs are free; Flow Logs charge per GB ingested, minimal for a quiet sandbox).

---

### Day 3 — Private DNS

**Theory:** `content/day03.md` — Route 53 private hosted zones, split-horizon DNS, Resolver inbound/outbound endpoints.

**Goal:** Create a private zone `internal.platform`, add a test A record, and set up Resolver to forward queries for `corp.internal` to a simulated on-prem DNS.

**Add to `main.tf`** (after Day 2 block):

```hcl
module "shared_services_dns" {
  source = "../../modules/dns"

  name               = "shared-services"
  vpc_id             = module.shared_services_vpc.vpc_id
  private_subnet_ids = module.shared_services_vpc.private_subnet_ids
  resolver_sg_id     = module.shared_services_security.resolver_sg_id
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day03.tfvars   # ~2 min
```

**Verify:** Console → Route 53 → Hosted Zones → `internal.platform`. Check the Resolver outbound endpoint is `OPERATIONAL` (takes ~2 min after apply).

**⚠ Cost — the most expensive day of the course.** Resolver endpoints bill
**per IP address**, ~$0.125/hr each. Two endpoints × two IPs = **~$0.50/hr,
about $12/day**, accruing whether or not a single query is sent. There is no
free tier. Destroy at end of day and confirm with `./scripts/sweep.sh` — check
the `resolver endpoints` row specifically.

---

### Day 4 — Transit Gateway

**Theory:** `content/day04.md` — VPC Peering (bilateral, non-transitive) vs TGW (hub-and-spoke, transitive), TGW route table segmentation.

**Goal:** Spin up a second VPC (`app`), attach both VPCs to a Transit Gateway, and verify cross-VPC routing.

**Add to `main.tf`** (after Day 3 block):

```hcl
module "app_vpc" {
  source = "../../modules/vpc"

  name                  = "app"
  cidr_block            = "10.1.0.0/16"
  azs                   = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs   = ["10.1.0.0/24", "10.1.1.0/24"]
  private_subnet_cidrs  = ["10.1.2.0/24", "10.1.3.0/24"]
  isolated_subnet_cidrs = ["10.1.4.0/24", "10.1.5.0/24"]
}

module "tgw" {
  source = "../../modules/tgw"

  name = "platform"

  shared_services_vpc_id                  = module.shared_services_vpc.vpc_id
  shared_services_private_subnet_ids      = module.shared_services_vpc.private_subnet_ids
  shared_services_private_route_table_ids = module.shared_services_vpc.private_route_table_ids

  app_vpc_id                  = module.app_vpc.vpc_id
  app_private_subnet_ids      = module.app_vpc.private_subnet_ids
  app_private_route_table_ids = module.app_vpc.private_route_table_ids
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day04.tfvars   # ~5–7 min — TGW creation is slow
```

Note `day04.tfvars` deliberately leaves `enable_dns = false`. Day 4 doesn't need
the DNS layer, so you don't pay $0.50/hr for Resolver endpoints today.

**Verify:** Console → VPC → Transit Gateways → `platform` in `available` state. Check Transit Gateway Attachments — both VPCs attached. Check private route tables in each VPC — routes to `10.0.0.0/16` and `10.1.0.0/16` via the TGW attachment.

**Cost warning:** Now 4 NAT Gateways (2 per VPC × 2 VPCs) + TGW attachments
(~$0.05/hr in us-east-1, ~$0.07/hr in ap-southeast-1, + $0.02/GB). ~$0.40/hr
base. TGW destroy takes 5–10 min — let it finish, or attachments are orphaned
and keep billing.

---

### Day 5 — VPC Endpoints + PrivateLink

**Theory:** `content/day05.md` — Gateway endpoints (S3/DynamoDB, free, route-table based) vs Interface endpoints (ENI-based, private DNS), PrivateLink.

**Goal:** Add S3 gateway endpoint, SSM interface endpoints, and create a PrivateLink endpoint service backed by an NLB.

**Pre-step (Console, optional):** If you want to test a live PrivateLink service, create an NLB manually in the Console and note its ARN, then set `privatelink_nlb_arn` in tfvars.

Left at its `""` default the endpoint service is **skipped entirely** — it is
gated on the ARN with `count = var.nlb_arn == "" ? 0 : 1`. It is not created
"without an NLB target": an endpoint service requires at least one NLB ARN, and
passing an empty one fails the apply with `InvalidParameter`. The gate is what
lets Day 5 run without an NLB.

**Add to `main.tf`** (after Day 4 block):

```hcl
module "shared_services_endpoints" {
  source = "../../modules/endpoints"

  name                    = "shared-services"
  vpc_id                  = module.shared_services_vpc.vpc_id
  region                  = var.region
  private_subnet_ids      = module.shared_services_vpc.private_subnet_ids
  private_route_table_ids = module.shared_services_vpc.private_route_table_ids
  isolated_route_table_id = module.shared_services_vpc.isolated_route_table_id
  endpoint_sg_id          = module.shared_services_security.endpoint_sg_id
  nlb_arn                 = var.privatelink_nlb_arn
  allowed_principal_arns  = var.allowed_principal_arns
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day05.tfvars   # ~3 min
```

**Verify:** Console → VPC → Endpoints — find `com.amazonaws.ap-southeast-1.s3` (type: Gateway) and three SSM interface endpoints (type: Interface, status: available). Console → EC2 → Systems Manager → Session Manager — if you have an EC2 in a private subnet, you can now connect without a bastion.

**Cost:** Interface endpoints: 3 × 2 AZs × $0.01/hr = $0.06/hr. Gateway endpoint is free.

---

### Day 6 — Site-to-Site VPN

**Theory:** `content/day06.md` — Customer Gateway, two IPSec tunnels, BGP/static routing, strongSwan simulation.

**Goal:** Set up a VPN connection from the TGW to a simulated on-prem Customer Gateway (a t3.micro EC2 with an EIP).

**Pre-step (Console, required):**
1. Launch a `t3.micro` EC2 in the **`onprem-sim` VPC's** public subnet (Amazon
   Linux 2023) — see the plan file's Day 6 Console lab, which builds that VPC
   first. It represents on-prem, so it must not live inside `shared-services`.
2. Allocate and associate an Elastic IP to it.
3. Note the EIP (e.g. `1.2.3.4`).
4. Add it to `terraform.tfvars`:
   ```
   customer_gateway_ip = "1.2.3.4"
   ```

**Add to `main.tf`** (after Day 5 block):

```hcl
module "vpn" {
  source = "../../modules/vpn"

  name                                    = "onprem-sim"
  tgw_id                                  = module.tgw.tgw_id
  tgw_shared_services_route_table_id      = module.tgw.shared_services_route_table_id
  customer_gateway_ip                     = var.customer_gateway_ip
  shared_services_private_route_table_ids = module.shared_services_vpc.private_route_table_ids
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day06.tfvars   # ~2 min — Customer GW + VPN (2 tunnels)
```

**Verify:** Console → VPN → Site-to-Site VPN Connections → `onprem-sim`. Tunnels will show `DOWN` until strongSwan is configured on the EC2 (follow Day 6 plan for strongSwan setup — that is a Console/SSH step, not Terraform). Download the VPN configuration from Console (Vendor: Generic, IKEv2) to get pre-shared keys.

**Sensitive outputs (PSKs + tunnel addresses):**
```bash
terraform output -json | jq '{tunnel1_address, tunnel2_address}'
```
These are marked `sensitive = true` in Terraform — they won't print unless you use `-json`.

**⚠ Cost — highest total burn of the course.** The VPN itself is only ~$0.05/hr,
but today stacks two VPCs (4 NAT GWs), a TGW with 2 attachments, the
`onprem-sim` VPC with its own NAT GW, and the strongSwan instance + its EIP:
roughly **$1.10/hr, ~$26/day**. Do the whole day in one sitting. Remember to
release the strongSwan EIP — terminating the instance does not release it.

---

### Day 7 — Multi-Account Networking

**Theory:** `content/day07.md` — AWS RAM, cross-account TGW attachments, subnet sharing, cross-account PrivateLink.

**Goal:** Share the TGW and private subnets to a second AWS account using RAM.

**Pre-step:** You need a second sandbox account ID. If you don't have one, you can still apply — Terraform will create the RAM shares, but the principal association will need a valid account ID. Use a placeholder like `"123456789012"` to see the RAM resource structure, then set it to a real account when available.

Add to `terraform.tfvars`:
```
account_b_id = "YOUR_SECOND_ACCOUNT_ID"
```

**Add to `main.tf`** (after Day 6 block):

```hcl
data "aws_caller_identity" "current" {}

module "ram" {
  source = "../../modules/ram"

  name         = "platform"
  account_b_id = var.account_b_id
  tgw_arn      = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:transit-gateway/${module.tgw.tgw_id}"
  subnet_arns  = [
    for id in module.shared_services_vpc.private_subnet_ids :
    "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"
  ]
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day07.tfvars   # ~1 min
```

**If account B is outside your AWS Organization** (a separate personal sandbox,
which is the common case here) you must also set:

```hcl
allow_external_principals = true
```

Left `false` for an external account the share is created, the principal
association succeeds, and account B **never sees it** — with no error anywhere.

**Verify:** Console → Resource Access Manager → Shared by me → two shares: `platform-subnets` and `platform-tgw`. If you have Account B: log in, go to RAM → Shared with me → accept the TGW share. Then create a TGW attachment from Account B.

---

### Day 8 — Debugging + Reachability Analyzer

**Theory:** `content/day08.md` — Reachability Analyzer, Network Access Analyzer, VPC Flow Logs analysis, the 5-layer debugging ladder.

**Goal:** Use Reachability Analyzer to validate connectivity between two EC2 instances and interpret the analysis output.

**Pre-step: none.** Day 8 is the only day with no Console build step. The test
instances come from the harness (`enable_ec2_test` is set in `day08.tfvars`), so
the path resource reads their IDs directly — nothing to paste in, and the
instances are destroyed with everything else.

Each instance runs an echo server on port 8080, so the port-8080 tests have
something real to connect to.

**Add to `main.tf`** (after Day 7 block):

```hcl
resource "aws_ec2_network_insights_path" "a_to_b" {
  count            = var.enable_ec2_test && local.app_vpc_enabled ? 1 : 0
  source           = one(module.ec2_test_shared_services[*].instance_ids)[0]
  destination      = one(module.ec2_test_app[*].instance_ids)[0]
  protocol         = "tcp"
  destination_port = 8080
  tags             = { Name = "ec2-a-to-ec2-b-8080" }
}

resource "aws_ec2_network_insights_analysis" "a_to_b" {
  count                    = var.enable_ec2_test && local.app_vpc_enabled ? 1 : 0
  network_insights_path_id = aws_ec2_network_insights_path.a_to_b[0].id
  tags                     = { Name = "ec2-a-to-b-analysis" }
}
```

**Terraform commands:**

```bash
terraform init
terraform apply -var-file=day08.tfvars   # path + one analysis run
```

The analysis runs **once, at create time**. After you break something in the
lab, a re-`apply` will not re-run it — Terraform sees no change. Force it:

```bash
terraform apply -var-file=day08.tfvars \
  -replace='aws_ec2_network_insights_analysis.a_to_b[0]' -auto-approve
```

Each analysis costs ~$0.10, so use the Console for the iterative break-fix loop
and keep this resource as the "path as code" example.

**Verify:** Console → VPC → Reachability Analyzer → Paths → `ec2-a-to-ec2-b-8080`. Check the analysis result — it will show the full hop path or the exact resource blocking connectivity (SG rule, NACL entry, missing route, etc.).

**Final teardown:** everything on Day 8 is Terraform-managed, including the test
instances, so one destroy covers it:
```bash
terraform destroy -var-file=day08.tfvars -auto-approve
./scripts/sweep.sh
```

---

## Terraform Reference

### First-Time Workflow (Day 1 only)

```bash
cd aws_network_components/terraform/envs/sandbox

terraform init                            # download provider + module sources
terraform fmt                             # format your edits
terraform validate                        # syntax check before plan
terraform plan  -var-file=day01.tfvars    # preview resources
terraform apply -var-file=day01.tfvars    # create them
```

### Every Subsequent Day

```bash
# 1. Add the day's module block(s) to main.tf, each gated on its enable_* flag
# 2. Then:
terraform init                            # re-init after adding a module source
terraform plan  -var-file=dayNN.tfvars    # only the new resources should appear
terraform apply -var-file=dayNN.tfvars
```

### Running the Console lab without collisions

Every day's Console lab builds by hand the same thing that day's module builds
in code, so applying `dayNN.tfvars` *before* the Console lab guarantees a name
collision (duplicate SG names and log groups fail the apply outright). Stand the
Console lab up on the VPC-only baseline plus test instances:

```bash
terraform apply -var-file=day01.tfvars -var enable_ec2_test=true -auto-approve
```

A command-line `-var` overrides the file. Switch to `dayNN.tfvars` only after
the Console resources are deleted.

### End-of-Day Teardown — both halves, in this order

**1. Console teardown.** Terraform has no record of anything you built by hand,
and `destroy` will not touch it. Each day in the plan file ends with an ordered
checklist — follow it. The traps that bite most often:

- Security groups must be deleted **data → app → web**; AWS refuses while
  another group's rule still references one.
- A NACL cannot be deleted while it has subnet associations — move the subnets
  to the default NACL first.
- Delete the NLB **before** its target group; the consumer endpoint **before**
  the endpoint service.
- **Deleting a VPC does not release its NAT Gateway Elastic IPs.** They stay
  allocated and keep billing.

**2. Terraform teardown** — same var-file you applied with:

```bash
terraform destroy -var-file=dayNN.tfvars -auto-approve
```

**3. Verify:**

```bash
./scripts/sweep.sh
```

Expect `ALL CLEAR`. Anything marked DIRTY is still on a meter.

### Targeting a Single Module (if apply fails midway)

```bash
terraform apply -target module.shared_services_vpc
terraform apply -target module.tgw
```

Use `-target` to retry a specific module without re-running all others. Remove `-target` for the next full apply.

### Reading Module Internals (answer key)

```bash
# View what a module creates before applying it:
cat terraform/modules/vpc/main.tf
cat terraform/modules/security/main.tf
# etc.
```

The `modules/` directory is fully pre-written. Reading it alongside the theory file deepens understanding — don't just copy-paste blindly.

---

## Cost Control

| Resource | Rate (ap-southeast-1) | Daily risk if not destroyed |
|---|---|---|
| Resolver endpoint | ~$0.125/hr **per IP** | 2 endpoints × 2 IPs = **~$12/day** |
| NAT Gateway | ~$0.059/hr each | 4 NATs from Day 4 = ~$5.66/day |
| TGW attachment | ~$0.05–0.07/hr each | 2 attachments = ~$3.40/day |
| VPN connection | ~$0.05/hr | ~$1.20/day |
| Interface endpoint | ~$0.013/hr per AZ | 3 ep × 2 AZ = ~$1.87/day |
| Network Load Balancer | ~$0.0243/hr | ~$0.58/day |
| **Elastic IP (idle or in use)** | ~$0.005/hr | ~$0.12/day each — **survives VPC deletion** |
| t3.micro | ~$0.0128/hr | ~$0.31/day each |
| Reachability Analyzer | ~$0.10 per analysis | one-off, not hourly |
| Gateway endpoint, SGs, NACLs, route tables | free | — |

Two things people consistently get wrong here. **Resolver endpoints bill per IP,
not per endpoint** — the HA layout this course builds is ~$0.50/hr, twice what
you'd guess. And **Elastic IPs bill whether or not they're attached to
anything**, and outlive the VPC that created them; that is the single most
common silent leak in this course.

**Rule: Console teardown, then `terraform destroy -var-file=dayNN.tfvars`, then
`./scripts/sweep.sh`. Every day.**

A full Day 6 topology left overnight (16h) is roughly **$18**; left a month,
about **$800**.

Check for orphans after every destroy:
```bash
./scripts/sweep.sh                    # defaults to profile sandbox, ap-southeast-1
./scripts/sweep.sh my-profile us-east-1
```

It exits non-zero if anything billable remains, so it also works in a shell
`&&` chain or a pre-commit style check.

---

## Stuck? Self-Help Checklist

Work through this before reaching out. Most issues are in the first 3 steps.

**Terraform errors:**

1. `Error: No valid credential sources found` — run `aws sts get-caller-identity --profile sandbox` to verify credentials. Check `terraform.tfvars` has `aws_profile = "sandbox"`.
2. `Error: Reference to undeclared module` — you referenced a module in a variable or output before declaring it in `main.tf`. Add the module block first.
3. `Error: Provider configuration not present` — run `terraform init` again after adding a new module.
4. `Error creating resource: ... already exists` — a previous run left orphaned resources. Check Console, delete manually, then re-apply.
5. Apply partial failure — use `terraform apply -target module.<name>` to retry the failed module. Run full `terraform apply` after.

**Console validation not matching Terraform:**

- Terraform creates resources using your `sandbox` profile. Verify the Console is in region `ap-southeast-1` and logged into the same account.
- Route table associations take a few seconds to propagate — refresh the Console.

**VPN tunnels stuck DOWN (Day 6):**

- Tunnel DOWN is expected until strongSwan is configured on the EC2. Follow the plan file's SSH steps.
- Verify the EC2's security group allows UDP 500 and UDP 4500 inbound (IKE/IPSec ports).
- `customer_gateway_ip` must be a public, reachable EIP — not a private IP.

**Reachability Analyzer shows UNREACHABLE (Day 8):**

- This is intentional during the break-it exercise. Read the "Explanation" in the analysis to find the blocking rule.
- Most common causes: missing TGW route, SG blocking port 8080, NACL denying traffic.

**General AWS Console navigation:**
- VPC resources: Console → VPC (search "VPC" in the top bar)
- Flow Logs: Console → CloudWatch → Log Groups → `shared-services-flow-logs`
- Resolver: Console → Route 53 → Resolver → Endpoints

---

## When to Reach Out

You should be able to handle 95% of issues using:
1. This README (you are here)
2. The plan file (`docs/superpowers/plans/…-mastery-plan.md`) — it has full Console steps, Terraform code, and a "Common Errors" subsection per day
3. The theory files (`content/dayNN.md`) — "Pitfalls" section near the bottom

**Reach out when:**
- A Terraform resource is failing with an AWS API error you don't recognize (paste the full error message)
- An AWS service behavior contradicts what the theory file describes
- The VPN tunnels stay DOWN after strongSwan is configured correctly (Day 6 — this can be fiddly)
- The Reachability Analyzer shows a block you can't trace back to a specific resource

**What to include when asking for help:**
- Which day and which step
- The exact error or unexpected behavior (paste it)
- What you already tried

---

## Journal

After each day, open `journal.md` and add an entry using the template at the top:

```
### Day N — <topic>
Key concept in my own words: ...
What confused me and how I resolved it: ...
Break-it exercise — what I misconfigured and how I found it: ...
```

Writing this forces retrieval practice — the single most effective way to lock in what you learned. Takes 5 minutes. Skip at your own risk.
