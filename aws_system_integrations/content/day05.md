# Day 5 — External Integration + Synthesis

## Why this matters

Payment providers (Stripe, Adyen, local payment rails) push events to your system via webhooks. A duplicate webhook means a double-processed payment. A dropped webhook means a missed settlement.

This is not a theoretical risk. Stripe's documentation explicitly warns that webhooks are delivered at-least-once. Every payment provider retries on timeout. Without idempotency controls, any transient slowness in your processing path — a slow database query, a Lambda cold start — will cause the provider to retry, and you will process the same event twice.

External integration patterns are the last frontier before your system can be called production-grade. Internal patterns (Days 1–4) govern what happens inside your system. External patterns govern what happens at the boundary between your system and systems outside your control.

## The boundary this manages

The **external boundary**: how your system communicates with third-party systems, external partners, and services outside your organisation's direct control.

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Your system                               │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Internal patterns (Days 1–4): BFF, ingress, egress, S2S      │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ← External boundary decisions: inbound webhook, outbound push,     │
│    idempotency, signature validation, cross-account connectivity    │
└───────────┬────────────────────────────────────────────┬────────────┘
            │                                            │
    External provider                            Partner / other
    (Stripe, Adyen, …)                           AWS account
    pushes webhooks in                           consumes via PrivateLink
```

Decisions made at this boundary determine whether a provider retry causes a double charge, whether an attacker can forge webhook payloads, and whether partners can reach your services privately.

---

## Core patterns

### 1. Inbound Webhook Receiver

**Problem:** External providers push events at unpredictable rates. Your system must accept, validate, and process them reliably. If processing is slow, the provider times out, marks the delivery as failed, and retries — causing duplicate processing.

**How it works:** Decouple acceptance from processing. The receiver Lambda's only job is to validate the request and enqueue it. Processing happens asynchronously by a separate consumer.

```
External provider
       │
       │ POST /webhook  (HMAC-signed payload)
       ▼
   API Gateway  ──────────────────────────────────────────────────────┐
   (public endpoint)                                                   │
       │                                                               │
       ▼                                                               │
  Validator Lambda                                                     │
  1. Verify HMAC signature   ←── Secrets Manager (signing secret)     │
  2. Check idempotency store ←── DynamoDB (event_id lookup)           │
  3. If new → PutItem (processing) + send to SQS                      │
  4. Return 200 immediately                                            │
       │                                                               │
       ▼                                                               │
   SQS webhook-queue                                                   │
   (+ DLQ on failure)                                                  │
       │                                                               │
       ▼                                                               │
  Consumer Lambda                                                      │
  (event source mapping)                                               │
  1. Process event                                                     │
  2. Update DynamoDB status → "completed"                              │
  3. Message deleted from SQS on success                              └─┘
```

**Why enqueue immediately:** Lambda has a 15-minute maximum execution time, but more critically the provider timeout is typically 30 seconds. If processing involves a slow database write, a fraud check, or a downstream API call, you will breach that timeout. Acknowledging with 200 immediately and processing async means the provider never retries due to your processing latency.

**Why SQS:** It decouples acceptance rate from processing rate. If the provider sends 1,000 webhooks in a burst, SQS absorbs the burst while the consumer processes at a sustainable rate. SQS also adds DLQ protection: if the consumer crashes, the message is retried up to `maxReceiveCount` times before landing in the DLQ.

**Validation must happen before enqueue** to avoid queue poisoning — accepting and storing an attacker's forged payload wastes processing resources and may trigger downstream side effects.

**AWS implementation:**
- API Gateway HTTP API (low-latency, cheaper than REST API for simple proxy)
- Lambda for validation (Python `hmac.compare_digest` — see SOLUTION.md for why `==` is wrong)
- DynamoDB `idempotency_store` (partition key: `event_id`, TTL attribute: `expires_at`)
- SQS standard queue (webhook-queue) + DLQ
- Lambda consumer with SQS event source mapping

**When it's wrong:** If events must be processed in strict order (payment → refund → chargeback for the same payment), use SQS FIFO with a message group ID equal to the payment ID. Standard SQS does not guarantee order.

---

### 2. Idempotency Key

**Problem:** External providers retry webhooks on timeout. If your Lambda took 28 seconds to process a payment and the provider's timeout is 30 seconds, the provider will retry. Your Lambda will receive the same event again and may charge the customer twice.

**How it works:** Extract the unique event ID from the payload (Stripe uses `id`, e.g. `evt_1234abc`). Before processing, write a "processing" record to DynamoDB with a conditional expression that only succeeds if the key does not already exist. If the write fails (key already exists), the event is a duplicate — return 200 and stop. If the write succeeds, process the event and update the record to "completed".

```
Validator Lambda receives event:
  event_id = payload["id"]   # e.g. "evt_1234abc"

