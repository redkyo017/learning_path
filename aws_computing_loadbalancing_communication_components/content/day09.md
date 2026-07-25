# Day 9 — SNS + Fan-out

Read this before starting the lab. Budget: 25 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain the push vs pull delivery model difference between SNS and SQS
- Describe the SNS+SQS fan-out pattern and why it decouples consumption rate from publication rate
- Configure a subscription filter policy and state where filtering runs
- Explain why an SQS queue needs a resource-based policy to accept SNS delivery
- Distinguish a FIFO SNS topic from a standard topic on ordering and throughput

---

## The megaphone vs mailbox mental model

Before touching the console, fix this image:

> **SNS is a megaphone — it shouts to all subscribers at once. SQS is a mailbox — it holds messages until someone reads them. The SNS+SQS fan-out pattern combines both: SNS shouts to multiple SQS queues, each with its own consumer processing at its own pace. The megaphone doesn't slow down because one mailbox is full.**

---

## SNS fundamentals

**Topics** are the named channels. A topic has no storage — it delivers in real time or drops the message. There is no built-in replay.

**Subscriptions** connect a topic to an endpoint. Supported protocols: SQS, Lambda, HTTP/HTTPS, email, SMS, mobile push, Kinesis Data Firehose.

**Message delivery** is simultaneous fan-out: SNS delivers a copy to every active subscription at the same time. There is no ordering guarantee across subscriptions.

**Retry behaviour** varies by protocol:
- HTTP/Lambda: SNS retries with exponential backoff on delivery failure (up to 23 times over 23 days depending on retry policy).
- SQS: SNS calls `sqs:SendMessage` on the queue. If the call fails — wrong resource policy, queue deleted, wrong account — the message is **lost immediately**. SNS does not retry SQS delivery failures. This is why a topic-level DLQ matters.

---

## The fan-out pattern

```
Publisher → SNS Topic → SQS Queue A  (billing service, fast consumer)
                      → SQS Queue B  (analytics, slow consumer)
                      → SQS Queue C  (notification service)
```

The publisher sends one message to the SNS topic. SNS delivers a copy to all three queues simultaneously. Each queue has its own consumer, its own scaling configuration, and its own processing speed.

**Why this matters:** if Consumer C is slow, its queue depth grows — but Consumer A and Consumer B are completely unaffected. The queue is the buffer; the megaphone doesn't wait. Without this pattern, the publisher would need to call all three consumers directly: tight coupling, synchronous risk, and a requirement that the publisher knows about every consumer. Adding a fourth consumer requires changing the publisher. With SNS fan-out, adding a consumer means adding a subscription — the publisher changes nothing.

---

## Filter policies

Filter policies are applied **per subscription**, not per publisher. The subscriber declares what it wants; the publisher does not control routing. Filters run at the SNS layer before delivery — a message that matches no subscription's filter is silently dropped.

Filter syntax (applied to message attributes set by the publisher):

- **String match:** `{"event_type": ["order.created", "order.updated"]}` — delivers only if `event_type` is one of these values.
- **Anything-but:** `{"event_type": [{"anything-but": "order.cancelled"}]}` — delivers for all values except `order.cancelled`.
- **Numeric range:** `{"price": [{"numeric": [">", 100]}]}` — delivers if `price` exceeds 100.
- **Prefix:** `{"source": [{"prefix": "com.myapp"}]}` — delivers if `source` starts with `com.myapp`.

**The most common filter mistake:** the publisher sends an attribute named `eventType` (camelCase) but the filter policy declares `event_type` (snake_case). The filter never matches. Messages flow past all filtered subscriptions silently. Always verify attribute names match exactly by publishing a test message and checking delivery before assuming the pipeline works.

---

## SQS resource policy requirement

SQS does not accept messages from external sources by default. When SNS delivers to an SQS queue, it calls `sqs:SendMessage` as the SNS service principal — not as your IAM user or role. The SQS queue must have an explicit resource-based policy granting SNS permission.

Minimal resource policy:

```json
{
  "Effect": "Allow",
  "Principal": {"Service": "sns.amazonaws.com"},
  "Action": "sqs:SendMessage",
  "Resource": "arn:aws:sqs:region:account:queue-name",
  "Condition": {
    "ArnEquals": {
      "aws:SourceArn": "arn:aws:sns:region:account:topic-name"
    }
  }
}
```

**Without this policy, SNS delivery fails immediately and the message is lost.** The `aws:SourceArn` condition restricts delivery to your specific topic — without it, any SNS topic in any account could write to your queue.

This is the most common Day 9 break-it scenario: create the SNS subscription, publish a message, observe zero messages in the SQS queue, then diagnose via the SNS delivery status logs in CloudWatch.

---

## FIFO SNS → FIFO SQS

A FIFO SNS topic delivers to FIFO SQS queues with the same ordering and deduplication guarantees maintained end-to-end:
- Messages are delivered in the order they are published (within a message group).
- Exactly-once delivery using `MessageDeduplicationId` or content-based deduplication.
- Message Group ID is preserved through the topic to all subscriber queues.
- Throughput: 300 msg/s (3,000 with batching) — the FIFO SQS limit applies throughout.

Use FIFO SNS → FIFO SQS when you need ordered, deduplicated fan-out across multiple consumers. A FIFO topic can only deliver to FIFO SQS queues and Lambda — it cannot deliver to email, HTTP, or SMS.

---

## When SNS vs SQS

| Need | Use |
|---|---|
| Fan-out to multiple consumers | SNS (or SNS+SQS) |
| Durability + retry for slow consumers | SQS |
| Push to Lambda, HTTP, email, or SMS | SNS direct subscription |
| Decouple consumer processing speed from publication rate | SNS → SQS |
| Ordering across consumers | FIFO SNS → FIFO SQS |

---

## Best practices

- **Combine SNS → SQS for durable fan-out.** Pure SNS with direct Lambda or HTTP subscriptions has no storage — a Lambda that fails loses the message unless Lambda itself has a DLQ configured. SQS provides the buffer and the retry.
- **Use filter policies** to avoid consumers receiving and ignoring irrelevant messages. Filtering at the SNS layer is cheaper than filtering inside the consumer.
- **Configure a DLQ on the SNS topic** to capture messages where delivery fails completely. Without a topic DLQ, failed deliveries are permanently lost.
- **Always use `aws:SourceArn` in the SQS resource policy** — without the condition, any SNS topic in any account can write to your queue.

---

## Common pitfalls

- **Missing SQS resource policy.** SNS delivery fails immediately. No error appears in the SQS console — the message was never received. Diagnose via SNS delivery status CloudWatch logs (enable delivery status logging on the subscription).
- **No DLQ on the SNS topic.** If SQS delivery fails — wrong policy, queue deleted, wrong region — the message disappears without a trace.
- **Filter policy attribute name mismatch.** Publisher sends `eventType`; filter expects `event_type`. Messages are silently dropped — not bounced, not errored. Always test with a real message.
- **Confusing topic DLQ with subscription DLQ.** The topic-level DLQ captures messages that fail SNS delivery (e.g., the SQS policy rejected the call). A Lambda subscription's DLQ captures messages where Lambda invocation succeeds but the function itself throws an error. These are different failure modes at different layers.

---

## Exercises

Answer before starting the lab:

1. You publish a message to an SNS topic with 3 SQS subscriptions. Two subscriptions have filter `event_type=order.created`. Your message has attribute `event_type=order.shipped`. How many SQS queues receive the message?
2. SNS delivery to your SQS queue is failing. The CloudWatch `NumberOfNotificationsFailed` metric is non-zero. What is the most likely cause, and which tool confirms it?
3. You need to publish an event once and have it processed by a billing service (must process every event) AND a notification service (can miss some events during brief downtime). How do you design the subscriptions differently for each?

## Lab reference

Follow Day 9 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 9 — SNS + Fan-out
Key concept — why SNS → SQS is more durable than SNS → Lambda directly: ...
When would I use SNS without SQS (direct subscription): ...
Break-it — what I observed when the SQS resource policy was missing: ...
```
