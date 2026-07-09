# Day 14 — Capstone: End-to-End Integration Pipeline

## Purpose

There is no new theory today. Every mechanism the capstone touches — keyed
partitioning, manual offset commits, SASL/SCRAM authentication, ACLs,
windowed aggregation — was introduced, in isolation, on an earlier day. What
today adds is *composition*: wiring those pieces into one pipeline that runs
continuously, then breaking it on purpose while it's running. That's a
harder and more realistic test of understanding than any single day's lab,
because each piece was exercised against a clean, narrow scenario built to
teach exactly that piece and nothing else. Day 5's ACL lab didn't have a
Streams app's internal consumer group also depending on the same cluster;
Day 13's windowed aggregation didn't have to survive a broker being killed
underneath it. Today both are true simultaneously — exactly the situation
production systems live in permanently.

This is also why the capstone is deliberately small in surface area (three
processes, one topic chain, one aggregation) rather than broad. The goal
isn't new scope — it's forcing every existing piece to justify its presence
in a system that has to actually run end-to-end, not just pass its own
isolated lab. A producer that only ever ran alone, a Streams app that only
ever read from an unsecured topic, and a consumer that only ever committed
offsets against a healthy cluster all have to prove they still work once
they're neighbors, sharing a cluster, sharing a topic's ACLs, and sharing
the blast radius of one injected failure.

Today is also forward-looking in a way a pure review day isn't: Day 15's
exam draws scenario questions directly from this pipeline. Building it,
predicting its failure behavior, and writing the retrospective is the last
chance to find a gap in your mental model before it shows up as a wrong
answer tomorrow, and the last chance to practice the skill the exam (and
real on-call work) actually demands: reasoning about a system as a whole,
not recalling facts about one component of it.

## Architecture recap

The pipeline has four hops. Each one is a specific concept from an earlier
day, not a fresh idea:

```
ProducerLoop  --->  orders (secured topic)  --->  CapstoneStreamsApp  --->  customer-spend-per-minute  --->  FileSinkConsumer  --->  capstone-output.jsonl
   (Day 2/3)              (Day 5)                  (Day 13 pattern)              (Day 5)                        (Day 2)
```

- **`ProducerLoop` → `orders`.** `ProducerLoop` (first written on Day 3) keys
  each record with `order-1` / `order-2` / `order-3` — Day 2's partitioning
  concept doing real work: the default partitioner hashes the key to a fixed
  partition, so every message for `order-1` lands on the same partition in
  the same order every time, which is exactly the property the downstream
  aggregation depends on to group correctly.
- **`orders` as a secured topic.** The cluster is the same
  SASL_PLAINTEXT-plus-ACL cluster stood up on Day 5, never reverted.
  `ProducerLoop` authenticates as whatever principal `local-sasl.properties`
  configures, and that principal needs an explicit `Write`/`Describe` grant
  on `orders` — deny-by-default doesn't get suspended for the capstone. Day
  5's authentication-vs-authorization distinction is now load-bearing rather
  than theoretical: get the ACL wrong and the producer authenticates fine
  and still can't write a single record.
