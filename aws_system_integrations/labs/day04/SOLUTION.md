# Day 4 Lab — Solution Guide

## Internal ALB mechanics

**`scheme = "internal"` means:**
- The ALB is assigned only private IP addresses from the subnets it is placed in.
- No public IP is allocated. The ALB DNS name (e.g., `day04lab-payment-alb-xxxxxxxxxx.ap-southeast-1.elb.amazonaws.com`) resolves to private IPs only.
- Routing to the ALB works only from within the VPC or from a connected network (peered VPC, VPN, Direct Connect). Calling the DNS name from your laptop over the internet returns a connection timeout — the IP is not routable from outside the VPC.
- This is the correct deployment model for inter-service communication inside your system. A public ALB for an internal payment service would expose it to internet traffic (even if SGs block it, the attack surface is larger and PCI scope expands).

**Why use an internal ALB instead of calling Lambda directly?**
- Stable DNS name — ALB DNS never changes even if Lambda function ARN changes.
- Load distribution — if you replace the Lambda target type with IP targets (ECS tasks), the ALB distributes across instances transparently. The Order Lambda code does not change.
- Health checks — ALB can route away from unhealthy targets. Lambda target type with a `/health` path gives you basic liveness checking at the ALB layer.

---

## Lambda as ALB target

Registering a Lambda function as an ALB target requires two resources:

1. **Target group with `target_type = "lambda"`** — unlike `ip` or `instance` target types, a Lambda target group requires no port. The ALB invokes the Lambda synchronously using the Lambda Invoke API.

2. **`aws_lambda_permission` granting `elasticloadbalancing.amazonaws.com`** — without this permission, the ALB cannot invoke the Lambda and the target will always show as unhealthy. The `source_arn` must be the target group ARN, not the ALB ARN.

```hcl
resource "aws_lambda_permission" "alb_invoke_payment" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.payment.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.payment.arn  # target group, not ALB
}
```

**ALB request/response format for Lambda targets:**
- ALB converts the HTTP request into an event object with `httpMethod`, `path`, `headers`, `body`, `queryStringParameters`.
- Lambda returns a dict with `statusCode`, `headers`, `body`.
- If the Lambda returns a non-dict (e.g., a raw string or None), the ALB returns 502 Bad Gateway.

---

## SQS DLQ redrive mechanics

Understanding exactly when a message moves to the DLQ is important for debugging.

**The receive count increments on receive, not on exception.**

The sequence:
1. Message arrives in queue.
2. Consumer Lambda is invoked with the message (SQS event source mapping does this automatically).
3. Lambda throws an exception (or times out).
4. SQS event source mapping does **not** delete the message. The message becomes **visible** again after the visibility timeout.
5. Lambda is invoked again with the same message. Receive count = 2.
6. Lambda throws again. Message becomes visible again. Receive count = 3.
7. Receive count equals `maxReceiveCount = 3`. SQS moves the message to the DLQ.

**Key detail:** The message is not deleted when Lambda throws. The Lambda error causes the SQS event source mapping to not send a delete request. The message re-enters the queue after the visibility timeout. The total time before DLQ delivery is approximately `maxReceiveCount × visibility_timeout_seconds` = 3 × 180s = 540 seconds (9 minutes) for this lab's configuration.

**Why is visibility timeout set to 180s (6× Lambda timeout)?**
Best practice: visibility timeout should be at least 6× the Lambda timeout. Reasoning: Lambda has a 30-second timeout. If Lambda takes exactly 30 seconds and times out, SQS needs to keep the message invisible long enough for the invocation to complete or fail. If visibility timeout equals Lambda timeout (30s), the message becomes visible before Lambda finishes, causing a duplicate invocation. The 6× multiplier provides headroom for retries and slow starts.

---

## Exercise C — Break it answer

**Expected behavior after setting `consumer_broken = true` and sending 10 messages:**

