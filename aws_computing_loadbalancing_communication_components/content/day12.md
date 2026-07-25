# Day 12 — Kinesis + Decision Matrix

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain what a shard is and state its read and write throughput limits
- Describe what `TRIM_HORIZON` and `LATEST` iterator types return, and when to use each
- Explain why Kinesis allows replay but SQS does not
- Describe Kinesis Firehose's role and what it is not
- Apply the SQS vs SNS vs EventBridge vs Kinesis decision matrix to a given requirement

---

## The ordered replayable log mental model

Before touching the console, internalise this distinction:

> **Kinesis is an ordered, replayable log. SQS is a queue that disappears after consumption. The question is not which is better — they solve different problems. Kinesis is for "I need to process this stream and replay it if something goes wrong." SQS is for "I need to distribute work to competing consumers."**

---

## Kinesis Data Streams fundamentals

A Kinesis Data Stream is an ordered sequence of records, distributed across one or more shards.

**Shard** — the unit of capacity. One shard gives you:
- Write: 1 MB/s or 1,000 records/s (whichever is reached first)
- Read: 2 MB/s (shared across all standard consumers on that shard)

To scale write capacity, add shards. To scale read capacity, add shards or enable enhanced fan-out.

**Partition key** — a string you assign to each record when writing. Kinesis hashes the partition key to determine which shard receives the record. Records with the same partition key always land on the same shard. This guarantees ordering within a partition key — all events for a given `orderId` or `userId` arrive in sequence on the same shard. Choose partition keys that distribute evenly across shards: a single partition key for all records creates a hot shard.

**Sequence number** — a unique identifier assigned by Kinesis within a shard. Consumers use sequence numbers to track their position and resume from a specific point after a restart.

**Retention** — 24 hours by default, configurable up to 365 days. Records remain available for replay within the retention window. Once a record ages out of the window, it is permanently gone.

**Replay** — the critical difference from SQS. A consumer can reset its position to any point within the retention window and re-read all records from there. This is impossible with SQS: once a message is deleted or expires, it cannot be recovered. Kinesis replay is the feature that makes it the right choice for event sourcing, backfill processing, and disaster recovery scenarios.

**Enhanced fan-out** — standard Kinesis polling shares the shard's 2 MB/s read throughput across all consumers polling that shard. If three consumers poll one shard, each gets approximately 667 KB/s. Enhanced fan-out gives each registered consumer a dedicated 2 MB/s pipe per shard, independent of all other consumers. Use it when you have more than two consumers reading the same stream and each needs full read speed.

---

## Shard iterator types

A shard iterator is a cursor that tells the Kinesis API where to start reading within a shard. Choosing the wrong type is the most common Day 12 mistake.

| Type | Starts reading from |
|---|---|
| `TRIM_HORIZON` | Oldest record in the stream (within the retention window) |
| `LATEST` | Next record written after the iterator is created |
| `AT_SEQUENCE_NUMBER` | A specific sequence number (inclusive) |
| `AFTER_SEQUENCE_NUMBER` | Immediately after a specific sequence number |
| `AT_TIMESTAMP` | The first record at or after a given timestamp |

**The beginner mistake with `LATEST`:** you start a consumer, create a `LATEST` iterator, and read — but the producer wrote all its records before you created the iterator. `LATEST` means "give me what comes next after now." Records written before the iterator was created are invisible to it. You read 0 records, and it looks like a bug in the producer. The producer is fine.

**When to use each:**
- `TRIM_HORIZON` — first-time consumer setup, backfill, or replay after failure. Start from the oldest available record and process forward.
- `LATEST` — real-time consumers that only care about new data and do not need to catch up on history.
- `AT_SEQUENCE_NUMBER` / `AFTER_SEQUENCE_NUMBER` — resuming from a checkpoint. Your consumer tracks the last successfully processed sequence number and resumes from there on restart.
- `AT_TIMESTAMP` — replay from a known time (e.g. replay the last two hours of events after a bug was introduced at a known timestamp).

**Production pattern:** on startup, use `TRIM_HORIZON` or a stored checkpoint sequence number. Never use `LATEST` as the startup strategy for a consumer that needs durability guarantees — a consumer restart would silently skip all records written while it was down.

---

## Kinesis Firehose — managed delivery

Kinesis Data Firehose (now Amazon Data Firehose) is not a stream you poll. It is a fully managed delivery pipeline that buffers, optionally transforms, and delivers records to a destination without requiring you to write any consumer code.

**Destinations:** S3 (primary), Redshift, OpenSearch Service, Splunk, HTTP endpoint.

**Buffer settings:** Firehose does not deliver records immediately. It accumulates records until either condition is met first:
- The buffer reaches the size threshold (default 5 MB, minimum 1 MB), or
- The buffer timer elapses (default 300 seconds, minimum 60 seconds)

The minimum possible delivery latency is 60 seconds. Firehose is not real-time.

**Transform:** optionally invoke a Lambda function to transform records before delivery — convert JSON to Parquet, filter fields, enrich records. Lambda receives a batch, transforms it, and returns the transformed batch to Firehose for delivery.