DynamoDB conditional write:
  PutItem(
    Item    = {event_id: "evt_1234abc", status: "processing", expires_at: now+86400},
    Condition = attribute_not_exists(event_id)
  )

  SUCCESS → item did not exist → proceed to enqueue
  ConditionalCheckFailedException → item already exists → return 200 (no-op)
```

**AWS implementation:**
- DynamoDB `PutItem` with `ConditionExpression = "attribute_not_exists(event_id)"`
- `ConditionalCheckFailedException` is caught and treated as success (return 200 to provider)
- TTL attribute `expires_at` set to `int(time.time()) + 86400` (24h) — prevents unbounded table growth
- Consumer Lambda updates status to "completed" after successful processing

**When it's wrong:** If two instances of your Lambda receive the same event ID at the exact same millisecond (race condition at creation), the DynamoDB conditional write is atomic — exactly one will succeed. This is safe. However, the idempotency check only covers the window between enqueue and Consumer Lambda completion. If the Consumer Lambda crashes after processing but before updating DynamoDB, the event will be re-enqueued by SQS (at-least-once delivery from SQS). Design the Consumer Lambda to also be idempotent.

---

### 3. Webhook Signature Validation

**Problem:** Your webhook endpoint is a public URL. Anyone who finds it can POST arbitrary payloads to it. Without validation, an attacker can send fake payment confirmations, trigger processing of fraudulent events, or flood your queue with garbage.

**How it works:** The provider signs each request's body using HMAC-SHA256 with a shared secret. Your receiver recomputes the HMAC of the raw request body using the same secret and compares it to the signature in the request headers. If they don't match, reject with 403.

```
Provider side:
  signature = HMAC-SHA256(raw_body, shared_secret)
  Header: X-Webhook-Signature: sha256=<hex_digest>

Receiver side:
  expected = HMAC-SHA256(raw_body, shared_secret_from_secrets_manager)
  received = header["X-Webhook-Signature"].removeprefix("sha256=")
  if not hmac.compare_digest(expected, received):
      return 403
```

**Why `hmac.compare_digest` and not `==`:** String equality (`==`) short-circuits on the first mismatched character. An attacker can measure response times to deduce the correct signature one byte at a time (timing attack). `compare_digest` takes constant time regardless of where the mismatch occurs.

**AWS implementation:**
- Secrets Manager secret stores the shared signing secret (never in Lambda environment variables — env vars are visible in the Lambda console and CloudWatch Logs)
- Lambda reads the secret at startup and caches it for the function lifetime
- Raw body must be the un-parsed bytes — never the JSON-parsed dict (JSON serialization is not canonical)
- API Gateway must be configured to pass raw body to Lambda (HTTP API proxy integration does this by default)

**When it's wrong:** If the provider rotates the signing secret, your Lambda must be able to accept both the old and new secrets during the transition window. Implement a "dual validation" period: read both secrets from Secrets Manager and accept if either matches.

---

### 4. Outbound Webhook / Event Push

**Problem:** Your system must notify external consumers (partner systems, third-party analytics, client-controlled endpoints) when events occur. The consumer cannot poll your system — they need near-real-time notification.

**How it works:** When an internal event occurs, publish it to an intermediate layer that handles delivery to external endpoints with retry logic and dead-lettering.

```
Internal event
       │
       ▼
  EventBridge (internal bus)
       │
       ▼
  EventBridge API Destination
  (managed HTTP endpoint with retry + rate limiting)
       │ POST (signed)
       ▼
  External consumer endpoint
