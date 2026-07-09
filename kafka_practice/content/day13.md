# Day 13 — Kafka Streams & ksqlDB

## Learning objectives

By the end of today you should be able to:
- Explain why Kafka Streams is a client library rather than a separate
  processing cluster, and what that implies for how it's deployed and scaled.
- State the `KStream` vs. `KTable` distinction, including how `KTable`
  relates to the changelog/compaction idea from Day 4.
- Explain what a windowed aggregation does mechanically (time buckets per
  key, a running aggregate per bucket) and why a grace period exists.
- Describe ksqlDB's relationship to Kafka Streams (a SQL layer over the same
  engine, not a different processing model) and judge when SQL vs.
  hand-written Java is the better tool for a given job.
- Diagnose whether a "missing" late event in a windowed result is a
  grace-period configuration issue or an event-time/processing-time mismatch.

## Reference material

- Kafka Streams docs — `KStream`/`KTable`, windowing:
  https://kafka.apache.org/documentation/streams/
- ksqlDB docs — `CREATE TABLE ... WINDOW TUMBLING`, the SQL surface over
  streams and tables: https://docs.ksqldb.io/

## Theory

### Kafka Streams is a library, not a cluster

Spark, Flink, and traditional ETL schedulers all share the same shape: you
submit a job to a separate cluster of worker processes that someone else
operates, and that cluster reads your input, runs your logic, writes your
output. Kafka Streams does not work that way, and that's the fact to
internalize before writing a line of it.

**Kafka Streams is a Java library you link into your own application.**
There is no "Streams cluster" to stand up, no dedicated fleet of worker
nodes provisioned specifically for stream processing. Your application — a
plain JVM process you build, deploy, and run like any other service — *is*
the stream processor. It connects to the same brokers your other clients
use, reads input topics via ordinary consumer-group mechanics, runs your
topology (`map`/`filter`/`groupByKey`/`aggregate`), and writes results via
an ordinary producer.

Two consequences follow directly. First, **scaling means running more
copies of your own application**, not requesting capacity from a processing
cluster — each instance is a member of a consumer group for the input
topic's partitions, so adding instances lets Kafka's normal
partition-assignment protocol spread the work, up to the partition count;
this is the exact mechanism Day 2's consumer groups used. Second, **there is
no separate system to operate** — no master/JobManager, no distinct
resource pool with its own upgrade cadence. Operationally, a Streams app is
exactly as heavy to run as any other Kafka client, because that's what it
is.

The trade-off is real: you give up a dedicated cluster's ability to be
managed independently of application deploys, in exchange for one fewer
system to operate. For a team already comfortable deploying JVM services
that's usually a clear win; a team that wants processing infrastructure
fully decoupled from application deploys is choosing a genuinely different
answer with Spark/Flink, not a strictly worse one.

### `KStream` vs. `KTable`: two lenses on the same kind of topic

Both abstractions sit over the same underlying thing — a Kafka topic — and
differ entirely in how you *interpret* the records, not in storage.

**`KStream`** treats every record as an **independent event**: "order
placed, order placed, order placed, ..." — an unbounded sequence of facts,
each meaningful on its own, none superseding an earlier one.

**`KTable`** treats the same shape of topic as a **continuously-updated
view: latest value per key**. A `KTable` keyed by `customerId` isn't "every
event for this customer," it's "current state, right now, per customer" —
a new record for a key *overwrites* the previous one. This is exactly the
**changelog-topic idea from Day 4's compaction discussion**, applied to
stream processing: a `cleanup.policy=compact` topic, read from the
beginning, is "one row per key, the latest one," and a `KTable` is the
continuously-maintained materialization of that same concept (backed by its
own changelog topic under the hood), rather than something reconstructed
once at startup.

The difference shows up when you aggregate or join: grouping a `KStream` by
key and aggregating produces a `KTable` ("total spend per customer so far,"
updated live); joining a `KStream` against a `KTable` means "enrich this
event with the current value for its key" (attach a customer's current tier
to each order), not "join against every historical value that key ever
had." `KTable` isn't a different storage mechanism — it's a semantic lens
that says "newer records for this key replace older ones."

### What a windowed aggregation actually does

