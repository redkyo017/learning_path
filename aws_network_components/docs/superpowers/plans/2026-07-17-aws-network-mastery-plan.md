# AWS Network Mastery — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each
> day is a study/lab session. Work the four blocks in order: read the theory
> file first, follow the lab guide, build in the Console, then rebuild the
> same thing in Terraform. Check off every step as you complete it. Do not
> skip ahead — each day's theory builds on the last. But **every day is
> independently runnable**: the root module gates each day's Terraform behind
> an `enable_*` flag and a `dayNN.tfvars` file turns on exactly what that day
> needs, so you can re-run Day 5 alone on a clean account without standing up
> Day 4's Transit Gateway first. See **Lab Harness** below — build it once
> before Day 1.
>
> Teardown is a mandatory step at the end of every day, not an afterthought.
> NAT Gateways, Route 53 Resolver endpoints, interface endpoints, TGW
> attachments and VPN connections all run on a per-hour meter, and
> `terraform destroy` does **not** remove anything you built in the Console.

**Goal:** Reach production-credible AWS networking competence in 8 days
(4–6 hours/day) — able to design, build, debug, and reason about real
integration platform networks including VPCs, Transit Gateway, PrivateLink,
hybrid VPN, and multi-account topology.

**Architecture:** Four sequential blocks per day — theory companion file
(concepts), lab guide (what to build and why), Console lab (build manually
for full visibility), Terraform lab (codify what you just understood). Labs
are cumulative: each day's Terraform module extends the previous day's root
module. By Day 8 the Terraform codebase is a working reference architecture
for an integration platform network.

**Tech Stack:** AWS Console, AWS CLI v2, Terraform >= 1.6 with AWS provider
>= 5.0, strongSwan (Day 6, installed via EC2 user_data), Amazon Linux 2023
AMI for EC2 test instances.

## Global Constraints

- **Finish every day with both teardowns**, in this order: the Console
  teardown checklist printed at the end of each day, then
  `terraform destroy -var-file=dayNN.tfvars -auto-approve`. Then run
  `scripts/sweep.sh` and confirm it prints all-clear. Skipping the Console
  checklist is the single most expensive mistake in this plan — Terraform has
  no record of Console-built resources and will happily leave them running.
- **Deleting a Console VPC does not release its Elastic IPs.** The
  "VPC and more" wizard allocates an EIP per NAT Gateway; deleting the VPC
  deletes the NAT Gateways but leaves the EIPs allocated and billing at
  ~$0.005/hr each, forever. `scripts/sweep.sh` catches this.
- Always build Console first, Terraform second — console visibility builds the
  mental model that makes Terraform debugging possible.
- Use region `ap-southeast-1` (Singapore) throughout. If you change regions,
  update `terraform.tfvars` and re-check AZ names (`ap-southeast-1a/b`).
- AWS CLI profile: every CLI command in this plan is written `--profile sandbox`.
  Substitute your own profile name, and keep it identical to `aws_profile` in
  `terraform.tfvars` — otherwise Terraform and the CLI act on different
  accounts. Export it once per session: `export AWS_PROFILE=<your-profile>`.
  Never run labs against a production account.
- The `break-it` exercise at the end of each Console lab is mandatory — it
  is the primary mechanism for building debugging intuition under controlled
  conditions.
- All Terraform state is local (`terraform.tfstate` in `envs/sandbox/`) — no
  remote backend is set up for this sandbox. Do not commit `tfstate` files.

## Project Layout

Built incrementally across 8 days — this is the target end state:

```
aws_network_components/
  content/
    day01.md          # Theory: VPC anatomy
    day02.md          # Theory: Security layer
    day03.md          # Theory: DNS inside VPC
    day04.md          # Theory: VPC Peering vs TGW
    day05.md          # Theory: VPC Endpoints + PrivateLink
    day06.md          # Theory: Hybrid connectivity
    day07.md          # Theory: Multi-account networking
    day08.md          # Theory: Debugging + Reachability
  scripts/
    sweep.sh          # Harness: post-teardown billable-resource sweep
  terraform/
    modules/
      vpc/            # Day 1: VPC, subnets, IGW, NAT, route tables
      security/       # Day 2: SGs, NACLs, Flow Logs
      dns/            # Day 3: Route53 PHZ, Resolver endpoints/rules
      tgw/            # Day 4: Transit Gateway, attachments, route tables
      endpoints/      # Day 5: VPC endpoints, PrivateLink NLB + service
      vpn/            # Day 6: Customer GW, VPN connection
      ram/            # Day 7: RAM shares, cross-account
      ec2_test/       # Harness: SSM-managed test instances (Days 2-8)
    envs/
      sandbox/
        main.tf       # Root module — every module gated by an enable_* flag
        variables.tf
        outputs.tf
        terraform.tfvars   # region + profile only
        day01.tfvars       # Per-day toggles — which modules today needs
        day02.tfvars
        day03.tfvars
        day04.tfvars
        day05.tfvars
        day06.tfvars
        day07.tfvars
        day08.tfvars
  docs/superpowers/
    specs/2026-07-17-aws-network-mastery-design.md
    plans/2026-07-17-aws-network-mastery-plan.md  (this file)
  journal.md
```

---

## Pre-flight: Prerequisites

Before Day 1, complete these once.

- [ ] **Install / verify tools.**

```bash
aws --version          # expect: aws-cli/2.x
terraform --version    # expect: Terraform v1.6+
```

Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
Install Terraform: https://developer.hashicorp.com/terraform/install

- [ ] **Configure AWS CLI profile.**

```bash
aws configure --profile sandbox
# AWS Access Key ID: <your sandbox key>
# AWS Secret Access Key: <your sandbox secret>
# Default region name: ap-southeast-1
# Default output format: json

aws sts get-caller-identity --profile sandbox
```

Expected: JSON showing your account ID and IAM user/role ARN. If you see
`InvalidClientTokenId`, the key is wrong.

- [ ] **Create journal file.**

Create `aws_network_components/journal.md` with this header:

```markdown
# AWS Network Mastery Journal

## Template (copy per day)
### Day N — <topic>
Key concept in my own words: ...
What confused me and how I resolved it: ...
Break-it exercise — what I misconfigured and how I found it: ...
```

- [ ] **Verify sandbox permissions.** You need EC2, VPC, Route 53, RAM, and
  TGW permissions. Quick check:

```bash
aws ec2 describe-vpcs --profile sandbox --region ap-southeast-1
```

Expected: JSON list of existing VPCs (default VPC at minimum). An
`AuthFailure` or `AccessDenied` error means your IAM permissions need
expanding before proceeding.

---

## Lab Harness — day toggles, EC2 test pair, cleanup sweep

Build this once, before Day 1. It is what lets you run any single day on its
own and remove it completely afterwards.

### Why this exists

Without it the labs have two structural problems:

1. **Every day re-applies everything.** A plain `terraform apply` on Day 8
   stands up two VPCs, four NAT Gateways, two Resolver endpoints, four
   interface endpoints, a TGW and a VPN — roughly **$1.10/hour** — just to
   practice Reachability Analyzer. You only need a fraction of that.
2. **`terraform destroy` cannot clean the Console labs.** Each day's Console
   block builds real, metered infrastructure that Terraform has no record of.
   Destroy runs clean, the Console resources keep billing, and nothing warns you.

### Step H1: Gate every module behind a flag

The VPC stays unconditional — every day needs it. Everything else gets a
`count`. Rewrite `terraform/envs/sandbox/main.tf` so each module block reads:

```hcl
module "shared_services_security" {
  count  = var.enable_security ? 1 : 0
  source = "../../modules/security"
  # ... arguments unchanged ...
}
```

Because a counted module becomes a list, references to it change shape.
Use `one()` — it returns the single element, or `null` when the count is 0,
which is exactly what you want for an optional dependency:

```hcl
# before:  module.shared_services_security.resolver_sg_id
# after:   one(module.shared_services_security[*].resolver_sg_id)
```

Add the flags to `terraform/envs/sandbox/variables.tf`:

```hcl
variable "enable_security" {
  type        = bool
  default     = false
  description = "Day 2+ : SGs, NACLs, Flow Logs"
}

variable "enable_dns" {
  type        = bool
  default     = false
  description = "Day 3 : PHZ + Resolver endpoints (~$0.50/hr -- most expensive)"
}

variable "enable_app_vpc" {
  type        = bool
  default     = false
  description = "Day 4+ : the second VPC"
}

variable "enable_tgw" {
  type        = bool
  default     = false
  description = "Day 4 : Transit Gateway (implies app_vpc)"
}

variable "enable_endpoints" {
  type        = bool
  default     = false
  description = "Day 5 : gateway + interface endpoints, PrivateLink service"
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "Day 6 : Site-to-Site VPN (implies tgw)"
}

variable "enable_ram" {
  type        = bool
  default     = false
  description = "Day 7 : RAM shares"
}

variable "enable_ec2_test" {
  type        = bool
  default     = false
  description = "SSM-managed test instances, used from Day 2 onward"
}
```

Write each argument on its own line, as above. The compact one-liner form you
sometimes see in blog posts — `variable "x" { type = bool, default = false }` —
is **not** valid HCL: commas do not separate arguments inside a block, and
`terraform fmt` will fail to parse it rather than fixing it for you.

Now derive the implications. The TGW attaches `app-vpc`, and the VPN attaches to
the TGW, so each flag implies the one below it. Deriving that here rather than
repeating it in every `dayNN.tfvars` keeps the day files honest:

```hcl
locals {
  tgw_enabled     = var.enable_tgw || var.enable_vpn
  app_vpc_enabled = var.enable_app_vpc || local.tgw_enabled
}

check "vpn_requires_tgw" {
  assert {
    condition     = !var.enable_vpn || local.tgw_enabled
    error_message = "enable_vpn requires enable_tgw."
  }
}
```

Use `local.app_vpc_enabled` as the `count` condition on the `app_vpc` module and
`local.tgw_enabled` on the `tgw` module — never the raw `var.enable_*` — so that
turning on `enable_vpn` alone brings up everything it depends on.

### Step H2: Write the per-day toggle files

One file per day, in `terraform/envs/sandbox/`. Each turns on **only** what
that day's lab actually touches — that is the whole point of the harness.

```hcl
# day01.tfvars — VPC only
# (all flags default to false; file intentionally has no overrides)
```

```hcl
# day02.tfvars — SGs, NACLs, Flow Logs + a test pair to prove the NACL
enable_security = true
enable_ec2_test = true
```

```hcl
# day03.tfvars — DNS needs the security module for the resolver SG
enable_security = true
enable_dns      = true
enable_ec2_test = true
```

```hcl
# day04.tfvars — TGW; no DNS today, so don't pay for Resolver endpoints
enable_security = true
enable_app_vpc  = true
enable_tgw      = true
enable_ec2_test = true
```

```hcl
# day05.tfvars — endpoints + PrivateLink; app-vpc is the consumer side.
# No TGW: PrivateLink deliberately works without peering or a TGW.
enable_security  = true
enable_app_vpc   = true
enable_endpoints = true
enable_ec2_test  = true
```

```hcl
# day06.tfvars — VPN terminates on the TGW
enable_security = true
enable_app_vpc  = true
enable_tgw      = true
enable_vpn      = true
enable_ec2_test = true
```

```hcl
# day07.tfvars — RAM shares the subnets and the TGW; no EC2 in account A
enable_security  = true
enable_app_vpc   = true
enable_tgw       = true
enable_endpoints = true
enable_ram       = true
```

```hcl
# day08.tfvars — debugging needs routes (TGW), NACL/SG, endpoints, flow logs
enable_security  = true
enable_app_vpc   = true
enable_tgw       = true
enable_endpoints = true
enable_ec2_test  = true
```

Every apply and destroy from here on names its day:

```bash
terraform apply   -var-file=day05.tfvars -auto-approve
terraform destroy -var-file=day05.tfvars -auto-approve
```

**The Console baseline.** Every day's Console lab builds by hand the very thing
that day's module builds in code, so applying `dayNN.tfvars` *before* the Console
lab guarantees a name collision. Stand the Console lab up on the VPC-only
baseline plus test instances instead:

```bash
terraform apply -var-file=day01.tfvars -var enable_ec2_test=true -auto-approve
```

A command-line `-var` overrides the file, so this gives you a VPC and a shell
inside it with none of today's resources. Switch to `dayNN.tfvars` only after the
Console resources are deleted.

**Always pass the same `-var-file` to `destroy` that you passed to `apply`.**
Destroying with the flags off makes Terraform plan against a config where those
modules don't exist — it still destroys what is in state, but the plan output
becomes unreadable and any module using `one()` on a now-absent dependency can
error. Same file in, same file out.

