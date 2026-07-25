# AWS Compute, Load Balancing & Service Communication — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each
> day is a study/lab session. Work the blocks in order: read the theory file
> first, build in the Console, run the break-it exercise, write your journal
> entry, then codify in Terraform (synthesis days only). Check off every step
> as you complete it. Do not skip ahead — Phase 2 extends the ALB built in
> Phase 1; Phase 3 extends the ECS service built in Phase 2. Teardown is a
> scheduled step at the end of every day, not an afterthought — ALB and
> Fargate tasks run on a per-hour meter.

**Goal:** Reach production-credible competence in AWS Compute, Load Balancing,
and Service Communication in 12 days (2–3 hours/day) — able to choose between
ALB/NLB/GWLB, design ASG lifecycle hooks, deploy ECS Fargate services, and
select the right messaging primitive (SQS/SNS/EventBridge/Kinesis) for any
inter-service communication requirement.

**Architecture:** Three cumulative phases — Traffic & Compute (Days 1–4),
Container Layer (Days 5–7), Communication Layer (Days 8–12). Each phase's
Terraform module builds on the previous. Console first every day; Terraform
only on synthesis days (4, 7, 12) after the console build is fully understood.
Day 13 wires all three modules into one reference architecture.

**Tech Stack:** AWS Console, AWS CLI v2, Terraform >= 1.6 with AWS provider
>= 5.0, Amazon Linux 2023 AMI, Docker (Days 5–7), nginx (test container).

## Global Constraints

- Run `terraform destroy` at the end of every lab day — ALB (~$0.008/hr),
  NAT Gateway (~$0.045/hr), and Fargate tasks (per vCPU/memory-second) are
  metered. Estimated cost per 2–3 hour session: $1–3.
- Always build Console first, Terraform second — console visibility builds
  the mental model that makes Terraform debugging possible. Never open `.tf`
  until you can explain the resource in plain English.
- Use region `ap-southeast-1` (Singapore) throughout. If you change regions,
  update `terraform.tfvars` and re-check AZ names (`ap-southeast-1a/b`).
- AWS CLI profile: set `AWS_PROFILE=sandbox` or use `--profile sandbox`.
  Never run labs against a production account.
- The break-it exercise at the end of each console lab is mandatory — it is
  the primary mechanism for building debugging intuition under controlled
  conditions.
- VPC: reuse the VPC built in `aws_network_components`. You will need its
  VPC ID, public subnet IDs (2), and private subnet IDs (2). Retrieve them
  from the AWS Console → VPC → Your VPCs before Day 1.

## Project Layout

```
aws_computing_loadbalancing_communication_components/
  content/
    day01.md    # Theory: EC2 depth
    day02.md    # Theory: Load balancers (ALB/NLB/GWLB)
    day03.md    # Theory: Auto Scaling Groups
    day04.md    # Theory: Phase 1 synthesis
    day05.md    # Theory: ECS + Fargate + ECR
    day06.md    # Theory: ECS + ALB + service discovery
    day07.md    # Theory: Phase 2 synthesis
    day08.md    # Theory: SQS
    day09.md    # Theory: SNS + fan-out
    day10.md    # Theory: EventBridge
    day11.md    # Theory: API Gateway
    day12.md    # Theory: Kinesis + Phase 3 synthesis
    day13.md    # Theory: Full reference architecture (optional)
  terraform/
    phase1_compute/
      main.tf
      variables.tf
      outputs.tf
    phase2_containers/
      main.tf
      variables.tf
      outputs.tf
    phase3_communication/
      main.tf
      variables.tf
      outputs.tf
    main.tf         # Day 13: wires all phases
    terraform.tfvars
  docs/superpowers/
    specs/2026-07-23-aws-compute-lb-communication-design.md
    plans/2026-07-23-aws-compute-lb-communication-plan.md  (this file)
  journal.md
```

---

## Pre-flight: Prerequisites

Complete once before Day 1.

- [ ] **Verify tools.**

```bash
aws --version          # expect: aws-cli/2.x
terraform --version    # expect: Terraform v1.6+
docker --version       # expect: Docker 24.x+ (needed for Days 5–7)
```

- [ ] **Configure AWS CLI profile.**

```bash
aws configure --profile sandbox
# Default region: ap-southeast-1
# Output format: json

aws sts get-caller-identity --profile sandbox
```

Expected: JSON with your account ID. `InvalidClientTokenId` means the key
is wrong.

- [ ] **Retrieve VPC details from aws_network_components.**

In the AWS Console → VPC → Your VPCs, locate the VPC created in the network
mastery plan. Note:

```
VPC_ID=vpc-xxxxxxxxxxxxxxxxx
PUBLIC_SUBNET_1A=subnet-xxxxxxxxxxxxxxxxx   # ap-southeast-1a public
PUBLIC_SUBNET_1B=subnet-xxxxxxxxxxxxxxxxx   # ap-southeast-1b public
PRIVATE_SUBNET_1A=subnet-xxxxxxxxxxxxxxxxx  # ap-southeast-1a private
PRIVATE_SUBNET_1B=subnet-xxxxxxxxxxxxxxxxx  # ap-southeast-1b private
```

You will use these values throughout all three Terraform phases.

- [ ] **Create journal file.**

Create `journal.md` with this header:

```markdown
# AWS Compute, LB & Service Communication Journal

## Template (copy per day)
### Day N — <topic>
Key concept in my own words: ...
When would I NOT use this: ...
Break-it exercise — what I misconfigured and how I found it: ...
```

- [ ] **Create terraform/terraform.tfvars.**

```hcl
aws_region         = "ap-southeast-1"
aws_profile        = "sandbox"
vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"   # your VPC ID
public_subnet_ids  = ["subnet-xxx", "subnet-yyy"]
private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
name_prefix        = "compute-lab"
```

---

## Phase 1 — Traffic & Compute (Days 1–4)

---

## Day 1 — EC2 Depth

**Theory file:** `content/day01.md` — read before starting the lab.
**Builds on:** nothing (Day 1).
**Sets up for:** Days 2–4 extend the security group pattern established today.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day01.md`. Focus on:
  - Instance family decision matrix (C = compute, M = general, R = memory,
    T = burstable, G = GPU) — know which family to pick for a given workload
  - EBS type decision matrix: gp3 (default), io2 (IOPS-critical), st1
    (throughput, sequential), sc1 (cold archive)
  - Instance store vs EBS: instance store is faster but non-persistent;
    data is lost on stop/terminate
  - Purchasing options: on-demand (flexibility), reserved (1/3-year commit,
    ~40% cheaper), spot (up to 90% cheaper, can be interrupted), savings plans
  - Placement groups: cluster (low latency, same rack), spread (max
    availability, 7 instances per AZ per group), partition (Hadoop/Kafka,
    isolated failure domains)

  Before touching the Console, write in `journal.md`:
  - Which EBS type would you use for a MySQL primary instance?
  - When would you choose spot over on-demand?

- [ ] **Step 2 (60 min): Console lab — EC2 instance types and EBS.**

  **Part A: Launch two instances of different families.**

  Navigate: EC2 Console → Instances → Launch instances

  Instance 1 (compute-optimised):
  - Name: `lab-c6i`
  - AMI: Amazon Linux 2023
  - Instance type: `c6i.large`
  - Key pair: Proceed without a key pair
  - Network: your VPC, private subnet 1a, no public IP
  - Security group: Create new → name `lab-ec2-sg` → add inbound rule:
    HTTP port 80, source anywhere (0.0.0.0/0)
  - Storage: 1 x 8 GiB gp3

  Instance 2 (memory-optimised):
  - Name: `lab-r6i`
  - Same settings but instance type: `r6i.large`

  Wait until both show `running`.

  **Part B: Compare EBS types.**

  Navigate: EC2 Console → Volumes → Create volume
  - Volume 1: type `gp3`, 20 GiB, AZ `ap-southeast-1a`
    Note: gp3 default = 3000 IOPS, 125 MiB/s throughput. You can increase
    IOPS up to 16000 and throughput to 1000 MiB/s independently of size.
  - Volume 2: type `io2`, 20 GiB, AZ `ap-southeast-1a`, IOPS = 5000

  Attach both to `lab-c6i`:
  Navigate: Volumes → select volume → Actions → Attach volume → instance
  `lab-c6i`. After attach, the device appears in the instance as `/dev/sdf`.

  **Part C: Explore spot capacity.**

  Navigate: EC2 Console → Spot Requests → Spot placement score
  - Instance types: `c6i.large`, `c5.large`
  - Desired capacity: 10 units
  - Click View score — observe which regions/AZs have highest spot availability.

  This gives you a feel for where spot instances are likely to be interrupted.

- [ ] **Step 3 (15 min): Break-it exercise — wrong EBS type for IOPS workload.**

  Navigate to your `io2` volume. Edit → change type to `sc1` (cold HDD).
  Note: `sc1` cannot be used as a boot volume and has a max of 250 IOPS.

  Now open CloudWatch → Metrics → EBS → Per-Volume Metrics → select the
  volume → observe `VolumeReadOps` and `VolumeWriteOps`. If you write to
  the volume from the instance, you will see the throughput capped far
  below what an IOPS-sensitive workload requires.

  Change the volume type back to `io2` before proceeding.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 1 — EC2 Depth
  Key concept in my own words: ...
  When would I NOT use this (instance store): ...
  Break-it exercise — what I misconfigured and how I found it: ...
  ```

- [ ] **Step 5: Teardown.**

  Terminate both instances (Actions → Terminate instance).
  Delete both EBS volumes (Volumes → select → Actions → Delete volume).

---

## Day 2 — Load Balancers (ALB / NLB / GWLB)