```

**AWS implementation:**
- **EventBridge API Destinations** (preferred for managed outbound HTTP): define an `aws_cloudwatch_event_api_destination` with the consumer URL; EventBridge handles retries with exponential backoff, rate limiting, and a dead-letter queue; no Lambda needed.
- **Lambda + SQS** (for custom retry logic or payload transformation): SQS triggers Lambda; Lambda POSTs to the consumer endpoint; on failure, message returns to queue for retry.
- Always include a request signature in outbound requests so consumers can validate authenticity.
- Delivery guarantee: at-least-once. Consumers must be idempotent.

**When it's wrong:** EventBridge API Destinations cap at 300 invocations per second per destination. For high-throughput push (>300 rps), use SNS → SQS → Lambda fan-out instead.

---

### 5. Polling vs Push Decision Tree

**Problem:** When should your system push events to consumers, and when should consumers poll your system?

**Push (your system delivers):**
- Provider controls delivery timing
- Lower latency (event delivered within seconds)
- Suits high-frequency events (>1 per minute)
- Consumer must be available and idempotent
- Example: payment status updates, real-time alerts

**Polling (consumer fetches):**
- Consumer controls fetch timing and rate
- Higher latency acceptable (minutes to hours)
- Suits infrequent or batch events (<1 per minute)
- Simpler consumer implementation
- Example: daily settlement file, nightly report

**Decision rule:**

```
Required latency < 1 minute
AND event frequency > 1/minute
    → Push

Otherwise
    → Polling acceptable
```

If the consumer is in a different AWS account and cannot accept inbound connections → push via EventBridge cross-account event bus or S3 bucket notification with cross-account access.

---

### 6. Cross-Account Access Patterns

**Problem:** Your payment service runs in Account A (PCI-scoped). A partner bank runs in Account B. A data team runs in Account C. Each needs different access — some need private connectivity, some need API access, some need shared resources.

**Patterns and when to use each:**

| Pattern | Use when | Mechanism |
|---|---|---|
| Resource-based policy | Same org, simple read/share | Add `Principal: {"AWS": "arn:aws:iam::ACCOUNT_B::root"}` to S3 bucket policy or SQS policy |
| PrivateLink | Private connectivity, different account, no internet | NLB + VPC Endpoint Service in Account A; Interface Endpoint in Account B |
| RAM (Resource Access Manager) | Share subnets, Transit GW, Resolver rules within org | `aws_ram_resource_share` pointing at the resource ARN |
| Assume Role | Cross-account API calls, federated access | Account B creates role with trust policy allowing Account A; Account A assumes the role |
| Cross-account EventBridge | Cross-account event delivery | Account A EventBridge rule targets Account B event bus; Account B bus policy allows the source |

**Decision tree:**

```
Need private (no-internet) connectivity?
  YES → PrivateLink
  NO  → Need to share a VPC subnet or Transit GW?
          YES → RAM
          NO  → Need to call an API in the other account?
                  YES → Assume Role
                  NO  → Need to share access to an S3/SQS/SNS resource?
                          YES → Resource-based policy
                          NO  → Cross-account EventBridge for event delivery
```

---

## Decision tree

```
Receiving an event from an external provider?
  │
  ├── YES → Is the event signed?
  │           YES → Validate HMAC before enqueue
  │           NO  → Reject or log only (do not process unsigned events in production)
  │         Is the event potentially duplicated?
  │           YES → DynamoDB idempotency key (always yes for webhook delivery)
  │         How long does processing take?
  │           > 5 seconds → Enqueue immediately, process async (SQS + consumer Lambda)
  │           < 5 seconds → Can process inline, but enqueue anyway for resilience
  │
  └── NO → Sending an event to an external consumer?
             │
             ├── Managed retry + rate limiting sufficient?
             │     YES → EventBridge API Destination
             │     NO  → Lambda + SQS (custom retry)
             │
             └── Consumer is in another AWS account?
                   Needs private connectivity? → PrivateLink
                   Needs cross-account event bus? → EventBridge cross-account
                   Needs resource access? → Resource-based policy or Assume Role
