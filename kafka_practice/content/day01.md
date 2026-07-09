# Day 1 — Kafka's Mental Model, Cluster Internals, Local KRaft Cluster

## Learning objectives

By the end of today you should be able to:
- Explain what a partition actually is (an append-only, ordered log) and what
  an offset is (a partition-local position in that log), without reaching for
  "it's like a queue" as an analogy.
- State, precisely, what it means for a replica to be "in sync" with a
  partition leader, and name the config (`replica.lag.time.max.ms`) that
  governs it.
- Articulate at least three concrete ways Kafka's delivery model differs from
  a traditional message queue (RabbitMQ, SQS), grounded in mechanism rather
  than vibes.
- Describe what KRaft mode is, what problem it solves, and why it replaced a
  separate ZooKeeper cluster.
- Read a `kafka-topics --describe` output and correctly interpret every
  field: `Leader`, `Replicas`, `Isr`.

## Reference material

- Apache Kafka docs: "Introduction" and "Design" — the canonical source for
  everything below. General location: kafka.apache.org/documentation/ (the
  "Introduction" section covers topics/partitions/producers/consumers at a
  high level; "Design" covers the log, replication, and the internals of how
  the broker persists and serves data).
- The Day 1 implementation plan for this course:
  `kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`
  (has the exact commands; this document is the theory to pair with them).

## Theory

### The log is the primitive, not the message