An unwindowed aggregation (`groupByKey().aggregate(...)`) produces one
running total per key, forever. A **windowed** aggregation adds a second
grouping dimension: time. `TimeWindows.ofSizeAndGrace(Duration.ofMinutes(1),
Duration.ofSeconds(10))` (today's lab) tells Streams to bucket events into
non-overlapping 1-minute windows by timestamp, maintain a separate running
aggregate *per key per window*, and — the "AndGrace" part — keep a window
open 10 extra seconds past its nominal end before treating it as final.

Mechanically, the engine holds a map of `(key, window) -> running
aggregate`, live only for windows still within their grace period. An event
late enough to fall into an already-closed window is dropped rather than
smeared into the wrong bucket — the correct behavior once a window is truly
closed, since admitting it would retroactively change a result downstream
consumers may already treat as final.

**Why the grace period exists:** an event's timestamp and the moment it
*arrives* at the application are never guaranteed to be the same instant.
Network delays, producer batching, a partition catching up after a
rebalance, clock skew — all mean a record timestamped just before a window's
boundary can genuinely arrive after that boundary passes. Without tolerance
for this, a perfectly valid event gets dropped purely because of ordinary
infrastructure jitter. The grace period is a bounded, explicit admission —
"some lateness is normal, tolerate up to this much before calling a window
final" — not a guarantee that nothing is ever late enough to miss it;
events beyond the grace period are still dropped, by design.

### ksqlDB: the same engine, a declarative surface

ksqlDB is not a competing stream-processing engine — it's **Kafka Streams
under a SQL layer**. `CREATE TABLE ... AS SELECT customerId, SUM(amount) ...
WINDOW TUMBLING (SIZE 1 MINUTE) GROUP BY customerId EMIT CHANGES` compiles
into the same kind of topology (`groupByKey`, `windowedBy`, `aggregate`) you'd
hand-write in Java, on the same consumer-group scaling model. Semantics
(grace periods, `KStream`/`KTable` — ksqlDB's `CREATE STREAM`/`CREATE TABLE`
map directly onto them) are identical; only the authoring surface differs.

So the choice isn't "which is more powerful," it's fit for the moment:

- **ksqlDB for fast iteration and exploration.** Standing up a pipeline
  idea, checking whether a windowed aggregation looks sane, demoing a
  transform — a statement typed into a console, no build, no deploy.
- **Java Streams for custom logic, testability, or tight integration.**
  Anything beyond SQL's aggregate/join/windowing vocabulary (custom
  deserialization, calling another library, non-trivial branching rules) is
  naturally a Java lambda, not a SQL expression bent into shape. Java apps
  are unit-testable with `TopologyTestDriver` and live inside the same
  codebase and deploy pipeline as the rest of a Java platform — no separate
  ksqlDB cluster to keep in sync.

Today's lab builds the same windowed aggregation both ways so this trade-off
stops being abstract.

## Best practices

- **Choose window size and grace period from observed event lateness, not
  guessed round numbers.** "10 seconds of grace" is a good choice only if
  informed by actual measurement (producer batching intervals, realistic
  network jitter) — not because it feels safe. A guessed grace period is
  either too short (drops events that were never anomalous) or needlessly
  long (see pitfalls).
- **Reach for `KTable`/changelog semantics for "latest state per key" needs**
  instead of re-deriving it from a raw `KStream` every time. If the actual
  need is "current customer tier," model it as a `KTable` from the start —
  manually tracking "the last value I saw for this key" over a `KStream`
  reinvents what `KTable` already does correctly, including its interaction
  with compaction and state-store recovery.
- **Prototype in ksqlDB, promote to Java once the logic is stable and needs
  custom code or tighter testing.** Use ksqlDB's speed to validate a
  pipeline idea against real data, then port to Java once you know the
  shape of the logic and it needs something ksqlDB's SQL surface doesn't
  express cleanly, or needs to live inside an existing service's tests and
  deploys.

## Common pitfalls

- **"Set the grace period as long as possible, to be safe."** This has a
  real, direct cost: the grace period is exactly how long a window's result
  stays non-final. A 10-minute grace on a 1-minute window means consumers
  of the output may not see a *final* value for that minute until 11
  minutes after it started. There's no free "safe" setting — every extra
  second of grace is a second of added result latency, so the right number
  is the smallest one that reliably covers real observed lateness.
