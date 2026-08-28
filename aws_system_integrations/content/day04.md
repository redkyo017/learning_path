# Day 4 — Service-to-Service Patterns

## Why this matters

An order service calling a payment service calling a fulfillment service is a synchronous chain. If payment is slow, order times out. If fulfillment is down, the payment still ran. Failure propagates backward through the chain and the caller cannot distinguish "downstream slow" from "downstream dead."

This is the most common source of cascading failures in microservice architectures. A single slow database query in the payment service can exhaust the order service's thread pool in minutes, making the order service appear unavailable to clients who never touched payment at all.

Service-to-service patterns break these failure propagation chains without losing data. They define the coupling contract between internal services — how tightly they are bound, what guarantees are made, and what happens when one side fails.

## The boundary this manages

The **internal boundary**: how services inside your system communicate with each other, and the reliability and coupling contract they hold.

```
┌──────────────────────────────────────────────────────────────────┐
│                        Your system                               │
│                                                                  │
│  ┌─────────────┐  sync call   ┌─────────────┐   sync call       │
│  │   Order     │─────────────>│   Payment   │──────────────>    │
│  │   Service   │              │   Service   │  Fulfillment      │
│  └──────┬──────┘              └─────────────┘                   │
│         │ async event                                            │
│         │                    ┌─────────────────────────┐        │
│         └──────────────────> │  SQS audit-queue        │        │
│                              │  (+ DLQ on failure)     │        │
│                              └─────────────────────────┘        │
│                                                                  │
│  ← Internal boundary decisions: sync vs async, circuit breaker, │
│    timeout budget, bulkhead, outbox                              │
└──────────────────────────────────────────────────────────────────┘
```

Decisions made at this boundary determine whether a downstream failure stays local or cascades upstream, whether events are durably delivered or silently lost, and how long a caller waits before giving up.

---

## Core patterns

### 1. Service Discovery

**Problem:** Services hardcode the IP address or hostname of their downstream. When an ECS task is replaced after a deployment, its IP changes. The caller now points at a dead address until someone updates a config file.

