# Day 1 Lab Teardown

Run after every lab session to avoid ongoing charges.

## Automated teardown

From `labs/day01/`:

```bash
terraform destroy -auto-approve
```

Terraform will delete all resources it manages: the HTTP API, all four Lambda functions, the IAM role and policies, CloudWatch log groups, and Lambda permissions.

## Manual verification checklist (run after destroy)

Run these checks in the AWS Console or CLI to confirm no resources were left behind.

- [ ] **API Gateway HTTP API deleted:**
  AWS Console → API Gateway → HTTP APIs → verify no `lab-day01-*` APIs listed.

  ```bash
  aws apigatewayv2 get-apis --query "Items[?contains(Name,'lab-day01')]"
  # Expected: empty Items array
  ```

- [ ] **Lambda functions deleted:**
  AWS Console → Lambda → Functions → verify no `lab-day01-*` functions listed.

  ```bash
  aws lambda list-functions --query "Functions[?contains(FunctionName,'lab-day01')].[FunctionName]" --output text
  # Expected: no output
  ```

- [ ] **IAM roles deleted:**
  AWS Console → IAM → Roles → verify no `lab-day01-*` roles listed.

  ```bash
  aws iam list-roles --query "Roles[?contains(RoleName,'lab-day01')].[RoleName]" --output text
  # Expected: no output
  ```

- [ ] **IAM policies deleted:**
  AWS Console → IAM → Policies → Customer managed → verify no `lab-day01-*` policies listed.

  ```bash
  aws iam list-policies --scope Local --query "Policies[?contains(PolicyName,'lab-day01')].[PolicyName]" --output text
  # Expected: no output
  ```

- [ ] **CloudWatch log groups deleted:**
  Terraform deletes the log group resources it manages. Verify manually:

  ```bash
  aws logs describe-log-groups --log-group-name-prefix /aws/lambda/lab-day01 \
    --query "logGroups[*].logGroupName" --output text
  # Expected: no output

  aws logs describe-log-groups --log-group-name-prefix /aws/apigateway/lab-day01 \
    --query "logGroups[*].logGroupName" --output text
  # Expected: no output
  ```

  If any log groups remain (e.g., created outside Terraform), delete manually:

  ```bash
  aws logs delete-log-group --log-group-name /aws/lambda/lab-day01-bff-aggregator
  aws logs delete-log-group --log-group-name /aws/lambda/lab-day01-account-mock
  aws logs delete-log-group --log-group-name /aws/lambda/lab-day01-transaction-mock
  aws logs delete-log-group --log-group-name /aws/lambda/lab-day01-jwt-authorizer
  aws logs delete-log-group --log-group-name /aws/apigateway/lab-day01-banking-bff
  ```

- [ ] **Local zip/src files cleaned up (optional):**
  Terraform creates `.lambda_src/` and `.lambda_zip/` directories in `labs/day01/` during `terraform apply`. These are local-only and do not incur AWS charges, but you may want to clean them up:

  ```bash
  rm -rf labs/day01/.lambda_src labs/day01/.lambda_zip
  ```

## Estimated cost if left running

| Resource | Always-on cost | Per-request cost |
|---|---|---|
| Lambda (4 functions) | $0.00 | ~$0.0000002/request (free tier covers 1M/month) |
| API GW HTTP API | $0.00 | ~$0.000001/request (free tier covers 1M/month) |
| CloudWatch Logs | $0.00 | ~$0.50/GB ingested |

**This lab has no always-on resources.** Cost only accrues per request. At lab volumes (< 1,000 requests), this lab costs $0.00 within free tier.

If you leave it running for months and it receives no traffic, the cost remains $0.00. The teardown is recommended as a hygiene practice, not because of meaningful ongoing charges.
