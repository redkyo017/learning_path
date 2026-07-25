# Day 8 — SQS

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what a visibility timeout is and why it causes at-least-once delivery
- Distinguish standard and FIFO queues on ordering guarantee, delivery semantics, and throughput
- Configure a Dead Letter Queue with an appropriate `maxReceiveCount`
- Explain why long polling reduces cost compared to short polling
- Describe a batch consumer pattern and quantify the cost reduction
- Choose between standard and FIFO for a given use case

---

## The visibility timeout mental model

Before touching the console, internalise this contract:

> **SQS is a buffer between producers and consumers. The visibility timeout is the contract between SQS and a consumer: "I will hide this message while you process it. If you don't delete it before the timeout expires, I will re-deliver it." Every SQS behaviour — duplicate processing, stuck messages, DLQ — flows from understanding this contract.**

---

## Standard vs FIFO

| | Standard | FIFO |
|---|---|---|
| Ordering | Best-effort (not guaranteed) | Strict (within message group) |
| Delivery | At-least-once (possible duplicates) | Exactly-once (deduplication) |
| Throughput | Unlimited | 3,000 msg/s with batching, 300 without |
| Use cases | Job queues, work distribution, fan-out | Financial transactions, ordered state machines, idempotency required |
| Deduplication | No | Yes (`ContentBasedDeduplication` or `MessageDeduplicationId`, 5-minute window) |

The throughput difference is significant. Standard queues impose no limit and are the right default for high-volume async work. FIFO queues trade throughput for ordering — choose them only when order matters or when idempotency guarantees are a hard requirement.

---

## Visibility timeout in depth

The complete lifecycle of a message:

1. **Producer calls `SendMessage`** — message stored durably in SQS.
2. **Consumer calls `ReceiveMessage`** — SQS returns the message AND starts the visibility timeout clock.
3. **SQS hides the message** from all other consumers for `visibility_timeout` seconds.
4. **Consumer processes and calls `DeleteMessage`** — message permanently removed from the queue.
5. **If the consumer crashes or takes too long:** the visibility timeout expires, the message becomes visible again, and SQS re-delivers it to the same or another consumer.

**The critical formula:** visibility timeout must be greater than maximum processing time. If processing takes 45 seconds and the visibility timeout is 30 seconds, the message will always be re-delivered before the consumer can delete it — duplicates are guaranteed. Rule of thumb: set visibility timeout to `max_processing_time × 1.5`.

**Extending during processing:** if a job runs longer than expected, call `ChangeMessageVisibility` to extend the timeout on that specific message. This is preferable to setting an excessively long static timeout, which delays re-delivery when a consumer genuinely fails.

Default visibility timeout: 30 seconds. Maximum: 12 hours.

---

## Dead Letter Queues (DLQ)

A DLQ is a separate SQS queue that receives messages that cannot be processed successfully. The key configuration parameter is `maxReceiveCount`:

- `maxReceiveCount = 3` means: after 3 separate `ReceiveMessage` calls for the same message without a subsequent `DeleteMessage`, SQS moves the message to the DLQ.
- Each receipt without deletion increments the receive count. A consumer crash, a visibility timeout expiry, or an explicit message return all count as a receive.

The DLQ is a standard SQS queue configured as the redrive target of the source queue. Messages in the DLQ are not automatically retried — they wait for manual investigation or a DLQ redrive (re-processing from the DLQ back to the source queue).

**Always alarm on `ApproximateNumberOfMessagesVisible > 0` on the DLQ.** Any message in the DLQ means a consumer has failed to process it repeatedly. Without this alarm, the failure is completely silent.

---

## Long polling vs short polling

| | Short polling | Long polling |
|---|---|---|
| Behaviour | Returns immediately, even if queue is empty | Waits up to `WaitTimeSeconds` (max 20 s) for a message |
| Empty-response cost | High — every empty response is a charged API call | Low — ~90% fewer empty responses on low-volume queues |
| Configuration | Default (`WaitTimeSeconds = 0`) | Set `WaitTimeSeconds = 20` |