### Step H3: The EC2 test module

Days 2, 3, 4, 5, 6 and 8 all need instances to verify anything end-to-end.
Building them by hand each day is where forgotten, still-billing instances come
from. This module makes them part of the same `apply`/`destroy` cycle as
everything else.

Create `terraform/modules/ec2_test/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "One instance is launched per subnet ID given"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR permitted to reach these instances on any port"
}

variable "extra_sg_ids" {
  type        = list(string)
  default     = []
  description = "Additional SGs to attach — used on Day 8 to test the tier SGs"
}
```

Create `terraform/modules/ec2_test/main.tf`:

```hcl
# Always-current Amazon Linux 2023 AMI — no hardcoded AMI IDs to rot.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ssm" {
  name = "${var.name}-ec2-test-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name}-ec2-test-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_security_group" "test" {
  name        = "${var.name}-ec2-test-sg"
  description = "Lab test instances - all traffic from the lab CIDR, all egress"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-ec2-test-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "from_lab" {
  security_group_id = aws_security_group.test.id
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.test.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  count                  = length(var.subnet_ids)
  ami                    = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_ids[count.index]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  vpc_security_group_ids = concat([aws_security_group.test.id], var.extra_sg_ids)

  # An echo server on 8080 so every connectivity test in this plan has
  # something real to connect to, plus dig/nc for the DNS and TCP labs.
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nmap-ncat bind-utils
    systemd-run --unit=lab-echo --collect \
      /usr/bin/ncat --listen --keep-open --sh-exec /bin/cat 8080
  EOF

  tags = { Name = "${var.name}-test-${count.index + 1}" }
}
```

Create `terraform/modules/ec2_test/outputs.tf`:

```hcl
output "instance_ids" {
  value = aws_instance.this[*].id
}

output "private_ips" {
  value = aws_instance.this[*].private_ip
}

output "sg_id" {
  value = aws_security_group.test.id
}
```

Wire it into `terraform/envs/sandbox/main.tf`:

```hcl
module "ec2_test_shared_services" {
  count  = var.enable_ec2_test ? 1 : 0
  source = "../../modules/ec2_test"

  name         = "shared-services"
  vpc_id       = module.shared_services_vpc.vpc_id
  subnet_ids   = module.shared_services_vpc.private_subnet_ids
  allowed_cidr = "10.0.0.0/8"
}

module "ec2_test_app" {
  count  = var.enable_ec2_test && local.app_vpc_enabled ? 1 : 0
  source = "../../modules/ec2_test"

  name         = "app"
  vpc_id       = one(module.app_vpc[*].vpc_id)
  subnet_ids   = one(module.app_vpc[*].private_subnet_ids)
  allowed_cidr = "10.0.0.0/8"
}
```

And expose the IDs you'll need constantly, in `outputs.tf`:

```hcl
output "ec2_test_shared_services_ids" {
  value = one(module.ec2_test_shared_services[*].instance_ids)
}

output "ec2_test_shared_services_ips" {
  value = one(module.ec2_test_shared_services[*].private_ips)
}

output "ec2_test_app_ids" {
  value = one(module.ec2_test_app[*].instance_ids)
}

output "ec2_test_app_ips" {
  value = one(module.ec2_test_app[*].private_ips)
}
```

**Connecting.** These instances have no key pair and no public IP — you reach
them through SSM Session Manager, which needs no inbound rule at all:

```bash
aws ssm start-session --target "$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')" --profile sandbox
```

Or in the Console: EC2 → select instance → **Connect** → **Session Manager**.

**How the agent reaches SSM matters, and it changes on Day 5.** On Days 2–4 the
instance registers with SSM over the internet, through the NAT Gateway. That
means the private subnet's NACL and route table must permit outbound 443 to
`0.0.0.0/0` and the matching inbound ephemeral range — a constraint the Day 2
NACL is written to satisfy. From Day 5 the interface endpoints carry that
traffic privately and the NAT path is no longer needed.

If **Connect → Session Manager** is greyed out, wait ~2 minutes after boot, then
check registration:

```bash
aws ssm describe-instance-information --profile sandbox \
  --query "InstanceInformationList[*].{Id:InstanceId,Ping:PingStatus}"
```

An instance that never appears is almost always one of: the NACL blocking
outbound 443 or inbound ephemeral, a missing `0.0.0.0/0 → nat` route, or the
instance profile not attached.

### Step H4: The cleanup sweep

Create `scripts/sweep.sh` and make it executable (`chmod +x scripts/sweep.sh`).
Run it after every teardown. It is the only thing that reliably catches
Console-built leftovers.

```bash
#!/usr/bin/env bash
# Post-teardown sweep — lists every lab resource that can still bill you.
# Usage: ./scripts/sweep.sh [profile] [region]
set -uo pipefail
PROFILE="${1:-${AWS_PROFILE:-sandbox}}"
REGION="${2:-${AWS_REGION:-ap-southeast-1}}"
Q=(--profile "$PROFILE" --region "$REGION" --output text)
dirty=0

check() { # check <label> <output>
  if [ -n "$2" ]; then
    printf '  DIRTY  %-22s %s\n' "$1" "$(echo "$2" | tr '\n' ' ')"
    dirty=1
  else
    printf '  clean  %s\n' "$1"
  fi
}

echo "Sweep: profile=$PROFILE region=$REGION"

check "non-default VPCs" "$(aws ec2 describe-vpcs "${Q[@]}" \
  --query 'Vpcs[?IsDefault==`false`].VpcId')"
check "NAT gateways" "$(aws ec2 describe-nat-gateways "${Q[@]}" \
  --query 'NatGateways[?State!=`deleted`].NatGatewayId')"
check "Elastic IPs" "$(aws ec2 describe-addresses "${Q[@]}" \
  --query 'Addresses[*].AllocationId')"
check "EC2 instances" "$(aws ec2 describe-instances "${Q[@]}" \
  --filters 'Name=instance-state-name,Values=pending,running,stopping,stopped' \
  --query 'Reservations[*].Instances[*].InstanceId')"
check "EBS volumes" "$(aws ec2 describe-volumes "${Q[@]}" --query 'Volumes[*].VolumeId')"
check "VPC endpoints" "$(aws ec2 describe-vpc-endpoints "${Q[@]}" \
  --query 'VpcEndpoints[*].VpcEndpointId')"
check "endpoint services" "$(aws ec2 describe-vpc-endpoint-services "${Q[@]}" \
  --filters 'Name=service-type,Values=Interface' \
  --query 'ServiceDetails[?Owner!=`amazon`].ServiceId')"
check "transit gateways" "$(aws ec2 describe-transit-gateways "${Q[@]}" \
  --query 'TransitGateways[?State!=`deleted`].TransitGatewayId')"
check "TGW attachments" "$(aws ec2 describe-transit-gateway-attachments "${Q[@]}" \
  --query 'TransitGatewayAttachments[?State!=`deleted`].TransitGatewayAttachmentId')"
check "VPN connections" "$(aws ec2 describe-vpn-connections "${Q[@]}" \
  --query 'VpnConnections[?State!=`deleted`].VpnConnectionId')"
check "peering connections" "$(aws ec2 describe-vpc-peering-connections "${Q[@]}" \
  --query 'VpcPeeringConnections[?Status.Code!=`deleted`].VpcPeeringConnectionId')"
check "resolver endpoints" "$(aws route53resolver list-resolver-endpoints "${Q[@]}" \
  --query 'ResolverEndpoints[*].Id')"
check "load balancers" "$(aws elbv2 describe-load-balancers "${Q[@]}" \
  --query 'LoadBalancers[*].LoadBalancerName')"
check "private hosted zones" "$(aws route53 list-hosted-zones \
  --profile "$PROFILE" --output text \
  --query 'HostedZones[?Config.PrivateZone==`true`].Name')"
check "lab log groups" "$(aws logs describe-log-groups "${Q[@]}" \
  --query 'logGroups[?starts_with(logGroupName,`/vpc/`)].logGroupName')"

echo
if [ "$dirty" -eq 0 ]; then
  echo "ALL CLEAR — nothing billable left in $REGION."
else
  echo "LEFTOVERS FOUND — delete the items marked DIRTY above."
  echo "Note: Elastic IPs bill ~\$0.005/hr each even when attached to nothing."
fi
exit "$dirty"
```

Two caveats on reading its output. Resolver endpoints and private hosted zones
are **global-ish** — the hosted-zone check is not region-filtered, so a zone from
another project will show as DIRTY; confirm the name before deleting. And the
sweep only covers one region, so pass a region explicitly if you ever stray from
`ap-southeast-1`.

### Step H5: Cost reference

Rough `ap-southeast-1` hourly rates, so you can tell a forgotten $0.005/hr EIP
from a forgotten $0.50/hr pair of Resolver endpoints:

| Resource | Rate | Notes |
|---|---|---|
| NAT Gateway | ~$0.059/hr each | 2 per VPC in this plan |
| Route 53 Resolver endpoint | ~$0.125/hr **per IP** | 2 endpoints × 2 IPs = ~$0.50/hr — the priciest thing here |
| Interface VPC endpoint | ~$0.013/hr per AZ | 3 SSM endpoints × 2 AZ ≈ $0.078/hr |
| Transit Gateway attachment | ~$0.07/hr each | plus data processing |
| Site-to-Site VPN connection | ~$0.05/hr | |
| Network Load Balancer | ~$0.0243/hr | plus LCU |
| Elastic IP (idle **or** in use) | ~$0.005/hr | survives VPC deletion |
| t3.micro | ~$0.0128/hr | |
| Reachability Analyzer | ~$0.10 per analysis | one-off, not hourly |
| Gateway endpoint (S3) | free | |
| Security groups, NACLs, route tables | free | |

A full Day 6 topology left running overnight (16h) costs roughly **$18**.
Left running for a month it is about **$800**. Run the sweep.

### Step H6: Which day needs what

Each row is self-contained — nothing requires you to have run the row above it.

| Day | Topic | Flags on | Console lab builds | ~$/hr |
|---|---|---|---|---|
| 1 | VPC anatomy | *(none)* | VPC + NAT + subnets | 0.12 |
| 2 | Security layer | `security`, `ec2_test` | SGs, NACL, Flow Logs | 0.15 |
| 3 | DNS | `security`, `dns`, `ec2_test` | PHZ, **2 Resolver endpoints** | **0.65** |
| 4 | Peering vs TGW | `security`, `app_vpc`, `tgw`, `ec2_test` | app-vpc, peering, TGW | 0.45 |
| 5 | Endpoints + PrivateLink | `security`, `app_vpc`, `endpoints`, `ec2_test` | 4 endpoints, NLB, service | 0.40 |
| 6 | Hybrid VPN | `security`, `app_vpc`, `tgw`, `vpn`, `ec2_test` | onprem-sim VPC, strongSwan, VPN | **1.10** |
| 7 | Multi-account | `security`, `app_vpc`, `tgw`, `endpoints`, `ram` | RAM shares, x-account TGW | 0.45 |
| 8 | Debugging | `security`, `app_vpc`, `tgw`, `endpoints`, `ec2_test` | *(nothing — all Terraform)* | 0.40 |

Rates are the Terraform-managed side only. While a Console lab is up you are
paying for **both copies**, which is another reason to delete the Console
resources before applying the day file.


---

## Day 1 — VPC Anatomy

**Theory file:** `content/day01.md` — read before starting the lab.
**Builds on:** nothing (Day 1).
**Sets up for:** Days 2–8 all extend the `shared-services-vpc` built today.

---

- [ ] **Step 1 (30 min): Read theory.** Open `content/day01.md`. Focus on:
  - The 3-tier subnet model (public / private / isolated)
  - The packet-tracing mental model
  - Why two NAT Gateways (one per AZ) are required for HA
  - The difference between "private" and "isolated" subnets
  
  Write the definition of each in `journal.md` in your own words before
  touching the Console.

