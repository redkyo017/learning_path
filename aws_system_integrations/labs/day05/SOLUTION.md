# Day 5 Lab — Solution Guide

## HMAC-SHA256 Validation Walkthrough

### Why `hmac.compare_digest` and not `==`

String equality (`==`) in Python (and most languages) short-circuits: it returns `False` as soon as it finds the first mismatched character. This creates a timing side-channel: a comparison that matches the first 3 bytes takes slightly longer than one that matches 0 bytes.

An attacker who can send arbitrary signatures and measure response times can use this to brute-force the correct signature one byte at a time. For a 32-byte (256-bit) SHA256 hex digest (64 hex characters), this reduces the brute-force space from 16^64 to 16 * 64 = 1,024 attempts.

`hmac.compare_digest` compares every byte unconditionally, taking the same time regardless of where the mismatch occurs. This eliminates the timing side-channel.

```python
# WRONG — timing attack possible
if expected_hmac == received_hmac:
    ...

# CORRECT — constant-time comparison
import hmac
if hmac.compare_digest(expected_hmac, received_hmac):
    ...
```

### The raw body requirement

HMAC is computed over the raw request bytes. Once you parse the JSON body into a Python dict and re-serialize it, the byte sequence may differ (key order, whitespace). Always compute HMAC over the raw bytes from `event["body"]` before parsing.

```python
raw_body = event.get("body", "")           # raw string from API GW proxy
payload  = json.loads(raw_body)            # parse AFTER computing HMAC
```

---

## DynamoDB Conditional Write Mechanics

### Why `attribute_not_exists` instead of a read-then-write

A read (`GetItem`) followed by a conditional write is a race condition under concurrent Lambda invocations. If two Lambda instances receive the same event simultaneously, both may read "not found" before either writes.

DynamoDB's `ConditionExpression = "attribute_not_exists(event_id)"` is evaluated atomically on the server side. Exactly one writer wins; the other gets `ConditionalCheckFailedException`. No race condition is possible.

```python
try:
    dynamodb.put_item(
        TableName=TABLE_NAME,
        Item={
            "event_id":   {"S": event_id},
            "status":     {"S": "processing"},
            "expires_at": {"N": str(int(time.time()) + 86400)}
        },
        ConditionExpression="attribute_not_exists(event_id)"
    )
except ClientError as e:
    if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
        # Duplicate — return 200 (idempotent acknowledge, no processing)
        return {"statusCode": 200, "body": json.dumps({"message": "duplicate"})}
    raise  # Any other error is unexpected — surface it
```

### What "idempotent acknowledge" means

Returning 200 to a duplicate delivery tells the provider "I received this successfully." The provider stops retrying and marks the delivery as successful. This is correct behaviour — you have already processed (or are processing) this event. Returning 4xx or 5xx would cause the provider to retry indefinitely.

---

## TTL Calculation

```python
expires_at = int(time.time()) + 86400   # now + 24 hours (in seconds)
```

DynamoDB TTL deletes items whose `expires_at` timestamp has passed. Deletion is asynchronous and may happen up to 48 hours after expiry, but the item is no longer readable via consistent reads after the TTL time.

**Why 24 hours?** Most payment providers retry within a few minutes to a few hours. 24 hours provides a generous window. Provider retry windows are typically 72 hours maximum, but a 24-hour idempotency window covers all realistic retry scenarios for this lab. In production, consider 72 hours to match the provider's full retry window.

**Why TTL is non-negotiable:** Without TTL, a webhook endpoint processing 1,000 events per day accumulates 365,000 DynamoDB items per year. At 1 KB per item, that is ~365 MB per year — and DynamoDB charges for storage. At 10,000 events per day (a modest production volume), that is 3.65 GB per year. Enable TTL from day one.

---

## SQS Exactly-Once Delivery Note

