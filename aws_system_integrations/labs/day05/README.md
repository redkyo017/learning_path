# Day 5 Lab — Inbound Webhook Receiver with Idempotency

## Scenario

Simulate a Stripe-style payment webhook receiver. An external provider POSTs a signed event payload to your API Gateway endpoint. Your system must:

1. Validate the HMAC-SHA256 signature to confirm the request is genuine.
2. Check the DynamoDB idempotency store to determine whether this event has already been processed.
3. If new: write a "processing" record to DynamoDB, enqueue the event to SQS, and return 200.
4. If duplicate: return 200 immediately without enqueuing (idempotent acknowledge).
5. Consumer Lambda reads from SQS and processes the event (updates DynamoDB status to "completed").

The key success condition: sending the same event ID three times results in exactly one DynamoDB record with status `"completed"` and exactly one Consumer Lambda invocation.

---

## Architecture

```
External provider (curl simulation)
           │
           │ POST /webhook
           │ Header: X-Webhook-Signature: sha256=<hmac>
           │ Body: {"id": "evt_test_001", "type": "payment.settled", ...}
           ▼
   API Gateway HTTP API
   (POST /webhook route → Lambda proxy integration)
           │
           ▼
   Validator Lambda (Python)
   ┌─────────────────────────────────────┐
   │ 1. Read signing secret              │◄─── Secrets Manager
   │    (webhook-signing-secret)         │     (webhook-signing-secret)
   │ 2. Compute expected HMAC            │
   │ 3. hmac.compare_digest(expected,    │
   │    received) — reject if mismatch   │
   │ 4. DynamoDB conditional PutItem     │◄─── DynamoDB
   │    ConditionExpression:             │     (webhook_idempotency table)
   │    attribute_not_exists(event_id)   │
   │ 5a. Condition FAILED → duplicate   │
   │     → return 200 (no-op)           │
   │ 5b. Condition PASSED → new event   │
   │     → SQS SendMessage              │───► SQS
   │     → return 200                   │     (webhook-queue)
   └─────────────────────────────────────┘
                                                    │
                                                    ▼
                                        Consumer Lambda
                                        (SQS event source mapping)
                                        - Logs event to CloudWatch
                                        - Updates DynamoDB status
                                          → "completed"
```

---

## Prerequisites

- AWS CLI configured with a non-production account (`aws sts get-caller-identity` shows the correct account).
- Terraform >= 1.5 installed.
- Python 3 available locally (to compute test HMAC signatures).

---

## Setup

```bash
cd aws_system_integrations/labs/day05/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if you want a different region or environment label
terraform init
terraform apply
```

After apply, Terraform outputs:
- `api_gateway_url`: the webhook endpoint URL (e.g. `https://XXXXXXXXXX.execute-api.ap-southeast-1.amazonaws.com/webhook`)
- `secrets_manager_secret_name`: the name of the secret to update

**Update the signing secret** before testing (the default value is a placeholder):

```bash
aws secretsmanager put-secret-value \
  --secret-id webhook-signing-secret-day05lab \
  --secret-string "my-test-signing-secret-do-not-use-in-production"
```

---

## Sending a test webhook

Use this Python snippet to compute a valid HMAC-SHA256 signature and send a test request:

```python
import hmac, hashlib, json, time, requests

SIGNING_SECRET = "my-test-signing-secret-do-not-use-in-production"
API_URL = "https://XXXXXXXXXX.execute-api.ap-southeast-1.amazonaws.com/webhook"

payload = json.dumps({
    "id": "evt_test_001",
    "type": "payment.settled",
    "amount": 10000,
    "currency": "usd",
    "timestamp": int(time.time())
})

signature = hmac.new(
    SIGNING_SECRET.encode(),
    payload.encode(),
    hashlib.sha256
).hexdigest()

response = requests.post(
    API_URL,
    data=payload,
    headers={
        "Content-Type": "application/json",
        "X-Webhook-Signature": f"sha256={signature}"
    }
)
print(response.status_code, response.text)
```

The first call should return `{"message": "accepted"}` with status 200.

---

## Verifying the success condition

After the first send:

```bash
# Check DynamoDB record
aws dynamodb get-item \
  --table-name webhook_idempotency_day05lab \
  --key '{"event_id": {"S": "evt_test_001"}}'
```

Expected output: `status` = `"processing"` or `"completed"` (completed once Consumer Lambda has run).

```bash
# Check CloudWatch Logs for Consumer Lambda invocation
aws logs filter-log-events \
  --log-group-name /aws/lambda/webhook-consumer-day05lab \
  --filter-pattern "evt_test_001"
```

Expected: exactly one log event containing `evt_test_001`.

---

## Break it exercise

**Simulate a provider retry burst.** Send the same event ID (`evt_test_001`) three times in rapid succession (copy the Python snippet above and run it three times, keeping the same `id` value).

Expected outcome:
1. First request: DynamoDB write succeeds, SQS message sent, Consumer Lambda invoked once.
2. Second request: `ConditionalCheckFailedException` raised, return 200 with no SQS message sent.
3. Third request: same as second.

**Verify:**

```bash
# DynamoDB should have exactly one record for evt_test_001
aws dynamodb scan \
  --table-name webhook_idempotency_day05lab \
  --filter-expression "event_id = :eid" \
  --expression-attribute-values '{":eid": {"S": "evt_test_001"}}' \
  --query "Count"
# Expected: 1

# CloudWatch Logs: Consumer Lambda invocation count for evt_test_001
aws logs filter-log-events \
  --log-group-name /aws/lambda/webhook-consumer-day05lab \
  --filter-pattern "evt_test_001" \
  --query "length(events)"
# Expected: 1 (or small number matching the single invocation's log lines)
```

**What to check:** If the count is greater than 1 in DynamoDB, the idempotency write has a bug. If Consumer Lambda was invoked more than once, the idempotency check happened after the enqueue (wrong order).

See `SOLUTION.md` for the full break it answer and explanation.

---

## Teardown

See `teardown.md`. Run `terraform destroy` immediately after completing the lab to avoid Secrets Manager charges (~$0.40/month per secret).