Almost everything unusual about Kafka falls out of one design choice: a
**partition is an append-only, ordered log file on disk**, and a **topic is
just a named collection of partitions**. There is no per-message routing
logic and no "queue" data structure in the RabbitMQ sense. When a producer
sends a record, a partitioner (by default, a hash of the record key, or
round-robin if there's no key) picks one partition and appends the record to
the end of that partition's log — that's it. The record gets an **offset**:
an integer that is nothing more than "this record's position in this
partition's log," starting at 0 and incrementing by 1 per record. Offsets
have no meaning across partitions or across topics — they're purely local
bookkeeping for one ordered sequence of bytes.

This has an immediate consequence that trips up people coming from queue
systems: **Kafka does not track, per consumer, which messages have been
"delivered."** The broker's job ends at durably appending to the log and
serving reads from it. It's the *consumer's* job to remember the last offset
it processed and ask for records after that offset next time. That
bookkeeping — the **consumer group's committed offset** — is itself just a
record in an internal Kafka topic (`__consumer_offsets`). The broker never
pushes data or tracks per-consumer delivery state; consumers pull, and own
their own position in the log.

### Replication: leader, followers, and what "in sync" really means

A topic's replication factor determines how many copies of each partition's
log exist across the cluster's brokers. For a partition with replication
factor 3, one broker holds the **leader** replica and two others hold
**follower** replicas. All producer writes and (by default) all consumer
reads go through the leader. Followers continuously fetch from the leader —
the same mechanism a consumer uses — appending whatever the leader has
appended, in order, to their own local copy of the log.

The **ISR (in-sync replica set)** is the list of replicas — including the
leader — currently considered "caught up enough." Concretely, a follower is
in sync if it has fetched from the leader recently enough that it hasn't
fallen behind by more than `replica.lag.time.max.ms` (default 30s). This is
a *time-based* definition, not an exact-offset one: a follower briefly one
fetch behind is still in sync; a follower that stops fetching (crash,
network partition, disk stall) for longer than that window gets dropped
from the ISR. Being in the ISR is what makes a replica eligible for leader
election if the leader fails — Kafka won't promote a replica that might be
missing recent data.

This is also the mechanism behind `acks=all`: it means "don't consider this
write successful until every replica *currently in the ISR* has
acknowledged it" — not every replica assigned to the partition, which
matters a lot once a broker is down and the ISR has shrunk.

### Why this is not a message queue

A generic message queue (RabbitMQ, SQS) is built around a different unit:
the individual message, with per-consumer delivery state. A message is
enqueued, a consumer receives and acks it, and the broker deletes or marks
it consumed — it's *gone* from the broker's perspective (modulo redelivery
on nack/timeout). Kafka inverts this:

- **Retention, not delete-on-ack.** A record stays on disk until it ages out
  per the topic's retention policy (time- or size-based), regardless of
  whether anyone consumed it. Consuming does not remove it.
- **Independent consumer groups re-read the same log.** Because the broker
  tracks no per-consumer "delivered" state, any number of independent
  consumer groups can each maintain their own committed-offset position and
  read the same partition from the beginning, in parallel, without
  interfering with each other. A queue has no equivalent — once consumed,
  it's consumed for everyone.
- **Ordering is per-partition, not per-topic.** Records within one partition
  are delivered in the exact order appended; Kafka makes *no* ordering
  guarantee across partitions. A global total order across an entire topic
  needs a single partition (accepting the throughput ceiling that implies)
  or an application-level scheme.
- **Replay is a first-class operation.** Because data persists and offsets
  are just a position a consumer chooses to track, you can deliberately
  reset a consumer group's offset backward (or to a timestamp) and
  reprocess history. A queue has no "rewind."
- **Pull, not push.** Consumers poll for records after their current offset;
  the broker never pushes or blocks waiting for an ack before serving the
  next record to someone else. Backpressure is entirely consumer-driven.

### KRaft: metadata management without ZooKeeper

Historically, a Kafka cluster needed two categories of systems: the brokers
(storing partition data, serving clients) and a separate ZooKeeper ensemble
storing cluster metadata — which brokers exist, which broker is the
controller (responsible for leader elections and propagating metadata
changes), topic configs, ACLs. That meant operating two distributed systems
with different failure modes to run one Kafka cluster.

**KRaft** (Kafka Raft) removes the second system by implementing the
metadata quorum *inside* Kafka, using the Raft consensus protocol. A subset
of nodes run the **controller** role and form a Raft quorum that replicates
the cluster's metadata log (topics, partitions, ISR state, configs) among
themselves the same way a partition leader replicates data to followers —
one controller is elected leader of the metadata log, and a majority of
voters must acknowledge a change before it's committed. Brokers can run
`broker`, `controller`, or both roles (as this lab's 3-node setup does, for
simplicity). The upshot: no separate ZooKeeper process, one less
distributed system to operate, and faster controller failover since
metadata is just another Raft-replicated log, not an external dependency.

## Best practices

- Use replication factor >= 3 for any topic in an environment that matters —
  factor 2 means a single broker failure leaves zero redundancy until it
  recovers.
- Pair replication factor 3 with `min.insync.replicas=2`: the standard
  combination that tolerates one broker down with zero risk of silent data
  loss on acknowledged writes, while still allowing writes to proceed.
- Use an odd number of KRaft controller voters (1, 3, or 5) — decisions
  require a majority, and an even number of voters adds a node without
  adding fault tolerance.
- At production scale, separate controller and broker roles onto dedicated
  nodes rather than combining them everywhere. This lab combines
  `broker,controller` on all three nodes purely to keep a 3-node local
  cluster simple; production clusters typically run dedicated
  controller-only nodes so metadata-quorum load never competes with
  data-plane load.
- Set retention deliberately per topic (`retention.ms` / `retention.bytes`),
  not just the cluster default — it's simultaneously your disk-usage lever
  and your "how far back can consumers replay" lever.

## Common pitfalls

- Assuming ordering holds across an entire topic. It only holds within a
  single partition. If a use case needs strict ordering across all events,
  it needs a single partition or a key that forces order-sensitive events
  into the same partition.
- Assuming a message disappears once a consumer has read it. It doesn't —
  it remains on disk until retention expires. This is precisely what makes
  independent consumer groups re-reading the same data possible, and why
  disk usage is a function of retention and write volume, not consumer
  speed.
- Under-provisioning partition count for a keyed topic and assuming you can
  fix it later by adding partitions. The default partitioner hashes a key
  modulo the *current* partition count, so changing that count changes the
  mapping only going forward — records already written under the old count
  don't get reshuffled. Same key, same logical entity, can end up split
  across "old" and "new" partitions, breaking any "all records for key K
  are in one partition" assumption for pre-resize data.
- Treating the ISR list as static. It shrinks the moment a replica falls
  behind (or its broker goes down) and grows back once it catches up —
  checking it once and assuming it stays that way is a common cause of
  "why did my `acks=all` producer suddenly start throwing
  `NotEnoughReplicasException`" surprises.
- Confusing "replicas" with "ISR." `Replicas` lists every broker *assigned*
  to host a copy, whether or not it's caught up. `Isr` is the (possibly
  smaller) subset actually in sync right now — a broker can appear in
  `Replicas` and be completely offline.

