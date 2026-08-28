# Day 2 Lab — ALB Weighted + Header-Based Routing

## Scenario

The core banking team is releasing `/api/payments` v2 with enhanced fraud signal injection. Two requirements must be met simultaneously:

1. **Canary deploy (10% v2):** Most production traffic stays on the proven v1 while v2 is validated. The percentage is adjustable without redeploying either service.
2. **Version pinning for QA:** The internal QA team must always hit v2 by sending `x-api-version: v2`, regardless of the canary weight.

## Architecture

```
                       Client
                         │
                    ┌────▼────┐
                    │   ALB   │  port 80
                    └────┬────┘
                         │
          ┌──────────────┼──────────────┐
          │                             │
    Rule 1 (priority 1)          Default action
    Condition:                   Weighted forward
    x-api-version: v2
          │                             │
          ▼                   ┌─────────┴──────────┐
      v2-tg (100%)       v1-tg (90%)          v2-tg (10%)
          │                   │                    │
    EC2: api-v2          EC2: api-v1          EC2: api-v2
```

Rule evaluation order:
1. Header rule fires first (priority 1): requests with `x-api-version: v2` → always v2-tg
2. All other requests fall through to the default weighted action → 90% v1, 10% v2

## Files

| File | Purpose |
|---|---|
| `main.tf` | VPC data, EC2 instances, ALB, target groups, listener, listener rules |
| `variables.tf` | `aws_region`, `environment`, `v2_weight` |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` before applying |
| `SOLUTION.md` | Explains listener rule priorities, weighted mechanics, canary promotion |
| `teardown.md` | `terraform destroy` checklist + manual cleanup steps |

## Prerequisites

- Terraform >= 1.5
- AWS credentials configured (`AWS_PROFILE` or environment variables — see `terraform.tfvars.example`)
- Default VPC present in the target region with at least two subnets

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set your region and confirm environment name
terraform init
terraform plan
terraform apply
```

After `apply`, Terraform outputs `alb_dns_name`. Allow 60–90 seconds for EC2 instances to pass health checks before testing.

## Test the routing

Replace `<alb_dns_name>` with the value from `terraform output alb_dns_name`.

```bash
# Weighted canary — run ~10 times, approximately 1 in 10 should return v2
curl http://<alb_dns_name>/

# Header-based routing — always returns v2
curl -H "x-api-version: v2" http://<alb_dns_name>/

# Confirm the X-Served-By response header
curl -I -H "x-api-version: v2" http://<alb_dns_name>/
```

Expected responses:
- Without header: `{"version": "v1", ...}` about 90% of the time
- With `x-api-version: v2`: `{"version": "v2", ...}` 100% of the time

## Canary promotion

To shift more traffic to v2, edit `terraform.tfvars` and increase `v2_weight`:

```hcl
v2_weight = 50   # 50/50 split
```

```bash
terraform apply   # ALB rules update in-place; no service restart
```

Continue to `v2_weight = 100` when ready. At that point, v1 receives zero traffic and can be decommissioned.

---

## Break it exercise

Remove all healthy targets from the v2 target group while the canary weight is still 10%.

**How to break it:**
- Option A: Stop the EC2 instance backing v2 (`aws ec2 stop-instances --instance-ids <v2_instance_id>`).
- Option B: Deregister the v2 target from the target group (`aws elbv2 deregister-targets --target-group-arn <v2-tg-arn> --targets Id=<v2_instance_id>`).

**Question:** With 10% of traffic weighted to v2-tg and all v2 targets unhealthy, what does the ALB do?
- (A) Returns 502/503 for ~10% of requests
- (B) Silently redistributes all traffic to v1-tg
- (C) Closes the connection before sending a response

Think through your answer, test it by running repeated `curl` requests, then check `SOLUTION.md` for the explanation.

**Re-register the target when done:**
```bash
aws elbv2 register-targets \
  --target-group-arn <v2-tg-arn> \
  --targets Id=<v2_instance_id>
```

---

### Exercise 3: WAF fraud-signal blocking
1. Send a normal request — observe 200
2. Send a request with the fraud header: `curl -H "x-fraud-signal: high-risk" http://<alb-dns>/`
3. Check CloudWatch → WAF → `FraudSignalHeader` metric — should show 1 counted request
4. Change the rule action from `count {}` to `block {}` in the AWS Console (do not modify Terraform)
5. Re-send the fraud-signal request — observe 403
6. Reset the rule back to Count mode before teardown
