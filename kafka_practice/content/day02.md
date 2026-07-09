# Day 2 — Producer/Consumer Semantics: Delivery Guarantees, Idempotence, Partitioning

## Learning objectives

By the end of today you should be able to:
- Explain precisely what each `acks` setting (`0`, `1`, `all`) does on the
  wire, and the durability/latency tradeoff of each.
- State exactly what the idempotent producer prevents — and, just as
  importantly, what it does *not* prevent.
- Explain how default partitioning works from a message key, and why that
  gives per-key ordering but not global ordering.
- Explain why "manual commit, after processing" gives at-least-once (not
  exactly-once) delivery, and identify the failure window that causes
  reprocessing.

## Reference material

- Kafka documentation: **Producer Configs** — focus on `acks`,
  `enable.idempotence`, `retries`, `max.in.flight.requests.per.connection`.
- Kafka documentation: **Consumer Configs** — focus on `enable.auto.commit`,
  `auto.offset.reset`, `group.id`.
- **KIP-98: Exactly Once Delivery and Transactional Messaging** — read only
  the abstract and motivation sections. This is the original, clearest
  explanation of why "the producer retried and created a duplicate" was
  treated as a distinct problem from "give me exactly-once end-to-end."

## Theory

### What `acks` actually controls

`acks` is purely producer-side: how many acknowledgments the producer waits
for from the broker before `send()` is considered complete. It says nothing
about what consumers see or when — it's about how much the producer trusts a
write to be durable before moving on.

- **`acks=0`** — fire and forget. The producer writes to the socket and
  considers the send done without waiting for any broker response. Lowest
  latency, but the only setting under which data can be lost silently — if
  the write never reaches the leader, the producer has no way of knowing.
- **`acks=1`** — leader-only. The leader writes to its local log and acks
  immediately, without waiting for followers. Protects against the producer
  not knowing whether the leader got the write, but not against losing that
  write if the leader crashes before any follower replicates it — an
  acknowledged message can vanish in that window.
- **`acks=all`** (`acks=-1`) — the leader waits until the message is
  replicated to every broker currently in the in-sync replica set (ISR)
  before acking. Durability-maximizing: the write survives as long as one
  ISR member survives. The cost is latency (waiting on the slowest ISR
  member), and the guarantee is only as strong as `min.insync.replicas` (see
  Best practices) — an ISR that has shrunk to just the leader makes
  `acks=all` durability-equivalent to `acks=1` while still paying the cost.

Less waiting means lower latency and higher throughput but a larger window
in which an "acknowledged" write can still be lost. None of this is about
duplicates — that's the idempotent producer's job, next.

### What the idempotent producer actually prevents

This is the most commonly misunderstood mechanism in the Kafka client stack.
`enable.idempotence=true` solves one specific problem: **a producer's own
retry logic creating duplicate writes on the broker.**

Failure mode without it: the producer sends a batch, the broker writes it
and acks, but the ack is lost in transit. The producer, never having
received the ack, assumes failure and retries — now the broker has two
copies, because the first write actually succeeded and only the
acknowledgment was lost.

The fix: Kafka assigns the producer a **producer ID (PID)**, and every
message is tagged with a monotonically increasing **sequence number** per
partition. The broker remembers the last sequence number it committed for
each `(PID, partition)` pair; a retried write with a sequence number already
seen is silently dropped, and the original ack is returned. Retries become
safe — replaying a batch never creates a second copy in the log.