- **`orders` → `CapstoneStreamsApp`.** The Streams app's internal consumer
  needs its own `Read`/`Describe` grant on the topic plus a `Read` grant on
  its internal consumer group (Day 5's "topic ACL and group ACL are checked
  separately" pitfall applies to a Streams app's hidden consumer group
  exactly as much as it applies to `FileSinkConsumer`'s explicit one). The
  `groupByKey().windowedBy(...).aggregate(...)` chain is Day 13's
  windowed-aggregation pattern, adapted (see Design considerations below) to
  plain JSON instead of Avro.
- **`CapstoneStreamsApp` → `customer-spend-per-minute` → `FileSinkConsumer`.**
  The Streams app writes per-window totals to a second topic, which needs
  its own ACL grants (`Write` for the Streams app, `Read`/`Describe` for
  `FileSinkConsumer`). `FileSinkConsumer` is Day 2's manual-commit pattern:
  `enable.auto.commit=false`, write the batch, flush, and only then
  `commitSync()` — the same "commit after the side effect is durable, not
  before" ordering Day 2 used to get at-least-once rather than a silent gap.

Read top to bottom, the arrows are: **partitioning/keys (Day 2) → producer
loop (Day 3) → ACL-secured topic (Day 5) → windowed aggregation (Day 13
pattern) → ACL-secured output topic (Day 5 again) → manual-commit consumer
(Day 2)**. Nothing in this pipeline is new; what's new is that all of it has
to hold together at once.

## Design considerations

**Why `CapstoneStreamsApp` parses plain JSON strings instead of reusing Day
12/13's Avro-plus-Schema-Registry setup.** This isn't an oversight — it's a
direct, deliberate consequence of Day 13's teardown. Day 13 ran on Confluent
Cloud specifically to get a hosted Schema Registry, and its Step 6 tore the
entire Confluent Cloud environment down, Schema Registry included, as part
of this course's cost-conscious discipline: nothing stays provisioned
longer than the day that needs it. By Day 14 there is no Schema Registry
reachable from anywhere, and standing a new one up just to reuse
`OrderAggregationStreamsApp`'s exact code would mean resurrecting cloud
infrastructure for the sake of one lab's serde choice. The plain-JSON
`CapstoneStreamsApp` sidesteps that: it reads the same JSON shape
`ProducerLoop` has produced since Day 2–3, pulls `amount` out with a regex
instead of an Avro deserializer, and needs nothing beyond the local Docker
cluster already running. The lesson to take from this, not just the
workaround: **infrastructure decisions have downstream consequences on
later work.** Tearing down Schema Registry on Day 13 was the right call for
that day's cost/scope, but it wasn't free — it shaped what Day 14's Streams
app is allowed to look like, the same way decommissioning a service or
vendor contract because *this quarter's* project no longer needs it
routinely constrains what *next quarter's* project can assume is still
there.

**Why the aggregation groups by the producer's existing message key rather
than introducing a "customerId" field.** Day 13's `OrderAggregationStreamsApp`
grouped by an Avro `customerId` field pulled out of a structured record. The
capstone doesn't have that record shape available (see above), and adding a
new field would mean also changing `ProducerLoop` to emit it — scope creep
unrelated to what today is testing. Grouping by the key `ProducerLoop`
already produces (`order-1`, `order-2`, `order-3`) keeps the capstone
self-contained: no producer changes, no new schema, just the *same*
partitioning key from Day 2 doing double duty as the aggregation's grouping
key. It also keeps the architecture recap's ordering argument airtight —
because `groupByKey()` groups by the exact key the partitioner already used
to route records, there's no hidden re-keying/repartitioning step, which is
one fewer moving part to reason about while a failure is injected in Step 6.

**Why the file-sink consumer writes to a local file instead of a database or
another topic.** A flat `.jsonl` file is the simplest sink that still
exercises the manual-commit-after-side-effect pattern honestly — it has a
real durability boundary (`FileWriter.flush()`) to commit after, without
new infrastructure that would dilute what today is actually about: proving
the whole chain holds together, not standing up a fifth system.

## Failure injection: what to expect from each option

**Rebalance storm (Day 3), injected here.** This pipeline has *two*
independent consumer groups sharing the cluster: `FileSinkConsumer`'s
explicit `capstone-file-sink` group, and `CapstoneStreamsApp`'s internal
consumer group (Streams uses the application ID, `capstone-streams-app`, as
its group ID under the hood). A rebalance storm targeting either group
triggers that group's coordinator to redo assignment the way Day 3
described — but now there are two places to watch lag spike independently.
Storm `capstone-file-sink` and expect `FileSinkConsumer`'s lag on
`customer-spend-per-minute` to spike and recover once membership settles,
while the Streams app's internal group and its `orders`-side lag stay
completely unaffected — different group, different topic, no shared
coordinator dependency. Storm the Streams app's own consumers instead (e.g.
running multiple `CapstoneStreamsApp` instances under the same application
ID and flapping one) and expect a visible pause in the aggregation's own
input consumption — windows stop advancing while the rebalance is in
progress — but `FileSinkConsumer` downstream just sees no new records for a
bit and stays healthy; it has no way to distinguish "producer paused" from
"producer has nothing new to say."