- [ ] **Step 2 (60 min): Console lab — Build shared-services-vpc.**

  Navigate: VPC Console → Your VPCs → Create VPC → **VPC and more**

  Settings:
  - Name tag auto-generation: `shared-services`
  - IPv4 CIDR: `10.0.0.0/16`
  - Number of Availability Zones: `2`
  - Number of public subnets: `2`
  - Number of private subnets: `2`
  - NAT gateways: `1 per AZ`
  - VPC endpoints: `None` (we add these on Day 5)
  - Expand **Customize subnets CIDR blocks** and replace each default with a
    `/24`, so the Console VPC matches the Terraform lab in Step 3:
    - Public subnet CIDR block in ap-southeast-1a: `10.0.0.0/24`
    - Public subnet CIDR block in ap-southeast-1b: `10.0.1.0/24`
    - Private subnet CIDR block in ap-southeast-1a: `10.0.2.0/24`
    - Private subnet CIDR block in ap-southeast-1b: `10.0.3.0/24`

  Why the customization matters: left alone, the wizard carves `10.0.0.0/16`
  into `/20`s — `10.0.0.0/20`, `10.0.16.0/20`, `10.0.128.0/20`, `10.0.144.0/20`.
  The first of those spans `10.0.0.0`–`10.0.15.255` and therefore already
  contains `10.0.4.0/24`, so creating the isolated subnets below would fail with
  *"The CIDR '10.0.4.0/24' conflicts with another subnet"*.

  Click **Create VPC** and wait ~3 minutes for NAT Gateways to provision.

  After creation, navigate to **Subnets** and verify the wizard created these 4
  subnets (the isolated pair added below brings the total to 6):
  - `shared-services-subnet-public1-ap-southeast-1a`
  - `shared-services-subnet-public2-ap-southeast-1b`
  - `shared-services-subnet-private1-ap-southeast-1a`
  - `shared-services-subnet-private2-ap-southeast-1b`
  
  Navigate to **Route tables** and confirm:
  - Public route table has route `0.0.0.0/0 → igw-xxx`
  - Each private route table has `0.0.0.0/0 → nat-xxx` (different NAT GW per AZ)

  **Add isolated subnets** (the wizard doesn't create these):
  Navigate: Subnets → Create subnet
  - VPC: `shared-services-vpc`
  - Subnet name: `shared-services-isolated-1a`
  - AZ: `ap-southeast-1a`
  - CIDR: `10.0.4.0/24`
  
  Repeat for AZ-b: name `shared-services-isolated-1b`, CIDR `10.0.5.0/24`

  **Already created the VPC with the wizard's default `/20` subnets?** Subnet
  CIDRs cannot be edited after creation, but you don't need to rebuild: the
  isolated tier just needs two free `/24`s inside `10.0.0.0/16`. Use
  `10.0.32.0/24` (AZ-a) and `10.0.33.0/24` (AZ-b) — both sit in the gap between
  the public `/20`s and the private `/20`s — and substitute them wherever this
  plan refers to `10.0.4.0/24` / `10.0.5.0/24` for the Console VPC. (The
  Terraform lab in Step 3 builds its own VPC, so its CIDRs stay as written.)

  Create a new route table: **Route tables → Create route table**
  - Name: `shared-services-isolated-rt`
  - VPC: `shared-services-vpc`
  - No routes added (isolated tier has no default route)
  
  Associate both isolated subnets to this route table via **Subnet associations**.

  **Break-it exercise:** Navigate to the private route table for AZ-a.
  Edit routes and delete the `0.0.0.0/0 → nat` route. Launch a test EC2
  in that private subnet (t3.micro, Amazon Linux 2023, no key pair) and
  observe that it launches fine but cannot reach the internet — with no
  default route there is nowhere for its packets to go. You cannot get a
  shell on it yet: SSM registration itself needs that route, which is the
  point. Restore the route, wait ~2 minutes, and confirm the instance now
  appears in `aws ssm describe-instance-information` — that transition from
  invisible to managed *is* the lesson.

  **Then terminate it**: EC2 → select instance → Instance state → Terminate.
  Terminating also deletes its root EBS volume. Do this now; a forgotten
  t3.micro plus volume is ~$0.02/hr that nothing in this plan will clean up
  for you.

- [ ] **Step 3: Terraform lab — VPC module.**

  **Apple Silicon prerequisite — check this before anything else:**

  ```bash
  terraform version   # must report: on darwin_arm64
  ```

  If it says `on darwin_amd64` on an M-series Mac (`uname -m` → `arm64`), stop
  and install a native build. An x86_64 Terraform asks the registry for the
  `darwin_amd64` AWS provider — a ~900 MB x86_64 binary whose schema
  initialization under Rosetta takes minutes, far past Terraform's ~60s plugin
  start timeout. Every command that needs the provider schema (`validate`,
  `plan`, `apply`) then dies with:

  ```
  Error: Failed to load plugin schemas
  Could not load the schema for provider registry.terraform.io/hashicorp/aws:
  failed to instantiate provider ... timeout while waiting for plugin to start
  ```

  The config is fine; the binary architecture is not. Fix:

  ```bash
  # 1. Install the native arm64 build ahead of any Intel one on PATH
  curl -sSL -o /tmp/tf.zip \
    https://releases.hashicorp.com/terraform/1.16.1/terraform_1.16.1_darwin_arm64.zip
  mkdir -p ~/.local/bin && unzip -oq /tmp/tf.zip -d ~/.local/bin
  chmod +x ~/.local/bin/terraform
  # ensure ~/.local/bin precedes /usr/local/bin in PATH

  # 2. Confirm, then drop the amd64 provider cache and re-init
  terraform version                 # → on darwin_arm64
  rm -rf .terraform                 # in terraform/envs/sandbox
  terraform init
  file .terraform/providers/registry.terraform.io/hashicorp/aws/*/*/terraform-provider-aws*
  #   → Mach-O 64-bit executable arm64
  ```

  With the native provider, `terraform validate` returns in seconds instead of
  timing out. (Homebrew installed under `/usr/local` is the Intel one; a native
  `brew` lives at `/opt/homebrew`.)

  Create `terraform/modules/vpc/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "isolated_subnet_cidrs" {
  type = list(string)
}
```

  Create `terraform/modules/vpc/main.tf`:

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name}-public-${count.index + 1}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "${var.name}-private-${count.index + 1}", Tier = "private" }
}

resource "aws_subnet" "isolated" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "${var.name}-isolated-${count.index + 1}", Tier = "isolated" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_eip" "nat" {
  count  = length(var.azs)
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.name}-nat-${count.index + 1}" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = { Name = "${var.name}-private-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-isolated-rt" }
}

resource "aws_route_table_association" "isolated" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}
```

  Create `terraform/modules/vpc/outputs.tf`:

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  value = aws_subnet.isolated[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "isolated_route_table_id" {
  value = aws_route_table.isolated.id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}
```

  Create `terraform/envs/sandbox/main.tf`:

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

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

  Create `terraform/envs/sandbox/variables.tf`:

```hcl
variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_profile" {
  type    = string
  default = "sandbox"
}
```

  Create `terraform/envs/sandbox/outputs.tf`:

```hcl
output "shared_services_vpc_id" {
  value = module.shared_services_vpc.vpc_id
}

output "shared_services_private_subnet_ids" {
  value = module.shared_services_vpc.private_subnet_ids
}
```

  Create `terraform/envs/sandbox/terraform.tfvars`:

```hcl
region      = "ap-southeast-1"
aws_profile = "sandbox"
```

- [ ] **Step 4: Init and apply.**

```bash
cd terraform/envs/sandbox
terraform init
terraform plan  -var-file=day01.tfvars
terraform apply -var-file=day01.tfvars -auto-approve
```

Expected plan output: `Plan: 22 to add, 0 to change, 0 to destroy.`

Count them before you apply — if your number differs, something is missing:

| Resource | Count |
|---|---|
| `aws_vpc` | 1 |
| `aws_subnet` (2 public + 2 private + 2 isolated) | 6 |
| `aws_internet_gateway` | 1 |
| `aws_eip` | 2 |
| `aws_nat_gateway` | 2 |
| `aws_route_table` (1 public + 2 private + 1 isolated) | 4 |
| `aws_route_table_association` (2 + 2 + 2) | 6 |
| **Total** | **22** |

Note there are **four** route tables, not three: the private tier gets one per
AZ so each can point at its own AZ's NAT Gateway, which is the whole reason
this plan builds two NAT Gateways.

- [ ] **Step 5: Verify via CLI.**

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=shared-services" \
  --profile sandbox --region ap-southeast-1 \
  --query "Vpcs[0].{VpcId:VpcId,CIDR:CidrBlock,DNS:EnableDnsHostnames}"
```

Expected: `{"VpcId": "vpc-xxx", "CIDR": "10.0.0.0/16", "DNS": true}`

- [ ] **Step 6: Journal entry.** Write in `journal.md`:
  - What is the difference between a private subnet and an isolated subnet
    in this VPC?
  - Why does each private subnet have its own NAT Gateway (not shared)?

- [ ] **Step 7: Teardown.**

**Console teardown first** — Terraform knows nothing about any of this:

1. **Terminate the break-it EC2** if you haven't already (EC2 → Instance state
   → Terminate).
2. **Delete the Console VPC**: VPC Console → Your VPCs → select
   `shared-services-vpc` → Actions → Delete VPC. This cascades to its subnets,
   route tables, IGW and NAT Gateways.
3. **Release the Elastic IPs the wizard allocated.** This is the step everyone
   misses. Deleting the VPC deleted its NAT Gateways, but their EIPs are still
   allocated to your account and still billing at ~$0.005/hr each:

   ```bash
   aws ec2 describe-addresses --profile sandbox --region ap-southeast-1 \
     --query "Addresses[?AssociationId==null].[PublicIp,AllocationId,Tags[?Key=='Name']|[0].Value]" \
     --output table
   ```

   Every row is an idle EIP. Release each one:

   ```bash
   aws ec2 release-address --allocation-id <eipalloc-xxx> \
     --profile sandbox --region ap-southeast-1
   ```

**Then Terraform:**

```bash
terraform destroy -var-file=day01.tfvars -auto-approve
```

**Then verify:**

```bash
./scripts/sweep.sh
```

Expect `ALL CLEAR`. If it reports DIRTY rows, clear them before you stop for
the day — every one of them is on a meter.

---

## Day 2 — Security Layer

**Theory file:** `content/day02.md` — read before starting the lab.
**Concepts build on:** Day 1's subnet model.
**Infra needed:** VPC only — `day02.tfvars`. Runnable standalone.
**Sets up for:** Day 8 queries the Flow Logs this module creates.

---

- [ ] **Step 1 (30 min): Read theory.** Open `content/day02.md`. Focus on:
  - Why SGs are stateful and NACLs are stateless
  - Why ephemeral ports matter for NACLs
  - Why SG-to-SG referencing scales better than CIDR rules

- [ ] **Step 2: Stand up today's baseline.**

Day 2 needs the VPC only — the security layer is what you're about to build by
hand in the Console, so leave its flag off for now:

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day01.tfvars -auto-approve
```

This works whether or not you ran Day 1 today; the day files are independent.
You'll switch to `day02.tfvars` in Step 4 once the Console lab is torn down.

- [ ] **Step 3 (60 min): Console lab — Security Groups and NACLs.**

  **Security Groups:**

  Navigate: VPC Console → Security Groups → Create security group

  SG 1 — Web tier:
  - Name: `shared-services-web-sg`
  - VPC: `shared-services-vpc`
  - Inbound: Type `HTTPS`, Source `0.0.0.0/0`
  - Outbound: default (allow all)

  SG 2 — App tier:
  - Name: `shared-services-app-sg`
  - VPC: `shared-services-vpc`
  - Inbound: Type `Custom TCP`, Port `8080`, Source: select `shared-services-web-sg` by ID (not CIDR)
  - Outbound: default

  SG 3 — Data tier:
  - Name: `shared-services-data-sg`
  - VPC: `shared-services-vpc`
  - Inbound: Type `PostgreSQL` (5432), Source: select `shared-services-app-sg` by ID
  - Outbound: default

  **NACLs:**

  Navigate: Network ACLs → Create network ACL
  - Name: `shared-services-private-nacl`
  - VPC: `shared-services-vpc`

  After creation, add rules:
  - Inbound rule 100: TCP, Port 8080, Source `10.0.0.0/16`, ALLOW
  - Inbound rule 200: TCP, Port 1024-65535, Source `0.0.0.0/0`, ALLOW
  - Outbound rule 100: TCP, Port 8080, Destination `10.0.0.0/16`, ALLOW
  - Outbound rule 110: TCP, Port 443, Destination `0.0.0.0/0`, ALLOW
  - Outbound rule 200: TCP, Port 1024-65535, Destination `10.0.0.0/16`, ALLOW

  Two of those source/destination values are worth pausing on, because getting
  them wrong is the most common NACL mistake there is:

  - **Inbound 200 is `0.0.0.0/0`, not `10.0.0.0/16`.** NACLs are stateless, so
    the reply to *any* connection your instance opens outward arrives as a fresh
    inbound packet, from wherever the server lives. Scope the inbound ephemeral
    range to the VPC CIDR and you have silently banned every reply from outside
    the VPC — package installs, SSM registration, S3, all of it. The port range
    is the control here; the source cannot be.
  - **Outbound 110 (`443` to `0.0.0.0/0`) is what makes SSM work at all.** On
    Days 2–4 the SSM agent registers over the internet through the NAT Gateway.
    Without this rule the instances in this subnet never become manageable and
    **Connect → Session Manager** stays greyed out. From Day 5 the interface
    endpoints carry it privately and this rule stops being load-bearing.

  Associate the NACL to both private subnets: Subnet associations → Edit → select both private subnets.

  **VPC Flow Logs:**

  Navigate: Your VPCs → select `shared-services-vpc` → Flow logs tab → Create flow log
  - Filter: `All`
  - Max aggregation interval: `1 minute`
  - Destination: `Send to CloudWatch Logs`
  - Destination log group: create new `/vpc/shared-services/flow-logs`
  - IAM role: create new — the Console will offer to auto-create the role; accept it.

  **Launch a test instance for this exercise.** You need a shell inside the
  private subnet. Use the harness rather than clicking through the launch wizard
  — it attaches the SSM role for you and, more importantly, it gets torn down by
  the same `destroy` as everything else:

```bash
terraform apply -var-file=day02.tfvars -auto-approve
aws ssm start-session --profile sandbox \
  --target "$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')"
```

  (`enable_security` in `day02.tfvars` also builds the Terraform copy of the SGs
  and NACL, which will collide with the Console ones you just made. Either do
  this exercise on the Console NACL *before* applying `day02.tfvars`, or delete
  the Console resources first — see Step 7. The collision itself is Step 4's
  lesson.)

  If Session Manager won't connect, your NACL is missing outbound 443 or the
  inbound ephemeral range — which is exactly what this exercise is about.

  **Break-it exercise:** Edit the private NACL and delete **Inbound** rule 200
  (the ephemeral range). From the test instance:

```bash
curl -sS --max-time 10 https://example.com ; echo "exit=$?"
```

  Expect it to hang and then fail with `exit=28` (timeout). Trace why: the
  outbound SYN to port 443 is allowed by outbound rule 110 and leaves through
  the NAT Gateway. The server's SYN-ACK comes back to your instance's
  **ephemeral** port as a brand-new inbound packet — and with rule 200 gone,
  nothing matches it, so the implicit `*` DENY drops it. The handshake never
  completes.

  Note carefully which rule you deleted. A returning SYN-ACK is an *inbound*
  packet, so it is governed by the **inbound** ephemeral rule. Deleting the
  *outbound* ephemeral rule breaks a different path — a server in this subnet
  replying from port 8080 to a client's ephemeral port — and would leave this
  particular `curl` working. Statelessness means you must reason about each
  direction as its own packet; this is the single most useful habit NACLs teach.

  Check Flow Logs in CloudWatch Logs Insights after ~2 minutes:

```
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action
| filter action = "REJECT" and srcPort = 443
| sort @timestamp desc | limit 20
```

  The REJECT rows show the inbound SYN-ACKs being dropped — `srcPort` 443,
  `dstPort` in the ephemeral range. Restore inbound rule 200 and re-run the
  `curl`; it should return `exit=0`.

- [ ] **Step 4: Terraform lab — Security module.**

  Create `terraform/modules/security/variables.tf`:

```hcl
variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "name" {
  type = string
}
```

  Create `terraform/modules/security/main.tf`:

```hcl
resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Web tier — inbound 443 from internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-web-sg", Tier = "web" }
}

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App tier — inbound 8080 from web SG only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-app-sg", Tier = "app" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_web" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "data" {
  name        = "${var.name}-data-sg"
  description = "Data tier — inbound 5432 from app SG only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-data-sg", Tier = "data" }
}

resource "aws_vpc_security_group_ingress_rule" "data_from_app" {
  security_group_id            = aws_security_group.data.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "data_all" {
  security_group_id = aws_security_group.data.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.name}-private-nacl" }
}

resource "aws_network_acl_rule" "private_inbound_app" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 8080
  to_port        = 8080
}

# Ephemeral inbound must be 0.0.0.0/0: this is the return path for every
# outbound connection, and the far end is usually outside the VPC.
resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_outbound_app" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 8080
  to_port        = 8080
}

# Outbound 443 to the internet via NAT — required for SSM agent registration
# on Days 2-4. From Day 5 the interface endpoints carry this privately.
resource "aws_network_acl_rule" "private_outbound_https" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "private_outbound_ephemeral" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = 7
  tags              = { Name = "${var.name}-flow-logs" }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name}-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id
  tags                 = { Name = "${var.name}-flow-log" }
}
```

  Create `terraform/modules/security/outputs.tf`:

```hcl
output "web_sg_id" {
  value = aws_security_group.web.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "data_sg_id" {
  value = aws_security_group.data.id
}

output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow_logs.name
}
```

  Add to `terraform/envs/sandbox/main.tf`:

```hcl
module "shared_services_security" {
  source = "../../modules/security"

  name               = "shared-services"
  vpc_id             = module.shared_services_vpc.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = module.shared_services_vpc.private_subnet_ids
}
```

- [ ] **Step 5: Apply and verify.**

```bash
terraform apply -var-file=day02.tfvars -auto-approve
```

Expected: **`Plan: 27 to add`** — 19 from the security module plus 8 from the
EC2 test harness:

| Security module | Count |
|---|---|
| `aws_security_group` (web, app, data) | 3 |
| `aws_vpc_security_group_ingress_rule` | 3 |
| `aws_vpc_security_group_egress_rule` | 3 |
| `aws_network_acl` | 1 |
| `aws_network_acl_rule` (2 in + 3 out) | 5 |
| `aws_cloudwatch_log_group` | 1 |
| `aws_iam_role` + `aws_iam_role_policy` | 2 |
| `aws_flow_log` | 1 |
| **subtotal** | **19** |

| EC2 test module | Count |
|---|---|
| `aws_iam_role` + attachment + instance profile | 3 |
| `aws_security_group` + 2 rules | 3 |
| `aws_instance` (one per private subnet) | 2 |
| **subtotal** | **8** |

If you set only `enable_security = true` and leave `enable_ec2_test = false`,
expect 19.

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$(terraform output -raw shared_services_vpc_id)" \
  --profile sandbox --region ap-southeast-1 \
  --query "SecurityGroups[*].{Name:GroupName,Id:GroupId}"
```

Expected: the 3 tier SGs (`shared-services-web-sg`, `app-sg`, `data-sg`), plus
the harness `shared-services-ec2-test-sg` and the VPC's `default`.

**Verify the SG chain end to end.** This is the payoff for building three tiers
that reference each other by ID. From the test instance:

```bash
aws ssm start-session --profile sandbox \
  --target "$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')"
# inside the session — the other test instance runs an echo server on 8080:
nc -zv <private-ip-of-instance-2> 8080   # succeeds
nc -zv <private-ip-of-instance-2> 9999   # hangs, then fails: nothing listening
```

Get the IPs from `terraform output ec2_test_shared_services_ips`.

- [ ] **Step 6: Journal entry.** Answer:
  - If a client sends a TCP SYN to port 8080 in the private subnet, trace
    the full packet path through NACL and SG layers. What happens to the
    SYN-ACK response packet at the NACL?

- [ ] **Step 7: Teardown.**

**Console teardown first.** Order matters here — security groups that
reference each other cannot be deleted out of order:

1. **Security groups**, in this exact sequence: `shared-services-data-sg`,
   then `app-sg`, then `web-sg`. Each references the one before it, and AWS
   refuses to delete a group while another group's rule still points at it.
2. **NACL** `shared-services-private-nacl`: you cannot delete a NACL that still
   has subnet associations. First go to the **default** NACL → Subnet
   associations → Edit → add both private subnets (this moves them off the
   custom NACL), then delete the custom one.
3. **Flow log** on the VPC (Your VPCs → Flow logs tab → select → Delete).
4. **CloudWatch log group** `/vpc/shared-services/flow-logs`. Terraform will
   refuse to create this on any future Day 2 run if it still exists —
   `ResourceAlreadyExistsException`.
5. **IAM role** the Console auto-created for the flow log. It is named
   `VPCFlowLogs-Cloudwatch-<digits>` — find it under IAM → Roles. Free, but it
   accumulates one per Console run.

```bash
# quick check that nothing security-related survives
aws ec2 describe-security-groups --profile sandbox --region ap-southeast-1 \
  --query "SecurityGroups[?GroupName!='default'].GroupName" --output text
aws logs describe-log-groups --profile sandbox --region ap-southeast-1 \
  --log-group-name-prefix /vpc/ --query "logGroups[*].logGroupName" --output text
```

Both should print nothing.

**Then Terraform** — same var-file you applied with:

```bash
terraform destroy -var-file=day02.tfvars -auto-approve
```

**Then verify:**

```bash
./scripts/sweep.sh
```

---

## Day 3 — DNS Inside VPC

**Theory file:** `content/day03.md` — read before starting.
**Concepts build on:** Day 2's SG model (the resolver endpoints need one).
**Infra needed:** VPC + security — `day03.tfvars`. Runnable standalone.
**Sets up for:** Day 6 activates the Resolver outbound rule built today.
**⚠ Most expensive day per hour:** Resolver endpoints bill ~$0.125/hr *per IP*.

---

- [ ] **Step 1 (30 min): Read theory.** Open `content/day03.md`. Focus on:
  - What enableDnsHostnames actually controls
  - Split-horizon DNS and why it matters for integration platforms
  - Why you need Resolver endpoints for hybrid DNS (not just a hosted zone)

- [ ] **Step 2: Stand up today's Console baseline.**

Day 3 needs the VPC and a shell inside it — not the DNS module, which you're
about to build by hand:

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day01.tfvars -var enable_ec2_test=true -auto-approve
```

You do **not** need to have run Days 1–2 today. Switch to `day03.tfvars` in
Step 4, after the Console resources are deleted.

> **Cost warning — read before Step 3.** Today's Console lab builds two Route 53
> Resolver endpoints. They bill **per IP address, ~$0.125/hr each**, and you're
> creating two endpoints with two IPs apiece: **~$0.50/hr, about $12/day**. This
> is by a wide margin the most expensive thing in these eight days, it is not
> covered by the free tier, and `terraform destroy` will not touch the Console
> copies. Do not walk away from this lab without completing Step 7.

- [ ] **Step 3 (60 min): Console lab — Private Hosted Zone and Resolver.**

  **Verify VPC DNS settings:**
  VPC Console → Your VPCs → select `shared-services-vpc` → Actions → Edit VPC settings
  Confirm both `Enable DNS resolution` and `Enable DNS hostnames` are checked.

  **Private hosted zone:**
  Navigate: Route 53 → Hosted zones → Create hosted zone
  - Domain name: `internal.platform`
  - Type: Private hosted zone
  - VPC Region: `ap-southeast-1`
  - VPC ID: `shared-services-vpc`

  Add an A record:
  - Record name: `api`
  - Type: A
  - Value: `10.0.2.10`
  - TTL: 300

  **Test resolution from EC2:**
  Step 2 already launched two SSM-managed instances in the private subnets.
  Connect to one:

```bash
aws ssm start-session --profile sandbox \
  --target "$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')"
```

  (If Session Manager is unavailable, give it ~2 minutes after boot and check
  `aws ssm describe-instance-information --profile sandbox`.)

  Inside the session:
  ```bash
  dig api.internal.platform
  ```
  Expected: `10.0.2.10` in the ANSWER section.

  ```bash
  dig api.internal.platform @8.8.8.8
  ```
  Expected: `NXDOMAIN` — the record only resolves inside the VPC (split-horizon).

  **Resolver endpoints:**
  Navigate: Route 53 → Resolver → Inbound endpoints → Create inbound endpoint
  - Name: `shared-services-inbound`
  - VPC: `shared-services-vpc`
  - Security group: create new `resolver-inbound-sg` allowing TCP/UDP 53 inbound from `10.0.0.0/8`
  - IP addresses: one in each private subnet (one per AZ)

  Outbound endpoint:
  - Name: `shared-services-outbound`
  - VPC: `shared-services-vpc`
  - Security group: create new `resolver-outbound-sg` allowing TCP/UDP 53 outbound
  - IP addresses: one in each private subnet

  Outbound rule:
  - Navigate: Route 53 → Resolver → Rules → Create rule
  - Name: `forward-corp-internal`
  - Rule type: Forward
  - Domain name: `corp.internal`
  - Outbound endpoint: `shared-services-outbound`
  - Target IP: `192.168.1.2` (placeholder — will be the simulated on-prem DNS on Day 6)
  - Associate with: `shared-services-vpc`

  **Break-it exercise:** Disassociate the `internal.platform` hosted zone from
  the VPC. Run `dig api.internal.platform` from the EC2 — observe `NXDOMAIN`.
  Reassociate and verify resolution returns.