What this does **not** do:
- No application-level dedup. If your own code calls `send()` twice for what
  a human would call "the same event" (a business-logic retry, not the
  client's internal retry), those are two distinct sequence numbers as far
  as the broker is concerned.
- Nothing about the consumer side. A consumer that reprocesses a batch after
  a crash (see below) still sees — and, if it has side effects, still acts
  on — the same message twice. The guarantee stops at "no producer-retry
  duplicates in the broker's log"; it does not extend to "your database was
  only touched once."
- Scoped per producer session, per partition — not a general content-based
  dedup mechanism. Kafka has no notion of two messages being "semantically"
  the same unless you build that yourself (e.g. an idempotency key in your
  own storage).

KIP-98 closed this producer-retry gap as a necessary *building block* for
exactly-once, but its own motivation section is explicit that transactions
(atomically tying a multi-partition write to a consumer offset commit) are
what's actually needed for end-to-end exactly-once — idempotence alone is a
narrower, single-producer guarantee.

### How partitioning works, and why it gives per-key ordering

Kafka's ordering guarantee is scoped to a single partition — offsets within
one partition are strictly ordered, and consumers read them in that order.
There is no ordering guarantee *across* partitions.

The default partitioner: if a record has a key, it computes
`hash(key) mod numPartitions` (murmur2 hash conceptually — "stable hash of
the key, mapped into the partition count") and that key always lands on the
same partition. If a record has no key, it's distributed round-robin/sticky
across partitions purely for load balancing, with no ordering guarantee at
all.

Consequence: **same key → same partition → in-order processing for that
key.** This is the only ordering mechanism Kafka offers, which is why
choosing a partition key is really choosing an ordering (and parallelism)
boundary — not a mechanism for global ordering across all keys. It's also
sensitive to partition count: increasing a topic's partitions changes the
hash-mod-N mapping for every existing key, so messages for the same key
produced before vs. after a resize can land on different partitions.

### Why manual commit-after-processing gives at-least-once, not exactly-once

`enable.auto.commit=false` plus `commitSync()` *after* finishing a batch is
the standard at-least-once pattern:

1. Poll a batch (offsets 100–119).
2. Process it (print, write to a DB, call an API — whatever the side effect).
3. `commitSync()` — tells the broker "processed through offset 119."

The guarantee lives in the ordering of 2 and 3: if the consumer crashes
between them, the committed offset is still wherever it was before this
batch (say, 99). On restart it resumes from 100, reprocessing everything it
had already handled. Every message is processed at least once, sometimes
more — a deliberate tradeoff of possible duplicates for never silently
dropping work (committing *before* processing inverts this into at-most-once
and drops work on crash instead).

Getting to *exactly-once* needs more than reordering two calls: either (a)
idempotent application-side effects (reprocessing becomes a no-op, e.g. an
upsert keyed on the message's own ID), or (b) Kafka transactions tying the
offset commit and the downstream write into one atomic unit (what KIP-98's
building blocks enable). Manual commits alone, regardless of placement, only
choose between at-least-once and at-most-once — never exactly-once.

## Best practices

- **Pair `acks=all` with `min.insync.replicas >= 2`** for durability-sensitive
  data. `acks=all` alone only guarantees replication to whatever the current
  ISR happens to be; if the ISR shrinks to the leader, durability quietly
  degrades to `acks=1` while still paying the latency cost.
  `min.insync.replicas` makes the broker reject writes it can't durably
  replicate instead of silently weakening the guarantee.
- **Enable idempotence by default.** It's close to free in throughput terms
  and removes a whole class of broker-side duplicate bugs. Leave it off only
  for a specific, deliberate reason.
- **Design partition keys around actual ordering/query needs, not
  arbitrarily.** The key is your ordering boundary — pick the entity that
  must stay ordered relative to itself (see Real-world use cases), not
  whatever field is merely convenient or unique.
- **Never treat "idempotent producer" as "my whole pipeline is
  exactly-once."** It's a narrow guarantee about the producer-to-broker leg.
  End-to-end exactly-once has to be engineered deliberately (idempotent
  sinks, transactions, or both).

## Common pitfalls

- **Assuming `enable.idempotence` alone gives end-to-end exactly-once.** The
  single most common misreading of this feature — it dedupes producer
  retries at the broker only.
- **Choosing a low-cardinality partition key.** A key like `"region"` with 4
  values on a 12-partition topic sends all traffic to at most 4 partitions,
  leaving 8 idle and concentrating consumer lag. Key cardinality should
  comfortably exceed partition count and be roughly uniform in frequency.
- **Committing offsets before processing completes.** Flips at-least-once
  into at-most-once: a crash after commit but before the side effect
  finishes means the message is marked done and never redelivered. Easy to
  hit accidentally via `enable.auto.commit=true` with a short interval —
  auto-commit fires on a timer, not on completion of your processing.
- **Assuming partitioning gives ordering it doesn't.** Ordering is
  per-partition only; messages with different keys can and will be processed
  out of relative order across partitions — that's normal, not a bug.
- **Resizing partitions on a topic that relies on key-based ordering.**
  Adding partitions changes the hash-mod-N mapping for every key, silently
  breaking the "same key, same partition" invariant downstream consumers may
  depend on.

## Real-world use cases

- **Integration pipeline keyed by entity ID.** For change events on customer
  accounts or orders, the natural partition key is the entity's own ID
  (`customerId`, `orderId`). A consumer that needs "create, then update,
  then delete" in the order they happened needs all of that entity's events
  on one partition — keying by entity ID delivers exactly that, for free.
- **Payment/financial pipeline.** Almost always `acks=all` with
  `min.insync.replicas>=2` and idempotence on, because losing or duplicating
  a financial write has direct monetary/compliance cost. Serious teams go
  further and add application-level idempotency (e.g. a unique transaction
  ID enforced as a DB constraint), because producer-level idempotence never
  covers the consumer's write to the ledger.
- **Metrics/logging pipeline.** Often deliberately `acks=1` (sometimes even
  `acks=0` for very high-volume, loss-tolerant telemetry) — a dropped metric
  sample costs nothing, and the throughput/latency win from a weaker
  guarantee is worth more than the guarantee itself.

## Worked example

Setup: producer with `acks=all` and `enable.idempotence=true` sends 3
messages, all keyed `order-7`, to a 3-broker cluster with
`min.insync.replicas=2`. The broker holding the leader replica restarts
partway through.

1. **Send 1** — `hash("order-7") mod numPartitions` picks partition 2;
   sequence number 0 for `(PID, partition 2)`. Leader writes, ISR (leader +
   at least one follower) replicates, ack returned.
2. **Send 2** — sequence number 1, same partition (guaranteed by the
   hash-based key). Mid-request, the leader broker restarts.
3. **What the producer sees** — the in-flight request times out or comes
   back retriable (e.g. leader-not-available after election). Because
   idempotence is on, the client safely retries with the same sequence
   number 1. Either the original write never landed (the retry is the write
   that actually lands — no duplicate risk, nothing committed before it), or
   it *did* land before the crash and the new leader already has sequence
   number 1 recorded — the retry is recognized as a duplicate and discarded,
   original success returned either way.
4. **Leader election settles** — once a leader is serving the partition
   again, the retry for send 2 completes, slower than send 1 but successful,
   since 2 of 3 brokers were never down together and
   `min.insync.replicas=2` held throughout.
5. **Send 3** — sequence number 2, proceeds normally on a stabilized cluster.
6. **End state** — all 3 messages land in partition 2 in order (0, 1, 2),
   with **no duplicate written to the log** despite the retry — the
   idempotent producer doing its one job. Send 2 took longer wall-clock time;
   nothing was lost, nothing was doubled on the broker.

This says nothing about whether a downstream consumer of partition 2 might
independently crash between processing and committing and reprocess one of
these messages — that's a separate, consumer-side at-least-once concern,
orthogonal to the producer-side duplicate prevention traced above.

## Exercises

1. A teammate says: "We turned on `enable.idempotence=true`, so our pipeline
   is exactly-once end to end." What's wrong, and what scenario breaks it?
2. A topic has 6 partitions; the partition key has only 2 distinct values,
   equally frequent. What do you observe about partition-level throughput?
3. A consumer has `enable.auto.commit=true`, `auto.commit.interval.ms=1000`,
   and a poll batch reliably takes 3 seconds to process. At-least-once or
   at-most-once? Walk through the failure that proves it.
4. `acks=1`, no idempotence. The leader acks a write, then crashes before any
   follower replicates it, and a follower is elected leader. What happened to
   that message, from the consumer's point of view?
5. Two events for the same customer — "profile updated" then "profile
   deleted," 200ms apart — must always be seen by consumers in that order.
   What single design choice guarantees this, and why?
6. A consumer processes and prints 20 records, then crashes before
   `commitSync()` returns. On restart, what happens, and is that consistent
   with at-least-once semantics?

## Answers

1. **Wrong.** Idempotence only prevents the producer's own retries from
   duplicating writes on the broker; it says nothing about the consumer
   side. Breaks the moment the consumer has a repeatable side effect — e.g.
   it writes to a database, crashes before committing its offset, and on
   restart reprocesses the same message and writes to the database again.
2. **Hot partitions.** At most 2 of the 6 partitions ever receive traffic
   (whichever two the key hashes map to); the other 4 sit idle. Throughput
   and consumer parallelism are capped at 2-way regardless of partition or
   consumer count, because a key's partition assignment never changes.
3. **At-most-once — a bug, not a tradeoff.** Auto-commit fires on its timer
   independent of processing state. Since processing takes 3s and the
   interval is 1s, an offset is typically committed before that batch
   finishes processing. A crash after that commit but mid-processing marks
   the batch done on the broker even though the side effects never
   completed, and it's never redelivered.
4. **Lost**, despite a successful ack. `acks=1` only waits for the leader's
   local write, not replication. No follower had the record before the
   crash, so the new leader's log simply doesn't contain it — nothing to
   lose track of, because it was never durably replicated. Any consumer
   reading after the failover never sees that offset.
5. **Key both events by the customer's own ID.** The default partitioner
   sends every message with the same key to the same partition, and a single
   partition is strictly ordered, so "updated" is guaranteed to precede
   "deleted" for any consumer reading that partition. No other setting
   substitutes — ordering in Kafka is only ever guaranteed within a
   partition.
6. **It reprocesses all 20 records** — expected at-least-once behavior.
   Because the commit never returned (so the broker never durably recorded
   the new offset) before the crash, the group's last committed offset is
   still what it was before this batch. Restart resumes from there and
   re-reads the same 20 records — the direct, observable cost of choosing
   at-least-once over at-most-once, not a malfunction.

## Hands-on lab

The Java track's lab classes for today are
`kafka_practice/labs/src/main/java/com/kafkapractice/ProducerDemo.java` and
`kafka_practice/labs/src/main/java/com/kafkapractice/ConsumerDemo.java`, both
loading broker config through the shared
`kafka_practice/labs/src/main/java/com/kafkapractice/KafkaClientConfig.java`
helper introduced today. A Go port may land under
`kafka_practice/labs-go/cmd/producerdemo/` and
`kafka_practice/labs-go/cmd/consumerdemo/` as a parallel track — check whether
those directories exist yet in your checkout, and use whichever track (Java
or Go) you're actually working through; the config/partitioning/commit
concepts above apply identically to both.

For exact run commands, the crash-and-reprocess exercise, and the
`acks=all`-under-broker-restart exercise, see **Day 2** in
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`.

## Journal template

```
## Day 2 — Producer/consumer semantics
Key idea in my own words: ...
What confused me: ...
```
