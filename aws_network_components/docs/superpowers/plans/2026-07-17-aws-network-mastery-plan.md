# AWS Network Mastery — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each
> day is a study/lab session. Work the four blocks in order: read the theory
> file first, follow the lab guide, build in the Console, then rebuild the
> same thing in Terraform. Check off every step as you complete it. Do not
> skip ahead — the Terraform modules are cumulative; each day's code extends
> the previous day's. Teardown is a scheduled step at the end of every day,
> not an afterthought — NAT Gateways and TGW attachments run on a per-hour
> meter.

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

- Run `terraform destroy` at the end of every day — NAT Gateway (~$0.10/hr
  each), TGW (~$0.05/hr/attachment), and VPN connection (~$0.05/hr) are metered.
- Always build Console first, Terraform second — console visibility builds the
  mental model that makes Terraform debugging possible.
- Use region `ap-southeast-1` (Singapore) throughout. If you change regions,
  update `terraform.tfvars` and re-check AZ names (`ap-southeast-1a/b`).
- AWS CLI profile: set `AWS_PROFILE=sandbox` or use `--profile sandbox` in
  every CLI command. Never run labs against a production account.
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
  terraform/
    modules/
      vpc/            # Day 1: VPC, subnets, IGW, NAT, route tables
      security/       # Day 2: SGs, NACLs, Flow Logs
      dns/            # Day 3: Route53 PHZ, Resolver endpoints/rules
      tgw/            # Day 4: Transit Gateway, attachments, route tables
      endpoints/      # Day 5: VPC endpoints, PrivateLink NLB + service
      vpn/            # Day 6: Customer GW, VPN connection
      ram/            # Day 7: RAM shares, cross-account
    envs/
      sandbox/
        main.tf       # Root module — wires all modules together
        variables.tf
        outputs.tf
        terraform.tfvars
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

  Click **Create VPC** and wait ~3 minutes for NAT Gateways to provision.

  After creation, navigate to **Subnets** and verify 6 subnets exist:
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
  
  Create a new route table: **Route tables → Create route table**
  - Name: `shared-services-isolated-rt`
  - VPC: `shared-services-vpc`
  - No routes added (isolated tier has no default route)
  
  Associate both isolated subnets to this route table via **Subnet associations**.

  **Break-it exercise:** Navigate to the private route table for AZ-a.
  Edit routes and delete the `0.0.0.0/0 → nat` route. Launch a test EC2
  in that private subnet (t3.micro, Amazon Linux 2023, no key pair needed
  since we'll use SSM — but SSM endpoint isn't set up yet, so just observe
  the launch). Note: the instance will launch fine but cannot reach the
  internet. Restore the route before proceeding.

- [ ] **Step 3: Terraform lab — VPC module.**

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
  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${var.name}-public-${count.index + 1}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.name}-private-${count.index + 1}", Tier = "private" }
}

resource "aws_subnet" "isolated" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "${var.name}-isolated-${count.index + 1}", Tier = "isolated" }
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
terraform plan
terraform apply -auto-approve
```

Expected plan output: `Plan: 17 to add, 0 to change, 0 to destroy.`
(1 VPC + 6 subnets + 1 IGW + 2 EIPs + 2 NAT GWs + 3 route tables + 6
route table associations = 21 resources — adjust count if yours differs,
verify each resource type is present before applying.)

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

```bash
terraform destroy -auto-approve
```

Also delete the Console-built VPC manually: VPC Console → Your VPCs →
select `shared-services-vpc` → Actions → Delete VPC (this also deletes
subnets, route tables, IGW, and NAT GWs attached to it).

---

## Day 2 — Security Layer

**Theory file:** `content/day02.md` — read before starting the lab.
**Builds on:** Day 1 VPC module (re-apply before starting today's lab).
**Sets up for:** Day 3 needs Flow Logs already sending to CloudWatch.

---

- [ ] **Step 1 (30 min): Read theory.** Open `content/day02.md`. Focus on:
  - Why SGs are stateful and NACLs are stateless
  - Why ephemeral ports matter for NACLs
  - Why SG-to-SG referencing scales better than CIDR rules

- [ ] **Step 2: Re-apply Day 1 Terraform** (VPC base must exist for Console lab).

```bash
cd terraform/envs/sandbox
terraform apply -auto-approve
```

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
  - Inbound rule 200: TCP, Port 1024-65535, Source `10.0.0.0/16`, ALLOW
  - Outbound rule 100: TCP, Port 8080, Destination `10.0.0.0/16`, ALLOW
  - Outbound rule 200: TCP, Port 1024-65535, Destination `10.0.0.0/16`, ALLOW

  Associate the NACL to both private subnets: Subnet associations → Edit → select both private subnets.

  **VPC Flow Logs:**

  Navigate: Your VPCs → select `shared-services-vpc` → Flow logs tab → Create flow log
  - Filter: `All`
  - Max aggregation interval: `1 minute`
  - Destination: `Send to CloudWatch Logs`
  - Destination log group: create new `/vpc/shared-services/flow-logs`
  - IAM role: create new — the Console will offer to auto-create the role; accept it.

  **Break-it exercise:** Edit the private NACL. Delete Outbound rule 200
  (ephemeral ports). From an EC2 in the private subnet, attempt `curl https://8.8.8.8`.
  The TCP handshake succeeds (SYN reaches NAT GW) but the SYN-ACK is blocked
  by the missing ephemeral-port outbound rule — the connection hangs.
  Check Flow Logs in CloudWatch after 2 minutes: look for `REJECT` entries
  on port 443. Restore the rule.

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

resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
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
terraform apply -auto-approve
```

Expected: `Plan: 13 to add` (3 SGs + 5 SG rules + 1 NACL + 4 NACL rules +
1 CW log group + 1 IAM role + 1 IAM role policy + 1 flow log ≈ 13 new resources).

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$(terraform output -raw shared_services_vpc_id)" \
  --profile sandbox --region ap-southeast-1 \
  --query "SecurityGroups[*].{Name:GroupName,Id:GroupId}"
```

Expected: 3 SGs listed (`shared-services-web-sg`, `app-sg`, `data-sg`).

- [ ] **Step 6: Journal entry.** Answer:
  - If a client sends a TCP SYN to port 8080 in the private subnet, trace
    the full packet path through NACL and SG layers. What happens to the
    SYN-ACK response packet at the NACL?

- [ ] **Step 7: Teardown.**

```bash
terraform destroy -auto-approve
```

---

## Day 3 — DNS Inside VPC

**Theory file:** `content/day03.md` — read before starting.
**Builds on:** Days 1–2 modules (re-apply before Console lab).
**Sets up for:** Day 6 activates the Resolver outbound rule built today.

---

- [ ] **Step 1 (30 min): Read theory.** Open `content/day03.md`. Focus on:
  - What enableDnsHostnames actually controls
  - Split-horizon DNS and why it matters for integration platforms
  - Why you need Resolver endpoints for hybrid DNS (not just a hosted zone)

- [ ] **Step 2: Re-apply Days 1–2 Terraform.**

```bash
cd terraform/envs/sandbox
terraform apply -auto-approve
```

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
  Launch a t3.micro EC2 in a private subnet (use Amazon Linux 2023, no key pair,
  assign an IAM role with `AmazonSSMManagedInstanceCore` policy for SSM access).
  Wait ~2 minutes for SSM to register, then connect via SSM Session Manager.

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
terraform apply -auto-approve
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

```bash
terraform destroy -auto-approve
```

---

## Day 4 — VPC Peering vs Transit Gateway

**Theory file:** `content/day04.md` — read before starting.
**Builds on:** Days 1–3 modules.
**Sets up for:** Day 5 adds VPC endpoints and PrivateLink on top of this topology.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - Why VPC peering is non-transitive
  - The N*(N-1)/2 peering problem
  - TGW route table segmentation for blast radius control

- [ ] **Step 2: Re-apply Days 1–3 Terraform.**

```bash
terraform apply -auto-approve
```

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

  **Break-it exercise:** Remove the `10.1.0.0/16 → tgw` route from one
  `shared-services-vpc` private route table. Launch EC2s in both VPCs' private
  subnets, use SSM to connect, ping across — observe failure only from that AZ.
  Restore the route.

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
terraform apply -auto-approve
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

```bash
terraform destroy -auto-approve
```

---

## Day 5 — VPC Endpoints + PrivateLink

**Theory file:** `content/day05.md` — read before starting.
**Builds on:** Days 1–4 modules.
**Sets up for:** Day 7 uses the PrivateLink service for cross-account consumption.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - Difference between gateway endpoints and interface endpoints
  - Why S3 traffic through NAT Gateway is a cost problem
  - How PrivateLink works from the consumer's perspective (no peering needed)

- [ ] **Step 2: Re-apply Days 1–4 Terraform.**