- [ ] **Step 4: Terraform lab — DNS module.**

  Create `terraform/modules/dns/variables.tf`:

```hcl
variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "private_hosted_zone_name" {
  type    = string
  default = "internal.platform"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "resolver_sg_id" {
  type = string
}

variable "onprem_dns_ip" {
  type        = string
  description = "IP of the on-prem DNS server (used in Day 6)"
  default     = "192.168.1.2"
}
```

  Create `terraform/modules/dns/main.tf`:

```hcl
resource "aws_route53_zone" "private" {
  name = var.private_hosted_zone_name
  vpc {
    vpc_id = var.vpc_id
  }
  tags = { Name = "${var.name}-phz" }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api.${var.private_hosted_zone_name}"
  type    = "A"
  ttl     = 300
  records = ["10.0.2.10"]
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name               = "${var.name}-resolver-inbound"
  direction          = "INBOUND"
  security_group_ids = [var.resolver_sg_id]

  dynamic "ip_address" {
    for_each = var.private_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = { Name = "${var.name}-resolver-inbound" }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "${var.name}-resolver-outbound"
  direction          = "OUTBOUND"
  security_group_ids = [var.resolver_sg_id]

  dynamic "ip_address" {
    for_each = var.private_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = { Name = "${var.name}-resolver-outbound" }
}

resource "aws_route53_resolver_rule" "corp_internal" {
  name                 = "forward-corp-internal"
  domain_name          = "corp.internal"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = var.onprem_dns_ip
  }

  tags = { Name = "${var.name}-corp-internal-rule" }
}

resource "aws_route53_resolver_rule_association" "corp_internal" {
  vpc_id           = var.vpc_id
  resolver_rule_id = aws_route53_resolver_rule.corp_internal.id
}
```

  Create `terraform/modules/dns/outputs.tf`:

```hcl
output "hosted_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "resolver_inbound_endpoint_id" {
  value = aws_route53_resolver_endpoint.inbound.id
}

output "resolver_outbound_endpoint_id" {
  value = aws_route53_resolver_endpoint.outbound.id
}
```

  Add a resolver security group to the security module (append to
  `terraform/modules/security/main.tf`):

```hcl
resource "aws_security_group" "resolver" {
  name        = "${var.name}-resolver-sg"
  description = "Route 53 Resolver endpoints"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-resolver-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "resolver_dns_tcp" {
  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "resolver_dns_udp" {
  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = "10.0.0.0/8"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "resolver_all" {
  security_group_id = aws_security_group.resolver.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

  Add to `terraform/modules/security/outputs.tf`:

```hcl
output "resolver_sg_id" {
  value = aws_security_group.resolver.id
}
```

  Add to `terraform/envs/sandbox/main.tf`:

```hcl
module "shared_services_dns" {
  source = "../../modules/dns"

  name               = "shared-services"
  vpc_id             = module.shared_services_vpc.vpc_id
  private_subnet_ids = module.shared_services_vpc.private_subnet_ids
  resolver_sg_id     = module.shared_services_security.resolver_sg_id
}
```

- [ ] **Step 5: Apply and verify.**

```bash
terraform apply -var-file=day03.tfvars -auto-approve
```

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name internal.platform \
  --profile sandbox \
  --query "HostedZones[0].{Name:Name,Id:Id,Private:Config.PrivateZone}"
```

Expected: `{"Name": "internal.platform.", "Private": true}`

- [ ] **Step 6: Journal entry.** Answer:
  - What is the difference between the inbound and outbound Resolver endpoints?
    Which direction does each handle, and who sends the query in each case?

- [ ] **Step 7: Teardown.**

**Console teardown first — this is the expensive one.** The two Resolver
endpoints burn roughly $0.50/hr between them until they are gone.

1. **Resolver rule association, then the rule.** Route 53 → Resolver → Rules →
   `forward-corp-internal` → Associations → disassociate from the VPC, then
   delete the rule. A rule still associated with a VPC cannot be deleted.
2. **Both Resolver endpoints**: Route 53 → Resolver → Inbound endpoints →
   `shared-services-inbound` → Delete. Repeat for the outbound endpoint.
   Deletion takes a few minutes; wait for them to disappear.
3. **Private hosted zone** `internal.platform`: Route 53 → Hosted zones →
   delete the `api` A record first, then the zone. A zone with records other
   than its own NS/SOA cannot be deleted.
4. **Security groups** `resolver-inbound-sg` and `resolver-outbound-sg` — only
   after the endpoints are fully deleted and have released their ENIs.

```bash
# must print nothing before you stop for the day
aws route53resolver list-resolver-endpoints --profile sandbox \
  --region ap-southeast-1 --query "ResolverEndpoints[*].[Id,Direction,Status]" --output text
```

**Then Terraform:**

```bash
terraform destroy -var-file=day03.tfvars -auto-approve
```

If you applied `day03.tfvars` in Step 5, this also removes the Terraform
Resolver endpoints — equally billable, equally important.

**Then verify:**

```bash
./scripts/sweep.sh
```

Check the `resolver endpoints` row specifically. It must read `clean`.

---

## Day 4 — VPC Peering vs Transit Gateway

**Theory file:** `content/day04.md` — read before starting.
**Concepts build on:** Day 1's route tables.
**Infra needed:** VPC + security + app-vpc + TGW — `day04.tfvars`. No DNS layer,
so today costs nothing in Resolver endpoints. Runnable standalone.
**Sets up for:** Day 6's VPN terminates on this TGW.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - Why VPC peering is non-transitive
  - The N*(N-1)/2 peering problem
  - TGW route table segmentation for blast radius control

- [ ] **Step 2: Stand up today's Console baseline.**

Day 4 is about peering and TGW; it does not need Day 3's DNS layer, so don't
pay for Resolver endpoints today:

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day01.tfvars -var enable_ec2_test=true -auto-approve
```

That gives you `shared-services-vpc` and test instances. You'll build `app-vpc`
by hand in Step 3, and switch to `day04.tfvars` in Step 4.

- [ ] **Step 3 (60 min): Console lab — VPC Peering, then TGW.**

  **Create app-vpc first:**
  VPC Console → Create VPC → VPC and more
  - Name: `app`
  - CIDR: `10.1.0.0/16`
  - 2 AZs, 2 public + 2 private subnets, 1 NAT GW per AZ

  **VPC Peering (then we'll replace with TGW):**
  Navigate: Peering connections → Create peering connection
  - Name: `shared-services-to-app`
  - VPC (Requester): `shared-services-vpc`
  - VPC (Accepter): `app-vpc`
  Click Create. Navigate back to the peering connection, select it → Actions →
  Accept request.

  Add routes manually (both sides):
  - In `shared-services-vpc` private route tables: add route `10.1.0.0/16 → pcx-xxx`
  - In `app-vpc` private route tables: add route `10.0.0.0/16 → pcx-xxx`

  Observe the limitation: every new VPC requires updating every other VPC's
  route tables manually.

  **Delete the peering connection** (we're replacing with TGW):
  Peering connections → select → Actions → Delete peering connection.
  Also delete the manually added routes from both VPCs' route tables.

  **Transit Gateway:**
  Navigate: Transit Gateways → Create transit gateway
  - Name: `platform-tgw`
  - Amazon side ASN: `64512`
  - Default route table association: **Disable** (we manage our own)
  - Default route table propagation: **Disable**
  - Auto accept shared attachments: Disable

  Attach `shared-services-vpc`:
  Transit Gateway Attachments → Create → VPC → select `platform-tgw` →
  select `shared-services-vpc` → select both private subnets.

  Attach `app-vpc` same way, selecting its private subnets.

  Create TGW route tables:
  Transit Gateway Route Tables → Create → Name: `shared-services-rt`, TGW: `platform-tgw`
  Transit Gateway Route Tables → Create → Name: `app-rt`, TGW: `platform-tgw`

  Associate attachments to route tables:
  - `shared-services-vpc` attachment → Associate → `shared-services-rt`
  - `app-vpc` attachment → Associate → `app-rt`

  Enable propagations:
  - `shared-services-rt` → Propagations → Create → add both `shared-services-vpc` and `app-vpc` attachments
  - `app-rt` → Propagations → Create → add only `shared-services-vpc` attachment (app VPC cannot reach other app VPCs)

  Update VPC route tables to send cross-VPC traffic via TGW:
  - `shared-services-vpc` private route tables: add `10.1.0.0/16 → tgw-xxx`
  - `app-vpc` private route tables: add `10.0.0.0/16 → tgw-xxx`

  **Launch a test instance in `app-vpc`.** You already have two in
  `shared-services-vpc` from Step 2; the Console-built `app-vpc` needs one to
  ping. Launch it by hand for now (EC2 → Launch instance → t3.micro, Amazon
  Linux 2023, `app-vpc` private subnet, no key pair, IAM role with
  `AmazonSSMManagedInstanceCore`) and **write down its instance ID** — Step 7
  requires you to terminate it. From Step 4 onward the harness builds this
  instance for you in both VPCs.

  **Break-it exercise:** Remove the `10.1.0.0/16 → tgw` route from **one** of
  `shared-services-vpc`'s two private route tables — the one for AZ-a. Connect
  via SSM to each `shared-services` test instance in turn and ping the `app-vpc`
  instance:

```bash
ping -c 3 <app-vpc-instance-private-ip>
```

  The instance in AZ-a fails; the one in AZ-b succeeds. That asymmetry is the
  lesson: each private subnet has its own route table, so a route removed from
  one affects exactly one AZ. A service behind a load balancer would show up as
  "works about half the time" — the signature of a per-AZ routing fault.
  Restore the route and confirm both succeed.

- [ ] **Step 4: Terraform lab — TGW module.**

  Create `terraform/modules/tgw/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "shared_services_vpc_id" {
  type = string
}

variable "shared_services_private_subnet_ids" {
  type = list(string)
}

variable "shared_services_private_route_table_ids" {
  type = list(string)
}

variable "app_vpc_id" {
  type = string
}

variable "app_private_subnet_ids" {
  type = list(string)
}

variable "app_private_route_table_ids" {
  type = list(string)
}
```

  Create `terraform/modules/tgw/main.tf`:

```hcl
resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} Transit Gateway"
  amazon_side_asn                 = 64512
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  tags                            = { Name = "${var.name}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "shared_services" {
  vpc_id             = var.shared_services_vpc_id
  subnet_ids         = var.shared_services_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "shared-services-attachment" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  vpc_id             = var.app_vpc_id
  subnet_ids         = var.app_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "app-attachment" }
}

resource "aws_ec2_transit_gateway_route_table" "shared_services" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "shared-services-rt" }
}

resource "aws_ec2_transit_gateway_route_table" "app" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "app-rt" }
}

resource "aws_ec2_transit_gateway_route_table_association" "shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_association" "app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# shared-services-rt propagates routes from both attachments
resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_from_ss" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_from_app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

# app-rt only propagates from shared-services (app cannot reach other app VPCs)
resource "aws_ec2_transit_gateway_route_table_propagation" "app_from_shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# VPC route table entries to send cross-VPC traffic via TGW
resource "aws_route" "shared_services_to_app" {
  count                  = length(var.shared_services_private_route_table_ids)
  route_table_id         = var.shared_services_private_route_table_ids[count.index]
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.shared_services]
}

resource "aws_route" "app_to_shared_services" {
  count                  = length(var.app_private_route_table_ids)
  route_table_id         = var.app_private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.app]
}
```

  Create `terraform/modules/tgw/outputs.tf`:

```hcl
output "tgw_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "shared_services_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
}

output "app_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.app.id
}

output "shared_services_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.shared_services.id
}

output "app_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.app.id
}
```

  Add `app-vpc` module and TGW module to `terraform/envs/sandbox/main.tf`:

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

- [ ] **Step 5: Apply and verify.**

```bash
terraform apply -var-file=day04.tfvars -auto-approve
```

```bash
aws ec2 describe-transit-gateways \
  --filters "Name=tag:Name,Values=platform-tgw" \
  --profile sandbox --region ap-southeast-1 \
  --query "TransitGateways[0].{Id:TransitGatewayId,State:State}"