- **Thinking Kafka Streams needs a separate cluster to operate or scale.**
  Backwards, per the theory above: there's no Streams-specific cluster to
  provision or capacity-plan. Scaling is running more instances of your own
  application, following the same partition-assignment model a consumer
  group already uses.
- **Underestimating that "Kafka Streams is JVM-only" is a real constraint,
  not a footnote.** There is no official Go, Python, or other non-JVM
  Kafka Streams client. For a non-JVM-primary team this is worth knowing
  *before* committing architecturally, not after. ksqlDB softens this (you
  interact over SQL/REST, without writing JVM code yourself) but the engine
  underneath is still the JVM-only Streams runtime — a non-JVM shop
  adopting ksqlDB is still taking on a JVM-based service to operate.

## Real-world use cases

1. **Real-time enrichment via a `KTable` join instead of a per-event
   database query.** An integration team attaching a customer's current
   tier to each order event can either query a database per event (adds
   per-event latency, couples pipeline throughput to the database's) or
   maintain a `KTable` of reference data sourced from a changelog/compacted
   topic and join the order `KStream` against it in-process, reading from a
   local, continuously-updated state store instead — exactly the pattern
   `KTable` exists for.
2. **Exploratory pipeline validation in ksqlDB before committing to a Java
   app.** When asked "can we get a real-time rolling total of X per Y," a
   `CREATE TABLE ... AS SELECT ... WINDOW TUMBLING ...` statement in ksqlDB
   is the fastest way to find out — no build, no deploy. The team decides
   afterward whether it's worth porting to Java (integration, custom logic,
   testing needs) or whether the ksqlDB pipeline is good enough as-is.
3. **Windowed rate/anomaly monitoring feeding an alerting system.** "Alert
   if a customer's spend in any 1-minute window exceeds threshold X" is
   exactly today's `TimeWindows`-based aggregate pattern, with the grace
   period tuned to how fast the alert needs to fire versus how much
   late-arrival tolerance is acceptable before a window's total is final.

## Worked example: "the aggregation is missing a few late events"

**Symptom:** the `customer-spend-per-minute` output (or the ksqlDB table) is
missing a few orders you know were sent — some minutes' totals are lower
than expected.

Two structurally different failure modes produce this symptom:

**Grace-period issue.** The events' timestamps are correctly inside the
window they belong to, but they *arrived* later than the window's nominal
end plus its grace period (today's app: 1 minute + 10 seconds). Nothing is
wrong with the record — it just showed up too late to be admitted.
**Signature:** the missing events' timestamps are correctly inside the
window they're missing from. **Fix:** widen the grace period to cover the
observed lateness (accepting the latency cost above), or investigate why
records are arriving late (slow producer, backlog, rebalance) instead of
reflexively widening.

**Event-time vs. processing-time mismatch.** The records' *timestamps
themselves* are wrong or come from an unexpected source, so they land in a
different window than intended regardless of grace period. Streams' default
extractor uses the record's embedded timestamp (producer-set `CreateTime`,
by default), not "when Streams happened to process it." A producer replaying
old data, running with a skewed clock, or stamping a business timestamp that
differs from send time will have its records correctly windowed by *that*
timestamp — which may not be the window a human expects. **Signature:** the
missing event's timestamp, inspected directly, points to an *earlier*
window than expected — it was never a late arrival into the right window,
it was headed for a different window all along. **Fix:** not a grace-period
problem at all — correct the timestamp source (a custom
`TimestampExtractor`, or fix the producer's clock/timestamp logic).

**Telling them apart:** pull the raw timestamp off a specific missing event
(e.g. a console consumer with `--property print.timestamp=true`) and
compare it to the window boundary you expected. Timestamp inside the
expected window but arrived late → grace period. Timestamp pointing to a
different window entirely → event-time mismatch, and no amount of grace-
period tuning fixes that.

## Exercises

1. A colleague says: "We need to provision a Kafka Streams cluster before
   we can run this aggregation app in production." What's wrong with this,
   and what should actually happen?
2. In one sentence each, state the difference between `KStream` and
   `KTable`, then explain how `KTable` relates to `cleanup.policy=compact`
   from Day 4.
3. A windowed aggregation uses `TimeWindows.ofSizeAndGrace(Duration.ofMinutes(5),
   Duration.ofMinutes(30))`. What cost does the 30-minute grace period
   impose on consumers of the output, regardless of whether any events
   actually arrive late?
4. A "missing" event's raw timestamp falls squarely within the window whose
   output is missing its contribution, but the event was produced by a
   batching producer with a 45-second internal buffer delay. Grace-period
   issue or event-time mismatch? What's the fix?
5. A different missing event's raw timestamp is three hours earlier than
   when it was actually produced — a bug stamped orders with a cached,
   stale timestamp. Grace-period issue or event-time mismatch? Would
   increasing the grace period ever fix this one?
6. Your team's primary language is Python, and someone proposes a Kafka
   Streams app for a new pipeline. What fact should be raised before that
   decision is finalized, and what are the realistic alternatives?

## Answers

1. **Wrong on the premise** — there's no separate "Kafka Streams cluster."
   It's a library linked into your app, which connects to the existing
   brokers via ordinary consumer/producer mechanics. What should happen:
   build it, deploy as many instances as you want parallelism (up to the
   input topic's partition count), and let Kafka's normal
   partition-assignment protocol divide the work — no dedicated cluster.
2. **`KStream`**: an unbounded sequence of independent events, none
   superseding earlier ones. **`KTable`**: a continuously-updated view of
   the latest value per key, where a new record replaces the previous one.
   `KTable` is the stream-processing application of the same idea as
   `cleanup.policy=compact`: both mean "keep only the most recent record per
   key" rather than full history — a `KTable`'s changelog topic is
   conceptually a compacted topic kept continuously current.
3. **It delays how quickly any window's result becomes final by up to 30
   minutes**, regardless of whether events actually arrive late. Consumers
   have to accept a 5-minute window's total might still revise for up to
   30 minutes after that window ends — latency imposed on every window,
   every time, whether or not lateness ever actually occurs.
4. **Grace-period issue.** The timestamp correctly places it in the right
   window — it just arrived later than the window's end plus grace,
   because of the batching delay. Fix: widen the grace period to cover the
   delay (accepting added latency), or address the delay itself if it's
   larger than acceptable — not a timestamp problem.
5. **Event-time mismatch**, and no, wider grace would not fix it. The
   timestamp itself is wrong — it points three hours into the past. Grace
   period only extends how long a window stays open for legitimately-late
   arrivals into *that* window; it can't retroactively reopen a window from
   three hours ago, and even an enormous grace period would still leave the
   event in the wrong window relative to when it was actually produced. Fix
   the producer's stale-timestamp bug at the source.
6. **Fact to raise: Kafka Streams (and ksqlDB underneath) is JVM-only** —
   no official Go, Python, or other non-JVM client. For a Python-primary
   team, adopting it means operating at least one JVM-based service.
   Alternatives: use ksqlDB if the logic fits its SQL surface (still a
   JVM-based service to run, but no JVM code to write), accept a bounded
   JVM service if the Streams features are worth it, or use a different
   approach entirely (a Python consumer doing the aggregation manually, or
   a processing engine with first-class Python support) if any JVM
   dependency is a hard no.

## Hands-on lab

Today's Java Streams app is
`kafka_practice/labs/src/main/java/com/kafkapractice/OrderAggregationStreamsApp.java`
— the windowed `customer-spend-per-minute` aggregation from the theory
section (1-minute window, 10-second grace, over the Avro `orders` topic from
Day 12).

There is deliberately **no Go equivalent for this file**. Kafka Streams has
no official non-JVM client — the constraint from Common Pitfalls above — so
the Go lab track in this project stays Java-only for today's Streams app by
design, not because of a gap in the port. A non-JVM implementation would
have to hand-roll the consume-aggregate-produce loop, windowing, and
state-store semantics manually — a materially larger undertaking than
"link the library," which is exactly the trade-off worth knowing before
committing to Kafka Streams for a non-JVM shop.

For the exact run commands (compiling and running the Streams app, feeding
it with `AvroProducerDemo`, consuming the output topic), the ksqlDB
comparison steps, the Phase 3 closed-book review questions, and the full
Confluent Cloud teardown sequence, follow **Day 13** in
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`
exactly as written — those commands aren't repeated here. The teardown step
is the last one touching billed Confluent Cloud resources this plan;
its verification commands are what confirm nothing keeps accruing cost
after today.

## Journal template

```
## Day 13 — Kafka Streams & ksqlDB
Key idea in my own words: ...
What confused me: ...
```