## Real-world use cases

- **Onboarding a new event-producing system.** The partition count chosen at
  topic-creation time is a decision you're mostly stuck with (see the
  pitfall above about re-partitioning keyed data). An integration team must
  think through expected throughput, the natural partitioning key (customer
  ID? order ID?), and downstream consumer parallelism (partition count is
  also the ceiling on how many consumer instances in one group can read in
  parallel) *before* the first producer writes a byte — not after data is
  flowing and repartitioning would silently scramble key locality.
- **Deciding whether a rolling broker restart is safe.** Before bouncing a
  broker for a patch, an operator checks that every partition led by (or
  replicated on) that broker still has enough ISR on other brokers to
  satisfy `min.insync.replicas` once it goes down. If a partition's ISR is
  already degraded, taking down a broker holding one of the few remaining
  in-sync replicas can push writes below `min.insync.replicas` and start
  failing producers — exactly what `kafka-topics --describe` is for before
  touching a shared cluster.
- **Diagnosing "why are we missing events" complaints.** The log-retention
  model gives a concrete, checkable explanation space: is retention shorter
  than the reprocessing window (data legitimately aged out), is the
  consumer group's committed offset stuck or reset, or is someone looking at
  a different consumer group than the one that originally read the data.
  None of these are "the broker lost your message" — there's a deterministic
  paper trail to check instead of a black box.

## Worked example

Suppose you run:

```
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic orders
```

against the 3-broker cluster from today's lab, and see:

```
Topic: orders   TopicId: 4L6g3nShT-eMCtK--X86sw   PartitionCount: 3   ReplicationFactor: 3   Configs: min.insync.replicas=2
        Topic: orders   Partition: 0   Leader: 1   Replicas: 1,2,3   Isr: 1,2,3
        Topic: orders   Partition: 1   Leader: 2   Replicas: 2,3,1   Isr: 2,3,1
        Topic: orders   Partition: 2   Leader: 3   Replicas: 3,1,2   Isr: 3,1,2
```

Reading this line by line: `PartitionCount: 3` / `ReplicationFactor: 3`
confirm 3 independent logs, each with 3 copies. For partition 0,
`Leader: 1` means broker 1 currently serves all produce/consume traffic for
that partition. `Replicas: 1,2,3` means brokers 1, 2, 3 are all *assigned*
to host a copy — regardless of current health. `Isr: 1,2,3` means all three
are currently caught up within `replica.lag.time.max.ms` — this partition
is fully healthy, and losing any single broker would still leave 2 in-sync
replicas, satisfying `min.insync.replicas=2`. Note the leaders are spread
across brokers 1/2/3 rather than concentrated on one — deliberate, so no
single broker bears all the traffic for every partition of a topic.

**Now suppose broker 3 develops a slow disk** and stops keeping up with
fetches for more than 30 seconds. A subsequent `--describe` might show:

```
        Topic: orders   Partition: 2   Leader: 1   Replicas: 3,1,2   Isr: 1,2
```

Two things changed. `Isr` shrank to `1,2` — broker 3 fell out of the
in-sync set (it's still listed in `Replicas`, just not currently trusted as
caught up). `Leader` changed from 3 to 1 — broker 3 was the leader and lost
sync (or went offline), so the controller elected a new leader among the
remaining in-sync replicas. Operationally, this partition now runs with
only 2 of 3 replicas healthy — exactly at the `min.insync.replicas=2` floor.
`acks=all` writes still succeed, but there's zero slack left: if broker 1 or
2 also has a problem before broker 3 recovers, this partition drops below
`min.insync.replicas` and starts rejecting writes. This is the live signal
an operator checks before deciding it's safe to restart another broker.

## Exercises

1. A topic has replication factor 3 and `min.insync.replicas=2`. One broker
   is down. Can producers using `acks=all` still write successfully to
   partitions that had a replica on that broker? What happens if a second
   broker also goes down?