```

Expected: `{"State": "available"}`

- [ ] **Step 6: Journal entry.** Answer:
  - Why is the `app-rt` propagation limited to the shared-services attachment only?
  - What would happen if you also propagated `app-vpc`'s own routes into `app-rt`?

- [ ] **Step 7: Teardown.**

**Console teardown first.** TGW attachments bill ~$0.07/hr each and survive
everything Terraform does.

1. **Terminate the `app-vpc` test EC2** you launched in Step 3.
2. **TGW route table associations** → disassociate both attachments.
3. **TGW attachments** → delete both (`shared-services` and `app`). Wait until
   they report `deleted` — the TGW cannot be deleted while attachments exist.
4. **TGW route tables** `shared-services-rt` and `app-rt` → delete.
5. **Transit gateway** `platform-tgw` → delete.
6. **Peering connection** — if you did not already delete it during Step 3,
   delete it now, along with the manual `pcx-` routes in both VPCs.
7. **`app-vpc`** → Delete VPC (cascades to its subnets, IGW and NAT Gateways).
8. **Release `app-vpc`'s Elastic IPs** — same trap as Day 1. Deleting the VPC
   deleted its two NAT Gateways but left their EIPs allocated:

   ```bash
   aws ec2 describe-addresses --profile sandbox --region ap-southeast-1 \
     --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" --output table
   # then, for each row:
   aws ec2 release-address --allocation-id <eipalloc-xxx> --profile sandbox --region ap-southeast-1
   ```

```bash
# both must print nothing
aws ec2 describe-transit-gateways --profile sandbox --region ap-southeast-1 \
  --query "TransitGateways[?State!='deleted'].TransitGatewayId" --output text
aws ec2 describe-transit-gateway-attachments --profile sandbox --region ap-southeast-1 \
  --query "TransitGatewayAttachments[?State!='deleted'].TransitGatewayAttachmentId" --output text
```

**Then Terraform:**

```bash
terraform destroy -var-file=day04.tfvars -auto-approve
```

TGW deletion is slow — expect this destroy to take 5–10 minutes. Let it finish;
interrupting it leaves attachments orphaned and still billing.

**Then verify:**

```bash
./scripts/sweep.sh
```

---

## Day 5 — VPC Endpoints + PrivateLink

**Theory file:** `content/day05.md` — read before starting.
**Concepts build on:** Day 1's routing, Day 2's SGs.
**Infra needed:** VPC + security + app-vpc + endpoints — `day05.tfvars`.
**No TGW today** — that PrivateLink works without one is the point.
Runnable standalone.
**Sets up for:** Day 7 uses the PrivateLink service for cross-account consumption.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - Difference between gateway endpoints and interface endpoints
  - Why S3 traffic through NAT Gateway is a cost problem
  - How PrivateLink works from the consumer's perspective (no peering needed)

- [ ] **Step 2: Stand up today's Console baseline.**

PrivateLink deliberately needs no peering and no TGW, so today skips Day 4's
Transit Gateway entirely — you only need a second VPC to act as the consumer:

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day01.tfvars \
  -var enable_app_vpc=true -var enable_ec2_test=true -auto-approve
```

That the consumer endpoint works with no TGW and no peering between the two
VPCs is the single most important thing to notice today.

- [ ] **Step 3 (60 min): Console lab — VPC Endpoints and PrivateLink.**

  **S3 Gateway endpoint:**
  Navigate: VPC Console → Endpoints → Create endpoint
  - Service category: AWS services
  - Search: `com.amazonaws.ap-southeast-1.s3`
  - Type: Gateway
  - VPC: `shared-services-vpc`
  - Route tables: select all private and isolated route tables

  After creation, check the private route tables — a new entry
  `pl-xxxxxxxxx (com.amazonaws.ap-southeast-1.s3) → vpce-xxx` appears
  automatically. This is the gateway endpoint route.

  **SSM Interface endpoint:**
  Endpoints → Create endpoint
  - Service: `com.amazonaws.ap-southeast-1.ssm`
  - Type: Interface
  - VPC: `shared-services-vpc`
  - Subnets: select both private subnets
  - Security groups: create `ssm-endpoint-sg` allowing TCP 443 from `10.0.0.0/16`
  - Enable private DNS: checked

  Repeat for `com.amazonaws.ap-southeast-1.ec2messages` and
  `com.amazonaws.ap-southeast-1.ssmmessages` (SSM requires all three).

  **Test SSM Session Manager:** Step 2 already launched SSM-managed instances
  in both VPCs' private subnets. The interesting test is proving the traffic
  now takes the private path rather than the NAT Gateway. From a
  `shared-services` instance:

```bash
aws ssm start-session --profile sandbox \
  --target "$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')"
# inside the session:
dig +short ssm.ap-southeast-1.amazonaws.com
```

  With private DNS enabled on the interface endpoint this resolves to a
  **10.0.x.x** address — an ENI in your own subnet. Before the endpoint existed
  it resolved to a public AWS IP and the agent reached it through the NAT
  Gateway. Same hostname, entirely different path; that substitution is what
  private DNS buys you.

  For a decisive check, temporarily remove the `0.0.0.0/0 → nat` route from a
  private route table. Session Manager keeps working — there is no longer any
  internet path in play. Restore the route afterwards.

  **PrivateLink service:**

  Deploy a placeholder NLB + target:
  - EC2: launch t3.micro in private subnet with a simple `nc -l 8080` as user_data
  - Target Group: IP type, port 8080
  - NLB: internal, private subnets, listener port 8080 → target group

  Endpoint service:
  Navigate: Endpoint services → Create endpoint service
  - Load balancers: select the NLB just created
  - Acceptance required: checked (whitelist mode)
  - Allowed principals: add your account ARN (for Day 7 cross-account, you'll add the second account ARN)

  Consumer side (from `app-vpc`):
  Endpoints → Create endpoint
  - Service name: paste the endpoint service name (`com.amazonaws.vpce.ap-southeast-1.vpce-svc-xxx`)
  - VPC: `app-vpc`
  - Subnets: app-vpc private subnets
  - Accept: back in Endpoint services → Endpoint connections → Accept

  **Break-it exercise:** Remove private DNS from the SSM endpoint. Attempt to
  connect via SSM Session Manager — it fails because `ssm.ap-southeast-1.amazonaws.com`
  now resolves to the public IP, which is unreachable from the private subnet
  (no public route). Re-enable private DNS and verify SSM reconnects.

- [ ] **Step 4: Terraform lab — Endpoints module.**

  Create `terraform/modules/endpoints/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_route_table_ids" {
  type = list(string)
}

variable "isolated_route_table_id" {
  type = string
}

variable "endpoint_sg_id" {
  type = string
}

variable "nlb_arn" {
  type        = string
  description = "ARN of the NLB fronting the PrivateLink service"
}

variable "allowed_principal_arns" {
  type        = list(string)
  description = "Account/IAM ARNs allowed to create endpoints for this service"
  default     = []
}
```

  Create `terraform/modules/endpoints/main.tf`:

```hcl
# S3 gateway endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(var.private_route_table_ids, [var.isolated_route_table_id])
  tags              = { Name = "${var.name}-s3-endpoint" }
}

# SSM interface endpoints (3 required for Session Manager)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.endpoint_sg_id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-ssm-endpoint" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.endpoint_sg_id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-ssmmessages-endpoint" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.endpoint_sg_id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-ec2messages-endpoint" }
}

# PrivateLink endpoint service.
#
# This module does not create the NLB — you build it by hand in Step 3 and pass
# its ARN in. So the service must be optional: with var.nlb_arn left at its ""
# default, an unconditional resource would send AWS network_load_balancer_arns
# = [""] and the apply fails with InvalidParameter. Gate it on the ARN.
resource "aws_vpc_endpoint_service" "this" {
  count                      = var.nlb_arn == "" ? 0 : 1
  acceptance_required        = true
  network_load_balancer_arns = [var.nlb_arn]
  tags                       = { Name = "${var.name}-endpoint-service" }
}

resource "aws_vpc_endpoint_service_allowed_principal" "this" {
  for_each                = var.nlb_arn == "" ? toset([]) : toset(var.allowed_principal_arns)
  vpc_endpoint_service_id = aws_vpc_endpoint_service.this[0].id
  principal_arn           = each.value
}
```

  Create `terraform/modules/endpoints/outputs.tf`:

```hcl
output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

# one() yields null instead of erroring when the service is disabled
output "endpoint_service_name" {
  value = one(aws_vpc_endpoint_service.this[*].service_name)
}

output "endpoint_service_id" {
  value = one(aws_vpc_endpoint_service.this[*].id)
}
```

  Add endpoint SG to security module (append to `modules/security/main.tf`):

```hcl
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints-sg"
  description = "VPC interface endpoints — allow 443 from VPC"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-endpoints-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.endpoints.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "endpoints_all" {
  security_group_id = aws_security_group.endpoints.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

  Add to `modules/security/outputs.tf`:

```hcl
output "endpoint_sg_id" {
  value = aws_security_group.endpoints.id
}
```

  Add to `terraform/envs/sandbox/main.tf`:

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

  Add to `terraform/envs/sandbox/variables.tf`:

```hcl
variable "privatelink_nlb_arn" {
  type        = string
  description = "ARN of the NLB for the PrivateLink service (create manually first)"
  default     = ""
}

variable "allowed_principal_arns" {
  type    = list(string)
  default = []
}
```

- [ ] **Step 5: Apply and verify.**

```bash
terraform apply -var-file=day05.tfvars -auto-approve
```

```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform output -raw shared_services_vpc_id)" \
  --profile sandbox --region ap-southeast-1 \
  --query "VpcEndpoints[*].{Service:ServiceName,Type:VpcEndpointType,State:State}"
```

Expected: 4 endpoints (`s3` Gateway + `ssm`, `ssmmessages`, `ec2messages` Interface), all `available`.

- [ ] **Step 6: Journal entry.** Answer:
  - Why does the S3 gateway endpoint not appear in `aws ec2 describe-vpc-endpoints`
    as a network interface in the subnet?

- [ ] **Step 7: Teardown.**

**Console teardown first.** Interface endpoints bill per AZ per endpoint and
the NLB bills hourly; neither is in Terraform state.

1. **Consumer endpoint in `app-vpc`** → Endpoints → delete. Do this before the
   endpoint service — a service with active connections cannot be deleted.
2. **Endpoint service** → Endpoint services → select → Delete.
3. **NLB**, then its **target group** (Load Balancers → delete, then Target
   Groups → delete). The NLB must go first.
4. **Terminate the `nc -l 8080` EC2** you launched as the PrivateLink target.
5. **Interface endpoints** `ssm`, `ssmmessages`, `ec2messages` → delete all three.
6. **S3 gateway endpoint** → delete (free, but it leaves routes behind in your
   route tables if you skip it).
7. **Security group** `ssm-endpoint-sg`, after the endpoints release their ENIs.

```bash
# must print nothing
aws ec2 describe-vpc-endpoints --profile sandbox --region ap-southeast-1 \
  --query "VpcEndpoints[*].[VpcEndpointId,ServiceName]" --output text
aws elbv2 describe-load-balancers --profile sandbox --region ap-southeast-1 \
  --query "LoadBalancers[*].LoadBalancerName" --output text
```

**Then Terraform:**

```bash
terraform destroy -var-file=day05.tfvars -auto-approve
```

**Then verify:**

```bash
./scripts/sweep.sh
```

Watch the `VPC endpoints`, `endpoint services` and `load balancers` rows.

---

## Day 6 — Hybrid Connectivity

**Theory file:** `content/day06.md` — read before starting.
**Concepts build on:** Day 4's TGW (the VPN attaches to it).
**Infra needed:** VPC + security + app-vpc + TGW + VPN — `day06.tfvars`.
Add `enable_dns = true` only if you also want to exercise the Day 3 Resolver
rule against the simulated on-prem DNS; it is optional and costs ~$0.50/hr.
**⚠ Highest total burn (~$1.10/hr).** Do it in one sitting.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - Why two tunnels are mandatory for VPN HA
  - Why BGP over static routes
  - The BGP ASN convention (AWS 64512, on-prem uses a different private ASN)

- [ ] **Step 2: Stand up today's baseline.**

The VPN terminates on the Transit Gateway, so today does need Day 4's TGW —
but not Day 3's DNS or Day 5's endpoints:

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day01.tfvars \
  -var enable_app_vpc=true -var enable_tgw=true -var enable_ec2_test=true -auto-approve
```

> **Cost warning.** Today is the most expensive day in the plan: two VPCs with
> four NAT Gateways, a TGW with two attachments, a VPN connection, a third
> (`onprem-sim`) VPC with its own NAT Gateway, and the strongSwan instance —
> roughly **$1.10/hr**, about **$26/day**. Budget a single sitting for it and
> complete Step 7 before you stop.