- Each of the 10 messages is received 3 times (maxReceiveCount = 3), and every receive ends in a RuntimeError.
- The guaranteed outcome is **all 10 messages in the DLQ**. The Lambda *invocation count* will be between 3 and 30: the event source mapping uses `batch_size = 10` with a 5-second batching window, so multiple messages are often delivered in one invocation, and the whole batch fails together. 30 invocations only occurs if every message is delivered alone.

**Verifying DLQ depth:**
```bash
aws sqs get-queue-attributes \
  --queue-url <audit_dlq_url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --region ap-southeast-1
```

Expected output:
```json
{
    "Attributes": {
        "ApproximateNumberOfMessages": "10",
        "ApproximateNumberOfMessagesNotVisible": "0"
    }
}
```

**Inspecting a DLQ message:**
```bash
aws sqs receive-message \
  --queue-url <audit_dlq_url> \
  --attribute-names All \
  --region ap-southeast-1
```

The `ApproximateReceiveCount` in the response is 1 — this is the first time you have received it from the DLQ. The DLQ is a regular SQS queue; it does not track the original queue's receive count.

**Draining the DLQ after fixing the consumer:**

Option 1 — AWS Console: SQS → audit-dlq → "Start DLQ redrive" → select source queue. AWS redrives messages back to the source queue automatically.

Option 2 — AWS CLI (manual, useful to understand the mechanics):
```bash
# 1. Fix the consumer
terraform apply -var="consumer_broken=false"

# 2. Start message move task (AWS CLI v2 only)
aws sqs start-message-move-task \
  --source-queue-url <audit_dlq_url> \
  --destination-queue-url <audit_queue_url>
```

Option 3 — Manual script (receives from DLQ, re-sends to source):
```bash
while true; do
  MSG=$(aws sqs receive-message --queue-url <dlq_url> --output json)
  BODY=$(echo "$MSG" | jq -r '.Messages[0].Body')
  RECEIPT=$(echo "$MSG" | jq -r '.Messages[0].ReceiptHandle')
  [ -z "$BODY" ] && break
  aws sqs send-message --queue-url <source_url> --message-body "$BODY"
  aws sqs delete-message --queue-url <dlq_url> --receipt-handle "$RECEIPT"
done
```

---

## Circuit breaker note (important conceptual clarification)

**ALB health checks are not a circuit breaker.**

In this lab, `payment_error_rate = 100` makes the Payment Lambda always return HTTP 500 on real requests (`/charge`). But the health check path (`/health`) always returns 200. The ALB sees a healthy target and keeps routing traffic to it.

Behavior observed:
- ALB target group shows the Payment Lambda as **healthy** (health check passes).
- Every request to `/charge` returns 500 from Lambda → ALB forwards 500 → Order Lambda sees HTTP error.
- ALB does NOT stop sending requests after N failures. It continues routing to the Lambda.

**What a real circuit breaker would add:**
- The Order Lambda tracks payment service failure rate in its own state (DynamoDB or ElastiCache).
- After 5 consecutive 500 responses, the Order Lambda stops calling the ALB entirely.
- It returns `{"payment_status": "circuit_open"}` immediately without making a network call.
- After 30 seconds, it sends one probe request. If that succeeds, it resumes normal calls.

ALB health checks detect **dead** targets (no response, connection refused). A circuit breaker detects **slow or error-returning** targets. They are complementary, not interchangeable.

---

## SQS Standard vs FIFO — when to use each

This lab uses SQS Standard. For the audit use case, ordering is not required — audit events from order-003 arriving before order-001 is acceptable; they each carry their own `order_id` timestamp. Standard SQS handles this at effectively unlimited throughput.

If you changed the use case to "debiting a bank account" where transaction ordering per account matters:
- Use FIFO with `MessageGroupId = account_id`.
- All transactions for the same account are delivered in order.
- Cap: 3,000 TPS with batching (300 TPS without).

The lab's `maxReceiveCount = 3` setting applies equally to Standard and FIFO queues.