2. You see `Replicas: 1,2,3` and `Isr: 1,2,3` for a partition, and separately
   you're told broker 3 has been completely powered off for the last 10
   minutes. Is this `Isr` output plausible? What would you expect to see
   instead, and why?
3. A topic `payments` has 6 partitions, partitioned by `customerId`. A
   teammate proposes: "let's bump it to 12 partitions to get more
   consumer parallelism, no big deal, Kafka lets you do that live." What's
   wrong with "no big deal" for a topic where downstream consumers assume
   "all events for a given customer arrive in order, in one partition"?
4. Two independent applications — a fraud-detection service and an
   analytics pipeline — both need to process every message published to the
   `transactions` topic, from the beginning, independently of each other's
   progress. Why does Kafka make this straightforward in a way a
   traditional message queue would not, without either application coding
   around the other?
5. A consumer group's lag (difference between the latest offset and the
   group's committed offset) has been growing steadily for an hour. Is this
   a sign that messages are being lost? Explain what's actually going on
   and what you'd check first.
6. Why does KRaft require an odd number of controller voters, and what
   would actually go wrong (not just "it's bad practice") if you configured
   4 controller voters instead of 3 or 5?

## Answers

1. Yes. With one broker down, replication factor 3 means the ISR drops from
   3 to (at worst) 2 replicas — still meeting `min.insync.replicas=2`, so
   `acks=all` writes are acknowledged once those 2 replicas have the data.
   If a *second* broker also goes down and both down brokers held the only
   remaining replicas, the ISR drops to 1 — below `min.insync.replicas=2` —
   and the broker rejects further produce requests for that partition
   (`NotEnoughReplicasException`) until enough replicas rejoin. Existing
   committed data isn't lost; new writes just stop being accepted.
2. Not plausible as a *current* snapshot. `Isr` reflects the in-sync set as
   of now, and a replica on a broker powered off for 10 minutes would long
   since have exceeded `replica.lag.time.max.ms` (default 30s) and been
   dropped. Expect `Isr: 1,2`, and likely a leader election already having
   happened if broker 3 was the leader. Stale `Isr: 1,2,3` suggests cached
   output, the wrong cluster, or broker 3 isn't actually down.
3. Resizing doesn't retroactively move already-written keyed data. The
   default partitioner maps a key to a partition via hash-modulo-partition-
   count; changing that count changes the mapping only going forward, while
   records in the original 6 partitions stay put. New events for
   `customerId=X` may now hash to a different partition than that
   customer's history, silently breaking the "one customer, one partition,
   in order" invariant — with no error at resize time. If ordering matters,
   create a new topic with the desired count and migrate; don't resize in
   place.
4. Kafka never marks records "consumed" — it only tracks each consumer
   group's own committed offset, independently of every other group. The
   fraud service and the analytics pipeline are just two different consumer
   groups, each reading at its own pace, oblivious to the other. There's no
   shared "delivered" state to contend over — structurally impossible in a
   traditional queue, where acking removes the message for everyone.
5. Not necessarily lost messages. Growing lag means the group is falling
   behind the production rate — a processing-speed problem, not data loss
   (records are still durably in the log). Check first: is the consumer
   actually running and calling poll() (a stalled consumer shows exactly
   this symptom); is per-record processing too slow for the arrival rate
   (needs more instances/partitions or faster processing); is a rebalance
   loop preventing progress. Lag is a health metric to alert on, not proof
   of loss — the data is exactly as safe as retention makes it, regardless
   of lag.
6. A Raft quorum needs a strict majority to commit a change, and fault
   tolerance is "how many voters can be lost while a majority remains." At
   3 voters, majority is 2 → tolerates 1 failure. At 5, majority is 3 →
   tolerates 2 failures. At 4, majority is 3 → *still only tolerates 1
   failure* (losing 2 of 4 leaves 2-of-4, not a majority) — so a 4th machine
   adds cost and network chatter without buying any extra fault tolerance
   over 3. It's concretely wasted capacity, not just convention.

## Hands-on lab

Follow Day 1 in the implementation plan
(`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`) for
the exact commands to bring up the cluster and explore it via the CLI — this
content doc is the theory to have in mind while you do that.

## Journal template

```
## Day 1 — Kafka's model, cluster internals
Key idea in my own words: ...
What confused me: ...
```
