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
└── terraform/
    ├── modules/
    │   ├── vpc/         ← Pre-written module (answer key for Day 1)
    │   ├── security/    ← Answer key for Day 2
    │   ├── dns/         ← Answer key for Day 3
    │   ├── tgw/         ← Answer key for Day 4
    │   ├── endpoints/   ← Answer key for Day 5
    │   ├── vpn/         ← Answer key for Day 6
    │   └── ram/         ← Answer key for Day 7
    └── envs/sandbox/
        ├── main.tf           ← YOU EDIT THIS: add one module block per day
        ├── main.complete.tf  ← Answer key: the fully assembled 8-day main.tf
        ├── outputs.tf        ← Uncomment outputs as you add modules
        ├── variables.tf      ← All variables (most have defaults)
        └── terraform.tfvars  ← Your values: region + profile already set
```

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
Close   — Journal + Teardown          journal.md, then terraform destroy
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
terraform init          # re-init to pick up the new module source
terraform plan          # review: expect ~18 resources to add
terraform apply         # ~3 min — VPC, 6 subnets, IGW, 2 NATs, route tables
```

**Verify:** Console → VPC → Your VPCs → `shared-services` visible. Check route tables: public RT has `0.0.0.0/0 → igw-xxx`, each private RT has `0.0.0.0/0 → nat-xxx`, isolated RT has no default route.

**Cost:** 2 NAT Gateways @ ~$0.045/hr each = ~$0.09/hr. Destroy at end of day.

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
terraform apply         # ~1 min — SGs, NACL, Flow Logs IAM role + log group
```

**Verify:** Console → VPC → Security Groups — find `shared-services-web`, `shared-services-app`, `shared-services-data`. Console → CloudWatch → Log Groups — find `shared-services-flow-logs`.

**Cost:** Negligible (SGs and NACLs are free; Flow Logs charge per GB ingested, minimal for a quiet sandbox).

---

### Day 3 — Private DNS

**Theory:** `content/day03.md` — Route 53 private hosted zones, split-horizon DNS, Resolver inbound/outbound endpoints.

**Goal:** Create a private zone `internal.platform.local`, add a test A record, and set up Resolver to forward queries for `corp.internal` to a simulated on-prem DNS.

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
terraform apply         # ~2 min — hosted zone, A record, resolver endpoints
```

**Verify:** Console → Route 53 → Hosted Zones → `internal.platform.local`. Check the Resolver outbound endpoint is `OPERATIONAL` (takes ~2 min after apply).

**Cost:** Resolver endpoints: 2 ENIs × 2 AZs × $0.125/hr = $0.50/hr. Note these down — destroy at end of day.

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
terraform apply         # ~5–7 min — TGW creation takes time; second VPC adds 2 more NATs
```

**Verify:** Console → VPC → Transit Gateways → `platform` in `available` state. Check Transit Gateway Attachments — both VPCs attached. Check private route tables in each VPC — routes to `10.0.0.0/16` and `10.1.0.0/16` via the TGW attachment.

**Cost warning:** Now 4 NAT Gateways (2 per VPC × 2 VPCs) + TGW ($0.05/hr + $0.02/GB). ~$0.18/hr base. Destroy at day end.

---

### Day 5 — VPC Endpoints + PrivateLink

**Theory:** `content/day05.md` — Gateway endpoints (S3/DynamoDB, free, route-table based) vs Interface endpoints (ENI-based, private DNS), PrivateLink.

**Goal:** Add S3 gateway endpoint, SSM interface endpoints, and create a PrivateLink endpoint service backed by an NLB.

**Pre-step (Console, optional):** If you want to test a live PrivateLink service, create an NLB manually in the Console and note its ARN. Otherwise leave `privatelink_nlb_arn = ""` in tfvars — the endpoint service will be created without an NLB target (API test only).

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
terraform apply         # ~3 min — S3 gateway endpoint, 3 SSM interface endpoints
```

**Verify:** Console → VPC → Endpoints — find `com.amazonaws.ap-southeast-1.s3` (type: Gateway) and three SSM interface endpoints (type: Interface, status: available). Console → EC2 → Systems Manager → Session Manager — if you have an EC2 in a private subnet, you can now connect without a bastion.

**Cost:** Interface endpoints: 3 × 2 AZs × $0.01/hr = $0.06/hr. Gateway endpoint is free.

---

### Day 6 — Site-to-Site VPN

**Theory:** `content/day06.md` — Customer Gateway, two IPSec tunnels, BGP/static routing, strongSwan simulation.

**Goal:** Set up a VPN connection from the TGW to a simulated on-prem Customer Gateway (a t3.micro EC2 with an EIP).

