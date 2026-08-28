# Day 4 Lab — Teardown

## Estimated costs (while lab is running)

| Resource | Cost |
|---|---|
| Internal ALB | ~$0.0225/hour base + LCU usage (~$0.54/day) — charged even with zero traffic |
| Lambda | $0.00 at lab volume (free tier covers 1M requests/month) |
| SQS (audit-queue + audit-dlq) | $0.00 at lab volume (free tier covers 1M requests/month) |
| VPC Endpoints (SQS + Lambda) | ~$0.01/hour per AZ; 2 endpoints × 2 AZs = ~$0.04/hour (~$0.96/day total) |
| CloudWatch alarm | $0.10/alarm/month (negligible) |

**Primary driver:** The internal ALB and VPC Interface Endpoints charge hourly even with no traffic. Destroy the lab when you are done.

---

## Teardown steps

### Step 1 — Destroy Terraform resources

```bash
terraform destroy
```

Terraform will show a plan of all resources to be destroyed. Review and confirm with `yes`.

If you applied with non-default variables (e.g., `payment_error_rate=100`, `consumer_broken=true`), pass them again so Terraform refreshes state correctly:
```bash
terraform destroy \
  -var="payment_error_rate=0" \
  -var="consumer_broken=false"
```

---

### Step 2 — Verify internal ALB deleted

```bash
aws elbv2 describe-load-balancers \
  --region ap-southeast-1 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'day04lab')]" \
  --output table
```

Expected: empty table (no rows).

If the ALB still exists: it may be in a `deleting` state. Wait 2–3 minutes and re-run.

---

### Step 3 — Verify SQS queues deleted

```bash
aws sqs list-queues \
  --queue-name-prefix day04lab \
  --region ap-southeast-1
```

Expected: `{"QueueUrls": []}` or no output.

If queues persist: check for SQS policies that prevent deletion, or retry after 60 seconds (SQS deletion is eventually consistent).

---

### Step 4 — Verify Lambda functions deleted

```bash
aws lambda list-functions \
  --region ap-southeast-1 \
  --query "Functions[?contains(FunctionName, 'day04lab')].[FunctionName]" \
  --output table
```

Expected: empty table.

---

### Step 5 — Verify VPC endpoints deleted

```bash
aws ec2 describe-vpc-endpoints \
  --region ap-southeast-1 \
  --filters "Name=tag:Environment,Values=day04lab" \
  --query "VpcEndpoints[].State" \
  --output table
```

Expected: empty table or all entries showing `deleted`.

---

### Step 6 — Delete CloudWatch log groups (manual — Terraform does not manage these)

Lambda automatically creates log groups. Terraform does not delete them on `terraform destroy`.

```bash
# List log groups created by the lab
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/day04lab \
  --region ap-southeast-1 \
  --query "logGroups[].logGroupName" \
  --output text

# Delete each log group found
aws logs delete-log-group \
  --log-group-name /aws/lambda/day04lab-payment-mock \
  --region ap-southeast-1

aws logs delete-log-group \
  --log-group-name /aws/lambda/day04lab-order-mock \
  --region ap-southeast-1

aws logs delete-log-group \
  --log-group-name /aws/lambda/day04lab-audit-consumer-mock \
  --region ap-southeast-1
```

---

### Step 7 — Delete local Terraform state files (optional)

If you do not need the state for reference:
```bash
rm -f terraform.tfstate terraform.tfstate.backup
rm -f terraform.tfvars  # Do not commit this file
rm -rf .terraform .terraform.lock.hcl
```

Keep `terraform.tfvars.example` — it is committed to version control and contains only placeholders.

---

## If terraform destroy fails

**Common causes:**

1. **Lambda event source mapping still active:** Terraform sometimes times out waiting for the SQS–Lambda mapping to detach. Wait 60 seconds and re-run `terraform destroy`.

2. **VPC endpoint in `deleting` state blocking subnet deletion:** VPC endpoints take 2–5 minutes to fully delete. Re-run `terraform destroy` after waiting.

3. **IAM role has non-Terraform-managed attachments:** If you manually attached policies to the Lambda roles during the lab, remove them via console or CLI before re-running destroy.

4. **S3 state backend conflict (if configured):** If you configured a remote state backend, ensure no other session holds a state lock.