SQS charges per API call. A short-polling consumer on a low-traffic queue makes thousands of empty `ReceiveMessage` calls per hour — every one billed. Long polling reduces this to near-zero by holding the connection open until a message arrives or the wait window expires.

**Almost always use long polling.** The only exception is a consumer that must process messages as fast as possible on a queue that is never empty — in that case long polling adds no benefit.

---

## Consumer patterns

**Polling worker** — the simplest pattern. An ECS task or standalone process loops:

```
ReceiveMessage (WaitTimeSeconds=20)
  → process message
  → DeleteMessage
  → repeat
```

**Batch consumer** — receive and delete up to 10 messages per API call:

```
ReceiveMessage (MaxNumberOfMessages=10)
  → process all 10
  → DeleteMessageBatch (all 10 in one call)
  → repeat
```

Batch reduces API call cost by up to 10× compared to single-message processing. Maximum batch size is 10 messages.

**Lambda event source mapping** — Lambda polls SQS automatically; AWS manages the poller. Lambda scales concurrency with queue depth: more messages waiting means more concurrent Lambda invocations. Lambda processes messages in batches (configurable batch size and batch window). On Lambda processing failure, messages return to the queue and eventually route to the DLQ.

---

## Message retention and other limits

| Parameter | Default | Range |
|---|---|---|
| Message retention | 4 days | 1 minute to 14 days |
| Maximum message size | 256 KB | — |
| Delivery delay | 0 seconds | 0 to 15 minutes |
| Maximum visibility timeout | — | 12 hours |
| Maximum batch size | — | 10 messages |

Messages that exceed the retention period are permanently deleted whether processed or not. Plan retention around your maximum acceptable recovery window.

---

## Best practices

- **Always use long polling** (`WaitTimeSeconds=20`) — reduces empty-receive API costs by ~90% on any queue that is not always saturated.
- **Set visibility timeout to 1.5× your maximum processing time** — shorter causes guaranteed duplicates; longer delays re-delivery when consumers fail.
- **Always configure a DLQ** with `maxReceiveCount=3–5` — without a DLQ, a poison-pill message loops forever, blocking other messages in a FIFO queue and wasting resources in a standard queue.
- **Batch receive and delete** (up to 10 messages) — reduces API call costs and improves consumer throughput.
- **Alarm on DLQ depth > 0** — a non-zero DLQ is a silent production failure without this alarm.

---

## Common pitfalls

- **Visibility timeout shorter than processing time.** The message reappears before the consumer can delete it. Every consumer sees every message. Duplicates are guaranteed and the queue never drains.
- **No DLQ configured.** A malformed message that causes a consumer crash loops forever — receive, crash, timeout, re-deliver, repeat indefinitely.
- **Short polling on a low-traffic queue.** The consumer makes thousands of billed API calls per hour against an empty queue. Long polling eliminates this cost.
- **Not deleting the message after successful processing.** The message becomes visible again after the visibility timeout and is re-delivered. This is functionally identical to a consumer crash.
- **Using a standard queue when order matters.** Standard queues offer best-effort ordering — not a guarantee. Financial transactions or state machine transitions require FIFO.

---

## Exercises

Answer before starting the lab:

1. A consumer takes 40 seconds to process a message. The visibility timeout is 30 seconds. Describe exactly what happens.
2. A message has been received 4 times and never deleted. `maxReceiveCount=3`. Where is the message now, and what moved it there?
3. Your SQS consumer runs on ECS. You want to scale ECS task count based on queue depth. What CloudWatch metric do you use?
4. You need to process financial transactions in the exact order they were submitted. Standard or FIFO? What additional field must every message include to maintain ordering within a group?

## Lab reference

Follow Day 8 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 8 — SQS
Key concept — visibility timeout: ...
When would I choose FIFO over standard: ...
Break-it — what I observed when visibility timeout was shorter than processing time: ...
```