**Broker kill (Day 4), injected here.** With `min.insync.replicas=2` still
set, killing one non-leader broker should be nearly invisible end-to-end:
the ISR shrinks by one, `acks=all` writes still succeed against the
remaining in-sync replicas, and both topics keep accepting writes exactly
as Day 4 predicted for a single-broker loss. Where it gets interesting here:
if the killed broker was the leader for a partition `ProducerLoop` or
`CapstoneStreamsApp`'s internal producer was actively writing to, expect a
short, bounded stall while leader election completes — a brief lull in
`capstone-output.jsonl`'s growth, not an error and not data loss, since
`acks=all` means nothing acknowledged was lost in the transition. If the
killed broker instead held the *last* in-sync replica needed to satisfy
`min.insync.replicas=2` (only plausible if the ISR was already degraded some
other way), writes on that partition would fail loudly with
`NotEnoughReplicasException` — a categorically louder symptom than the
quiet leader-failover case, worth explicitly noticing you're *not* seeing
when you kill just one healthy broker.

**ACL revocation (Day 5), injected here.** Because authorization is
re-checked per request, revoking a grant takes effect on that principal's
very next call — no restart needed to see it, and no restart will fix it
either. Revoke `ProducerLoop`'s `Write` grant on `orders` and the producer
keeps running (its session and authentication are untouched) while every
`send()` fails with `TopicAuthorizationException`; downstream,
`CapstoneStreamsApp` simply stops seeing new input and stops advancing
windows, which starves `FileSinkConsumer` too — neither downstream
component logs an error of its own. The more instructive revocation targets
`CapstoneStreamsApp`'s own principal: revoke its `Read` on `orders` (or its
internal group) and it throws authorization exceptions on its *own* poll
loop while `ProducerLoop` and `FileSinkConsumer` both keep working happily —
the difference between "the producer is broken" and "the middle of the
pipeline is broken" is invisible from either end, showing up only as each
side's own logs or as a total absence of new lines in
`capstone-output.jsonl` despite `orders` visibly growing: exactly the
"authenticated but not authorized, and nobody upstream can tell" scenario
from Day 5's ticket-diagnosis exercise, now embedded in a live pipeline.

## Exercises

1. If `CapstoneStreamsApp`'s internal state store (the running per-window
   totals) were lost entirely — say, its local RocksDB state directory was
   deleted while the app was stopped — what exactly would need to
   reprocess, and from where, for the aggregation to recover correct totals?
2. `FileSinkConsumer` and `CapstoneStreamsApp`'s internal consumer are two
   separate consumer groups reading two different topics. Under what
   circumstance, if any, could a rebalance in one of these groups directly
   cause a rebalance in the other?
3. Suppose you revoke `FileSinkConsumer`'s `Read` ACL on
   `customer-spend-per-minute` while the pipeline is running, then restore
   it two minutes later. Will `capstone-output.jsonl` be missing the
   aggregates produced during those two minutes, or will it eventually
   catch up? Justify your answer from `FileSinkConsumer`'s commit behavior.
4. Why does killing a broker that is *not* the leader for any partition
   `ProducerLoop` or `CapstoneStreamsApp` is currently writing to still
   matter at all for this pipeline, even though no visible stall or error
   would occur?
5. A teammate reviewing this pipeline says the Streams app and
   `FileSinkConsumer` should share one consumer group ID "to keep things
   simple." Explain concretely why that would break the pipeline.