```

---

## Synthesis: The complete integration stack

This section shows how all five days' patterns combine in a single production-grade scenario.

**Scenario:** A mobile banking application serving 500,000 users. Backend includes a payment service that must be PCI-scoped, a core banking legacy SOAP system, and an external payment provider that pushes settlement webhooks.

### Architecture walkthrough

```
Mobile app (iOS/Android)
       │
       │ HTTPS
       ▼
  CloudFront (CDN + WAF)                              ← Day 2: L7 ingress, WAF
       │
       │ origin request
       ▼
  Application Load Balancer                           ← Day 2: L7 ingress, header-based routing
  (listener rules: /api/* → BFF target group)
       │
       ▼
  BFF Lambda / ECS (HTTP API Gateway)                 ← Day 1: BFF pattern
  - Aggregates: GET /account + GET /payment-history
  - Translates: mobile API request → internal service calls
       │                    │
       │ internal HTTP       │ SOAP (XML)
       ▼                    ▼
  Internal ALB            ACL Lambda                 ← Day 1: ACL pattern (SOAP→REST)
  (service discovery)     (translates REST→SOAP)     ← Day 4: Internal ALB (service discovery)
       │                    │
       ▼                    ▼
  Payment Service         Core Banking (SOAP)
  (ECS, PCI VPC)          (legacy, on-prem or EC2)
       │
       │ async events (payment created, payment settled)
       ▼
  SQS fan-out queues                                  ← Day 4: async decoupling
  ├── audit-queue → Audit Lambda
  ├── fraud-queue → Fraud Lambda
  └── compliance-queue → Compliance Lambda
  (Each queue has a DLQ)                              ← Day 4: DLQ pattern
       │
       │ PCI egress
       ▼
  Interface Endpoints (SQS, Secrets Manager)          ← Day 3: Interface Endpoint
  Gateway Endpoint (S3 for audit logs)                ← Day 3: Gateway Endpoint
       │
       │ expose payment service to partner bank
       ▼
  NLB + VPC Endpoint Service                          ← Day 3: PrivateLink
  (partner bank connects via Interface Endpoint
   in their own account — no internet, no VPC peering)

External payment provider
       │
       │ POST /webhook (HMAC-signed)
       ▼
  API Gateway (public endpoint)                       ← Day 5: Inbound webhook receiver
  POST /webhook
       │
       ▼
  Validator Lambda
  - HMAC-SHA256 verify ←── Secrets Manager            ← Day 5: Signature validation
  - DynamoDB idempotency check                        ← Day 5: Idempotency key
  - Enqueue to SQS webhook-queue
  - Return 200 immediately
       │
       ▼
  Consumer Lambda (SQS event source mapping)
  - Updates payment record in DynamoDB
  - Publishes settlement event to internal SQS fan-out
```

### Cross-cutting concerns applied across all layers

| Concern | Pattern applied | Day |
|---|---|---|
| Mobile → backend ingress | CloudFront + ALB with WAF | Day 2 |
| Legacy SOAP integration | ACL (Anti-Corruption Layer) | Day 1 |
| Service-to-service calls | Internal ALB (service discovery), circuit breaker + timeout budget on SOAP | Day 4 |
| Async audit + compliance | SQS fan-out + DLQ on every queue | Day 4 |
| PCI egress | Interface Endpoints (no NAT Gateway for sensitive services) | Day 3 |
| Partner bank connectivity | PrivateLink (private, no internet, no CIDR conflicts) | Day 3 |
| Internal service resolution | Split-horizon DNS (internal ALB DNS resolves privately inside VPC) | Day 3 |
| Provider webhook ingress | API GW → Validator Lambda → SQS → Consumer | Day 5 |
| Duplicate webhook prevention | DynamoDB conditional write (idempotency key) | Day 5 |
| Webhook authenticity | HMAC-SHA256 validation, secret in Secrets Manager | Day 5 |

---

## Exercises

### Exercise 1 — Double charge via webhook retry

Stripe sends your webhook endpoint a `payment_intent.succeeded` event. Your Lambda processes it and charges the customer. Stripe times out waiting for your 200 response (your Lambda took 35 seconds due to a slow downstream call) and retries. You charge the customer twice.

Walk through the complete idempotency fix. What DynamoDB write do you make? What do you do if the write fails? What TTL do you set and why?

**Hint:** You need to detect the duplicate before you act, not after. The detection must be atomic — a read followed by a write is not safe under concurrent retries.

**Solution sketch:**

1. Extract `stripe_event_id` from payload: `event_id = payload["id"]` (e.g. `"evt_1a2b3c4d"`).

2. Attempt DynamoDB conditional write:
   ```python
   dynamodb.put_item(
       TableName="webhook_idempotency",
       Item={
           "event_id": {"S": event_id},
           "status":   {"S": "processing"},
           "expires_at": {"N": str(int(time.time()) + 86400)}
       },
       ConditionExpression="attribute_not_exists(event_id)"
   )
   ```

3. If `ConditionalCheckFailedException` is raised → item already exists → this is a duplicate → return 200 immediately without processing. Provider marks delivery as successful. No charge occurs.

4. If write succeeds → item did not exist → this is the first delivery → proceed to process (charge customer).

5. After successful processing, update status:
   ```python
   dynamodb.update_item(
       TableName="webhook_idempotency",
       Key={"event_id": {"S": event_id}},
       UpdateExpression="SET #s = :completed",
       ExpressionAttributeNames={"#s": "status"},
       ExpressionAttributeValues={":completed": {"S": "completed"}}
   )
   ```

6. TTL = `now + 86400` (24 hours). Stripe's retry window is 3 days, but idempotency protection for 24h covers all realistic retry scenarios. Without TTL, the DynamoDB table grows unboundedly — every event ever received stays in the table forever.

**Key insight:** The `attribute_not_exists` condition and the `PutItem` are evaluated atomically by DynamoDB. Even if two Lambda instances receive the same event at the same millisecond, exactly one will succeed the write and exactly one will get `ConditionalCheckFailedException`.

---

### Exercise 2 — Private partner connectivity

You need to expose an internal payment service to a partner bank in a separate AWS account. The partner refuses to route traffic over the internet. VPC peering is ruled out because both accounts use the `10.0.0.0/8` CIDR block (overlapping ranges). What connectivity pattern do you use, and what are the setup steps?

**Hint:** Review Day 3 egress patterns — one was specifically designed for cross-account private connectivity that does not require CIDR coordination and does not expose your VPC topology to the consumer.

**Solution sketch:**

Pattern: **PrivateLink** (VPC Endpoint Service).

Steps:

1. **Your account (provider):** Place the payment service behind a Network Load Balancer. Create a VPC Endpoint Service: `aws_vpc_endpoint_service { network_load_balancer_arns = [nlb_arn], acceptance_required = true }`.

2. **Share:** Provide the partner with your Endpoint Service name (format: `com.amazonaws.vpce.ap-southeast-1.vpce-svc-XXXXXXXXXX`).

3. **Partner account (consumer):** Partner creates an Interface Endpoint in their VPC pointing to your Endpoint Service: `aws_vpc_endpoint { vpc_id = partner_vpc_id, service_name = "com.amazonaws.vpce.ap-southeast-1.vpce-svc-XXXXXXXXXX", vpc_endpoint_type = "Interface" }`.

4. **Approval:** In your account, you approve the connection request (since `acceptance_required = true`). For automated approval, use an `aws_vpc_endpoint_connection_accepter` resource or set `acceptance_required = false` if you trust all requestors.

5. **DNS:** Partner's DNS resolves the endpoint service name to the Interface Endpoint's private IP in their VPC. No entry point into your VPC — traffic flows one-way through AWS's internal network.

**Why not VPC peering:** Overlapping CIDRs block peering. PrivateLink is CIDR-agnostic — it uses private IPs in the consumer's VPC, not your VPC.

**Why not internet + TLS:** Partner refused internet routing. PrivateLink traffic never traverses the public internet.

---

### Exercise 3 — Full architecture design (capstone)

Design (do not build) the complete integration architecture for the following system. Use exact pattern names from Days 1–5 for each decision.

**System:**
- Mobile banking app, 500,000 users
- Payment service that must be PCI-scoped (isolated account or VPC, strict egress)
- Core banking legacy SOAP system (slow, sometimes unavailable, on-prem)
- External payment provider that sends `payment.settled` webhooks at up to 500/minute

Work boundary by boundary: ingress first, then internal, then egress, then external. Name the pattern and the AWS service for each decision point.

**Hint:** Work boundary by boundary: ingress first, then internal, then egress, then external. For each boundary, ask: what failure mode does this pattern prevent?

**Solution sketch:**

**Ingress boundary (Day 2):**
- CloudFront in front of the mobile-facing ALB: CDN caches static assets, WAF blocks OWASP Top 10, provides DDoS mitigation at the edge layer.
- ALB listener rules for API routing: header-based routing sends `X-API-Version: v2` requests to a separate target group during the mobile app upgrade rollout period (weighted target groups for canary release of new payment API).
- mTLS at ALB optional if the mobile app uses certificate pinning — provides mutual authentication without a separate API key system.

**API Gateway pattern (Day 1):**
- BFF (Backend for Frontend) via HTTP API Gateway + Lambda aggregator for the mobile app. Mobile app makes a single call; BFF fans out to `GET /account` (Account Service) and `GET /payment-history` (Payment Service), merges responses, and returns a mobile-optimised payload. Prevents mobile app from knowing the internal service topology.
- ACL (Anti-Corruption Layer) Lambda for the SOAP core banking system. The BFF calls the ACL with a REST request; ACL translates to SOAP XML, calls core banking, parses the response, and returns REST-compatible JSON. Core banking's SOAP contract does not leak into the BFF or mobile API.

**Internal boundary (Day 4):**
- Internal ALB as the stable DNS endpoint for service-to-service calls (service discovery). Payment Service's DNS name does not change when ECS tasks are replaced.
- Circuit breaker on all calls to core banking: core banking is a known-slow downstream. If the circuit opens, the BFF returns cached balance data rather than waiting indefinitely. Timeout budget: set a 3-second timeout on SOAP calls so core banking latency does not exhaust the BFF's connection pool.
- SQS fan-out for async payment events: when a payment is created, Payment Service publishes to an SNS topic; SNS fans out to three SQS queues — audit-queue (compliance archiving), fraud-queue (ML fraud scoring), compliance-queue (regulatory reporting). Each queue has a DLQ with `maxReceiveCount = 3` so transient consumer failures do not lose events.

**Egress boundary (Day 3):**
- Interface Endpoints for SQS and Secrets Manager inside the PCI VPC: payment service never routes to these AWS services over the internet. No NAT Gateway in the PCI VPC — reduces the attack surface by eliminating any outbound internet path.
- Gateway Endpoint for S3: compliance audit logs written to S3 without traversing the internet; no data transfer cost for S3 traffic within the region.
- PrivateLink to expose Payment Service to the partner bank (separate AWS account, overlapping CIDRs): NLB in PCI VPC + VPC Endpoint Service; partner creates an Interface Endpoint in their account; no internet, no CIDR coordination.
- Split-horizon DNS: internal services resolve `payment.internal.mybank.com` to the Internal ALB private IP; external DNS resolves the same name to nothing (not published). Services never accidentally hit a public endpoint.

**External boundary (Day 5):**
- Inbound webhook receiver for the payment provider's `payment.settled` events: API Gateway (public endpoint) → Validator Lambda (HMAC-SHA256 check + DynamoDB idempotency) → SQS webhook-queue → Consumer Lambda. Provider receives 200 immediately after enqueue; processing is async. At 500 webhooks/minute, this is well within Lambda and SQS capacity.
- HMAC-SHA256 validation: provider's signing secret stored in Secrets Manager (not Lambda env var). Validator Lambda reads and caches the secret. Requests with invalid signatures return 403 before touching DynamoDB or SQS.
- DynamoDB idempotency store: `attribute_not_exists(event_id)` conditional write prevents double-processing on provider retries. TTL = 24 hours prevents unbounded table growth.

**Annotated architecture summary:**

```
[Mobile App]
  → CloudFront (WAF, CDN)                          [Day 2: L7 ingress]
  → ALB (listener rules, canary weights)           [Day 2: L7 ingress]
  → BFF Lambda (HTTP API GW)                       [Day 1: BFF]
      ├── Account Service (Internal ALB)           [Day 4: service discovery]
      └── Payment Service (Internal ALB)           [Day 4: service discovery]
              │ (circuit breaker + timeout)        [Day 4: circuit breaker]
              ▼
          ACL Lambda → Core Banking SOAP           [Day 1: ACL]
              │ (SQS fan-out + DLQ)                [Day 4: async decoupling]
              ▼
          audit / fraud / compliance queues
              │ (Interface + Gateway Endpoints)    [Day 3: egress]
              ▼
          S3, Secrets Manager, SQS (no internet)
              │ (PrivateLink)                      [Day 3: cross-account private]
              ▼
          Partner bank Interface Endpoint

[Payment Provider]
  → POST /webhook (signed)
  → API GW → Validator Lambda                      [Day 5: webhook receiver]
      HMAC check (Secrets Manager)                 [Day 5: signature validation]
      DynamoDB idempotency                         [Day 5: idempotency key]
      → SQS → Consumer Lambda
```

---

## Anti-patterns / Common mistakes

**Storing webhook signing secret in Lambda environment variable.** Rotatable secrets belong in Secrets Manager. Lambda env vars are visible to anyone with `lambda:GetFunctionConfiguration` IAM permission, and their values appear in CloudWatch Logs if accidentally logged. A leaked signing secret means any attacker can forge webhook payloads.

**Processing webhook payload synchronously in the receiver Lambda.** If processing takes more than the provider's timeout (typically 30 seconds), the provider marks the delivery as failed and retries. You have now processed the event once plus however many retries occur. Always acknowledge with 200 immediately after validation and enqueue for async processing.

**No TTL on the idempotency store.** DynamoDB charges per GB stored. Without TTL, every event ever received stays in the table permanently. A busy webhook endpoint receiving 1,000 events per day accumulates 365,000 records per year. Set `expires_at = now + 86400` and enable TTL on the `expires_at` attribute.

**Validating HMAC with `==` instead of `hmac.compare_digest`.** String equality short-circuits at the first mismatched byte. An attacker can measure microsecond-level response time differences to brute-force the signature one byte at a time (timing side-channel attack). `compare_digest` always takes the same time regardless of where the mismatch occurs.

**Using VPC peering when CIDR blocks overlap.** VPC peering requires non-overlapping IP ranges. PrivateLink has no such requirement — it uses the consumer's own VPC private IPs to reach the provider's service. Default to PrivateLink for cross-account private connectivity unless you control both CIDR allocations.

**Skipping the DLQ on the webhook queue.** If the Consumer Lambda throws an exception, SQS redelivers the message up to `maxReceiveCount` times. Without a DLQ, after `maxReceiveCount` failed attempts the message is silently deleted. Payment events must never be silently dropped — always attach a DLQ and alert on the DLQ depth metric.

---

## Lab

See `labs/day05/`. The lab provisions a Stripe-style webhook receiver with HMAC-SHA256 signature validation and DynamoDB idempotency.

**Goal:** Send the same event ID three times (simulating a provider retry burst). Confirm that:
1. DynamoDB contains exactly one record for the event ID with status `"completed"`.
2. The Consumer Lambda was invoked exactly once (CloudWatch Logs shows one invocation for that event ID).
3. The second and third requests returned 200 (idempotent acknowledge) without triggering Consumer Lambda.

---

## Teardown

See `labs/day05/teardown.md` for the full teardown checklist.

Estimated monthly cost if left running: API Gateway ~$0.00 (lab volume), DynamoDB ~$0.00 (on-demand at lab volume), SQS ~$0.00 (lab volume), Secrets Manager ~$0.40/month per secret.

**Run `terraform destroy` immediately after completing the lab to avoid the Secrets Manager charge.**
