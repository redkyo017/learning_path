# Day 7 — Kafka Connect & Integration Patterns on MSK

## Learning objectives

By the end of today you should be able to:
- Explain what Kafka Connect is and why it exists (removing hand-written
  producer/consumer code for every system integration).
- Distinguish a source connector from a sink connector by data direction.
- Explain what a converter does, and why a converter mismatch against the
  actual bytes on a topic causes failure downstream.
- Explain standalone vs. distributed worker mode, and why distributed mode
  (what MSK Connect runs) is the production-relevant one.
- Read a failed connector/task status and localize the cause to a converter
  mismatch, a permissions/network issue, or malformed data hitting a schema.

## Reference material

- Kafka Connect architecture docs (Apache Kafka documentation, "Kafka
  Connect" section) — connectors, tasks, workers, converters, standalone vs.
  distributed mode; the vendor-neutral foundation for everything below.
- AWS MSK Connect docs — how AWS operationalizes Connect as a managed
  service: custom plugins via S3, worker configuration, IAM auth for
  connectors, capacity units.
- AWS Glue Schema Registry docs — how Glue integrates with Connect via
  Avro/JSON-Schema converters, compatibility modes, and schema registration
  on write.
- The Day 7 implementation plan for this course:
  `kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`
  (exact AWS CLI commands; this document is the theory to pair with them).

## Theory

### What Kafka Connect actually is, and why it exists

Every prior day treated "getting data into or out of Kafka" as something you
do by writing a producer or consumer — the right model when the other end of
the wire *is* your application. It's a bad model when the other end is a
database, S3, a REST API, or any system that isn't yours to modify: every
team needing to pipe data in or out ends up hand-rolling its own polling
loop, offset bookkeeping, retry logic, and error handling. Do that across a
dozen integrations and you have a dozen bespoke, differently-broken pieces
of glue code.

**Kafka Connect** is a framework, shipped with Apache Kafka, for running
that integration logic as reusable, configuration-driven **connector**
plugins inside a managed **worker** process, instead of as bespoke
application code. The ecosystem already has connectors for Postgres CDC,
S3, Elasticsearch, and dozens more — you configure an existing connector
(table name, bucket, credentials, converter, topic) rather than writing and
maintaining a service. The worker handles what every integration needs
regardless of the target system: polling, splitting work into parallel
**tasks**, tracking offsets, retrying transient failures, and exposing a
REST API for lifecycle operations. That's the whole point: Connect turns "N
integrations" into "N configuration files running on one shared runtime,"
not "N bespoke codebases."

### Source connectors vs. sink connectors

The distinction is just data direction:

- A **source connector** pulls data from an external system *into* Kafka
  (poll a table, tail a database's change log, poll an API) and produces
  what it finds onto one or more topics. From Kafka's point of view it's a
  managed producer.
- A **sink connector** pulls data *out of* Kafka into an external system,
  consuming from topics (as a Connect-managed consumer group) and
  translating each record into a write operation on the target (an S3
  `PutObject`, a JDBC `INSERT`). From Kafka's point of view it's a managed
  consumer.

Today's lab runs one of each: a source connector (`kafka-connect-datagen`,
generating synthetic records so no real upstream DB is needed) and a sink
connector (S3 sink).

### Converters: what actually serializes and deserializes

A connector's job is "how to talk to the external system" — not how records
are serialized onto the topic itself. That's the separate, pluggable
**converter** concept, configured via `key.converter`/`value.converter`. A
converter translates between Connect's internal record representation and
the actual bytes on the topic: JSON (with or without an embedded schema),
Avro via a schema registry (Confluent's or, here, AWS Glue — compact binary
with the schema registered externally and referenced by ID), or plain
string/byte pass-through.

The converter must match what's *actually* on the topic, not what you wish
were there. Point a JSON converter at a topic whose data is really
Avro-encoded (schema registered in Glue, binary payload with a schema-ID
prefix) and it won't fail at connector-creation time — it fails the moment
it tries to deserialize a real record, because it's parsing Avro binary as
if it were JSON text. This is a configuration mistake, not a connector bug,
and it's one of the most common Connect failure modes in practice.

### Standalone vs. distributed worker mode

- **Standalone mode**: one worker process on one machine, config and offsets
  in local files, no coordination or fault tolerance. Useful for local
  testing or a fixed single-host agent, not for production.
- **Distributed mode**: multiple workers form a group (coordinated like a
  consumer group), and connector config, status, and offsets live in
  internal Kafka topics rather than local files. Tasks are load-balanced
  across the group, and if a worker dies, the rest rebalance and pick up its
  tasks automatically.

**MSK Connect runs distributed mode** — not a knob you can turn off, because
it's the only mode compatible with "AWS manages the compute and can replace
an instance transparently." Standalone's local-file state has nowhere
durable to live if the underlying instance disappears. This is also why
connector config/status/offsets live in inspectable Kafka topics rather than
on a server you'd SSH into.

## Best practices

- **Treat connector configs as versioned artifacts, not disposable glue.** A
  connector's JSON config is the data contract with the external system —
  which table, which topic, which converter. Track it in the same repo/PR
  workflow as other infrastructure, like this course's `kafka_practice/aws/
  *.json` files.
- **Use a schema-registry-backed converter (Avro/Protobuf) for anything
  beyond a disposable lab.** Schemaless JSON lets fields appear, change type,
  or disappear with zero enforcement. A registry with a compatibility mode
  rejects incompatible changes *at write time*, turning a silent downstream
  outage into an immediate, loud failure at the actual point of mistake.
- **Give each connector the narrowest IAM role it needs**, not a shared
  broad one — a sink writing to one bucket needs `s3:PutObject` scoped to
  that bucket, not blanket S3 access. A shared over-broad role means one
  misconfigured connector has a blast radius far beyond its own integration.
- **Pin connector plugin versions**, don't point at "latest." Treat plugin
  upgrades as a deliberate, tested change.
- **Monitor connector/task status, not just cluster health.** A connector
  can sit `FAILED` for hours while the broker is perfectly healthy — nothing
  cluster-level surfaces that.

## Common pitfalls

- **Assuming a sink's flush interval means near-instant delivery.** Sink
  connectors batch on a size or time threshold, not per record. Producing a
  message and immediately checking the target and finding nothing is not
  evidence of breakage — check the flush/rotate config first.
- **Mismatching a converter against what's actually on the topic.** The
  single most common way a freshly created connector goes straight to
  `FAILED`. The fix is "go check the real format on the topic," not "guess
  another converter."
- **Underestimating how much of "integration work" is config, IAM, and
  network plumbing, not code.** The connector's logic is usually already
  written by someone else; what takes the time is the execution role and
  trust policy, security-group paths to both the cluster and the external
  system, plugin registration, and getting the converter/registry settings
  to match reality. This is exactly why Connect competence is core
  integration-team skill, not a niche detail.
- **Missing per-task status.** A connector can show `RUNNING` while one
  specific task under it is `FAILED` — checking only the top-level status
  misses partial failures.
- **Assuming `RUNNING` means the data contract is correct.** It only means
  the worker instantiated the connector/tasks successfully, not that the
  data is being interpreted correctly — a subtly wrong converter config can
  run a long time producing corrupted output before anyone notices.

## Real-world use cases

- **Onboarding a new upstream system without a custom polling service.**
  When a team needs their Postgres table's changes in Kafka, the answer is
  rarely "write a scheduled polling job" — it's deploying a CDC-style source
  connector against that database, giving ordered change events (including
  updates/deletes) with no bespoke polling logic to maintain or scale.
- **Standardizing how the team pipes events into a data lake.** If five
  teams each need their topic mirrored to S3, five bespoke consumer apps
  reinventing batching and retry logic is the wrong answer. One shared,
  well-tested S3 sink pattern (bucket convention, partitioning, flush
  interval, IAM role template) that every team reuses turns "five
  integrations" into "one pattern, five config files."
- **Schema registry becomes the real contract past two systems.** With one
  producer and one consumer, teams get away with an informal agreed shape.
  The moment a third system reads (or a second writes) the same topic, that
  informal agreement is unenforceable by any single team — a field rename
  breaks someone else's consumer with no warning. A registry with an
  enforced compatibility mode makes the contract binding: an incompatible
  change is rejected at write time, not discovered independently by three
  teams days apart.

## Worked example

A sink connector's status shows:

```
Connector: s3-sink-orders
  State: RUNNING
  Tasks:
    Task 0: FAILED
      Trace: org.apache.kafka.connect.errors.DataException: Failed to
      deserialize data for topic 'orders' to Avro:
      org.apache.kafka.common.errors.SerializationException: Unknown magic
      byte!
```

Diagnosis: the connector itself is `RUNNING` — the worker created it and its
tasks started fine — but Task 0 failed while actually processing records,
which points to a data-path problem, not a startup/config-typo problem (a
bad top-level config usually prevents `RUNNING` entirely, or fails every task
identically). "Unknown magic byte" is the classic signature of a converter
mismatch: schema-registry-aware Avro serialization prefixes a magic byte and
schema ID before the payload, and this error means the converter tried to
read that prefix and got bytes that don't match — almost always because the
topic's real data isn't in the format this converter expects (e.g., plain
JSON on the topic but a Glue Avro converter configured, or Avro from a
different registry/serializer than this converter talks to).

What this is *not*: an IAM/network problem would show up as access-denied or
connection-timeout at the point of *writing* to S3, not a deserialization
error reading the topic. It's also not a registry-rejection case (a
malformed record hitting a strict schema) — that surfaces as a schema
compatibility error from the registry client, not "unknown magic byte." The
fix is to check what's really on `orders` (consume raw bytes and inspect)
against what the connector's converter/registry settings expect, then align
one to the other — restarting the task without fixing the mismatch just
fails again identically. A trace reading
`AccessDeniedException: not authorized to perform: s3:PutObject` would
instead point at the IAM role missing a bucket permission — a different
category of fix despite both showing as "Task 0: FAILED."

## Exercises

1. A newly created source connector shows connector-level `FAILED` within
   seconds, before it could plausibly have processed real data. What
   category of problem does this suggest, versus "RUNNING, one task FAILED
   after running a while"?
2. You configure a sink's `value.converter` as the Glue Avro converter,
   pointed at a topic a legacy producer has written plain JSON to for
   months. What happens when the sink starts consuming existing records?
3. Your S3 sink has `flush.size=1000`, no time-based rotation. You produce 3
   test messages and the bucket is empty. Broken? What would you check or
   change to see results from a small test batch quickly?
4. Explain why MSK Connect can transparently replace an unhealthy worker
   instance without losing track of running connectors/tasks, in a way
   standalone mode fundamentally could not.
5. A teammate says "we're the only producer, we'll just be careful, no
   registry needed." Two more teams start consuming that topic next
   quarter. What breaks, and what does a registry enforce that "careful"
   cannot?
6. Onboarding a new upstream Postgres database: one teammate proposes a
   Python service polling the table every 30s; another proposes a CDC
   source connector. Name two concrete disadvantages of polling that the
   connector avoids.

## Answers

1. An instant connector-level `FAILED` points to a problem in the
   connector's own configuration or ability to initialize — a missing
   required field, a plugin class that can't load, or an inability to even
   reach the cluster. "RUNNING, task FAILED later" means the connector
   initialized fine and the failure is specific to something hit while
   handling data (bad record, converter mismatch, downstream permission).
2. It fails on the very first real record — likely the same "unknown magic
   byte" error — because the Glue Avro converter expects a magic-byte/
   schema-ID prefix followed by Avro binary, and plain JSON text has no such
   structure. This isn't "some records work" — it fails consistently and
   immediately once it hits real topic data.
3. Not necessarily broken — with `flush.size=1000` the connector is by
   design waiting to accumulate 1000 records per partition before writing an
   object; 3 messages is nowhere near that. To see results quickly, lower
   `flush.size` temporarily (e.g., to 1–10) or add a time-based rotation
   interval so it flushes on a wall-clock schedule, then revert for
   production use.
4. Distributed mode stores connector config, status, and offsets in
   internal Kafka topics, replicated durably on the cluster — not on any one
   worker's local disk. A replacement worker joins the group, the group
   rebalances, and workers pick up the departed instance's tasks by reading
   config/offsets straight from those topics. Standalone mode keeps that
   same state in local files on one fixed machine; if that machine is
   replaced, there's nowhere else to recover the state from.
5. "Careful" is a social commitment with no enforcement — a field rename or
   type change can ship with no write-time signal, and the two new consuming
   teams discover breakage independently, after the fact, with no shared
   record of what shape was "agreed." A registry with a compatibility mode
   enforces the contract mechanically: an incompatible schema change is
   rejected at the moment a producer tries to register it, forcing the
   break to surface immediately to the team causing it, before it reaches
   any consumer.
6. Polling has to invent its own change-detection and offset-tracking (what
   counts as "new," how to handle updates/deletes, how to resume correctly
   after a crash), while CDC gets ordered, complete change events (including
   updates/deletes) directly from the database's replication log with
   offset tracking already handled by Connect. Polling is also a single
   bespoke process needing hand-built restart/scaling logic, whereas the
   connector's tasks run inside Connect's distributed worker group with
   built-in task distribution and failover.

## Hands-on lab

Follow Day 7 in the implementation plan
(`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`) for
the exact AWS CLI and MSK Connect commands: creating the Glue registry,
registering the datagen source connector plugin, standing up the S3 sink,
and reconfiguring a converter to use the Glue Avro converter.

The plan deliberately does not spell out literal MSK Connect connector JSON
in full — that's intentional, not an oversight. MSK Connect's
`create-connector` request schema has several nested required blocks
(capacity, kafkaCluster, kafkaConnectVersion, plugin ARNs) that need
verifying live against `aws kafkaconnect create-connector help` and your
account's actual ARNs at the time you run it, rather than copied from a doc
that could drift out of sync with the real API shape. Build
`kafka_practice/aws/datagen-connector.json` and
`kafka_practice/aws/s3-sink-connector.json` from that live CLI help output
and your account's real resource ARNs, per the plan's steps.

## Journal template

```
## Day 7 — Kafka Connect & integration patterns
Key idea in my own words: ...
What confused me: ...
```