- [ ] **Step 3 (90 min): Console lab — Simulated on-prem VPN.**

  **Create the simulated on-prem VPC:**
  VPC Console → Create VPC → VPC and more
  - Name: `onprem-sim`
  - CIDR: `192.168.0.0/16`
  - 1 AZ, 1 public subnet
  - 1 NAT GW

  **Launch strongSwan EC2:**
  EC2 → Launch instance
  - AMI: Amazon Linux 2023
  - Instance type: t3.micro
  - Network: `onprem-sim-vpc`, public subnet
  - Auto-assign public IP: Enable
  - Security group: allow UDP 500, UDP 4500 (IKE/IPSec) inbound from `0.0.0.0/0`;
    allow all traffic from `192.168.0.0/16`
  - User data: (strongSwan config goes in after VPN credentials are created below)
  - Note the Elastic IP after launch — this becomes the Customer Gateway IP

  Disable source/destination check on the instance:
  EC2 → select instance → Actions → Networking → Change source/destination check → Disable

  **Customer Gateway:**
  VPC Console → Customer Gateways → Create customer gateway
  - Name: `onprem-sim-cgw`
  - BGP ASN: `65000`
  - IP address: the Elastic IP of the strongSwan EC2

  **VPN Connection (attached to TGW):**
  Site-to-Site VPN connections → Create VPN connection
  - Name: `onprem-sim-vpn`
  - Target gateway type: Transit gateway
  - Transit gateway: `platform-tgw`
  - Customer gateway: `onprem-sim-cgw`
  - Routing options: Dynamic (requires BGP)
  - Tunnel 1 inside IPv4 CIDR: `169.254.10.0/30`
  - Tunnel 2 inside IPv4 CIDR: `169.254.10.4/30`

  Wait ~5 minutes. Download the configuration (strongSwan format). Note the
  PSK, tunnel IPs, and AWS endpoint IPs from the downloaded file.

  **Configure strongSwan:**
  SSM into the strongSwan EC2 and configure `/etc/strongswan/ipsec.conf`
  and `/etc/strongswan/ipsec.secrets` using the values from the downloaded
  config. Restart strongSwan. Both tunnel states should move to `UP` within
  2–3 minutes (check VPN connection status in the Console).

  **TGW route table update:**
  TGW route tables → `shared-services-rt` → Propagations → Create propagation →
  add the VPN attachment. This propagates `192.168.0.0/16` routes into the TGW
  route table automatically via BGP.

  Update `shared-services-vpc` private route tables:
  Add `192.168.0.0/16 → tgw-xxx` (for traffic from the VPC toward on-prem).

  Also update the `onprem-sim-vpc` route table:
  Add `10.0.0.0/8 → <strongSwan EC2 ENI>` so on-prem traffic toward AWS
  routes through the VPN instance.

  **Break-it exercise:** In the strongSwan config, comment out tunnel 1's
  connection block and restart strongSwan. Observe that tunnel 1 goes DOWN
  in the Console but tunnel 2 stays UP and traffic fails over automatically
  (BGP withdraws and re-advertises the route via tunnel 2). Restore tunnel 1.

- [ ] **Step 4: Terraform lab — VPN module.**

  Create `terraform/modules/vpn/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "tgw_id" {
  type = string
}

variable "tgw_shared_services_route_table_id" {
  type = string
}

variable "customer_gateway_ip" {
  type        = string
  description = "Elastic IP of the strongSwan EC2"
}

variable "shared_services_private_route_table_ids" {
  type = list(string)
}
```

  Create `terraform/modules/vpn/main.tf`:

```hcl
resource "aws_customer_gateway" "onprem_sim" {
  bgp_asn    = 65000
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"
  tags       = { Name = "${var.name}-cgw" }
}

resource "aws_vpn_connection" "onprem_sim" {
  customer_gateway_id = aws_customer_gateway.onprem_sim.id
  transit_gateway_id  = var.tgw_id
  type                = "ipsec.1"
  static_routes_only  = false
  tunnel1_inside_cidr = "169.254.10.0/30"
  tunnel2_inside_cidr = "169.254.10.4/30"
  tags                = { Name = "${var.name}-vpn" }
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_to_shared_services" {
  transit_gateway_attachment_id  = aws_vpn_connection.onprem_sim.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.tgw_shared_services_route_table_id
}

resource "aws_route" "shared_services_to_onprem" {
  count                  = length(var.shared_services_private_route_table_ids)
  route_table_id         = var.shared_services_private_route_table_ids[count.index]
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = var.tgw_id
  depends_on             = [aws_vpn_connection.onprem_sim]
}
```

  Create `terraform/modules/vpn/outputs.tf`:

```hcl
output "vpn_connection_id" {
  value = aws_vpn_connection.onprem_sim.id
}

output "tunnel1_address" {
  value     = aws_vpn_connection.onprem_sim.tunnel1_address
  sensitive = true
}

output "tunnel2_address" {
  value     = aws_vpn_connection.onprem_sim.tunnel2_address
  sensitive = true
}

output "tunnel1_psk" {
  value     = aws_vpn_connection.onprem_sim.tunnel1_preshared_key
  sensitive = true
}

output "tunnel2_psk" {
  value     = aws_vpn_connection.onprem_sim.tunnel2_preshared_key
  sensitive = true
}
```

  Add to `terraform/envs/sandbox/main.tf`:

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

  Add to `terraform/envs/sandbox/variables.tf`:

```hcl
variable "customer_gateway_ip" {
  type        = string
  description = "Elastic IP of the on-prem sim strongSwan EC2"
  default     = ""
}
```

- [ ] **Step 5: Apply (after creating the strongSwan EC2 manually and noting its EIP).**

```bash
terraform apply -var-file=day06.tfvars -auto-approve
```

  Print VPN tunnel credentials for strongSwan config:

```bash
terraform output tunnel1_address
terraform output tunnel1_psk
terraform output tunnel2_address
terraform output tunnel2_psk
```

- [ ] **Step 6: Journal entry.** Answer:
  - What is the BGP inside CIDR (`169.254.10.0/30`) used for?
  - If both VPN tunnels go down, what happens to traffic from `shared-services-vpc`
    to `192.168.0.0/16`? Is data lost?

- [ ] **Step 7: Teardown.**

**Console teardown first**, in this order:

1. **VPN connection** `onprem-sim-vpn` → Site-to-Site VPN connections → Delete.
   (If you also created it in Terraform, `destroy` handles that copy — but the
   Console one is separate and bills separately at ~$0.05/hr.)
2. **Customer gateway** `onprem-sim-cgw` → delete (free, but it blocks nothing
   and accumulates).
3. **Terminate the strongSwan EC2.**
4. **Release the strongSwan Elastic IP.** You allocated this one explicitly, so
   it is easy to forget — terminating the instance does not release it:

   ```bash
   aws ec2 describe-addresses --profile sandbox --region ap-southeast-1 \
     --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" --output table
   aws ec2 release-address --allocation-id <eipalloc-xxx> --profile sandbox --region ap-southeast-1
   ```

5. **Delete `onprem-sim-vpc`**, then release *its* NAT Gateway EIP too (same
   command as above — run it again after the VPC is gone).
6. **TGW VPN attachment** → confirm it disappeared with the VPN connection;
   delete it if it lingers.

```bash
# must print nothing
aws ec2 describe-vpn-connections --profile sandbox --region ap-southeast-1 \
  --query "VpnConnections[?State!='deleted'].VpnConnectionId" --output text
```

**Then Terraform:**

```bash
terraform destroy -var-file=day06.tfvars -auto-approve
```

**Then verify:**

```bash
./scripts/sweep.sh
```

The `VPN connections`, `Elastic IPs` and `NAT gateways` rows all matter today.

---

## Day 7 — Multi-Account Networking

**Theory file:** `content/day07.md` — read before starting.
**Concepts build on:** Day 4's TGW and Day 5's PrivateLink service.
**Infra needed:** VPC + security + app-vpc + TGW + endpoints + RAM —
`day07.tfvars`. No VPN. Runnable standalone.
**Requires:** A second AWS account. Use a sub-account in your Organization
  or a separate personal sandbox account. If it is **outside** your
  Organization, `allow_external_principals` must be `true` (see Step 5).

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - RAM subnet sharing vs full VPC sharing (what the consumer account can/cannot do)
  - Why TGW cross-account attachments require explicit acceptance
  - PrivateLink for cross-account service consumption (no peering or TGW needed)

- [ ] **Step 2: Set up second account CLI profile.**

```bash
aws configure --profile sandbox-b
# Enter credentials for account B
aws sts get-caller-identity --profile sandbox-b
```

Verify account B ID is different from account A.

- [ ] **Step 3: Stand up today's baseline (no VPN — not needed for sharing).**

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day01.tfvars \
  -var enable_app_vpc=true -var enable_tgw=true -auto-approve
```

The TGW is required (you share it via RAM); the VPN and DNS layers are not.
Leave `enable_ec2_test` off in account A — today's test instances get launched
from **account B**, into account A's shared subnets, which is the whole point.

- [ ] **Step 4 (60 min): Console lab — RAM, cross-account TGW, cross-account PrivateLink.**

  **RAM subnet sharing (Account A → Account B):**
  Navigate: Resource Access Manager → Resource shares → Create resource share
  - Name: `shared-services-private-subnets`
  - Resources: select both private subnets from `shared-services-vpc`
  - Principals: enter Account B's account ID
  - Allow external accounts: yes

  In Account B Console: RAM → Shared with me → Accept the resource share.
  Account B can now see the subnets in its EC2 Console under **Subnets**,
  even though the VPC belongs to Account A. Launch a t3.micro in one of
  these subnets from Account B — it deploys into Account A's VPC CIDR.

  **Cross-account TGW attachment:**
  In Account A: TGW → share the TGW via RAM to Account B
  (Resource type: `ec2:TransitGateway`, add Account B as principal).

  In Account B: create a new VPC (`tenant-vpc`, CIDR `10.2.0.0/16`, private
  subnets `10.2.2.0/24` and `10.2.3.0/24`).

  In Account B: TGW Attachments → Create attachment → Transit gateway owner
  account: Account A's account ID, TGW ID: the shared TGW ID → select
  `tenant-vpc` private subnets.

  In Account A: TGW → Attachments → pending attachment from Account B → Accept.

  In Account A: TGW route table `shared-services-rt` → Propagations → add the
  new cross-account attachment.

  Update `tenant-vpc` route tables in Account B: add `10.0.0.0/16 → tgw-xxx`.

  **Cross-account PrivateLink:**
  In Account A: Endpoint services → the service created on Day 5 → Allowed
  principals → Add Account B's root ARN (`arn:aws:iam::<account-b-id>:root`).

  In Account B: Endpoints → Create endpoint → enter the endpoint service name
  from Day 5 → select `tenant-vpc`, private subnets.

  In Account A: Endpoint services → Endpoint connections → Accept Account B's
  pending connection.

  Verify from an EC2 in `tenant-vpc` (Account B): connect to the PrivateLink
  endpoint DNS name. Traffic routes privately — no internet, no TGW.

  **Break-it exercise:** Remove Account B from the endpoint service allowed
  principals. The existing endpoint in Account B moves to `rejected` state
  within a few minutes. Re-allow and verify it returns to `available`.

- [ ] **Step 5: Terraform lab — RAM module.**

  Create `terraform/modules/ram/variables.tf`:

```hcl
variable "name" {
  type = string
}

variable "subnet_arns" {
  type        = list(string)
  description = "ARNs of subnets to share"
}

variable "tgw_arn" {
  type        = string
  description = "ARN of the Transit Gateway to share"
}

variable "account_b_id" {
  type        = string
  description = "AWS account ID for account B"
}

variable "allow_external_principals" {
  type        = bool
  default     = true
  description = "True when account B is outside this AWS Organization"
}
```

  Create `terraform/modules/ram/main.tf`:

```hcl
# allow_external_principals must be TRUE when account B is not in the same
# AWS Organization — and the Console lab above told you to enable exactly that.
# Left false, the principal association is accepted but account B never sees
# the share, which is a genuinely confusing failure to debug. Set it from a
# variable so the same module works both ways.
resource "aws_ram_resource_share" "subnets" {
  name                      = "${var.name}-subnet-share"
  allow_external_principals = var.allow_external_principals
  tags                      = { Name = "${var.name}-subnet-share" }
}