**Pre-step (Console, required):**
1. Launch a `t3.micro` EC2 in the `shared-services` public subnet (Amazon Linux 2023).
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
terraform apply         # ~2 min — Customer GW + VPN connection (2 tunnels created)
```

**Verify:** Console → VPN → Site-to-Site VPN Connections → `onprem-sim`. Tunnels will show `DOWN` until strongSwan is configured on the EC2 (follow Day 6 plan for strongSwan setup — that is a Console/SSH step, not Terraform). Download the VPN configuration from Console (Vendor: Generic, IKEv2) to get pre-shared keys.

**Sensitive outputs (PSKs + tunnel addresses):**
```bash
terraform output -json | jq '{tunnel1_address, tunnel2_address}'
```
These are marked `sensitive = true` in Terraform — they won't print unless you use `-json`.

**Cost:** VPN connection: $0.05/hr. EC2 t3.micro: ~$0.0052/hr. Minimal, but destroy at day end.

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
terraform apply         # ~1 min — RAM shares + principal associations
```

**Verify:** Console → Resource Access Manager → Shared by me → two shares: `platform-subnets` and `platform-tgw`. If you have Account B: log in, go to RAM → Shared with me → accept the TGW share. Then create a TGW attachment from Account B.

---

### Day 8 — Debugging + Reachability Analyzer

**Theory:** `content/day08.md` — Reachability Analyzer, Network Access Analyzer, VPC Flow Logs analysis, the 5-layer debugging ladder.

**Goal:** Use Reachability Analyzer to validate connectivity between two EC2 instances and interpret the analysis output.

**Pre-step (Console, required):**
1. Launch two `t3.micro` EC2 instances (one in `shared-services` private subnet, one in `app` private subnet).
2. Note their instance IDs (e.g. `i-0abc123` and `i-0def456`).
3. Add to `terraform.tfvars`:
   ```
   ec2_a_id = "i-0abc123"
   ec2_b_id = "i-0def456"
   ```

**Add to `main.tf`** (after Day 7 block):

```hcl
resource "aws_ec2_network_insights_path" "a_to_b" {
  source           = var.ec2_a_id
  destination      = var.ec2_b_id
  protocol         = "tcp"
  destination_port = 8080
  tags             = { Name = "ec2-a-to-ec2-b-8080" }
}

resource "aws_ec2_network_insights_analysis" "a_to_b" {
  network_insights_path_id = aws_ec2_network_insights_path.a_to_b.id
  tags                     = { Name = "ec2-a-to-b-analysis" }
}
```

**Terraform commands:**

```bash
terraform init
terraform apply         # Creates the path + triggers an analysis run
```

**Verify:** Console → VPC → Reachability Analyzer → Paths → `ec2-a-to-ec2-b-8080`. Check the analysis result — it will show the full hop path or the exact resource blocking connectivity (SG rule, NACL entry, missing route, etc.).

**Final teardown:** After Day 8, run full destroy and terminate all test EC2s manually:
```bash
terraform destroy -auto-approve
```

---

## Terraform Reference

### First-Time Workflow (Day 1 only)

```bash
cd aws_network_components/terraform/envs/sandbox

terraform init          # download provider + module sources
terraform fmt           # format your edits (optional but good habit)
terraform validate      # syntax check before plan
terraform plan          # preview resources
terraform apply         # create resources (prompts "yes" unless -auto-approve)
```

### Every Subsequent Day

```bash
# 1. Add the day's module block(s) to main.tf (see above)
# 2. Then:
terraform init          # always re-init after adding a new module source
terraform plan          # verify only the new resources appear in the diff
terraform apply
```

### End-of-Day Teardown

```bash
terraform destroy -auto-approve
```

This destroys ALL resources tracked in `terraform.tfstate`. Resources created manually in the Console (EC2 instances, NLBs, EIPs) are NOT destroyed by Terraform — terminate those manually.

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

| Resource           | Rate (ap-southeast-1) | Daily risk if not destroyed |
|--------------------|----------------------|-----------------------------|
| NAT Gateway        | $0.045/hr each        | 4 NATs from Day 4 = ~$4.32/day |
| Resolver Endpoints | $0.125/hr each        | 2 endpoints = ~$6/day       |
| Transit Gateway    | $0.05/hr attachment   | 2 attachments = ~$2.40/day  |
| VPN Connection     | $0.05/hr              | ~$1.20/day                  |
| Interface Endpoints| $0.01/hr each         | 6 ENIs (3 ep × 2 AZ) = ~$1.44/day |

**Rule: always run `terraform destroy` at the end of every day.**

Total if forgotten overnight (8 hrs, Day 4+): ~$15–20. Over a week: significant.

Check for orphaned resources after destroy:
```bash
aws ec2 describe-nat-gateways --profile sandbox --region ap-southeast-1 \
  --filter "Name=state,Values=available" \
  --query "NatGateways[].NatGatewayId"

aws ec2 describe-transit-gateways --profile sandbox --region ap-southeast-1 \
  --query "TransitGateways[?State=='available'].TransitGatewayId"
```

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
