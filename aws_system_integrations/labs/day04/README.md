# Day 4 Lab — Service-to-Service Patterns

## Scenario

You are wiring together three services in an order management microservice mesh:

- **Order Lambda** — receives customer orders, calls payment service synchronously, publishes an audit event asynchronously.
- **Payment Lambda (mock)** — represents the payment service behind an internal ALB. Returns 200 (success) or 500 (error) based on a configurable error rate environment variable.
- **Consumer Lambda (mock)** — reads from the audit SQS queue. Can be broken to simulate processing failures.

This lab has two main threads:
1. **Synchronous path:** Order Lambda → Internal ALB → Payment Lambda. You will manipulate the payment error rate and observe how ALB responds.
2. **Asynchronous path:** Order Lambda → SQS audit-queue → Consumer Lambda. You will break the consumer and observe DLQ fill.

---

## Architecture

```
                        ┌──────────────────────────────────────┐
                        │             VPC (private)            │
                        │                                      │
  [Test invoke]         │  ┌──────────────┐                    │
       │                │  │ Order Lambda │                    │
       └───────────────>│  │              │─────────────────┐  │
                        │  └──────────────┘                 │  │
                        │         │                         │  │
                        │         │ HTTP POST /charge       │  │
                        │         ▼                         │  │
                        │  ┌──────────────────┐             │  │
                        │  │  Internal ALB    │             │  │
                        │  │ (scheme=internal)│             │  │
                        │  └────────┬─────────┘             │  │
                        │           │                       │  │
                        │           ▼                       │  │
                        │  ┌─────────────────┐              │  │
                        │  │ Payment Lambda  │              │  │
                        │  │ (mock, 200/500) │              │  │
                        │  └─────────────────┘              │  │
                        │                                   │  │
                        │  SQS (audit-queue) <──────────────┘  │
                        │         │                            │
                        │         │ (Lambda event source)      │
                        │         ▼                            │
                        │  ┌─────────────────┐                 │
                        │  │ Consumer Lambda │                 │
                        │  │ (mock, throws   │                 │
                        │  │  on break-it)   │                 │
                        │  └─────────────────┘                 │
                        │         │ (maxReceiveCount=3)        │
                        │         ▼                            │
                        │  SQS (audit-dlq)                     │
                        └──────────────────────────────────────┘
```

---

## Prerequisites

- Terraform >= 1.5
- AWS credentials configured (SSO or environment variables — never hardcode)
- An AWS account where you can create Lambda, ALB, SQS, VPC, and IAM resources
- The `aws` CLI for verification steps

---

## Setup

1. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your region. Leave `payment_error_rate = 0` for the happy path.

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Note the outputs:
   - `alb_dns_name` — internal ALB DNS (only reachable within VPC)
   - `audit_queue_url` — SQS queue URL
   - `audit_dlq_url` — DLQ URL
   - `order_lambda_arn` — Order Lambda ARN for test invocations

---

## Exercises

### Exercise A — Happy path

Invoke the Order Lambda with a test payload:
```bash
aws lambda invoke \
  --function-name <order_lambda_name> \
  --payload '{"order_id":"ord-001","amount":99.00}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

Expected: `{"payment_status": "success", "audit_sent": true}`

Check SQS audit queue depth (should be 1 message waiting or already processed):
```bash
aws sqs get-queue-attributes \
  --queue-url <audit_queue_url> \
  --attribute-names ApproximateNumberOfMessages
```

---

### Exercise B — Simulate payment service failure

Set `payment_error_rate = 100` in `terraform.tfvars` and apply:
```bash
terraform apply -var="payment_error_rate=100"
```

Invoke Order Lambda again:
```bash
aws lambda invoke \
  --function-name <order_lambda_name> \
  --payload '{"order_id":"ord-002","amount":50.00}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

Expected: `{"payment_status": "error", "alb_status_code": 500}`

**What you are observing:** The payment Lambda returns 500. ALB passes the Lambda's 500 response through verbatim to the Order Lambda; 502 only occurs when the Lambda response is malformed. The Order Lambda sees a non-2xx response. This is **not** a circuit breaker — ALB will continue sending requests to the payment Lambda even though it keeps failing. A true circuit breaker requires application-level logic in the Order Lambda to stop calling after N failures.

Reset: `terraform apply -var="payment_error_rate=0"`

---

### Exercise C (Break it) — DLQ fill

**Goal:** Set Consumer Lambda to always throw an exception. Send 10 messages to SQS. After 3 receive attempts each, verify all 10 land in DLQ. Then fix the consumer and drain the DLQ.

**Step 1:** Update Consumer Lambda to simulate a broken consumer. In `main.tf`, change the Consumer Lambda environment variable `CONSUMER_BROKEN` to `"true"`, then apply:
```bash
terraform apply -var="consumer_broken=true"
```
(See `variables.tf` for the `consumer_broken` variable.)

**Step 2:** Send 10 messages to the audit queue:
```bash
for i in $(seq 1 10); do
  aws sqs send-message \
    --queue-url <audit_queue_url> \
    --message-body "{\"audit_id\": \"aud-$(printf '%03d' $i)\", \"event\": \"payment_completed\"}"
done
```

**Step 3:** Wait for SQS to exhaust receive attempts. With `maxReceiveCount=3`, this takes approximately 3 × 180s = 540s (~9 minutes) — the queue's visibility timeout is 180 seconds. All messages process in parallel, so total wait is ~9 minutes.

**Step 4:** Check DLQ depth:
```bash
aws sqs get-queue-attributes \
  --queue-url <audit_dlq_url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
```

Expected: `ApproximateNumberOfMessages = 10`

**Step 5:** Inspect a DLQ message:
```bash
aws sqs receive-message \
  --queue-url <audit_dlq_url> \
  --attribute-names All \
  --message-attribute-names All
```

Note the `ApproximateReceiveCount` attribute — it should be 1 (the DLQ is a regular SQS queue; this is the first receive from the DLQ itself). The original receive count that triggered the DLQ move is tracked in `ApproximateFirstReceiveTimestamp`.

**Step 6:** Fix the consumer and drain the DLQ:
```bash
# Fix consumer
terraform apply -var="consumer_broken=false"

# Redrive DLQ messages back to source queue using SQS console
# or manually re-send each DLQ message to the audit-queue:
# aws sqs receive-message --queue-url <dlq_url> | parse | send to source queue
```

The SQS console provides a "Start DLQ redrive" button that automates this. AWS CLI v2 also supports `start-message-move-task`.

---

## Key observations

1. **Internal ALB is not internet-reachable.** The `alb_dns_name` output resolves to a private IP. Calling it from outside the VPC returns a connection timeout.

2. **ALB health checks ≠ circuit breaker.** The payment Lambda passes health checks (it always returns 200 on `GET /health`) even when `payment_error_rate=100`. ALB keeps sending traffic. A true circuit breaker needs to live in the Order Lambda.

3. **DLQ receive count is message-level, not per-invocation.** SQS increments the receive count each time a message is made visible and received. Three Lambda invocations that each throw an exception = receive count of 3 = DLQ.

4. **Visibility timeout must exceed Lambda timeout.** If Lambda takes 25 seconds but visibility timeout is 30 seconds, a slow Lambda invocation risks the message becoming visible again before the Lambda finishes — causing a duplicate. Set visibility timeout to at least 6× Lambda timeout.

---

## Teardown

See `teardown.md` for step-by-step teardown instructions. The internal ALB charges ~$0.008/hour even with zero traffic.