resource "aws_ram_resource_association" "subnets" {
  for_each           = toset(var.subnet_arns)
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

resource "aws_ram_principal_association" "account_b_subnets" {
  principal          = var.account_b_id
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name}-tgw-share"
  allow_external_principals = var.allow_external_principals
  tags                      = { Name = "${var.name}-tgw-share" }
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = var.tgw_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "account_b_tgw" {
  principal          = var.account_b_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

data "aws_caller_identity" "current" {}
```

  Create `terraform/modules/ram/outputs.tf`:

```hcl
output "subnet_share_arn" {
  value = aws_ram_resource_share.subnets.arn
}

output "tgw_share_arn" {
  value = aws_ram_resource_share.tgw.arn
}
```

  Add to `terraform/envs/sandbox/main.tf`:

```hcl
module "ram" {
  source = "../../modules/ram"

  name         = "platform"
  account_b_id = var.account_b_id
  tgw_arn      = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:transit-gateway/${module.tgw.tgw_id}"
  subnet_arns = [
    for id in module.shared_services_vpc.private_subnet_ids :
    "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"
  ]
}

data "aws_caller_identity" "current" {}
```

  Add to `terraform/envs/sandbox/variables.tf`:

```hcl
variable "account_b_id" {
  type        = string
  description = "AWS account ID for account B"
  default     = ""
}
```

- [ ] **Step 6: Apply and verify.**

```bash
terraform apply -var-file=day07.tfvars -auto-approve
```

```bash
aws ram list-resources \
  --resource-owner SELF \
  --profile sandbox --region ap-southeast-1 \
  --query "resources[*].{Arn:arn,Type:type,Status:status}"
```

Expected: shared subnets and TGW listed with `AVAILABLE` status.

- [ ] **Step 7: Journal entry.** Answer:
  - What is the difference between sharing a subnet (RAM) and sharing a full VPC?
  - When would you choose cross-account PrivateLink over cross-account TGW attachment?

- [ ] **Step 8: Teardown.**

**Account B first** — you cannot clean up account A while B still holds
attachments and endpoints into it.

1. **Terminate account B's EC2s**, including the one launched into account A's
   shared subnet. That instance is billed to **account B** but occupies account
   A's VPC, and it blocks the subnet share from being deleted.
2. **Delete account B's PrivateLink endpoint** into account A's service.
3. **Delete account B's TGW attachment** (from account B's console). Wait for
   `deleted`.
4. **Delete `tenant-vpc`** in account B, then release its Elastic IPs
   (`aws ec2 describe-addresses --profile sandbox-b` → `release-address`).

**Then account A:**

5. **RAM shares** → Resource shares → delete both the subnet share and the TGW
   share.
6. **Endpoint service allowed principals** → remove account B's ARN.
7. Then the full **Day 4 TGW teardown** (associations → attachments → route
   tables → TGW) and the **Day 5 endpoint teardown**.

```bash
# run against BOTH profiles
for p in sandbox sandbox-b; do
  echo "== $p =="
  aws ec2 describe-transit-gateway-attachments --profile $p --region ap-southeast-1 \
    --query "TransitGatewayAttachments[?State!='deleted'].TransitGatewayAttachmentId" --output text
  aws ec2 describe-instances --profile $p --region ap-southeast-1 \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" --output text
done
```

**Then Terraform:**

```bash
terraform destroy -var-file=day07.tfvars -auto-approve
```

**Then verify — both accounts:**

```bash
./scripts/sweep.sh sandbox
./scripts/sweep.sh sandbox-b
```

Account B is the one most likely to be forgotten; it has its own bill.

---

## Day 8 — Debugging and Reachability Analysis

**Theory file:** `content/day08.md` — read before starting.
**Concepts build on:** every prior day — this is the synthesis.
**Infra needed:** VPC + security + app-vpc + TGW + endpoints + test EC2s —
`day08.tfvars`. No VPN, no RAM, no DNS. Runnable standalone, and the only day
with no Console build step.
**Goal:** Build debugging intuition by diagnosing 5 intentional failures using
  the 5-layer ladder and Reachability Analyzer.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - The 5-layer debugging ladder (route → NACL → SG → endpoint policy → IAM)
  - What Reachability Analyzer returns for a blocked path vs an allowed path
  - The Flow Logs query pattern for finding REJECT entries

- [ ] **Step 2: Stand up the debugging topology.**

Today is entirely Terraform-driven — there is no Console build step to collide
with, so apply the day file directly. It brings up both VPCs, the TGW, the
security layer (for the NACL and SG failures), the endpoints (for the endpoint
policy failure), and the test instances:

```bash
cd terraform/envs/sandbox
terraform apply -var-file=day08.tfvars -auto-approve
```

  The harness gives you EC2-A and EC2-B without any manual launching:

```bash
terraform output ec2_test_shared_services_ids   # EC2-A (one per private subnet)
terraform output ec2_test_shared_services_ips
terraform output ec2_test_app_ids               # EC2-B
terraform output ec2_test_app_ips
```

  Capture them for the exercises below:

```bash
EC2_A=$(terraform output -json ec2_test_shared_services_ids | jq -r '.[0]')
EC2_B=$(terraform output -json ec2_test_app_ids            | jq -r '.[0]')
IP_B=$(terraform output -json ec2_test_app_ips             | jq -r '.[0]')
echo "A=$EC2_A  B=$EC2_B  B_ip=$IP_B"
```

  Each instance runs an echo server on port 8080 (from the module's user_data),
  so every "port 8080" test below has something real to connect to. Confirm the
  baseline works before you start breaking things:

```bash
aws ssm start-session --target "$EC2_A" --profile sandbox
# inside: nc -zv $IP_B 8080   →  succeeds
```

  If that fails now, fix it before Step 3 — otherwise you'll be debugging two
  faults at once.

- [ ] **Step 3 (60 min): 5-failure diagnosis lab.**

For each failure: **predict which layer** is broken before running Reachability Analyzer. Then confirm with the tool.

  **Failure 1 — Layer 1 (Route):**
  Remove the `10.1.0.0/16 → tgw` route from one of `shared-services-vpc`'s
  private route tables.
  
  Prediction: EC2-A in that AZ cannot reach EC2-B; EC2-A in the other AZ can.
  
  Reachability Analyzer:
  Navigate: VPC Console → Reachability Analyzer → Create and analyze path
  - Source type: Instance, Source: EC2-A
  - Destination type: Instance, Destination: EC2-B
  - Protocol: TCP, Destination port: 8080
  
  Expected result: `Not reachable`. Expand the path analysis — it identifies
  the missing route as the blocking component, with the route table ID.
  
  Fix: restore the route. Re-run the analysis — result changes to `Reachable`.

  **Failure 2 — Layer 2 (NACL):**
  In `shared-services-vpc`'s private NACL, add an explicit DENY rule at
  rule number 50 for TCP port 8080 (before the ALLOW at 100).
  
  Prediction: all traffic on port 8080 from the VPC CIDR is blocked at the
  subnet before it reaches any SG.
  
  Run Reachability Analyzer. Expected: `Not reachable`, component type
  `network-acl`, blocking rule number 50.
  
  Fix: delete the DENY rule at 50.

  **Failure 3 — Layer 3 (Security Group):**
  Remove the inbound rule from `shared-services-app-sg` (the rule allowing
  port 8080 from the web SG).
  
  Prediction: route is fine, NACL is fine, SG drops the packet.
  
  Run Reachability Analyzer with source = EC2 with web SG, destination =
  EC2 with app SG, port 8080. Expected: `Not reachable`, component type
  `security-group`.
  
  Fix: restore the inbound rule.

  **Failure 4 — Layer 4 (Endpoint policy):**
  Edit the S3 gateway endpoint policy to an explicit deny:
  Endpoints → select S3 endpoint → Policy tab → Edit
  Replace with:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "*"
    }]
  }
  ```
  From EC2-A: `aws s3 ls --profile sandbox` — observe `Access Denied`.
  Route is fine (the gateway endpoint is there), SG is fine, but the
  endpoint resource policy blocks all S3 actions.
  
  Fix: reset the endpoint policy to the default (Full access).

  **Failure 5 — Multi-layer (TGW attachment disruption):**
  Disassociate the `app-vpc` attachment from the `app-rt` TGW route table
  (TGW Route Tables → app-rt → Associations → disassociate app-vpc attachment).
  
  Prediction: app-vpc can no longer receive traffic via TGW — both the route
  table has no association (layer 1 at TGW level) and the TGW has no valid
  route for return traffic.
  
  Run Reachability Analyzer source=EC2-B (app-vpc), destination=EC2-A.
  Expected: `Not reachable`. The path analysis will show the TGW as the
  blocking component.
  
  Fix: reassociate the attachment.

- [ ] **Step 4: Flow Logs query.**

  Trigger a REJECT by attempting TCP to a blocked port:
  From EC2-A, run: `timeout 2 bash -c "echo > /dev/tcp/10.0.2.100/9999"` (any unused IP/port).

  After 2 minutes, query Flow Logs in CloudWatch Logs Insights:
  Navigate: CloudWatch → Logs Insights → select log group `/vpc/shared-services/flow-logs`

```
fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, protocol, action
| filter action = "REJECT"
| sort @timestamp desc
| limit 20
```

  Identify the REJECT entry for the port 9999 attempt.

- [ ] **Step 5: Terraform — Reachability Analyzer path as code.**

  Add to `terraform/envs/sandbox/main.tf` (after EC2 instances are created):

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

  Because the harness already builds these instances, wire the path straight to
  its outputs instead of passing IDs in by hand — no variables needed, and the
  path resource is created and destroyed with everything else:

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

  Note that `aws_ec2_network_insights_analysis` runs the analysis **once, at
  create time**. After you break something in Step 3, a re-`apply` will not
  re-run it — Terraform sees no change. Force a fresh run with:

```bash
terraform apply -var-file=day08.tfvars -replace=aws_ec2_network_insights_analysis.a_to_b[0] -auto-approve
```

  Each analysis costs ~$0.10, so prefer the Console for the iterative
  break-fix-recheck loop and keep this resource as the "path as code" example.

  Apply, then check the analysis result:

```bash
terraform apply -var-file=day08.tfvars -auto-approve

aws ec2 describe-network-insights-analyses \
  --profile sandbox --region ap-southeast-1 \
  --query "NetworkInsightsAnalyses[0].{Status:Status,Reachable:NetworkPathFound}"
```

Expected: `{"Status": "succeeded", "Reachable": true}` (if topology is correct).

- [ ] **Step 6: Final journal entry.** Complete this scenario in writing:
  "A developer on the app team says their service in `app-vpc` can't reach
  the shared API in `shared-services-vpc` on port 8080. Walk through the
  5-layer debugging ladder and describe exactly what you would check at
  each layer, in order, and what tool you would use to check it."

- [ ] **Step 7: Final teardown.**

Everything today was built by Terraform, including the test instances, so a
single destroy covers it — as long as you pass the same var-file:

```bash
terraform destroy -var-file=day08.tfvars -auto-approve
```

Expect 5–10 minutes; the TGW attachments dominate.

**Undo any Console edits you made during Step 3 first.** A DENY rule you added
to a NACL by hand lives on a Terraform-managed NACL — destroy removes the whole
NACL, so that one resolves itself. But the **S3 endpoint policy** from Failure 4
and any **route you deleted** are modifications to managed resources; leaving
them is harmless before a destroy, but if you plan to re-apply instead, reset
them or Terraform will show confusing drift.

**Then the final sweep** — this is the last one of the whole plan, so read every
row:

```bash
./scripts/sweep.sh
```

Then confirm nothing lingers in other regions, where a stray Console click is
easy to lose track of:

```bash
for r in ap-southeast-1 us-east-1 us-west-2; do
  echo "== $r =="
  aws ec2 describe-vpcs --profile sandbox --region $r \
    --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text
  aws ec2 describe-addresses --profile sandbox --region $r \
    --query "Addresses[*].AllocationId" --output text
done
```

Finally, check the bill itself two days later — Billing → Cost Explorer, grouped
by service, filtered to the last 7 days. A flat line after your teardown date is
the only real proof. Anything still accruing points at a resource none of the
above caught.

---

## Graduation check

By the end of Day 8, you should be able to:

- [ ] Draw the full topology from memory: two VPCs, TGW, VPN, PrivateLink, DNS
- [ ] Explain the 5-layer debugging ladder without notes
- [ ] Re-create any single module's Terraform from the AWS provider docs with
  no copy-paste — knowing the resource names and key arguments from memory
- [ ] Complete a Reachability Analyzer analysis and interpret the output in
  under 5 minutes
- [ ] Answer: "A new team wants to consume our shared API privately. They have
  their own AWS account. What are the two options, and when would you choose
  each?" — without hesitation