**Use case:** high-volume event logging to S3 for analytics — CloudTrail events, application access logs, clickstream data. You write records into Firehose and they arrive in S3 within 60–300 seconds, compressed and partitioned by date.

**What Firehose is not:** it is not a message queue, and it is not real-time. There are no consumers to write and no polling interface. If you need real-time processing alongside durable storage, use Kinesis Data Streams with a Lambda or custom consumer for the real-time path, and a separate Firehose stream (or a Firehose delivery stream attached to the same Kinesis Data Stream) for the S3 delivery path.

---

## The complete decision matrix

The four services are complementary, not interchangeable. Apply this matrix when selecting a messaging service for a new requirement.

| Need | Service | Why |
|---|---|---|
| Distribute work to competing workers | SQS Standard | At-least-once delivery, unlimited throughput, workers scale independently |
| Ordered processing, one entity at a time | SQS FIFO | Exactly-once within a message group, strict per-group ordering |
| Fan-out to multiple consumers at different speeds | SNS + SQS | Each consumer has its own queue and its own consumption rate |
| Content-based routing between services | EventBridge | Route on any field in the event payload without the producer knowing who consumes it |
| High-throughput ordered stream with replay | Kinesis Data Streams | Ordered per partition key, replayable within retention window, scales with shards |
| Managed buffered delivery to S3 or a data warehouse | Kinesis Firehose | No consumer code to write, buffered delivery, optional transformation Lambda |
| AWS service event routing (EC2 state change, S3 put, etc.) | EventBridge default bus | Receives events from 100+ AWS services automatically |

**Tie-breaker questions when the matrix is ambiguous:**

- **Do you need replay?** → Kinesis Data Streams. SQS cannot replay consumed or expired messages.
- **Do you need ordering without FIFO's 300 req/s (unbatched) throughput ceiling?** → Kinesis. Ordering is per partition key; throughput scales by adding shards.
- **Do you need multiple independent consumers at different speeds?** → SNS + SQS. Each consumer has its own queue and processes at its own rate.
- **Do you need to route based on event content without coupling the producer to each consumer?** → EventBridge. Rules match on any field in the event detail.
- **Everything else?** → SQS Standard. Simple, cheap, durable, and scales without configuration.

---

## Best practices

- **Choose partition keys that distribute load evenly across shards.** If all records share one partition key, all writes land on one shard while others are idle — a hot shard. Use a high-cardinality field like `userId` or `orderId`. If ordering is not required, use a random or round-robin key to maximise distribution.
- **Use enhanced fan-out when you have more than two consumers on a stream.** Standard polling shares 2 MB/s per shard across all consumers. Enhanced fan-out provides dedicated per-consumer throughput and eliminates read contention between consumers.
- **Use `TRIM_HORIZON` for consumer startup, then track sequence numbers for subsequent reads.** Starting from `TRIM_HORIZON` ensures no records are missed. After the first successful batch, checkpoint the last sequence number so a consumer restart resumes from where it left off, not from the beginning of the stream.
- **Set retention to at least your maximum acceptable replay window plus a buffer.** If you can tolerate up to 48 hours of consumer failure before data is irretrievably lost, set retention to 72 hours — not exactly 48. The buffer accounts for slow failure detection and incident response time.

---

## Common pitfalls

- **`LATEST` iterator with no new records reads nothing.** The producer wrote records before the iterator was created. `LATEST` only sees new records. Symptom: consumer runs, reads 0 records, appears stuck. Fix: use `TRIM_HORIZON` for initial setup, or use a checkpointed sequence number.
- **Hot shard from a non-distributed partition key.** Every record written with the same key goes to the same shard. That shard hits its 1 MB/s write limit and returns `ProvisionedThroughputExceededException`; other shards receive no traffic. Fix: use a high-cardinality partition key or a random suffix.
- **Treating Firehose as real-time.** Firehose has a minimum 60-second buffering window. Applications expecting near-real-time delivery (under 5 seconds) will observe significant lag and potentially misdiagnose the delivery pipeline as broken. Use Kinesis Data Streams + Lambda for real-time work; Firehose for near-real-time archival.
- **Multiple consumers on a shard without enhanced fan-out.** Standard polling shares the shard's 2 MB/s read limit. Three consumers on one shard each get 667 KB/s maximum. A slow consumer polling frequently starves faster consumers. Enable enhanced fan-out to decouple consumer read rates.

---

## Exercises

Answer before starting the lab:

1. Your Kinesis consumer reads 0 records on startup. The producer has been writing for 10 minutes. You are using a `LATEST` shard iterator. What is wrong and how do you fix it?
2. You have 1 shard and 3 consumers, each of which needs 2 MB/s of read throughput from that shard. What do you enable, and what is required to register each consumer?
3. You need to store clickstream events with a 72-hour replay window for debugging, process them in real time, and load them to S3 for analytics. Design the architecture in one sentence.

## Lab reference

Follow Day 12 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 12 — Kinesis + Decision Matrix
Key concept — replay vs queue: ...
When Firehose vs Data Streams: ...
Break-it — what happened with the wrong iterator type and how I fixed it: ...
```
