# Daily Runbook — AWS Compute, LB & Service Communication

Use this alongside the plan file. The plan has the exact steps; this has the
rhythm, the habits, and the guardrails.

---

## Before You Start Anything

Open three tabs every morning:

1. **Theory file** — `content/dayNN.md` for today
2. **Plan file** — `docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
   (find today's day section)
3. **journal.md** — your running narration

Do not open the AWS Console yet.

---

## The Daily Rhythm (every day, every phase)

```
Step 1 — Read theory (20–30 min)         content/dayNN.md
Step 2 — Answer pre-lab exercises        journal.md, BEFORE Console
Step 3 — Console lab                     plan file, Step 2
Step 4 — Break-it exercise               plan file, Step 3
Step 5 — Journal entry                   journal.md
Step 6 — Terraform (synthesis days only) plan file, Step 5
Step 7 — Teardown                        plan file, last step
```

**Step 2 is non-negotiable.** The exercises in the theory file are designed to
force you to reason about the concept before you see it working. If you skip
them and go straight to Console, you are doing a tutorial, not learning.

**Step 4 is non-negotiable.** Debugging a known failure is the entire point.
If you skip the break-it exercise, you will not be able to debug the real
failure when it happens in production.

---

## Phase Guide

### Phase 1 — Traffic & Compute (Days 1–4)

What you are building: an internet-facing ALB routing HTTP traffic to an
EC2 fleet managed by an Auto Scaling Group.

| Day | Read | Build | Synthesise |
|---|---|---|---|
| 1 | EC2 families, EBS types, purchasing | Launch instances, attach EBS | — |
| 2 | ALB vs NLB vs GWLB, health checks | ALB + two target groups + NLB | — |
| 3 | Lifecycle hooks, scaling policies | ASG + target tracking + lifecycle hook | — |
| 4 | 502 diagnosis, module outputs | Reproduce + debug 502 | **Terraform phase1_compute/** |

Day 4 Terraform applies everything from Days 1–3. Do not write Terraform
before Day 4 — build it in Console first.

---

### Phase 2 — Container Layer (Days 5–7)

What you are building: ECS Fargate service behind the same ALB from Phase 1,
accessed at `/api/*`.

**Before Day 5:** Make sure you have Docker installed and can push to ECR.
```bash
docker --version   # expect: Docker 24.x+
aws ecr get-login-password --region ap-southeast-1 --profile sandbox | \
  docker login --username AWS \
  --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com
```

| Day | Read | Build | Synthesise |
|---|---|---|---|
| 5 | Task definition, awsvpc, execution role | ECR push + Fargate task + ENI inspection | — |
| 6 | Deregistration delay, Cloud Map, blue/green | ECS service behind ALB | — |
| 7 | Dual-backend ALB, target_type ip | Wire EC2 + ECS behind same ALB | **Terraform phase2_containers/** |

Day 7 Terraform requires Phase 1 to be applied first. Run:
```bash
cd terraform
terraform apply -var-file=terraform.tfvars   # applies both phase1 + phase2
```

---

### Phase 3 — Communication Layer (Days 8–12)

What you are building: SQS, SNS, EventBridge, API Gateway, Kinesis — the
messaging backbone that connects your services.

No Docker needed. These days are AWS Console + CLI only until Day 12 Terraform.

| Day | Read | Build | Synthesise |
|---|---|---|---|
| 8 | Visibility timeout, DLQ, standard vs FIFO | SQS queue + DLQ + consumer simulation | — |
| 9 | SNS fan-out, filter policies | SNS → 3 SQS queues with filters | — |
| 10 | EventBridge buses, rules, targets | Custom bus + rules + SQS target | — |
| 11 | HTTP API vs REST API, VPC Link, CORS | HTTP API + VPC Link + ALB backend | — |
| 12 | Kinesis shards, iterator types, Firehose | Kinesis stream + producer/consumer | **Terraform phase3_communication/** |

---

### Day 13 (Optional) — Full Reference Architecture

Only do Day 13 if you completed Days 1–12 and want to see the entire system
working together. This day:
- Applies all three Terraform modules at once via `terraform/main.tf`
- Runs one end-to-end request trace through every layer
- Runs one multi-service debug exercise

```bash
cd terraform
terraform apply -var-file=terraform.tfvars
```

---

## Teardown — Do This Every Day

ALB and NAT Gateway are the main cost drivers. Both run on hourly meters.

**After every console-only day:**
- Delete ALBs manually: EC2 → Load Balancers → select → Actions → Delete
- Delete target groups: EC2 → Target Groups → select → Actions → Delete
- Terminate EC2 instances
- Delete SQS/SNS/EventBridge resources created in that session

**After every Terraform day:**
```bash
cd terraform
terraform destroy -var-file=terraform.tfvars
```

Verify teardown:
```bash
# Check no ALBs remain
aws elbv2 describe-load-balancers --profile sandbox \
  --query 'LoadBalancers[].LoadBalancerName' --output text

# Check no running ECS tasks
aws ecs list-tasks --cluster compute-lab-cluster \
  --profile sandbox --region ap-southeast-1 2>/dev/null || echo "no cluster"
```

Estimated cost if you forget to teardown overnight: **$3–8** (ALB + NAT GW).

---

## The Journal Habit

Every day, write in `journal.md` twice:

**Before Console (from the theory exercises):**
```
Answering pre-lab questions before I touch AWS...
Q1: ...
Q2: ...
```

**After lab (the day template):**
```
### Day N — Topic
Key concept in my own words: ...
When would I NOT use this: ...
Break-it — what I misconfigured and how I found it: ...
```

The "when would I NOT use this" question is the one that separates people who
pass certifications from people who can make architecture decisions. Force
yourself to answer it every day.

---

## When You Get Stuck

### Console lab not working as expected

1. Check the **target group health status** first — almost every connectivity
   problem in Phase 1 and 2 shows up here.
2. Check the **security group** — wrong source (EC2 SG allows 0.0.0.0/0 instead
   of ALB SG, or ECS task SG doesn't allow the ALB SG).
3. Check **CloudWatch Logs** — ECS tasks, Lambda, and EventBridge targets all
   log here. Most "why isn't it working" questions are answered in the logs.
4. Check **IAM** via CloudTrail — if something can't access an AWS service,
   there's an AccessDenied event in CloudTrail within 5 minutes.

### Terraform errors

| Error | Likely cause |
|---|---|
| `ResourceAlreadyExistsException` | Console resource not cleaned up before apply |
| `InvalidParameterException: target group ... already exists` | Previous Terraform state lost; import or rename |
| `AccessDenied` during apply | AWS CLI profile wrong, or IAM permissions missing |
| `module.phase2 depends on module.phase1` error | Apply from terraform/ root, not from phase subdirectory |

Always run from the `terraform/` directory, not from inside a module:
```bash
cd /path/to/aws_computing_loadbalancing_communication_components/terraform
terraform apply -var-file=terraform.tfvars
```

### ECS task stuck in PENDING or STOPPED

```bash
# Get stopped reason
aws ecs describe-tasks \
  --cluster compute-lab-cluster \
  --tasks <TASK_ARN> \
  --profile sandbox \
  --region ap-southeast-1 \
  --query 'tasks[0].stoppedReason'
```

Common stopped reasons:
- `CannotPullContainerError` → execution role missing ECR permissions
- `Essential container exited` → app crashed, check CloudWatch Logs
- `ResourceInitializationError` → ENI provisioning failed, try a different subnet

### SQS messages not arriving

1. Is the SQS **resource policy** allowing the sender (SNS, EventBridge)?
2. Is the SNS **filter policy** matching your message attributes?
3. Is the EventBridge **rule IAM role** allowed to call `sqs:SendMessage`?
4. Is the message in the **DLQ** instead of the main queue?

---

## Quick Reference

### Get VPC + subnet IDs (needed for terraform.tfvars)
```bash
aws ec2 describe-vpcs --profile sandbox \
  --filters "Name=tag:Name,Values=shared-services*" \
  --query 'Vpcs[0].{VpcId:VpcId}' --output table

aws ec2 describe-subnets --profile sandbox \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'Subnets[*].{Id:SubnetId,AZ:AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

### Apply only one phase
```bash
terraform apply -var-file=terraform.tfvars -target=module.phase1
terraform apply -var-file=terraform.tfvars -target=module.phase2
terraform apply -var-file=terraform.tfvars -target=module.phase3
```

### Watch ECS service events
```bash
aws ecs describe-services \
  --cluster compute-lab-cluster \
  --services compute-lab-app-service \
  --profile sandbox \
  --query 'services[0].events[:5]' --output table
```

### Poll SQS queue
```bash
aws sqs receive-message \
  --queue-url <QUEUE_URL> \
  --wait-time-seconds 20 \
  --profile sandbox \
  --query 'Messages[*].Body' --output text
```

### Publish EventBridge test event
```bash
aws events put-events \
  --entries '[{
    "Source": "com.myapp.test",
    "DetailType": "OrderCreated",
    "Detail": "{\"orderId\":\"test-1\"}",
    "EventBusName": "compute-lab-bus"
  }]' \
  --profile sandbox
```

---

## Day Completion Checklist

Before closing your laptop:

- [ ] All AWS Console resources deleted (or `terraform destroy` run)
- [ ] Journal entry written (key concept + when NOT to use + break-it)
- [ ] Pre-lab exercises answered for tomorrow's day (optional but highly recommended)
- [ ] No running Fargate tasks or ALBs (verify with quick CLI check above)