## Answers

1. Nothing on the brokers needs to reprocess — the state store is a local,
   disposable cache, not the source of truth. On restart,
   `CapstoneStreamsApp` detects it has no local state for its application ID
   and rebuilds it by replaying `orders` from its last committed offset (or
   from the internal changelog topic Streams maintains for the store, if
   that survived — Streams backs every state store with a changelog topic
   precisely so this restore doesn't require rereading all of `orders` from
   the beginning). Same durability shape as Day 4's `cleanup.policy=compact`
   changelogs: the store is a rebuildable cache over data whose durable copy
   lives in Kafka, not the other way around.
2. Only indirectly, through a shared resource, not through direct coupling.
   The two groups have independent coordinators, independent membership, and
   read different topics, so one group's `JoinGroup`/`LeaveGroup` traffic has
   no protocol-level effect on the other. The one path by which trouble in
   one could still affect the other is a shared *broker* — if both groups'
   coordinators happen to live on the same struggling or killed broker, both
   could see disruption at overlapping times, but that's a shared-
   infrastructure effect, not one group causing the other's rebalance.
3. It will eventually catch up, with no data loss. `FileSinkConsumer` commits
   manually, after writing and flushing to the file, so its committed offset
   never advances past what it's actually written. While the ACL is revoked,
   its fetches fail with `TopicAuthorizationException` and it makes no
   progress — it never commits an offset for records it didn't process. Once
   restored, its next poll resumes from the same committed offset, so it
   reads and writes everything that accumulated during the gap, just later
   than it would have otherwise (lag catches up; nothing goes missing).
4. Because the ISR for every partition on that broker just shrank by one,
   even though the leader didn't move. `acks=all` writes are only as durable
   as the current ISR — losing a broker that held an in-sync replica means
   that partition tolerates one fewer additional failure before
   `min.insync.replicas` is violated and writes start failing outright. The
   pipeline looks perfectly healthy, but its safety margin against a
   *second* failure has quietly thinned; "no visible symptom" and "no
   consequence" aren't the same thing.
5. Streams uses the application ID as its internal consumer's group ID, and
   that group's committed offsets on `orders` track how far the
   *aggregation* has progressed. `FileSinkConsumer`'s group tracks how far
   the *file sink* has progressed on an unrelated topic
   (`customer-spend-per-minute`). Sharing one group ID wouldn't simplify
   anything — it would make both consumers members of one group
   subscribed to two unrelated topics with unrelated offset semantics,
   triggering constant rebalances between processes with no reason to
   coordinate, and corrupting the independent progress tracking each one
   needs. They stay separate because they track two different, unrelated
   notions of "how far has this consumer gotten."

## Hands-on lab

The Java implementation is
`kafka_practice/labs/src/main/java/com/kafkapractice/CapstoneStreamsApp.java`
(plain-JSON windowed aggregation) and
`kafka_practice/labs/src/main/java/com/kafkapractice/FileSinkConsumer.java`
(manual-commit file sink). On the Go side, only the file-sink half has a
port: `kafka_practice/labs-go/cmd/filesinkconsumer/`. There is no Go Streams
app — Kafka Streams is JVM-only by design, and this course's Go track has
never tried to reimplement it, per the project's standing decision that
anything Kafka-Streams-shaped stays Java-only. Running the full capstone
"in Go" therefore means pairing the Java `CapstoneStreamsApp` with the Go
`filesinkconsumer` binary reading its output topic, not a pure-Go pipeline.

Follow **Day 14** in
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` for
the exact wiring: bringing the cluster back up, granting the ACLs both new
components need, the three-terminal run sequence, and the exact chaos-lab
trigger commands for whichever failure you choose. This document is the
*why* behind the design and the predicted behavior; the plan has the exact
commands — don't duplicate them here, work from the plan directly.

## Journal template

```
## Day 14 — Capstone
Key idea in my own words: ...
What confused me: ...
```