**How it works:** Instead of IPs, services register with a naming system and callers resolve a stable DNS name. The naming system tracks which instances are healthy and maps the name to one of them. Two models: client-side discovery (the caller queries the registry and picks an instance) and server-side discovery (a load balancer does the lookup on the caller's behalf).

**AWS implementation:**
- **Cloud Map** (`aws_service_discovery_service`): fully managed service registry; supports DNS and HTTP API discovery; integrates with ECS.
- **ECS Service Connect**: built-in to ECS; each task sidecar proxies connections and handles discovery; no extra infrastructure.
- **ALB DNS name as stable endpoint**: create an internal ALB once; its DNS name never changes even as targets scale. This is the simplest approach and the one used in this day's lab.

```
Internal ALB DNS:
  my-payment-alb-internal-1234567890.ap-southeast-1.elb.amazonaws.com

Order service env var:
  PAYMENT_ENDPOINT=http://my-payment-alb-internal-1234567890...
```

**When it's wrong:** Using an ALB for very-low-latency (sub-millisecond) gRPC calls where the extra hop matters — prefer Service Connect or direct mTLS mesh in those cases.

---

### 2. Internal Load Balancing Strategies

**Problem:** You have three payment service instances. The caller needs to distribute load across all three without knowing their IPs, and without overloading an instance that is already saturated.

**How it works:** An internal load balancer (ALB set to `scheme = "internal"`) receives all traffic and distributes it to registered targets. Three distribution algorithms matter for microservice meshes:

- **Round-robin (default):** Each request goes to the next instance in rotation. Fair for homogeneous request sizes, but can overload a slow instance since it keeps receiving new requests while processing old ones.
- **Least outstanding requests (LOR):** Each request goes to the instance with the fewest in-flight requests. Better for variable response times (e.g., payment service where 90% of calls take 200ms but 10% take 5s).
- **Weighted:** Assign explicit weights per target. Used for staged rollouts — send 10% of traffic to a new version while 90% goes to the old one.

**AWS implementation:**
```hcl
resource "aws_lb_target_group" "payment" {
  name             = "payment-tg"
  target_type      = "lambda"  # or "ip" for ECS
  load_balancing_algorithm_type = "least_outstanding_requests"
}
```

**When it's wrong:** LOR with Lambda targets — Lambda auto-scales per request, so "outstanding requests" is less meaningful than for long-lived ECS tasks. Use round-robin for Lambda targets.

---

### 3. Circuit Breaker

**Problem:** Payment service starts responding in 8–15 seconds instead of 200ms. Order service callers set a 5-second timeout. Every order request now waits 5 full seconds before failing. The order service's thread pool (or Lambda concurrency limit) fills with threads waiting for payment. The order service is now unavailable to all callers, even requests that don't touch payment at all.

**How it works:** Track the failure rate per downstream. When the rate crosses a threshold, **trip** the circuit (open it): stop calling the downstream entirely and return a fallback response immediately. After a configured timeout, allow a single **probe** request (half-open state). If the probe succeeds, close the circuit. If it fails, reopen it.

```
States:
  CLOSED  →  normal operation; call downstream
  OPEN    →  tripped; return fallback immediately; no call made
  HALF-OPEN → probe; one request allowed through

Transition rules:
  CLOSED → OPEN:      failure rate > threshold (e.g., 50%) over window
  OPEN → HALF-OPEN:   after timeout (e.g., 30 seconds)
  HALF-OPEN → CLOSED: probe succeeds
  HALF-OPEN → OPEN:   probe fails
```

**AWS implementation:** There is no native AWS circuit breaker. Implement in application code:

```python
# Python example — resilience4py or manual state in DynamoDB/ElastiCache
class CircuitBreaker:
    def call_payment(self, payload):
        if self.state == "OPEN":
            if time.time() - self.tripped_at < 30:
                return {"status": "queued"}  # fallback
            self.state = "HALF_OPEN"
        try:
            response = requests.post(PAYMENT_URL, json=payload, timeout=2)
            self.record_success()
            return response.json()
        except Exception:
            self.record_failure()
            raise
```

Alternatively: **App Mesh + Envoy** provides outlier detection (passive circuit breaking based on consecutive 5xx responses), retry policies, and timeouts as mesh configuration rather than application code.

**When it's wrong:** Treating ALB health checks as a circuit breaker. ALB routes away from *unhealthy* targets (failing health checks), not from *slow* ones. A payment Lambda that responds in 15 seconds is still healthy by the ALB's definition. The circuit breaker lives in the caller.

---

### 4. Timeout + Retry Budget

**Problem:** Each service in a call chain sets its own timeout independently. Order service sets 10s. Payment service sets 10s to call fulfillment. Total possible wait: 20s — the order service's timeout fires while payment is still processing fulfillment, leaving the payment committed but the order unaware.

**How it works:** Use a **total budget** passed as a deadline through the chain, not a per-hop timeout set independently:

1. Order service starts a request with a 3-second total budget.
2. It calls payment service with `X-Deadline: <absolute_timestamp>`.
3. Payment service reads the deadline. If less than 100ms remains, it returns 503 immediately without calling fulfillment (fast fail).
4. If retrying, apply **exponential backoff with jitter** to avoid synchronized retry storms:

```python
def backoff_with_jitter(attempt, base=0.1, cap=5.0):
    delay = min(cap, base * (2 ** attempt))
    return delay + random.uniform(0, delay)  # full jitter
```

**Retryable vs non-retryable:**
- Retryable: connection error, timeout, 429, 503
- Non-retryable: 400 (malformed request), 402 (payment required), 409 (conflict), 422 (validation error) — retrying these will not change the outcome

**AWS implementation:**
- Lambda: `timeout = 30` (seconds) in resource config; set below the caller's deadline
- ALB: idle timeout (default 60s) — set to 5s for payment-facing target groups if SLA requires fast failures
- SDK retry config: `boto3.client('sqs', config=Config(retries={'max_attempts': 3, 'mode': 'adaptive'}))`

**When it's wrong:** Retrying non-retryable errors. Retrying a 400 (bad request) ten times wastes time and budget. Retrying a payment-already-processed 409 ten times may double-charge if the idempotency key is per-attempt.

---

### 5. Bulkhead

**Problem:** Order service calls both payment service and inventory service. Payment service goes slow. The shared Lambda concurrency pool fills with payment calls. Now inventory calls are throttled too, even though inventory is perfectly healthy. One degraded downstream degrades all downstreams.

**How it works:** Isolate resources (threads, connection pools, concurrency) per downstream. A bulkhead ensures failures in one downstream cannot exhaust resources needed by another. Named after ship hull compartments: if one compartment floods, the others stay dry.

**AWS implementation:** Lambda reserved concurrency per function:

```hcl
resource "aws_lambda_function" "order_payment_caller" {
  # Handles calls to payment service only
  reserved_concurrent_executions = 50  # Hard cap; other functions unaffected
}

resource "aws_lambda_function" "order_inventory_caller" {
  # Handles calls to inventory service only
  reserved_concurrent_executions = 30
}
```

With ECS: separate task definitions with separate CPU/memory limits per downstream integration.

**When it's wrong:** Setting reserved concurrency too low on a critical path — if the payment caller is capped at 10 and you get a traffic spike, the cap causes throttling even when payment is healthy.

---

### 6. Point-to-Point Queue (SQS)

**Problem:** Order service needs to notify fulfillment service that payment is complete. Fulfillment service is sometimes slow or temporarily unavailable. If the call is synchronous and fulfillment is down, the order is stuck even though payment succeeded.

**How it works:** Order service writes a message to an SQS queue. Fulfillment service reads from the queue at its own pace. The producer and consumer are decoupled — producer does not wait for consumer to process the message, and consumer failure does not affect the producer. One message is processed by exactly one consumer.

```
Order Lambda  →  SQS (payment-completed-queue)  →  Fulfillment Lambda
```

**AWS SQS types:**

| Feature | Standard | FIFO |
|---|---|---|
| Ordering | At-least-once, best-effort | Strict per MessageGroupId |
| Deduplication | Consumer must handle | Content-based or explicit DeduplicationId |
| Throughput | Effectively unlimited | 3,000 TPS with batching |
| Use case | High throughput, order irrelevant | Order matters (e.g., account transactions) |

**Decision:** Ordering required? → FIFO. Throughput critical (>3,000 TPS)? → Standard. Most audit and notification workloads: Standard.

**When it's wrong:** Using FIFO queues for high-volume event streams. At 3,000 TPS maximum, a single FIFO queue will bottleneck under heavy load. Standard SQS with consumer-side idempotency handles most ordering requirements adequately.

---

### 7. Pub-Sub (SNS / EventBridge)

**Problem:** Payment completed. Three services need to know: audit log, fraud detection, compliance reporting. If you call each synchronously, failure in fraud detection blocks audit and compliance. If you call three SQS queues directly, you are coupling the payment service to the list of subscribers.

**How it works:** Payment service publishes one event to a broker (topic or event bus). The broker distributes copies to all subscribers simultaneously. Adding a new subscriber does not require changing the publisher.

**SNS vs EventBridge:**

| Feature | SNS | EventBridge |
|---|---|---|
| Message routing | Topic-level; basic attribute filters | Content-based (filter on event `detail` fields) |
| Cross-account | Requires per-subscription IAM | Native, first-class |
| Schema registry | No | Yes — schema enforcement and discovery |
| Replay | No | Yes — archive + replay up to 90 days |
| Targets | SQS, Lambda, HTTP, email | 20+ AWS services, API destinations |

**When EventBridge over SNS:**
- Need to route by event content (e.g., `payment.amount > 10000` → fraud queue only)
- Cross-account fan-out
- Schema enforcement across teams
- Need event replay after consumer outage

**When SNS over EventBridge:**
- High throughput fan-out to SQS (SNS→SQS is very high throughput)
- Simple attribute-based filtering only
- No schema requirements

---

### 8. Outbox Pattern

**Problem:** Payment Lambda writes a DB record and publishes a "payment-completed" SQS message. These are two separate side effects. If the DB write succeeds and then the SQS publish fails (network hiccup, Lambda timeout after DB commit), the payment is recorded but no downstream ever hears about it. The message is silently lost.

**How it works:** Write the event to an `outbox` table in the same database transaction as the main record. A separate relay process reads the outbox table and publishes to the queue. Delete the outbox record only after successful publish.

```
Payment Lambda:
  ┌─ DynamoDB TransactWriteItems ─────────────────────┐
  │  1. Write payment record to payments table         │
  │  2. Write event to payment_outbox table            │
  └───────────────────────────────────────────────────┘
  (atomic — both succeed or both fail)

Relay Lambda (triggered by DynamoDB Streams on payment_outbox):
  1. Read outbox record from stream
  2. Publish to SQS
  3. Delete outbox record
  (If SQS publish fails → relay retries → outbox record remains)
```

**AWS implementation:** Lambda on DynamoDB Streams as the relay. `TransactWriteItems` provides the atomic DB + outbox write. If the relay Lambda times out after publishing but before deleting, it will re-publish — so the SQS consumer must be idempotent (use `MessageDeduplicationId` on FIFO, or check for duplicate processing on Standard).

**When it's wrong:** Building the outbox pattern on RDS + SQS without a reliable stream mechanism — polling the outbox table with a cron Lambda introduces a race condition under high write load and adds latency equal to the polling interval.

---

### 9. Fan-Out to Queues

**Problem:** You need the distribution of pub-sub (one publish reaches N consumers) and the buffering of a queue (each consumer processes at its own rate with its own DLQ). SNS alone pushes to consumers and drops messages if the consumer is unavailable. SQS alone requires the producer to know all queue URLs.

**How it works:** SNS topic → multiple SQS subscriptions. SNS distributes one publish to all subscribed queues simultaneously. Each queue buffers independently. Each consumer reads from its own queue.

```
Payment service
       │
       ▼
 SNS topic: payment-events
       │
  ┌────┴───────────────────────┐
  ▼                            ▼
SQS: audit-queue         SQS: fraud-queue
  │                            │
  ▼                            ▼
DLQ: audit-dlq           DLQ: fraud-dlq
```

**AWS implementation:** `aws_sns_topic_subscription` with `protocol = "sqs"`. Use `filter_policy` on the subscription to route only matching events to each queue (e.g., fraud queue receives only events where `amount > 10000`).

**When it's wrong:** Sending large payloads directly through SNS→SQS. SNS max message size is 256 KB. For larger payloads: write to S3, publish S3 object key to SNS (SNS Extended Client pattern or manual).

---

### 10. Dead-Letter Queue (DLQ)

**Problem:** A fulfillment SQS message contains malformed data that the consumer Lambda cannot parse. The Lambda throws an exception. SQS makes the message visible again after the visibility timeout. The Lambda processes it again, throws again. This continues indefinitely, blocking queue throughput and generating alarm noise.

**How it works:** Configure `maxReceiveCount` on the source queue. After `maxReceiveCount` failed receive attempts, SQS automatically moves the message to the DLQ. The DLQ is a separate SQS queue. Set a CloudWatch alarm on `ApproximateNumberOfMessagesVisible` in the DLQ.

```
Message receive flow:
  SQS receives message → Lambda invoked → Lambda throws exception
  → message becomes visible again after visibility timeout
  → receive count += 1
  → repeat until receive count == maxReceiveCount
  → message moved to DLQ automatically
```

**AWS implementation:**
```hcl
resource "aws_sqs_queue" "audit_dlq" {
  name = "${var.environment}-audit-dlq"
  message_retention_seconds = 1209600  # 14 days
}

resource "aws_sqs_queue" "audit_queue" {
  name = "${var.environment}-audit-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.audit_dlq.arn
    maxReceiveCount     = 3
  })
}
```

**When it's wrong:** Setting `maxReceiveCount = 1`. A single transient network error (Lambda cold start timeout, brief downstream unavailability) sends the message to the DLQ immediately. Set `maxReceiveCount` to at least 3 to absorb transient failures. Set `maxReceiveCount` to 1 only for truly non-retryable messages (duplicate detection already handled elsewhere).

---

## Decision tree

**Sync vs async: choosing the coupling contract**

```
Is an immediate response required by the caller?
  YES → Is the downstream critical to the response?
          YES → Synchronous (+ timeout budget + circuit breaker)
          NO  → Sync call for the critical part; async for non-critical side effects
  NO  → Async (queue or event bus)

If async: does order matter?
  YES → SQS FIFO (if ≤ 3,000 TPS) or partitioned Standard with consumer-side ordering
  NO  → SQS Standard

If async: multiple independent consumers?
  YES → SNS → SQS fan-out (or EventBridge if content routing / cross-account needed)
  NO  → SQS direct

If async + DB write + message must be atomic:
  → Outbox pattern (same-transaction outbox table + relay process)

If sync + slow downstream risk:
  → Circuit breaker + timeout budget + fallback response

If sync + multiple downstreams share resources:
  → Bulkhead (separate concurrency reservations per downstream)
```

---

## Exercises

**Exercise 1:** Your order service calls payment service synchronously. Under normal load, payment responds in 200ms. Under peak load (Black Friday), payment responds in 8–15 seconds. Orders are timing out. Walk through the patterns you apply, in order of priority, and explain what each one does.

**Hint:** There are two separate problems here — unbounded wait time and a downstream becoming a bottleneck. They require different fixes, and one fix should happen before the other.

**Solution sketch:**
1. **Timeout budget first:** Order service sets a hard 2-second timeout on the payment call. Instead of waiting 15 seconds and failing, it returns HTTP 503 after 2 seconds. Callers know immediately that payment is unavailable rather than hanging. This stops the cascading thread-pool exhaustion.
2. **Circuit breaker second:** After the timeout fires N consecutive times (e.g., 5 in 10 seconds), the circuit trips. Order service stops calling payment entirely and returns a fallback response (e.g., `{"status": "payment_queued"}`). Payment service gets breathing room to recover without being hammered by retries.
3. **Async decoupling if SLA allows:** Move the payment call to an SQS queue. Order service writes to the queue and returns HTTP 202 Accepted immediately. Payment service processes at its own rate. This eliminates the synchronous dependency entirely — but only works if the user can tolerate eventual confirmation rather than synchronous confirmation.

---

**Exercise 2:** An audit event must be delivered to three consumers: the audit log service, the fraud detection service, and the compliance reporting service. Each must receive every event independently. Fraud detection goes down for 2 hours. What pattern do you use, and what happens to fraud detection's events during the outage?

**Hint:** Three independent consumers each needing every event, each with independent failure isolation — the key word is "independently."

**Solution sketch:**
- **Pattern:** SNS topic → three SQS subscriptions (fan-out to queues). Each service reads from its own SQS queue. Each queue has its own DLQ.
- **During fraud detection outage:** Events continue to publish to SNS. SNS delivers to all three SQS queues. The fraud detection SQS queue accumulates messages (SQS default retention is 4 days; set to 14 days for audit workloads to cover weekend outages). The audit log and compliance queues process normally — fraud detection's outage has zero effect on them.
- **When fraud detection recovers:** It drains its queue. If any messages aged past retention, they moved to the fraud DLQ — alarm fires, team investigates.
- **Why not three direct Lambda subscriptions?** SNS can push to Lambda directly, but if fraud detection Lambda is throttled or errors, SNS retries for a limited window then drops the message. The SQS buffer is what guarantees the 2-hour backlog survives.

---

**Exercise 3:** Your payment service writes a DB record and sends a `payment-completed` SQS message. In testing you find that 0.1% of the time the DB write succeeds but the SQS publish fails. What pattern fixes this, and what does the implementation look like on DynamoDB?

**Hint:** The problem is two side effects that need to appear atomic — either both happen or neither does — but they operate on separate systems with no native transaction support between them.

**Solution sketch:**
- **Pattern:** Outbox pattern.
- **Implementation:**
  1. Add a `payment_outbox` DynamoDB table (partition key: `payment_id`).
  2. In the payment Lambda, use `DynamoDB.TransactWriteItems` to write both the payment record (to `payments` table) and the outbox record (to `payment_outbox`) in one atomic operation. Either both succeed or both fail — no partial state.
  3. Add a DynamoDB Streams trigger on `payment_outbox` (stream type: `NEW_IMAGE`).
  4. Relay Lambda receives the stream event, publishes to SQS, then deletes the outbox record.
  5. If SQS publish fails: relay Lambda throws, DynamoDB Streams retries the relay. Outbox record remains. Message eventually delivered.
  6. If relay Lambda crashes after publishing but before deleting: the outbox record survives; relay re-runs and re-publishes. SQS consumer must be idempotent — check `payment_id` before processing.
- **What 0.1% failure rate becomes:** Near-zero. The only failure mode is DynamoDB Streams itself being unavailable, which is an extremely rare regional event.

---

## Anti-patterns and common mistakes

**Retry without jitter:** Setting a fixed retry delay (e.g., always wait 1 second). When a downstream recovers at T+60s, every caller retried at exactly the same intervals and now sends their retry simultaneously. The synchronized spike re-overwhelms the recovering service (thundering herd). Fix: `delay = base * 2^attempt + random.uniform(0, base)`.

**SQS FIFO for high-throughput event streams:** FIFO queues have a hard limit of 3,000 TPS with batching. A payment event stream at 5,000 TPS will be throttled. Standard SQS is effectively unlimited. Most ordering requirements can be handled with consumer-side deduplication and idempotency rather than strict queue-level ordering.

**Publishing to SNS/SQS outside a DB transaction:** Without the outbox pattern, the sequence is: (1) write to DB, (2) publish to queue. A network partition or Lambda timeout between steps 1 and 2 silently loses the event. The DB says payment completed; no downstream ever hears about it. The fix is not retrying the publish — the fix is making the write and the publish-intent atomic.

**Treating ALB health checks as a circuit breaker:** ALB deregisters targets that fail health checks. But a payment Lambda that responds correctly to the `/health` endpoint while taking 15 seconds on real requests is healthy by the ALB's definition. ALB health checks detect dead targets; circuit breakers detect slow targets. They are different tools solving different problems.

**Setting `maxReceiveCount = 1` on SQS:** Any transient error — a Lambda cold start exceeding visibility timeout, a momentary DynamoDB throttle, a brief network hiccup — sends the message to the DLQ. Operations teams spend time investigating DLQ messages that were never actually broken, just slow on first attempt. Use 3–5 as a baseline and adjust based on observed failure patterns.

---

## Lab

See `labs/day04/`. Goal: provision an internal ALB routing to a payment Lambda mock, an SQS audit queue with a consumer Lambda and DLQ, and observe circuit-breaker-adjacent behavior by manipulating the payment Lambda's simulated error rate.

**Architecture:**
```
Order Lambda  →  Internal ALB  →  Payment Lambda (mock)
Order Lambda  →  SQS (audit-queue)  →  Consumer Lambda
                                         ↓ (on maxReceiveCount=3)
                                   SQS (audit-dlq)
```

**Success signals:**
- Internal ALB DNS resolves only within the VPC (no public reachability)
- Payment Lambda returns 500 when `payment_error_rate = 100`; ALB passes the 500 through to the caller (ALB returns 502 only when the Lambda response is malformed)
- Consumer Lambda throwing an exception causes messages to move to DLQ after 3 receive attempts
- `aws sqs get-queue-attributes --attribute-name ApproximateNumberOfMessages` on DLQ shows 10 after the break-it exercise

---

## Teardown

See `labs/day04/teardown.md` for step-by-step teardown instructions. Run `terraform destroy` and verify all resources are deleted to avoid ongoing ALB charges (~$0.008/hour).