SQS standard queues provide **at-least-once** delivery. The Consumer Lambda may receive the same SQS message more than once (e.g., if the Lambda crashes after processing but before deleting the message, SQS redelivers it after the visibility timeout expires).

The idempotency in the Validator Lambda ensures that the Consumer Lambda sees each **logical event** exactly once. Here is the full chain:

1. Provider sends event `evt_001` once.
2. Validator Lambda: DynamoDB write succeeds → SQS message sent once.
3. Consumer Lambda: processes `evt_001`, updates DynamoDB to "completed", SQS message deleted.

If SQS redelivers the message to Consumer Lambda (because Consumer Lambda crashed at step 3), Consumer Lambda will:
- Attempt to update DynamoDB status to "completed".
- DynamoDB UpdateItem is idempotent (setting status to "completed" twice has no side effect).
- SQS message is deleted on success.

The Consumer Lambda side effect (in a real system: writing a payment record to a database) must also be idempotent. Before applying a side effect, the Consumer Lambda should check whether the DynamoDB record is already "completed". If it is, skip the side effect and delete the SQS message.

---

## Break It Answer — Three Rapid Requests

**Scenario:** Event ID `evt_test_001` is sent three times in rapid succession.

**What happens:**

| Request | DynamoDB result | SQS | Consumer Lambda | Return code |
|---|---|---|---|---|
| 1st | PutItem SUCCEEDS — item created with status "processing" | Message sent | Invoked once, updates to "completed" | 200 "accepted" |
| 2nd | PutItem FAILS — `ConditionalCheckFailedException` (item exists) | No message sent | Not invoked | 200 "duplicate" |
| 3rd | PutItem FAILS — same as above | No message sent | Not invoked | 200 "duplicate" |

**Verification:**

```bash
# DynamoDB count for evt_test_001 = 1
aws dynamodb scan \
  --table-name webhook_idempotency_day05lab \
  --filter-expression "event_id = :eid" \
  --expression-attribute-values '{":eid": {"S": "evt_test_001"}}' \
  --query "Count"
# Expected: 1

# DynamoDB status = "completed"
aws dynamodb get-item \
  --table-name webhook_idempotency_day05lab \
  --key '{"event_id": {"S": "evt_test_001"}}' \
  --query "Item.status.S"
# Expected: "completed"

# CloudWatch Logs: Consumer Lambda invocations for evt_test_001
aws logs filter-log-events \
  --log-group-name /aws/lambda/webhook-consumer-day05lab \
  --filter-pattern "evt_test_001" \
  --query "length(events)"
# Expected: small number (1 invocation = a few log lines)
```

**If Consumer Lambda count > 1:** The SQS message was redelivered (Consumer Lambda crashed before deleting the message). This is SQS at-least-once behaviour — not a bug in the idempotency logic. Check Consumer Lambda CloudWatch Logs for errors.

**If DynamoDB count > 1:** The conditional write is not working. Verify the `ConditionExpression` is exactly `"attribute_not_exists(event_id)"` and the partition key attribute name matches the table definition.

---

## Synthesis Design Model Answer

### Exercise 3 Walkthrough — Mobile Banking Architecture

The following ASCII diagram annotates each pattern name against the component it implements.

