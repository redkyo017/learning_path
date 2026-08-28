# Day 5 Lab — Teardown Checklist

Run these steps immediately after completing the lab. The most important item is Secrets Manager — it bills ~$0.40/month per secret even when unused.

---

## Step 1: Terraform destroy

```bash
cd aws_system_integrations/labs/day05/
terraform destroy
```

Terraform will show a destroy plan listing all resources. Confirm with `yes`.

**Estimated destroy time:** 2–5 minutes (API GW and Lambda deletion takes a few seconds each; DynamoDB table and SQS queue delete quickly).

---

## Step 2: Verify each resource is deleted

After `terraform destroy` completes, verify manually:

### API Gateway

```bash
aws apigatewayv2 get-apis \
  --query "Items[?Name=='webhook-day05lab-api'].{Name:Name, ApiId:ApiId}"
# Expected: empty list []
```

### Lambda functions

```bash
aws lambda list-functions \
  --query "Functions[?starts_with(FunctionName, 'webhook-') && ends_with(FunctionName, 'day05lab')].FunctionName"
# Expected: empty list []
```

### DynamoDB table

```bash
aws dynamodb describe-table \
  --table-name webhook_idempotency_day05lab 2>&1 | grep -i "ResourceNotFoundException"
# Expected: "ResourceNotFoundException" in output
```

### SQS queues

```bash
aws sqs list-queues \
  --queue-name-prefix "webhook-day05lab" \
  --query "QueueUrls"
# Expected: empty or null
```

### Secrets Manager secret

Terraform sets `recovery_window_in_days = 0` which schedules immediate deletion. Verify:

```bash
aws secretsmanager describe-secret \
  --secret-id webhook-signing-secret-day05lab 2>&1 | grep -i "ResourceNotFoundException"
# Expected: "ResourceNotFoundException" in output
```

If Terraform did not delete the secret (e.g., due to a partial destroy failure), force-delete it manually:

```bash
aws secretsmanager delete-secret \
  --secret-id webhook-signing-secret-day05lab \
  --force-delete-without-recovery
```

**Warning:** `--force-delete-without-recovery` is immediate and irreversible. Use only for lab secrets with placeholder values.

### CloudWatch Log Groups

Lambda creates log groups automatically. They are not managed by Terraform and must be deleted separately:

```bash
aws logs delete-log-group \
  --log-group-name /aws/lambda/webhook-validator-day05lab

aws logs delete-log-group \
  --log-group-name /aws/lambda/webhook-consumer-day05lab
```

Or delete all day05 log groups at once:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/webhook- \
  --query "logGroups[?ends_with(logGroupName, 'day05lab')].logGroupName" \
  --output text | xargs -I {} aws logs delete-log-group --log-group-name {}
```

### Local build artifacts

Terraform writes Lambda deployment zips to `.lambda_build/`. These contain no secrets but can be cleaned up:

```bash
rm -rf aws_system_integrations/labs/day05/.lambda_build/
```

---

## Estimated cost if left running

| Resource | Monthly cost at lab volume |
|---|---|
| API Gateway HTTP API | ~$0.00 (first 1M requests/month free) |
| Lambda functions | ~$0.00 (first 1M requests/month free) |
| DynamoDB (on-demand) | ~$0.00 (lab-scale read/write units) |
| SQS | ~$0.00 (first 1M requests/month free) |
| Secrets Manager | **~$0.40/month per secret** (billed per secret, not per request) |

**The only material cost is Secrets Manager.** Delete the secret immediately after the lab.

---

## Terraform state cleanup

If you used local state (the default for this lab), the state file `terraform.tfstate` remains in the lab directory after destroy. It contains no credentials but does contain resource IDs and ARNs. Delete it if you do not need it:

```bash
rm aws_system_integrations/labs/day05/terraform.tfstate
rm aws_system_integrations/labs/day05/terraform.tfstate.backup
```

Do not commit these files to version control.