**Theory file:** `content/day02.md` — read before starting the lab.
**Builds on:** Day 1 security group pattern.
**Sets up for:** Day 3 wires ASG into the ALB built today. Day 4 Terraform
codifies this entire stack.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day02.md`. Focus on:
  - OSI layer decision: ALB = L7 (reads HTTP headers), NLB = L4 (TCP/UDP),
    GWLB = L3 (IP packet, for inline security appliances)
  - ALB routing rules: path-based (`/api/*`), host-based (`api.example.com`),
    query string, HTTP method — evaluated top to bottom by priority
  - NLB: preserves source IP (no SNAT), supports static/elastic IPs per AZ,
    supports TCP/UDP/TLS — required for non-HTTP protocols
  - GWLB: GENEVE protocol on port 6081, transparent inspection, used in front
    of firewalls/IDS appliances — you will not encounter this in typical
    application work but must know it for SAA-C03
  - Health checks: ALB checks HTTP response code; NLB checks TCP connection
    (or HTTP if configured). Unhealthy threshold = 2 consecutive failures
    before target is deregistered.
  - Cross-zone load balancing: ALB has it enabled by default (routes to any
    target in any AZ); NLB has it disabled by default (routes within AZ only)

  Before touching Console, answer in `journal.md`:
  - You need to expose a gRPC service to the internet. ALB or NLB? Why?
  - Your compliance team requires a firewall to inspect all traffic before
    it reaches EC2. Which load balancer type sits in front of the firewall?

- [ ] **Step 2 (70 min): Console lab — ALB with path-based routing + NLB.**

  **Part A: Create two EC2 targets.**

  Navigate: EC2 → Launch instances (launch both at once using count=2)
  - Name: `lab-web`
  - AMI: Amazon Linux 2023
  - Instance type: `t3.micro`
  - Network: your VPC, private subnet 1a AND 1b (one in each AZ)
  - Security group: Create `lab-web-sg`
    - Inbound: HTTP 80, source: `lab-alb-sg` (we will create this next —
      for now use `0.0.0.0/0` and tighten after)
  - User data (Advanced → User data):
    ```bash
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
    echo "App server $(hostname)" > /usr/share/nginx/html/index.html
    mkdir -p /usr/share/nginx/html/api
    echo "API server $(hostname)" > /usr/share/nginx/html/api/index.html
    ```

  Wait until both instances show `2/2 checks passed`.

  **Part B: Create the ALB.**

  Navigate: EC2 → Load Balancers → Create load balancer → Application Load
  Balancer

  - Name: `lab-alb`
  - Scheme: Internet-facing
  - IP address type: IPv4
  - VPC: your VPC
  - Mappings: select BOTH AZs, select public subnet in each
  - Security group: Create new → `lab-alb-sg`
    - Inbound: HTTP 80 from `0.0.0.0/0`
    - Outbound: all traffic

  Target group (click "Create target group"):
  - Type: Instances
  - Name: `lab-app-tg`
  - Protocol: HTTP, port 80
  - Health check path: `/`
  - Register targets: select both EC2 instances

  Back in the ALB wizard, select `lab-app-tg` as the default target group.
  Click Create.

  Wait ~2 minutes. Navigate to the ALB → DNS name. Copy it and test:
  ```bash
  curl http://<alb-dns-name>/
  # Expected: "App server ip-10-0-x-x"
  ```

  Run several times — you should see both hostnames alternating (round-robin).

  **Part C: Add a second target group for /api/* path.**

  Navigate: Target Groups → Create target group
  - Name: `lab-api-tg`
  - Protocol: HTTP, port 80
  - Register the same two EC2 instances

  Navigate: Load Balancers → `lab-alb` → Listeners tab → HTTP:80 → View/edit rules

  Add rule (before the default):
  - IF: Path is `/api/*`
  - THEN: Forward to `lab-api-tg`
  - Priority: 1

  Test:
  ```bash
  curl http://<alb-dns-name>/api/
  # Expected: "API server ip-10-0-x-x"
  curl http://<alb-dns-name>/
  # Expected: "App server ip-10-0-x-x"
  ```

  **Part D: Create NLB and observe the differences.**

  Navigate: EC2 → Load Balancers → Create load balancer → Network Load Balancer
  - Name: `lab-nlb`
  - Scheme: Internet-facing
  - VPC: your VPC
  - Mappings: both AZs, public subnets
  - Listener: TCP port 80
  - Target group: Create new → TCP → port 80 → register both EC2 instances

  After creation, note:
  - NLB has a static IP per AZ (shown in the Description tab)
  - NLB listener does not support path-based routing rules (no Rules tab)
  - NLB preserves the client source IP (the EC2 will see the real client IP
    in nginx access logs, not the NLB's IP)

  ```bash
  curl http://<nlb-dns-name>/
  ```

- [ ] **Step 3 (15 min): Break-it exercise — health check misconfiguration.**

  Navigate: Target Groups → `lab-app-tg` → Health checks → Edit
  - Change health check path to `/healthz` (this path does not exist on nginx)
  - Change healthy threshold to 2, unhealthy threshold to 2

  Wait 60–90 seconds. Navigate: Target Groups → `lab-app-tg` → Targets tab.
  Both targets will show status `unhealthy`.

  Navigate: Load Balancers → `lab-alb` → test the DNS name:
  ```bash
  curl -v http://<alb-dns-name>/
  # Expected: HTTP 503 Service Unavailable
  ```

  This is how ALB behaves when all targets are unhealthy — it returns 503,
  not a connection timeout.

  Fix: change the health check path back to `/`, wait for targets to become
  `healthy` again before proceeding.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 2 — Load Balancers
  Key concept — OSI layer decision: ...
  When would I NOT use ALB: ...
  Break-it — what the 503 taught me about health checks: ...
  ```

- [ ] **Step 5: Teardown.**

  Delete `lab-nlb` and `lab-alb` (Load Balancers → select → Actions → Delete).
  Delete `lab-app-tg` and `lab-api-tg` (Target Groups → select → Actions → Delete).
  Terminate both EC2 instances.

---

## Day 3 — Auto Scaling Groups

**Theory file:** `content/day03.md` — read before starting the lab.
**Builds on:** Day 2 ALB + target group pattern (you will recreate it today
as the ASG's load balancer target).
**Sets up for:** Day 4 Terraform codifies today's full stack.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day03.md`. Focus on:
  - Launch template vs launch configuration: launch configs are deprecated;
    always use launch templates. Templates support versioning and mixed
    instance policies (spot + on-demand).
  - Scaling policies:
    - Target tracking: simplest — "keep CPU at 50%." AWS manages scale-out
      and scale-in automatically.
    - Step scaling: more control — "add 2 when CPU > 70%, add 4 when CPU > 90%"
    - Scheduled: predictable load — "scale to 10 at 08:00, scale to 2 at 20:00"
  - Lifecycle hooks: the most important concept beginners miss.
    - `autoscaling:EC2_INSTANCE_LAUNCHING` / `pending:wait`: instance is
      launched but NOT yet in service. Use for bootstrap tasks (pull config,
      join service mesh). Must complete heartbeat within timeout or ASG abandons.
    - `autoscaling:EC2_INSTANCE_TERMINATING` / `terminating:wait`: instance
      is draining but NOT yet terminated. Use for graceful shutdown (flush
      queues, deregister from service registry). Must complete or ASG force-terminates.
  - Health check types:
    - EC2: checks the instance is running (hypervisor-level)
    - ELB: checks the target is healthy in the target group (application-level)
    - ELB is almost always correct for web workloads — an instance that passes
      EC2 health check but fails the ALB health check stays in the ASG and
      receives traffic if only EC2 health check is configured.
  - Instance refresh: performs a rolling replacement of all instances when
    you update the launch template. `min_healthy_percentage` controls how
    many instances stay healthy during the roll.

  Before Console: answer in `journal.md`:
  - A new instance needs 90 seconds to pull its config from S3 and start the
    app before it can serve traffic. Which lifecycle hook do you use and at
    which state?
  - You update the AMI in the launch template. How do you apply it to running
    instances without taking the service down?

- [ ] **Step 2 (70 min): Console lab — ASG with target tracking + lifecycle hook.**

  **Part A: Recreate the ALB and target group (from Day 2).**

  Navigate: EC2 → Target Groups → Create target group
  - Name: `lab-asg-tg`
  - Protocol: HTTP, port 80, VPC: your VPC
  - Health check path: `/`

  Navigate: EC2 → Load Balancers → Create load balancer → Application Load Balancer
  - Name: `lab-asg-alb`, Internet-facing, both AZs + public subnets
  - Security group: create `lab-asg-alb-sg` (HTTP 80 inbound from 0.0.0.0/0)
  - Default action: forward to `lab-asg-tg`

  **Part B: Create a launch template.**

  Navigate: EC2 → Launch Templates → Create launch template
  - Name: `lab-lt`, version description: `v1`
  - AMI: Amazon Linux 2023 (64-bit x86)
  - Instance type: `t3.micro`
  - Network interfaces: do not include (ASG will assign subnet)
  - Security group: create `lab-ec2-sg`
    - Inbound: HTTP 80, source: `lab-asg-alb-sg`
  - Advanced → User data:
    ```bash
    #!/bin/bash
    dnf install -y nginx stress-ng
    systemctl enable --now nginx
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/local-hostname)
    echo "Hello from $HOSTNAME" > /usr/share/nginx/html/index.html
    ```

  **Part C: Create the ASG.**

  Navigate: EC2 → Auto Scaling Groups → Create Auto Scaling group
  - Name: `lab-asg`
  - Launch template: `lab-lt`
  - VPC: your VPC
  - Availability Zones: select BOTH private subnets
  - Load balancing: Attach to an existing load balancer → choose from target
    groups → `lab-asg-tg`
  - Health checks: Turn on Elastic Load Balancing health checks
  - Group size: Desired=2, Min=1, Max=4
  - Scaling policies: Target tracking → CPU utilization → target 50%

  Click Create.

  Wait until the Activity tab shows 2 instances launched. Navigate to Target
  Groups → `lab-asg-tg` → Targets: both should be `healthy`.

  Test:
  ```bash
  curl http://<alb-dns-name>/
  # Expected: "Hello from ip-10-0-x-x.ap-southeast-1.compute.internal"
  ```

  **Part D: Add a lifecycle hook.**

  Navigate: Auto Scaling Groups → `lab-asg` → Instance management tab →
  Lifecycle hooks → Create lifecycle hook
  - Name: `launch-hook`
  - Lifecycle transition: Instance launch
  - Heartbeat timeout: 120 seconds
  - Default result: ABANDON (if heartbeat is never sent, abandon the launch)

  To observe the hook in action, trigger a scale-out:
  ```bash
  # Find an instance ID in the ASG
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names lab-asg \
    --profile sandbox \
    --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
    --output text

  # Manually increase desired capacity to 3
  aws autoscaling set-desired-capacity \
    --auto-scaling-group-name lab-asg \
    --desired-capacity 3 \
    --profile sandbox
  ```

  Navigate: ASG → Activity tab. The new instance enters `Pending:Wait` state.
  It will stay there for 120 seconds (the heartbeat timeout) then either:
  - Complete normally if something sends a heartbeat (`complete-lifecycle-action`)
  - Be abandoned (ABANDON result) — the instance terminates

  Complete the hook manually:
  ```bash
  # Get the new instance ID (the one in Pending:Wait)
  INSTANCE_ID=<the pending instance ID>

  aws autoscaling complete-lifecycle-action \
    --lifecycle-hook-name launch-hook \
    --auto-scaling-group-name lab-asg \
    --instance-id $INSTANCE_ID \
    --lifecycle-action-result CONTINUE \
    --profile sandbox
  ```

  The instance transitions from `Pending:Wait` to `InService`.

- [ ] **Step 3 (15 min): Break-it exercise — lifecycle hook that never completes.**

  Update the lifecycle hook: change Default result to `ABANDON` and heartbeat
  timeout to 60 seconds.

  Scale out to 4 instances:
  ```bash
  aws autoscaling set-desired-capacity \
    --auto-scaling-group-name lab-asg \
    --desired-capacity 4 \
    --profile sandbox
  ```

  Do NOT send a heartbeat. After 60 seconds, navigate to the ASG → Activity
  tab. You will see:
  ```
  Launching a new EC2 instance: <id>. Status Reason: Lifecycle hook
  launch-hook abandoned: instance <id> will be terminated.
  ```

  The ASG terminated the instance because the hook timed out. This is the
  failure mode when a bootstrap script crashes silently — the instance never
  signals CONTINUE, the hook times out, and ASG abandons the launch.

  Restore: set Default result back to `CONTINUE`.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 3 — Auto Scaling Groups
  Key concept — lifecycle hooks: ...
  When would I NOT use target tracking (use step scaling instead): ...
  Break-it — how a hung bootstrap script manifests in the ASG: ...
  ```

- [ ] **Step 5: Teardown.**

  Navigate: ASG → `lab-asg` → Delete (this terminates instances automatically).
  Delete `lab-asg-alb` (Load Balancers → select → Actions → Delete).
  Delete `lab-asg-tg` (Target Groups → select → Delete).
  Delete `lab-lt` (Launch Templates → select → Actions → Delete).

---

## Day 4 — Phase 1 Synthesis + Terraform

**Theory file:** `content/day04.md` — read before starting the lab.
**Builds on:** Days 1–3. This day codifies everything from Phase 1 in Terraform.
**Sets up for:** Phase 2 extends this ALB with a second target group for ECS.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day04.md`. Focus on:
  - The full traffic path: internet → ALB (L7 routing decision) → target group
    → EC2 in private subnet (ASG manages count and health)
  - How ALB health check failure and ELB health check on ASG interact:
    if a target fails the health check, ALB stops routing to it AND the ASG
    marks the instance unhealthy → ASG terminates and replaces it
  - Instance refresh with `min_healthy_percentage`: during a roll, ASG ensures
    this percentage of instances remain healthy before terminating old ones.
    At 90%, a 10-instance ASG replaces one instance at a time.
  - 502 Bad Gateway root cause: ALB received a connection reset or timeout from
    the target. Always check: is the target healthy? Is nginx/app running on
    port 80? Is the security group allowing 80 from the ALB SG?

- [ ] **Step 2 (20 min): Console synthesis — reproduce and debug a 502.**

  Launch a single EC2 instance manually in your VPC (private subnet, security
  group that allows 80 from anywhere). In user data, start nginx normally.

  Create an ALB pointing to a target group with this instance.

  After the instance becomes healthy, **stop nginx on the instance**. If you
  have SSM access:
  ```bash
  aws ssm start-session --target <instance-id> --profile sandbox
  # Inside the session:
  sudo systemctl stop nginx
  ```

  Test the ALB:
  ```bash
  curl -v http://<alb-dns-name>/
  # Expected: HTTP 502 Bad Gateway
  ```

  Navigate: Target Groups → Targets tab → the instance shows `unhealthy`.
  Navigate: Instance → check System Log (Actions → Monitor and troubleshoot
  → Get system log) — this is where nginx crash output would appear.

  Restart nginx and verify the ALB recovers to 200 in under 60 seconds.
  Teardown this manual stack before moving to Terraform.

- [ ] **Step 3 (60 min): Terraform — phase1_compute module.**

  Create `terraform/phase1_compute/variables.tf`:

```hcl
variable "aws_region"          { type = string }
variable "vpc_id"              { type = string }
variable "public_subnet_ids"   { type = list(string) }
variable "private_subnet_ids"  { type = list(string) }
variable "name_prefix"         { type = string, default = "compute-lab" }
```

  Create `terraform/phase1_compute/main.tf`:

```hcl
# ── Security groups ────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-alb-sg" }
}

resource "aws_security_group" "ec2" {
  name_prefix = "${var.name_prefix}-ec2-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-ec2-sg" }
}

# ── ALB ───────────────────────────────────────────────────────────────────

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = { Name = "${var.name_prefix}-alb" }
}

resource "aws_lb_target_group" "ec2" {
  name     = "${var.name_prefix}-ec2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = { Name = "${var.name_prefix}-ec2-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2.arn
  }
}

# ── Launch template ───────────────────────────────────────────────────────

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    HOSTNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/local-hostname)
    echo "Hello from $HOSTNAME" > /usr/share/nginx/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.name_prefix}-instance" }
  }
}

# ── Auto Scaling Group ────────────────────────────────────────────────────

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name_prefix}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.ec2.arn]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name_prefix}-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
```

  Create `terraform/phase1_compute/outputs.tf`:

```hcl
output "alb_arn"           { value = aws_lb.this.arn }
output "alb_dns_name"      { value = aws_lb.this.dns_name }
output "alb_sg_id"         { value = aws_security_group.alb.id }
output "ec2_tg_arn"        { value = aws_lb_target_group.ec2.arn }
output "http_listener_arn" { value = aws_lb_listener.http.arn }
```

  Create `terraform/main.tf` (partial — will grow each phase):

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region"         { type = string }
variable "aws_profile"        { type = string, default = "sandbox" }
variable "vpc_id"             { type = string }
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "name_prefix"        { type = string, default = "compute-lab" }

module "phase1" {
  source             = "./phase1_compute"
  aws_region         = var.aws_region
  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
  name_prefix        = var.name_prefix
}

output "alb_dns_name" { value = module.phase1.alb_dns_name }
```

  Apply and verify:

```bash
cd terraform
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

  Expected output includes `alb_dns_name = "compute-lab-alb-xxxx.ap-southeast-1.elb.amazonaws.com"`.

```bash
# Wait ~90 seconds for instances to pass health checks, then:
curl http://$(terraform output -raw alb_dns_name)/
# Expected: "Hello from ip-10-0-x-x.ap-southeast-1.compute.internal"
```

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 4 — Phase 1 Synthesis
  Key concept — the 502 root cause checklist: ...
  What Terraform made explicit that I hadn't noticed in Console: ...
  ```

- [ ] **Step 5: Teardown.**

```bash
terraform destroy -var-file=terraform.tfvars
```

---

## Phase 2 — Container Layer (Days 5–7)

---

## Day 5 — ECS + Fargate + ECR

**Theory file:** `content/day05.md` — read before starting the lab.
**Builds on:** Security group patterns from Phase 1.
**Sets up for:** Day 6 registers the ECS service behind the ALB from Phase 1.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day05.md`. Focus on:
  - Task definition: the unit of work. Defines CPU (in vCPU units: 256=0.25vCPU),
    memory (MB), network mode, container image, port mappings, environment
    variables, log configuration.
  - Network modes: `awsvpc` (Fargate requires this — each task gets its own
    ENI and security group), `bridge` (EC2 launch type, dynamic port mapping),
    `host` (EC2 only, shares host network namespace)
  - The key insight: in `awsvpc` mode, security groups are applied to the
    ENI of the task, not the EC2 host. This means you control ingress/egress
    per-task, not per-host. A task that cannot connect to SQS has a security
    group or VPC endpoint problem — not an EC2 configuration problem.
  - ECS service: maintains `desired_count` running tasks. Replaces unhealthy
    tasks. Integrates with ALB (registers task IPs as targets).
  - Task execution role vs task role:
    - Execution role: permissions needed by ECS agent to pull the image (ECR)
      and write logs (CloudWatch). Uses `AmazonECSTaskExecutionRolePolicy`.
    - Task role: permissions your application code needs (S3, SQS, DynamoDB).
      Assumed by the running container, not the agent.
  - Fargate vs EC2 launch type: Fargate removes cluster management (no EC2
    instances to patch, no ECS agent to maintain). You still own the VPC,
    security groups, task definition, and service. EC2 launch type gives you
    GPU access, larger instance sizes, and spot integration.

  Before Console: answer in `journal.md`:
  - Your Fargate task cannot pull its image from ECR. Is this a task role or
    execution role problem?
  - A Fargate task's container connects to an RDS database. The connection
    times out. Name two things to check first.

- [ ] **Step 2 (60 min): Console lab — ECR + Fargate task.**

  **Part A: Create ECR repository and push image.**

  Navigate: ECR → Create repository
  - Visibility: Private
  - Name: `lab-app`
  - Image tag mutability: Mutable
  - Scan on push: enabled

  Authenticate Docker to ECR:
  ```bash
  ACCOUNT=$(aws sts get-caller-identity --profile sandbox --query Account --output text)
  aws ecr get-login-password --region ap-southeast-1 --profile sandbox | \
    docker login --username AWS \
    --password-stdin $ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com
  ```

  Build and push a simple nginx image:
  ```bash
  # Create a minimal Dockerfile
  cat > /tmp/Dockerfile <<'EOF'
  FROM nginx:alpine
  RUN echo "ECS Fargate task" > /usr/share/nginx/html/index.html
  EXPOSE 80
  EOF

  docker build -t lab-app /tmp/
  docker tag lab-app:latest \
    $ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/lab-app:latest
  docker push \
    $ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/lab-app:latest
  ```

  Expected: `latest: digest: sha256:...` after push completes.

  **Part B: Create task execution role.**

  Navigate: IAM → Roles → Create role
  - Trusted entity: AWS service → Elastic Container Service → ECS Task
  - Permissions: attach `AmazonECSTaskExecutionRolePolicy`
  - Name: `lab-ecs-task-execution-role`

  **Part C: Create ECS cluster.**

  Navigate: ECS → Clusters → Create cluster
  - Cluster name: `lab-cluster`
  - Infrastructure: AWS Fargate (serverless) — leave EC2 unchecked

  **Part D: Create task definition.**

  Navigate: ECS → Task definitions → Create new task definition
  - Family: `lab-app`
  - Launch type: Fargate
  - CPU: 0.25 vCPU (256), Memory: 512 MiB
  - Task execution role: `lab-ecs-task-execution-role`
  - Container:
    - Name: `app`
    - Image URI: `$ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/lab-app:latest`
    - Port mapping: 80 TCP
    - Log collection: enable → CloudWatch Logs → log group `/ecs/lab-app`

  **Part E: Run a Fargate task.**

  Navigate: ECS → Clusters → `lab-cluster` → Tasks → Run new task
  - Launch type: Fargate
  - Task definition: `lab-app` (latest)
  - VPC: your VPC
  - Subnets: private subnet 1a
  - Security group: Create new → `lab-ecs-task-sg`
    - Inbound: HTTP 80 from 0.0.0.0/0 (for testing; we tighten this in Day 6)
  - Public IP: disabled

  After the task enters `RUNNING` state, click on it. Note:
  - **Private IP** of the task ENI (e.g. `10.0.2.45`)
  - Under **Network** → ENI ID: click through to see the ENI attached to the task
  - The security group is on the ENI, not on any EC2 instance

  Navigate: EC2 → Network Interfaces → find the ENI → the task's private IP
  is there. When the task stops, this ENI is released.

- [ ] **Step 3 (15 min): Break-it exercise — wrong execution role.**

  Edit the task definition: change the task execution role to `None` (or create
  a new role with no ECR permissions).

  Run a new task with this definition. Navigate to the task → Stopped reason:
  ```
  CannotPullContainerError: pull access denied for <account>.dkr.ecr...
  ```

  This is the most common ECS error: the execution role cannot pull from ECR.
  Fix: restore `lab-ecs-task-execution-role` as the execution role.

  Also navigate: CloudTrail → Event history → filter by event name
  `GetAuthorizationToken` — you will NOT find a successful event during the
  failed run, confirming the agent never got an auth token.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 5 — ECS + Fargate + ECR
  Key concept — task execution role vs task role: ...
  When would I NOT use Fargate (use EC2 launch type instead): ...
  Break-it — the CannotPullContainerError and how to diagnose it: ...
  ```

- [ ] **Step 5: Teardown.**

  Stop any running tasks (ECS → Tasks → select → Stop).
  Delete the `lab-cluster` (ECS → Clusters → select → Delete cluster).
  Deregister the task definition (ECS → Task definitions → select revision →
  Deregister).
  Delete ECR repository (ECR → select → Delete).

---

## Day 6 — ECS + ALB + Service Discovery

**Theory file:** `content/day06.md` — read before starting the lab.
**Builds on:** Phase 1 ALB + Day 5 ECS/Fargate knowledge.
**Sets up for:** Day 7 Terraform codifies this complete ECS + ALB stack.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day06.md`. Focus on:
  - How ALB + ECS works: the ECS service registers task private IPs as targets
    in the target group. When a task is replaced, the old IP is deregistered
    and the new IP is registered automatically. The ALB health check determines
    whether a new task receives traffic.
  - Deregistration delay (connection draining): when ECS stops a task (during
    a deploy), ALB waits `deregistration_delay.timeout_seconds` before removing
    the target. During this window, in-flight requests complete. Too short =
    dropped requests. Too long = slow deployments.
  - Cloud Map service discovery: a managed DNS service that registers ECS tasks
    under a private hosted zone. When a task launches, ECS registers an SRV
    or A record. Other services resolve the name to get the task IP.
    Use case: service-to-service HTTP calls within the VPC where ALB overhead
    is unnecessary.
  - Blue/green with CodeDeploy: ALB has two listener rules pointing to two
    target groups (blue = current, green = new). CodeDeploy shifts traffic
    gradually (linear or canary) from blue to green. On failure, shift back
    to blue in seconds.
  - Task auto-scaling: ECS services support target tracking (ALB request count
    per target, CPU, memory) and step scaling, the same as ASG.

- [ ] **Step 2 (70 min): Console lab — ECS service behind ALB.**

  **Part A: Rebuild Phase 1 ALB (if torn down).**

  Rebuild the ALB from Day 4 manually or apply the Phase 1 Terraform module:
  ```bash
  cd terraform
  terraform apply -var-file=terraform.tfvars -target=module.phase1
  ```

  **Part B: Create ECS infrastructure.**

  Repeat the ECR push, cluster creation, and task definition from Day 5
  (or use the Terraform module from Day 5's steps — reference only; full
  Terraform for ECS comes in Day 7).

  Navigate: ECS → Clusters → `lab-cluster` → Services → Create service
  - Launch type: Fargate
  - Task definition: `lab-app`
  - Service name: `lab-app-service`
  - Desired tasks: 2
  - Deployment type: Rolling update
  - VPC: your VPC
  - Subnets: private subnet 1a AND 1b
  - Security group: Create `lab-ecs-tasks-sg`
    - Inbound: HTTP 80 from `lab-alb-sg` (the ALB security group)
  - Load balancing: Application Load Balancer → select `compute-lab-alb`
    - Container to load balance: `app:80`
    - Create new target group: `lab-ecs-tg`, port 80, health check path `/`
  - Listener: select existing HTTP:80 listener
    - Add listener rule: path `/api/*` → `lab-ecs-tg`, priority 10

  Wait for both tasks to enter `RUNNING` and become `healthy` in the target
  group. Test:
  ```bash
  curl http://<alb-dns-name>/api/
  # Expected: "ECS Fargate task" (served by container)
  curl http://<alb-dns-name>/
  # Expected: "Hello from ip-10-0-x-x..." (served by EC2 ASG)
  ```

  **Part C: Observe a rolling deploy.**

  Navigate: ECR → `lab-app` → push a new image version:
  ```bash
  cat > /tmp/Dockerfile <<'EOF'
  FROM nginx:alpine
  RUN echo "ECS Fargate task v2" > /usr/share/nginx/html/index.html
  EXPOSE 80
  EOF
  docker build -t lab-app:v2 /tmp/
  docker tag lab-app:v2 \
    $ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/lab-app:v2
  docker push $ACCOUNT.dkr.ecr.ap-southeast-1.amazonaws.com/lab-app:v2
  ```

  Update the task definition to use `:v2`. Then navigate to the ECS service →
  Update service → force new deployment. Watch the Deployments tab: tasks
  drain from the old definition and new tasks launch with the new image.

  During the rollout:
  ```bash
  while true; do curl -s http://<alb-dns-name>/api/ && sleep 2; done
  ```

  You will see a mix of `v1` and `v2` responses until the rollout completes.
  No 502s should appear if deregistration delay is correctly set (>= 30s).

- [ ] **Step 3 (15 min): Break-it exercise — deregistration delay too short.**

  Navigate: Target Groups → `lab-ecs-tg` → Attributes → Edit →
  set Deregistration delay to `5` seconds.

  Trigger a new forced deployment and watch the rolling deploy while running:
  ```bash
  while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://<alb-dns-name>/api/)
    echo "$(date): $STATUS"
    sleep 1
  done
  ```

  With a 5-second drain window, in-flight requests that were already routed to
  a draining task will receive a 502 or connection reset as the task stops
  before they complete.

  Fix: set deregistration delay back to `30` seconds. Confirm no 502s on
  next forced deployment.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 6 — ECS + ALB + Service Discovery
  Key concept — deregistration delay: ...
  When would I use Cloud Map instead of ALB: ...
  Break-it — the 502 during a deploy and the drain window fix: ...
  ```

- [ ] **Step 5: Partial teardown.** Keep the ALB and ECS service running — Day 7
  Terraform will codify this stack. If cost is a concern, tear down manually.

---

## Day 7 — Phase 2 Synthesis + Terraform

**Theory file:** `content/day07.md` — read before starting the lab.
**Builds on:** Phase 1 Terraform module + Days 5–6 ECS knowledge.
**Sets up for:** Phase 3 adds messaging services that connect to this ECS service.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day07.md`. Focus on:
  - The combined ALB routing table: one ALB, two target group rules
    (`/api/*` → ECS tasks, default → EC2 ASG). Both target groups share the
    same ALB and listener — only the routing rule determines which receives traffic.
  - ECS service health check grace period: when a new task registers with ALB,
    ECS ignores unhealthy status for this duration. Too short = ECS kills
    tasks before app has finished starting. Set to at least the app's startup time.
  - awsvpc + ALB: ECS registers task private IPs (not EC2 instance IDs) as
    `ip` type targets. The target group must have `target_type = "ip"`.
    If you accidentally create the target group with `target_type = "instance"`,
    registration will fail silently.

- [ ] **Step 2 (20 min): Console — verify the two-path ALB.**

  With Phase 1 still applied (or reapply), confirm both routes work:
  ```bash
  ALB=$(terraform output -raw alb_dns_name)
  curl http://$ALB/          # → EC2 ASG response
  curl http://$ALB/api/      # → ECS Fargate response
  ```

- [ ] **Step 3 (60 min): Terraform — phase2_containers module.**

  Create `terraform/phase2_containers/variables.tf`:

```hcl
variable "aws_region"          { type = string }
variable "vpc_id"              { type = string }
variable "private_subnet_ids"  { type = list(string) }
variable "alb_sg_id"           { type = string }
variable "http_listener_arn"   { type = string }
variable "name_prefix"         { type = string, default = "compute-lab" }
```

  Create `terraform/phase2_containers/main.tf`:

```hcl
# ── ECR ───────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "app" {
  name                 = "${var.name_prefix}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }

  tags = { Name = "${var.name_prefix}-ecr" }
}

# ── ECS cluster ───────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.name_prefix}-cluster" }
}

# ── IAM roles ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "task_execution" {
  name = "${var.name_prefix}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── Security group for ECS tasks ─────────────────────────────────────────

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.name_prefix}-ecs-tasks-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-ecs-tasks-sg" }
}

# ── Task definition ───────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}-app"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "nginx:alpine"
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = { Name = "${var.name_prefix}-task-def" }
}

# ── ALB target group + listener rule for ECS ─────────────────────────────

resource "aws_lb_target_group" "ecs" {
  name        = "${var.name_prefix}-ecs-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = { Name = "${var.name_prefix}-ecs-tg" }
}

resource "aws_lb_listener_rule" "ecs_api" {
  listener_arn = var.http_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    path_pattern { values = ["/api/*"] }
  }
}

# ── ECS service ───────────────────────────────────────────────────────────

resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-app-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "app"
    container_port   = 80
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_lb_listener_rule.ecs_api]

  tags = { Name = "${var.name_prefix}-app-service" }
}
```

  Create `terraform/phase2_containers/outputs.tf`:

```hcl
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "ecs_cluster_name"   { value = aws_ecs_cluster.this.name }
output "ecs_sg_id"          { value = aws_security_group.ecs_tasks.id }
output "ecs_tg_arn"         { value = aws_lb_target_group.ecs.arn }
```

  Update `terraform/main.tf` to add Phase 2:

```hcl
module "phase2" {
  source             = "./phase2_containers"
  aws_region         = var.aws_region
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  alb_sg_id          = module.phase1.alb_sg_id
  http_listener_arn  = module.phase1.http_listener_arn
  name_prefix        = var.name_prefix
}

output "ecr_repository_url" { value = module.phase2.ecr_repository_url }
```

  Apply and verify:

```bash
terraform apply -var-file=terraform.tfvars
ALB=$(terraform output -raw alb_dns_name)

# Wait ~90 seconds for ECS tasks to start and pass health checks
curl http://$ALB/        # → EC2 ASG (nginx with hostname)
curl http://$ALB/api/    # → ECS Fargate (nginx:alpine default page)
```

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 7 — Phase 2 Synthesis
  Key concept — target_type ip vs instance: ...
  What would break if health_check_grace_period was set to 0: ...
  ```

- [ ] **Step 5: Teardown.**

```bash
terraform destroy -var-file=terraform.tfvars
```

---

## Phase 3 — Communication Layer (Days 8–12)

---

## Day 8 — SQS

**Theory file:** `content/day08.md` — read before starting the lab.
**Builds on:** nothing new infrastructure-wise — Console only today.
**Sets up for:** Day 9 adds SNS fan-out on top of SQS. Day 12 Terraform
codifies all Phase 3 resources.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day08.md`. Focus on:
  - Standard vs FIFO:
    - Standard: at-least-once delivery, best-effort ordering, unlimited
      throughput. Use for most workloads.
    - FIFO: exactly-once processing (deduplication ID), strict ordering
      within a message group, 3000 msg/s with batching. Use when order
      matters (financial transactions, state machines).
  - Visibility timeout: the core mechanism. When a consumer reads a message,
    SQS hides it for `visibility_timeout` seconds. If the consumer deletes it
    before the timeout, it's gone. If not (crash, slow processing), SQS makes
    it visible again → re-delivered to another consumer. This is why
    at-least-once means "possibly more than once."
  - DLQ (Dead Letter Queue): after `maxReceiveCount` delivery attempts, the
    message moves to a DLQ. Always alarm on DLQ depth — a non-zero DLQ means
    something is failing silently.
  - Long polling (`WaitTimeSeconds = 20`): consumer waits up to 20s for a
    message before returning empty. Reduces empty receives and cost vs short
    polling (returns immediately even if queue is empty).
  - Message retention: 4 days default, up to 14 days. Messages not processed
    within retention are permanently deleted.

  Before Console: answer in `journal.md`:
  - Your consumer takes 45 seconds to process a message. What visibility
    timeout should you set?
  - A message has been delivered 5 times but never deleted. `maxReceiveCount`
    is 3. Where is the message now?

- [ ] **Step 2 (50 min): Console lab — SQS standard queue with DLQ.**

  **Part A: Create DLQ and main queue.**

  Navigate: SQS → Create queue
  - Type: Standard
  - Name: `lab-dlq`
  - Message retention: 14 days
  - All other settings: default

  Navigate: SQS → Create queue
  - Type: Standard
  - Name: `lab-main-queue`
  - Visibility timeout: 30 seconds
  - Message retention: 4 days
  - Dead-letter queue: enable → select `lab-dlq` → maxReceiveCount: 3

  **Part B: Send and receive messages.**

  Navigate: SQS → `lab-main-queue` → Send and receive messages

  Send a test message:
  - Message body: `{"orderId": "123", "status": "created"}`
  - Click Send message

  Poll for messages:
  - Click Poll for messages
  - The message appears with status `In flight` (visibility timeout active)
  - Click the message → note the Receipt Handle (needed for deletion)

  Simulate consumer failure by NOT deleting the message. Wait 30 seconds.
  Poll again — the message reappears (visibility timeout expired → re-delivered).

  Delete the message by clicking its checkbox → Delete.

  **Part C: Observe DLQ behaviour.**

  Send a new message. Poll for it and record its receipt handle. Poll again
  (without deleting) 3 more times — each poll counts as one receive. After
  3 receives without deletion, the message moves to `lab-dlq`.

  Navigate: SQS → `lab-dlq` → Poll for messages. The message appears here.

  Navigate: CloudWatch → Alarms → Create alarm
  - Metric: SQS → Per-Queue Metrics → `lab-dlq` → `ApproximateNumberOfMessagesVisible`
  - Condition: Greater than 0
  - Action: (for the lab, just create without notification)
  - Name: `lab-dlq-alarm`

  This is the production alarm pattern — any message reaching the DLQ should
  wake someone up.

  **Part D: Compare long vs short polling.**

  Using the AWS CLI, observe the difference:

```bash
# Short polling (default) — returns immediately even if queue is empty
time aws sqs receive-message \
  --queue-url $(aws sqs get-queue-url --queue-name lab-main-queue \
    --profile sandbox --query QueueUrl --output text) \
  --profile sandbox
# Expected: returns in ~0.5s with empty response

# Long polling — waits up to 20s for a message
time aws sqs receive-message \
  --queue-url $(aws sqs get-queue-url --queue-name lab-main-queue \
    --profile sandbox --query QueueUrl --output text) \
  --wait-time-seconds 20 \
  --profile sandbox
# Expected: returns in ~1-2s (no messages) but waited, not instant
```

- [ ] **Step 3 (15 min): Break-it exercise — visibility timeout shorter than processing time.**

  Edit `lab-main-queue` → Edit → Visibility timeout: set to `5` seconds.

  Send a message. Poll for it. Before 5 seconds elapse, poll again without
  deleting it. Observe: the same message reappears immediately (second consumer
  would now process the same message in parallel).

  This is duplicate processing: two consumers see the same message because
  the timeout was shorter than the work took. In a payment processor, this
  means charging a customer twice.

  Fix: set visibility timeout back to `30` seconds. In production, set it to
  at least `max_processing_time × 1.5`.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 8 — SQS
  Key concept — visibility timeout and at-least-once delivery: ...
  When would I choose FIFO over Standard: ...
  Break-it — duplicate processing and the fix: ...
  ```

- [ ] **Step 5: Teardown.**

  Delete `lab-dlq-alarm` (CloudWatch → Alarms → select → Actions → Delete).
  Delete `lab-main-queue` and `lab-dlq` (SQS → select → Delete).

---

## Day 9 — SNS + Fan-out

**Theory file:** `content/day09.md` — read before starting the lab.
**Builds on:** Day 8 SQS queues.
**Sets up for:** Day 10 EventBridge replaces direct SNS coupling in some patterns.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day09.md`. Focus on:
  - SNS is a push service — it delivers to subscribers immediately on publish.
    SQS is a pull service — consumers poll. The difference: SNS cannot retry
    on its own if the subscriber is down (it delivers once and moves on, with
    a retry policy). SQS absorbs backpressure — producers keep writing even
    if consumers are slow.
  - Fan-out pattern: SNS topic → multiple SQS queues. Each SQS queue has its
    own consumer with its own processing speed. SNS publishes once; each
    subscriber gets a copy. This decouples the fan-out rate from the
    consumption rate — a slow consumer doesn't block a fast one.
  - Filter policies: applied per-subscription, not per-publisher. You can
    subscribe to a topic and filter by message attribute (e.g. only receive
    messages where `event_type = "order.created"`). The publisher does not
    need to know about filter policies.
  - FIFO SNS topic → FIFO SQS queue: preserves ordering end-to-end across
    the fan-out. Throughput limited to 300 msg/s (3000 with batching).

- [ ] **Step 2 (50 min): Console lab — SNS fan-out with filter policies.**

  **Part A: Create three SQS queues.**

  Navigate: SQS → Create queue × 3
  - `lab-orders-queue` (Standard)
  - `lab-notifications-queue` (Standard)
  - `lab-analytics-queue` (Standard)

  **Part B: Create SNS topic.**

  Navigate: SNS → Topics → Create topic
  - Type: Standard
  - Name: `lab-events`

  **Part C: Subscribe each queue with a different filter.**

  Navigate: SNS → `lab-events` → Create subscription × 3

  Subscription 1 (orders — receives all order events):
  - Protocol: Amazon SQS
  - Endpoint: ARN of `lab-orders-queue`
  - Subscription filter policy (JSON):
    ```json
    {
      "event_type": ["order.created", "order.updated", "order.cancelled"]
    }
    ```
  - Click Save

  For the SQS queue to accept messages from SNS, add a resource policy.
  Navigate: SQS → `lab-orders-queue` → Access policy → Edit:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "sns.amazonaws.com" },
      "Action": "sqs:SendMessage",
      "Resource": "<lab-orders-queue-ARN>",
      "Condition": {
        "ArnLike": { "aws:SourceArn": "<lab-events-SNS-ARN>" }
      }
    }]
  }
  ```

  Subscription 2 (notifications — only new orders):
  - Protocol: Amazon SQS → `lab-notifications-queue`
  - Filter: `{"event_type": ["order.created"]}`
  - Add the same resource policy to `lab-notifications-queue`

  Subscription 3 (analytics — all events):
  - Protocol: Amazon SQS → `lab-analytics-queue`
  - No filter policy (receives everything)
  - Add resource policy to `lab-analytics-queue`

  **Part D: Publish test messages.**

  Navigate: SNS → `lab-events` → Publish message

  Message 1:
  - Subject: `test`
  - Message body: `{"orderId": "1", "status": "created"}`
  - Message attributes: Key=`event_type`, Data type=`String`, Value=`order.created`

  Message 2:
  - Message body: `{"orderId": "2", "status": "shipped"}`
  - Attributes: `event_type = order.updated`

  Navigate to each SQS queue and poll for messages. Expected:
  - `lab-orders-queue`: both messages
  - `lab-notifications-queue`: only message 1 (order.created)
  - `lab-analytics-queue`: both messages

- [ ] **Step 3 (15 min): Break-it exercise — missing SQS resource policy.**

  Remove the resource policy from `lab-analytics-queue`. Publish a new SNS
  message. Navigate to SQS → `lab-analytics-queue` → poll: no message.

  Navigate: SNS → `lab-events` → Subscriptions → select the analytics
  subscription → Delivery status. You will see `Failed` with error:
  `Access to the resource https://sqs.ap-southeast-1.amazonaws.com/... is denied.`

  Fix: restore the resource policy. The next published message will deliver.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 9 — SNS + Fan-out
  Key concept — why fan-out needs SQS buffers: ...
  When would I use SNS direct Lambda instead of SQS in between: ...
  Break-it — the missing resource policy and how SNS surfaces it: ...
  ```

- [ ] **Step 5: Teardown.**

  Delete all three subscriptions. Delete the SNS topic. Delete the three
  SQS queues.

---

## Day 10 — EventBridge

**Theory file:** `content/day10.md` — read before starting the lab.
**Builds on:** SNS/SQS mental model from Days 8–9.
**Sets up for:** Day 11 API Gateway can use EventBridge as a backend target.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day10.md`. Focus on:
  - EventBridge vs SNS:
    - SNS: topic-based fan-out, publisher sends to a topic, subscribers
      receive all (or filtered) messages. Coupling: publishers know the topic ARN.
    - EventBridge: rule-based routing on an event bus. Publishers send events
      to a bus. Rules match events by content (detail-type, source, any JSON
      field). Targets receive matching events. Publishers and targets are
      completely decoupled — neither knows about the other.
    - Use EventBridge when: routing logic is content-based, you have many
      sources and many targets, you need cross-account delivery, or you want
      schema registry + code bindings.
    - Use SNS when: simple topic fan-out, filter by message attribute (not
      body), you need email/HTTP/Lambda subscriptions.
  - Event buses:
    - Default bus: receives events from AWS services (EC2 state changes,
      S3 events, CodePipeline state, etc.)
    - Custom bus: your application's events. Recommended to keep app events
      off the default bus to avoid noise.
    - Partner bus: ingests events from third-party SaaS (Zendesk, Datadog, etc.)
  - Rules: match on `source`, `detail-type`, and any field in `detail` (JSON
    path, prefix, suffix, numeric ranges, anything-but). Rules are evaluated
    in parallel — an event can match multiple rules simultaneously.
  - Event DLQ: if a target invocation fails (Lambda throws, SQS policy denies,
    ECS task can't be started), EventBridge retries up to 24 hours, then sends
    the event to a DLQ. Always configure DLQ on production rules.

- [ ] **Step 2 (50 min): Console lab — custom bus with rules and multiple targets.**

  **Part A: Create custom event bus.**

  Navigate: EventBridge → Event buses → Create event bus
  - Name: `lab-app-bus`

  **Part B: Create SQS target and rule.**

  Create an SQS queue first:
  Navigate: SQS → Create queue → `lab-eb-queue` (Standard)

  Add resource policy to allow EventBridge:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "events.amazonaws.com" },
      "Action": "sqs:SendMessage",
      "Resource": "<lab-eb-queue-ARN>"
    }]
  }
  ```

  Navigate: EventBridge → Rules → Create rule
  - Name: `lab-order-rule`
  - Event bus: `lab-app-bus`
  - Rule type: Rule with an event pattern
  - Event pattern:
    ```json
    {
      "detail-type": ["OrderCreated", "OrderUpdated"]
    }
    ```
  - Target: SQS → `lab-eb-queue`
  - Create a new IAM role for the rule (EventBridge → SQS delivery)

  **Part C: Publish test events.**

```bash
# Publish a matching event
aws events put-events \
  --entries '[{
    "Source": "com.myapp.orders",
    "DetailType": "OrderCreated",
    "Detail": "{\"orderId\": \"123\", \"amount\": 99.99}",
    "EventBusName": "lab-app-bus"
  }]' \
  --profile sandbox

# Publish a non-matching event
aws events put-events \
  --entries '[{
    "Source": "com.myapp.users",
    "DetailType": "UserRegistered",
    "Detail": "{\"userId\": \"456\"}",
    "EventBusName": "lab-app-bus"
  }]' \
  --profile sandbox
```

  Navigate: SQS → `lab-eb-queue` → Poll. Only the `OrderCreated` event
  should appear. `UserRegistered` matched no rules and was silently dropped.

  Note: to capture unmatched events, create a rule with event pattern `{}` (matches
  all) and route to a separate SQS queue or CloudWatch Logs for debugging.

  **Part D: Add a scheduled rule.**

  Navigate: EventBridge → Rules → Create rule (on the default bus this time)
  - Name: `lab-every-minute`
  - Rule type: Schedule
  - Schedule pattern: Rate-based → every 1 minute
  - Target: SQS → `lab-eb-queue`

  After 2 minutes, poll `lab-eb-queue` — scheduled events appear as:
  ```json
  {"version": "0", "id": "...", "detail-type": "Scheduled Event", ...}
  ```

  Delete this rule before it fills up the queue.

- [ ] **Step 3 (15 min): Break-it exercise — missing IAM permission for target.**

  Navigate: EventBridge → Rules → `lab-order-rule` → Targets → edit the
  IAM role → remove the `sqs:SendMessage` permission.

  Publish an OrderCreated event. Navigate: EventBridge → Rules →
  `lab-order-rule` → Monitoring tab → Invocations (failed). You will see
  failed invocations.

  Navigate: CloudTrail → Event history → filter by `PutTargets` or look for
  `AccessDenied` from `events.amazonaws.com`. The denial will be visible.

  Fix: restore `sqs:SendMessage` to the IAM role.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 10 — EventBridge
  Key concept — EventBridge vs SNS decoupling: ...
  When would I use the default bus vs a custom bus: ...
  Break-it — how to diagnose a failed EventBridge target invocation: ...
  ```

- [ ] **Step 5: Teardown.**

  Delete `lab-every-minute` rule. Delete `lab-order-rule`. Delete `lab-app-bus`.
  Delete `lab-eb-queue`.

---

## Day 11 — API Gateway

**Theory file:** `content/day11.md` — read before starting the lab.
**Builds on:** Phase 2 ECS service + ALB. Phase 3 messaging services.
**Sets up for:** Day 12 Terraform codifies API Gateway alongside all Phase 3 resources.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day11.md`. Focus on:
  - HTTP API vs REST API:
    - HTTP API: lower latency, cheaper (~70% less), supports Lambda + HTTP
      integrations. No request/response transformation, no usage plans, no
      API keys. Use for most new APIs.
    - REST API: full feature set — request/response mapping templates, usage
      plans, API keys, resource policies, WAF integration, caching. Use when
      you need these features or are modernising an existing REST API.
  - Integration types:
    - Lambda proxy: API GW passes the entire request to Lambda; Lambda returns
      a full HTTP response. Simplest for Lambda backends.
    - HTTP proxy: API GW forwards to an HTTP endpoint (your ALB) without
      transformation. This is the pattern for VPC Link → private ALB.
    - AWS service: direct integration with AWS APIs (e.g. SQS, Kinesis).
      API GW calls SQS `SendMessage` directly — no Lambda needed.
  - VPC Link: a private tunnel from API GW to an NLB (for REST API) or ALB
    (for HTTP API) inside your VPC. Requests never leave AWS's internal network.
    Required when your backend has no public IP.
  - Throttling: per-stage default (10,000 req/s burst, 5,000 req/s steady-state
    for the account). Per-method throttling overrides the stage default.
    Throttled requests receive `429 Too Many Requests`.
  - CORS: must be configured at the API Gateway layer if your frontend is at
    a different origin than the API. Browser sends an OPTIONS preflight request;
    API GW must respond with `Access-Control-Allow-Origin`. Missing CORS headers
    cause the browser to block the response silently — the backend served 200
    but the browser throws a CORS error.

- [ ] **Step 2 (60 min): Console lab — HTTP API with VPC Link to private ALB.**

  Prerequisites: Phase 1 Terraform must be applied (ALB running).
  ```bash
  cd terraform && terraform apply -var-file=terraform.tfvars
  ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null || \
    aws elbv2 describe-load-balancers \
      --names compute-lab-alb --profile sandbox \
      --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  ```

  **Part A: Create VPC Link.**

  Navigate: API Gateway → VPC Links → Create (for HTTP APIs)
  - Name: `lab-vpc-link`
  - VPC: your VPC
  - Subnets: both private subnets
  - Security groups: leave default (or create one that allows outbound to the ALB)

  Wait until the VPC Link status is `Available` (~2 minutes).

  **Part B: Create HTTP API.**

  Navigate: API Gateway → Create API → HTTP API → Build
  - API name: `lab-http-api`
  - Integrations: Add → HTTP → HTTP proxy integration
    - Integration target: `http://<alb-dns-name>/{proxy}`
    - Method: ANY
  - Routes: `/{proxy+}` mapped to the integration
  - Stages: `$default` (auto-deploy)

  After creation, note the Invoke URL:
  ```bash
  curl https://<api-id>.execute-api.ap-southeast-1.amazonaws.com/
  # Expected: "Hello from ip-10-0-x-x..." (EC2 ASG response via ALB)
  curl https://<api-id>.execute-api.ap-southeast-1.amazonaws.com/api/
  # Expected: ECS Fargate response
  ```

  Note: this routes via the public ALB. For a private ALB, you would update
  the integration to use the VPC Link.

  **Part C: Configure CORS.**

  Navigate: API Gateway → `lab-http-api` → CORS → Configure
  - Allow origins: `*`
  - Allow headers: `content-type,authorization`
  - Allow methods: `GET,POST,OPTIONS`
  - Max age: 300

  Test CORS from the terminal (simulating a browser preflight):
  ```bash
  curl -X OPTIONS -v \
    -H "Origin: https://example.com" \
    -H "Access-Control-Request-Method: POST" \
    https://<api-id>.execute-api.ap-southeast-1.amazonaws.com/
  # Expected: response includes Access-Control-Allow-Origin: *
  ```

  **Part D: Add throttling.**

  Navigate: API Gateway → `lab-http-api` → Stages → `$default` → Edit →
  Throttling: set Default route throttle → Rate: 100, Burst: 200.

  This limits the entire API to 100 sustained req/s, 200 burst.

- [ ] **Step 3 (15 min): Break-it exercise — CORS misconfiguration.**

  Navigate: API Gateway → `lab-http-api` → CORS → Edit →
  Remove all entries from Allow origins (blank).

  Test:
  ```bash
  curl -X OPTIONS -v \
    -H "Origin: https://example.com" \
    -H "Access-Control-Request-Method: GET" \
    https://<api-id>.execute-api.ap-southeast-1.amazonaws.com/
  # Expected: no Access-Control-Allow-Origin header in response
  ```

  In a real browser, the JavaScript `fetch()` call would succeed at the
  network level but the browser would throw:
  ```
  Access to fetch at '...' from origin '...' has been blocked by CORS policy:
  No 'Access-Control-Allow-Origin' header is present.
  ```

  Fix: restore `Allow origins: *`.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 11 — API Gateway
  Key concept — HTTP API vs REST API decision: ...
  When would I use AWS service integration (direct SQS) vs Lambda proxy: ...
  Break-it — the CORS error that's actually an API Gateway config problem: ...
  ```

- [ ] **Step 5: Teardown.**

  Delete the HTTP API (API Gateway → `lab-http-api` → Delete).
  Delete the VPC Link (API Gateway → VPC Links → `lab-vpc-link` → Delete).
  Terraform destroy Phase 1 if you applied it:
  ```bash
  terraform destroy -var-file=terraform.tfvars -target=module.phase1
  ```

---

## Day 12 — Kinesis + Phase 3 Terraform

**Theory file:** `content/day12.md` — read before starting the lab.
**Builds on:** SQS (Day 8), SNS (Day 9), EventBridge (Day 10), API GW (Day 11).
**Sets up for:** Day 13 wires all three modules into one reference architecture.

---

- [ ] **Step 1 (20 min): Read theory.** Open `content/day12.md`. Focus on:
  - Kinesis Data Streams vs SQS:
    | Dimension | SQS | Kinesis |
    |---|---|---|
    | Ordering | FIFO queue only | Per-shard ordering always |
    | Replay | No (consumed = gone) | Yes (up to 365 days) |
    | Consumers | Many independent pollers | Multiple consumers share shards |
    | Throughput | Unlimited | 1 MB/s write, 2 MB/s read per shard |
    | Use case | Job queues, work distribution | Analytics pipelines, audit logs, ML ingestion |
  - Shards: the unit of throughput. 1 shard = 1 MB/s in, 2 MB/s out. Add
    shards to scale. Each shard is ordered independently — records with the
    same partition key always go to the same shard.
  - Enhanced fan-out: dedicated 2 MB/s read bandwidth per consumer per shard.
    Standard polling shares the 2 MB/s across all consumers. Use enhanced
    fan-out when you have multiple consumers competing for the same shard.
  - Kinesis Firehose: fully managed delivery to S3, Redshift, OpenSearch, or
    Splunk. No consumers to write. Handles batching, compression, and retry.
    Not real-time (60-second buffer minimum).
  - Decision matrix summary:
    - Need to distribute work to competing workers → SQS standard
    - Need ordered processing of a domain entity's events → SQS FIFO
    - Need fan-out to multiple independent consumers → SNS + SQS
    - Need content-based routing between services → EventBridge
    - Need high-throughput ordered stream with replay → Kinesis Data Streams
    - Need managed delivery to S3/data warehouse → Kinesis Firehose

- [ ] **Step 2 (40 min): Console lab — Kinesis Data Stream.**

  Navigate: Kinesis → Data streams → Create data stream
  - Name: `lab-events-stream`
  - Capacity mode: Provisioned → 1 shard

  **Part A: Produce records.**

```bash
STREAM=lab-events-stream
REGION=ap-southeast-1

# Produce 5 records
for i in 1 2 3 4 5; do
  aws kinesis put-record \
    --stream-name $STREAM \
    --data "$(echo -n "{\"eventId\":$i}" | base64)" \
    --partition-key "order-$i" \
    --region $REGION --profile sandbox
done
```

  **Part B: Consume with standard iterator.**

```bash
# Get shard ID
SHARD=$(aws kinesis list-shards --stream-name $STREAM \
  --region $REGION --profile sandbox \
  --query 'Shards[0].ShardId' --output text)

# Get shard iterator (TRIM_HORIZON = from oldest record)
ITERATOR=$(aws kinesis get-shard-iterator \
  --stream-name $STREAM \
  --shard-id $SHARD \
  --shard-iterator-type TRIM_HORIZON \
  --region $REGION --profile sandbox \
  --query ShardIterator --output text)

# Read records
aws kinesis get-records \
  --shard-iterator $ITERATOR \
  --region $REGION --profile sandbox \
  --query 'Records[*].Data' --output text | \
  while read b64; do echo $b64 | base64 -d; echo; done
```

  Expected: all 5 JSON records, in order.

  **Part C: Observe replay.**

  Wait 30 seconds, then re-run the `get-shard-iterator` command with
  `TRIM_HORIZON` and read again. All 5 records are still available.
  Compare this to SQS: once consumed and deleted, records are gone forever.

- [ ] **Step 3 (15 min): Break-it exercise — wrong shard iterator type.**

  Use `LATEST` iterator type instead of `TRIM_HORIZON`:

```bash
ITERATOR=$(aws kinesis get-shard-iterator \
  --stream-name $STREAM \
  --shard-id $SHARD \
  --shard-iterator-type LATEST \
  --region $REGION --profile sandbox \
  --query ShardIterator --output text)

aws kinesis get-records \
  --shard-iterator $ITERATOR \
  --region $REGION --profile sandbox
```

  Expected: 0 records (LATEST starts at the tip — no new records have been
  written since the iterator was created). This is the confusion beginners hit:
  "my consumer reads nothing" — often because LATEST was used and the producer
  had already written before the iterator was obtained.

  Fix: use `TRIM_HORIZON` to read from the beginning, or `AT_TIMESTAMP` to
  read from a specific point.

- [ ] **Step 4 (10 min): Journal entry.**

  ```
  ### Day 12 — Kinesis + Decision Matrix
  Key concept — when replay changes the architecture choice: ...
  When would I use Firehose instead of a consumer application: ...
  Break-it — LATEST vs TRIM_HORIZON and the empty read problem: ...
  ```

- [ ] **Step 5 (60 min): Terraform — phase3_communication module.**

  Create `terraform/phase3_communication/variables.tf`:

```hcl
variable "aws_region"  { type = string }
variable "vpc_id"      { type = string }
variable "alb_arn"     { type = string }
variable "name_prefix" { type = string, default = "compute-lab" }
```

  Create `terraform/phase3_communication/main.tf`:

```hcl
# ── SQS queues ────────────────────────────────────────────────────────────

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-dlq"
  message_retention_seconds = 1209600
  tags = { Name = "${var.name_prefix}-dlq" }
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.name_prefix}-main"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${var.name_prefix}-main-queue" }
}

resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
      Condition = {
        ArnLike = { "aws:SourceArn" = aws_sns_topic.events.arn }
      }
    }, {
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.main.arn
    }]
  })
}

# ── SNS ───────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "events" {
  name = "${var.name_prefix}-events"
  tags = { Name = "${var.name_prefix}-events-topic" }
}

resource "aws_sns_topic_subscription" "to_sqs" {
  topic_arn = aws_sns_topic.events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.main.arn

  filter_policy = jsonencode({
    event_type = ["order.created", "order.updated"]
  })
}

# ── EventBridge ───────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_bus" "app" {
  name = "${var.name_prefix}-bus"
  tags = { Name = "${var.name_prefix}-bus" }
}

resource "aws_cloudwatch_event_rule" "order_events" {
  name           = "${var.name_prefix}-order-events"
  event_bus_name = aws_cloudwatch_event_bus.app.name

  event_pattern = jsonencode({
    "detail-type" = ["OrderCreated", "OrderUpdated"]
  })

  tags = { Name = "${var.name_prefix}-order-events-rule" }
}

resource "aws_cloudwatch_event_target" "to_sqs" {
  rule           = aws_cloudwatch_event_rule.order_events.name
  event_bus_name = aws_cloudwatch_event_bus.app.name
  target_id      = "ToSQS"
  arn            = aws_sqs_queue.main.arn
}

# ── Kinesis ───────────────────────────────────────────────────────────────

resource "aws_kinesis_stream" "events" {
  name             = "${var.name_prefix}-events-stream"
  shard_count      = 1
  retention_period = 24

  tags = { Name = "${var.name_prefix}-events-stream" }
}

# ── API Gateway (HTTP API) ─────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type", "authorization"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
    max_age       = 300
  }

  tags = { Name = "${var.name_prefix}-http-api" }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}
```

  Create `terraform/phase3_communication/outputs.tf`:

```hcl
output "sqs_queue_url"        { value = aws_sqs_queue.main.id }
output "sqs_queue_arn"        { value = aws_sqs_queue.main.arn }
output "sns_topic_arn"        { value = aws_sns_topic.events.arn }
output "eventbridge_bus_name" { value = aws_cloudwatch_event_bus.app.name }
output "kinesis_stream_name"  { value = aws_kinesis_stream.events.name }
output "api_gateway_endpoint" { value = aws_apigatewayv2_api.http.api_endpoint }
```

  Update `terraform/main.tf` to add Phase 3:

```hcl
module "phase3" {
  source      = "./phase3_communication"
  aws_region  = var.aws_region
  vpc_id      = var.vpc_id
  alb_arn     = module.phase1.alb_arn
  name_prefix = var.name_prefix
}

output "api_gateway_endpoint" { value = module.phase3.api_gateway_endpoint }
output "sqs_queue_url"        { value = module.phase3.sqs_queue_url }
output "kinesis_stream_name"  { value = module.phase3.kinesis_stream_name }
```

  Apply and verify:

```bash
terraform apply -var-file=terraform.tfvars

# Test API Gateway
curl $(terraform output -raw api_gateway_endpoint)
# Expected: 404 (no routes configured yet — wired in Day 13)

# Test SQS
aws sqs send-message \
  --queue-url $(terraform output -raw sqs_queue_url) \
  --message-body '{"test": true}' \
  --profile sandbox
# Expected: {"MD5OfMessageBody": "...", "MessageId": "..."}

# Test Kinesis
aws kinesis put-record \
  --stream-name $(terraform output -raw kinesis_stream_name) \
  --data "$(echo -n '{"test":true}' | base64)" \
  --partition-key "test" \
  --region ap-southeast-1 --profile sandbox
# Expected: {"ShardId": "shardId-000000000000", "SequenceNumber": "..."}
```

- [ ] **Step 6: Teardown.**

```bash
terraform destroy -var-file=terraform.tfvars
```

---

## Optional Day 13 — Full Reference Architecture

**Theory file:** `content/day13.md` — read before starting.
**Builds on:** All three Terraform modules from Days 4, 7, 12.

This day wires all three phases into one reference architecture and runs
an end-to-end trace through every layer.

---

- [ ] **Step 1: Update terraform/main.tf to wire all three phases.**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region"         { type = string }
variable "aws_profile"        { type = string, default = "sandbox" }
variable "vpc_id"             { type = string }
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "name_prefix"        { type = string, default = "compute-lab" }

module "phase1" {
  source             = "./phase1_compute"
  aws_region         = var.aws_region
  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
  name_prefix        = var.name_prefix
}

module "phase2" {
  source             = "./phase2_containers"
  aws_region         = var.aws_region
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  alb_sg_id          = module.phase1.alb_sg_id
  http_listener_arn  = module.phase1.http_listener_arn
  name_prefix        = var.name_prefix
}

module "phase3" {
  source      = "./phase3_communication"
  aws_region  = var.aws_region
  vpc_id      = var.vpc_id
  alb_arn     = module.phase1.alb_arn
  name_prefix = var.name_prefix
}

output "alb_dns_name"          { value = module.phase1.alb_dns_name }
output "ecr_repository_url"    { value = module.phase2.ecr_repository_url }
output "api_gateway_endpoint"  { value = module.phase3.api_gateway_endpoint }
output "sqs_queue_url"         { value = module.phase3.sqs_queue_url }
output "sns_topic_arn"         { value = module.phase3.sns_topic_arn }
output "eventbridge_bus_name"  { value = module.phase3.eventbridge_bus_name }
output "kinesis_stream_name"   { value = module.phase3.kinesis_stream_name }
```

- [ ] **Step 2: Apply full stack.**

```bash
cd terraform
terraform init
terraform apply -var-file=terraform.tfvars
```

  Expected: ~40 resources created across all three modules.

- [ ] **Step 3: End-to-end trace exercise.**

  Trace a request through every layer:

```bash
ALB=$(terraform output -raw alb_dns_name)

# 1. Request enters ALB → default rule → EC2 ASG
curl http://$ALB/
# Expected: "Hello from ip-10-0-x-x..."

# 2. Request enters ALB → path rule → ECS Fargate
curl http://$ALB/api/
# Expected: nginx default page from ECS container

# 3. Produce SNS event → fan-out to SQS
SQS_URL=$(terraform output -raw sqs_queue_url)
SNS_ARN=$(terraform output -raw sns_topic_arn)
aws sns publish \
  --topic-arn $SNS_ARN \
  --message '{"orderId":"999"}' \
  --message-attributes '{"event_type":{"DataType":"String","StringValue":"order.created"}}' \
  --profile sandbox

# Wait 5 seconds, then receive from SQS:
aws sqs receive-message --queue-url $SQS_URL \
  --profile sandbox --query 'Messages[0].Body' --output text

# 4. Produce EventBridge event → SQS
BUS=$(terraform output -raw eventbridge_bus_name)
aws events put-events \
  --entries "[{\"Source\":\"com.myapp\",\"DetailType\":\"OrderCreated\",
    \"Detail\":\"{\\\"orderId\\\":\\\"888\\\"}\",\"EventBusName\":\"$BUS\"}]" \
  --profile sandbox

# 5. Write to Kinesis
STREAM=$(terraform output -raw kinesis_stream_name)
aws kinesis put-record \
  --stream-name $STREAM \
  --data "$(echo -n '{"orderId":"777","type":"stream"}' | base64)" \
  --partition-key "order-777" \
  --profile sandbox
```

- [ ] **Step 4: Multi-service debug exercise.**

  Introduce a failure: remove the SQS resource policy so EventBridge cannot
  deliver to SQS.

  Navigate: SQS → `compute-lab-main` → Access policy → Edit →
  Remove the `events.amazonaws.com` statement.

  Publish an EventBridge event:
  ```bash
  aws events put-events \
    --entries "[{\"Source\":\"com.myapp\",\"DetailType\":\"OrderCreated\",
      \"Detail\":\"{\\\"orderId\\\":\\\"test\\\"}\",\"EventBusName\":\"$BUS\"}]" \
    --profile sandbox
  ```

  Diagnose using this checklist:
  1. Navigate: EventBridge → Rules → `compute-lab-order-events` → Monitoring →
     check `Invocations(failed)` CloudWatch metric. Non-zero = target failure.
  2. Check for EventBridge DLQ messages (no DLQ configured in this lab — note
     this gap for production).
  3. Navigate: CloudTrail → Event history → filter `sqs.amazonaws.com` →
     look for `SendMessage` with `AccessDenied`.
  4. The denial confirms the SQS resource policy is the problem.

  Fix: restore the resource policy. Verify next event delivers to SQS.

- [ ] **Step 5: Journal — final synthesis entry.**

  ```
  ### Day 13 — Full Reference Architecture
  The service I found hardest to understand and why: ...
  One thing I would design differently in a real production system: ...
  The debugging tool I reached for most: ...
  ```

- [ ] **Step 6: Final teardown.**

```bash
terraform destroy -var-file=terraform.tfvars
```

  Verify all resources are removed:
  ```bash
  aws ec2 describe-instances --profile sandbox \
    --filters "Name=tag:Name,Values=compute-lab*" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text
  # Expected: empty

  aws elbv2 describe-load-balancers --profile sandbox \
    --query 'LoadBalancers[?contains(LoadBalancerName, `compute-lab`)].LoadBalancerName' \
    --output text
  # Expected: empty
  ```

---

## Success Criteria

You have completed this plan when you can:

- [ ] Choose ALB vs NLB vs GWLB and state the OSI layer reason
- [ ] Design an ASG with lifecycle hooks for a zero-downtime deploy
- [ ] Explain why a Fargate task gets its own ENI and what that means for security groups
- [ ] Choose between SQS, SNS, EventBridge, and Kinesis for a given requirement
- [ ] Trace a 502 from API Gateway through ALB to its root cause in ECS or ASG
- [ ] Write any of the above Terraform modules from scratch without copy-pasting