```bash
terraform apply -auto-approve
```

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

  **Test SSM Session Manager:** Launch a t3.micro EC2 in a private subnet
  (Amazon Linux 2023, IAM role with `AmazonSSMManagedInstanceCore`, no public IP).
  Wait 2 minutes → EC2 Console → Connect → Session Manager. If successful,
  traffic is going through the interface endpoints, not the internet.

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

# PrivateLink endpoint service
resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = true
  network_load_balancer_arns = [var.nlb_arn]
  tags                       = { Name = "${var.name}-endpoint-service" }
}

resource "aws_vpc_endpoint_service_allowed_principal" "this" {
  for_each                = toset(var.allowed_principal_arns)
  vpc_endpoint_service_id = aws_vpc_endpoint_service.this.id
  principal_arn           = each.value
}
```

  Create `terraform/modules/endpoints/outputs.tf`:

```hcl
output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "endpoint_service_name" {
  value = aws_vpc_endpoint_service.this.service_name
}

output "endpoint_service_id" {
  value = aws_vpc_endpoint_service.this.id
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
terraform apply -auto-approve
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

```bash
terraform destroy -auto-approve
```

---

## Day 6 — Hybrid Connectivity

**Theory file:** `content/day06.md` — read before starting.
**Builds on:** Days 1–5 modules. The Day 3 Resolver outbound rule is activated today.
**Sets up for:** Day 7 builds on the full topology including VPN.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - Why two tunnels are mandatory for VPN HA
  - Why BGP over static routes
  - The BGP ASN convention (AWS 64512, on-prem uses a different private ASN)

- [ ] **Step 2: Re-apply Days 1–5 Terraform.**

```bash
terraform apply -auto-approve
```

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
  customer_gateway_id   = aws_customer_gateway.onprem_sim.id
  transit_gateway_id    = var.tgw_id
  type                  = "ipsec.1"
  static_routes_only    = false
  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel2_inside_cidr   = "169.254.10.4/30"
  tags                  = { Name = "${var.name}-vpn" }
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
terraform apply -auto-approve
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

```bash
terraform destroy -auto-approve
```

Also terminate the strongSwan EC2 and delete the `onprem-sim-vpc` manually.

---

## Day 7 — Multi-Account Networking

**Theory file:** `content/day07.md` — read before starting.
**Builds on:** Days 1–6 modules.
**Requires:** A second AWS account. Use a sub-account in your Organization
  or a separate personal sandbox account.

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

- [ ] **Step 3: Re-apply Days 1–6 Terraform (without VPN for simplicity today).**

```bash
terraform apply -auto-approve
```

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
```

  Create `terraform/modules/ram/main.tf`:

```hcl
resource "aws_ram_resource_share" "subnets" {
  name                      = "${var.name}-subnet-share"
  allow_external_principals = false
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
  allow_external_principals = false
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
  subnet_arns  = [
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
terraform apply -auto-approve
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

```bash
terraform destroy -auto-approve
```

---

## Day 8 — Debugging and Reachability Analysis

**Theory file:** `content/day08.md` — read before starting.
**Builds on:** The full Days 1–7 topology (re-apply all modules).
**Goal:** Build debugging intuition by diagnosing 5 intentional failures using
  the 5-layer ladder and Reachability Analyzer.

---

- [ ] **Step 1 (30 min): Read theory.** Focus on:
  - The 5-layer debugging ladder (route → NACL → SG → endpoint policy → IAM)
  - What Reachability Analyzer returns for a blocked path vs an allowed path
  - The Flow Logs query pattern for finding REJECT entries

- [ ] **Step 2: Re-apply full topology (Days 1–5; skip VPN/RAM for time).**

```bash
terraform apply -auto-approve
```

  Launch two EC2 test instances (one per VPC) for end-to-end testing:
  - EC2-A: private subnet in `shared-services-vpc`, Amazon Linux 2023,
    IAM role with `AmazonSSMManagedInstanceCore`
  - EC2-B: private subnet in `app-vpc`, same AMI and role

  Note both instance IDs and their private IPs.

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

  Add to `terraform/envs/sandbox/variables.tf`:

```hcl
variable "ec2_a_id" {
  type    = string
  default = ""
}

variable "ec2_b_id" {
  type    = string
  default = ""
}
```

  Apply, then check the analysis result:

```bash
terraform apply -auto-approve

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

```bash
terraform destroy -auto-approve
```

  Terminate both test EC2 instances manually. Verify zero running resources
  in the Console (EC2, VPC Endpoints, TGW, NAT GWs) to confirm no
  unintended charges.

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