```
[Mobile App]
  │
  │ HTTPS (TLS 1.2+ enforced by CloudFront)
  ▼
[CloudFront]                         ← Day 2: L7 ingress (CDN + WAF)
  WAF: OWASP Top 10 rules, rate limiting
  Caches: static assets (JS, CSS, images)
  Origin: ALB
  │
  ▼
[Application Load Balancer]          ← Day 2: L7 ingress (header-based routing)
  Listener rule: X-API-Version: v2 → target group: v2 ECS tasks
  Listener rule: default → target group: v1 ECS tasks
  (Weighted target group for canary release: 10% v2, 90% v1 during rollout)
  │
  ▼
[BFF Lambda / HTTP API Gateway]      ← Day 1: BFF (Backend for Frontend)
  Aggregates: /account + /payment-history into single mobile response
  Translates: mobile-optimised JSON ↔ internal service contracts
  │
  ├──────────────────────────────────────────────────────┐
  │ internal HTTP                                         │ REST
  ▼                                                       ▼
[Internal ALB]                       ← Day 4: service discovery (stable DNS)
  [Payment Service — ECS]                      [ACL Lambda]   ← Day 1: ACL
                                               REST → SOAP XML translation
                                                       │ SOAP
                                                       ▼
                                             [Core Banking (legacy)]
  │
  │ Payment event: {type: payment.created, amount: ...}
  ▼
[SNS topic]
  │ fan-out
  ├── [SQS audit-queue] → [Audit Lambda]       ← Day 4: SQS async decoupling
  │     [SQS audit-dlq] (maxReceiveCount=3)    ← Day 4: DLQ
  ├── [SQS fraud-queue] → [Fraud Lambda]
  │     [SQS fraud-dlq]
  └── [SQS compliance-queue] → [Compliance Lambda]
        [SQS compliance-dlq]
  │
  │ PCI egress (no internet path)
  ▼
[VPC Endpoints]
  SQS Interface Endpoint                       ← Day 3: Interface Endpoint
  Secrets Manager Interface Endpoint           ← Day 3: Interface Endpoint
  S3 Gateway Endpoint                          ← Day 3: Gateway Endpoint
  │
  │ expose to partner bank (different account, overlapping CIDRs)
  ▼
[NLB + VPC Endpoint Service]
[Partner creates Interface Endpoint in their VPC]   ← Day 3: PrivateLink
  No internet. No CIDR coordination needed.

[Internal DNS]
  payment.internal.mybank.com → Internal ALB private IP   ← Day 3: split-horizon DNS
  Not published in external DNS → no accidental public routing

[External Payment Provider]
  │
  │ POST /webhook (HMAC-SHA256 signed)
  ▼
[API Gateway HTTP API]               ← Day 5: inbound webhook receiver
  POST /webhook → Validator Lambda
  │
  ▼
[Validator Lambda]
  HMAC-SHA256 verify ← Secrets Manager secret    ← Day 5: signature validation
  DynamoDB conditional PutItem                   ← Day 5: idempotency key
  (attribute_not_exists — atomic duplicate check)
  If new → SQS SendMessage
  Return 200 immediately (before SQS, before processing)
  │
  ▼
[SQS webhook-queue]
  [SQS webhook-dlq] (alert on DLQ depth > 0)
  │
  ▼
[Consumer Lambda]
  Updates DynamoDB status → "completed"
  Publishes settlement event to internal SQS fan-out
```

### Pattern-to-day cross-reference

| Pattern | Day | Purpose in this architecture |
|---|---|---|
| BFF | Day 1 | Aggregate account + payment into mobile-optimised response |
| ACL | Day 1 | SOAP→REST translation for core banking |
| CloudFront + ALB | Day 2 | CDN, WAF, L7 routing, canary release |
| Header-based routing | Day 2 | API version routing during mobile app rollout |
| Interface Endpoints | Day 3 | PCI egress for SQS and Secrets Manager without internet |
| Gateway Endpoint | Day 3 | S3 audit log writes without internet or NAT |
| PrivateLink | Day 3 | Cross-account private connectivity to partner bank |
| Split-horizon DNS | Day 3 | Internal-only resolution for service names |
| Internal ALB (service discovery) | Day 4 | Stable DNS for ECS service-to-service calls |
| Circuit breaker | Day 4 | Prevent core banking latency cascading to BFF |
| SQS fan-out + DLQ | Day 4 | Async payment event distribution with failure protection |
| Inbound webhook receiver | Day 5 | Accept provider settlement events reliably |
| HMAC signature validation | Day 5 | Authenticate provider requests |
| DynamoDB idempotency key | Day 5 | Exactly-once processing of provider events |
