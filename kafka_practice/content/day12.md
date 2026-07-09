# Day 12 — Schema Registry & Fully-Managed Kafka Connect on Confluent

## Learning objectives

By the end of today you should be able to:
- Explain what problem a schema registry solves that an out-of-band
  convention (wiki page, Slack message) cannot, and what actually travels
  on the wire instead of a full schema.
- State precisely what `BACKWARD`, `FORWARD`, and `FULL` compatibility each
  enforce, in terms of which side's code is guaranteed to keep working.
- Apply Avro's evolution rules to classify a field-level change (add,
  remove, rename, widen a type) as safe or unsafe under a given
  compatibility mode.
- Contrast a self-managed connector (MSK Connect, Day 7) with a
  fully-managed connector (Confluent Cloud, today): who owns the plugin
  packaging, the runtime, and the credentials in each case.
- Describe the concrete steps to verify a proposed schema change is
  actually safe, rather than trusting a producer team's "nobody uses that
  field anymore."

## Reference material

- Confluent Schema Registry docs — compatibility modes
  (`BACKWARD`/`FORWARD`/`FULL` and their `_TRANSITIVE` variants): the
  authoritative definition of what each mode checks and when.
- Avro schema evolution rules: the field-level rules (defaults on new
  fields, type promotion, alias-based renames) compatibility checking is
  built on.
- Confluent-managed connectors catalog: the vendor-operated source/sink
  connectors available on Confluent Cloud, and what each one's supported
  configuration surface actually covers.

## Theory

### What a schema registry actually solves

Without a registry, producers and consumers agree on message shape by
*convention* — a wiki page, a shared library version, a Slack message
saying "we added a field, redeploy." That agreement lives outside the
system: nothing enforces it, and the first signal of a mismatch is usually
a consumer's deserialization exception in production, after the producer
already shipped.

A schema registry replaces that with an in-band, enforced source of truth.
Each schema is registered under a **subject** (conventionally
`<topic>-value`), and gets a unique **schema ID**. Two things follow:

1. **Messages carry an ID, not the schema.** An Avro-serialized record on
   the wire is a magic byte plus a schema ID, then the encoded payload — not
   the schema itself. A consumer reads the ID, fetches (and caches) the
   matching schema from the registry, and decodes with it. This saves
   bytes on the wire, but it's a side effect, not the main point.
2. **Registration is a checked act.** When a producer registers a new
   schema version under a subject, the registry runs a **compatibility
   check** against existing version(s) *before* accepting it. An
   incompatible schema is rejected at registration time — a producer
   deploy that would silently break downstream consumers instead fails
   loudly, before a single bad message is produced.

### What each compatibility mode enforces

- **`BACKWARD`** — a consumer on the **new** schema can read data written
  with the **previous** schema. Safe to upgrade consumers before producers.
  This is Confluent's default (see Best practices for why).
- **`FORWARD`** — a consumer on the **previous** schema can read data
  written with the **new** schema. Safe to upgrade producers before
  consumers.
- **`FULL`** — both hold at once: safe regardless of deploy order, at the
  cost of ruling out more kinds of changes. `_TRANSITIVE` variants check
  the candidate against *every* prior version, not just the immediate
  predecessor.

### The concrete Avro rule underneath add vs. remove

- **Adding a field is safe only with a default.** A reader on the *old*
  schema decoding new-schema data just ignores the extra field — that
  direction is always fine. The direction that needs a default is the
  other one: a reader on the *new* schema decoding *old*-written data (which
  lacks the field) needs a fallback value, and Avro uses the field's
  declared `"default"`. No default, no fallback — the registry rejects it.
- **Removing a required (no-default) field is unsafe** by the mirror
  argument: any reader still expecting that field has nothing to populate
  it with. (Removing a field that *does* have a default is generally safe —
  "does the field have a default" is the load-bearing detail, not "is the
  field present.")
- **Renaming without `aliases`** is structurally a remove-plus-add, and
  inherits both operations' risk. `aliases` lets a new field name also
  resolve old writer data under its previous name.
- **Widening a numeric type** (`int`→`long`, `float`→`double`) is a defined
  Avro **promotion** and is safe for `BACKWARD` (new schema reads old data
  via promotion); narrowing the other direction is not a defined promotion.

The compatibility check is, in effect, running these Avro resolution rules
against your exact old/new pair and telling you the answer before
production does.

### Self-managed vs. fully-managed connectors

Day 7's MSK Connect required you to build/download the plugin JAR, zip it,
upload to S3 as a custom plugin, create an IAM role scoped to the
connector's specific Kafka/Glue permissions, and hand-write the worker
config JSON. AWS runs the worker infrastructure; you own the plugin
artifact, its IAM identity, and its configuration correctness.

**Confluent Cloud's fully-managed connectors** move a layer higher: pick a
connector by name from a vendor-curated catalog
(`confluent connect plugin list`) — there is no plugin artifact to build or
upload at all, and auth is handled through the connector's own config
fields and Confluent's identity model rather than an IAM role you construct.
The trade-off is catalog coverage: a managed connector only exists for
integrations Confluent chose to build, so a bespoke source may have no
managed option (see Common pitfalls).

## Best practices

- **Add new fields with a default, always** — the mechanical precondition
  that makes an addition safe under `BACKWARD`, not just a style
  preference.
- **Never remove a field outright; deprecate first.** Stop writing to it,
  communicate the deprecation, wait out a real window, confirm every
  consumer has migrated, then remove. "Nobody uses this" is a claim about
  the producer's knowledge, not a fact about every reader.
- **Default to `BACKWARD` unless you have a specific reason otherwise.**
  "Will my existing consumers still read data from an upgraded producer?"
  is the most common real question, and that's exactly what `BACKWARD`
  answers. Reach for `FORWARD` only to support producers upgrading ahead of
  consumers, `FULL` only when deploy order across teams is uncontrolled.
- **Review schema changes with API-contract rigor**, because a topic
  schema *is* a contract between teams that often don't share a deploy
  pipeline — require consumer-side sign-off on any `.avsc` change, not just
  producer-team approval.
- **Check a connector's actual configuration surface before committing to
  it**, not just its catalog name/category.

## Common pitfalls

- **Treating compatibility checking as busywork to route around.** Loosening
  compatibility settings to get past a rejection removes the exact
  mechanism that turns "a deploy silently breaks every consumer" into "a
  deploy fails a pre-merge check" — it doesn't remove the risk.
- **Assuming "nobody uses this field" is sufficient evidence.** A producer
  team can see its own code and registered consumer groups, not every
  reader's internal deserialization logic — downstream ETL jobs and
  one-off scripts included. That gap is exactly what the Worked example
  below closes with verification instead of assumption.
- **Picking a managed connector by catalog name alone.** A listing like
  "Postgres CDC Source" can still miss a specific auth method, type
  mapping, or required transform your integration needs — visible only in
  the connector's actual config reference, not its one-line description.
  Discovering the gap mid-integration is expensive; checking upfront is
  cheap.

## Real-world use cases

1. **Schema Registry as the literal contract between uncoordinated teams.**
   An orders team and three independent downstream consumers (billing,
   analytics, fraud) share no release calendar. The compatibility check
   lets the producer ship autonomously while consumers trust anything
   already registered keeps working — no standing cross-team review needed.
2. **Managed connector for a common SaaS integration.** A well-supported
   source (e.g. a standard Postgres CDC feed) with an existing
   Confluent-managed connector — building a custom MSK Connect plugin for
   the same thing is pure overhead with no compensating benefit.
3. **Self-managed when the integration is bespoke.** An internal,
   home-grown system with no catalog entry anywhere — the choice isn't
   "managed vs. self-managed," it's "self-managed, or skip Connect and
   write a bespoke producer/consumer instead."

## Worked example: verifying a "safe" field removal

**Request:** the orders producer team opens a PR removing `amount` from
`Order`: "our code hasn't read it in months, should be safe to drop."

1. **Check the subject's compatibility mode** (`confluent schema-registry`
   subject config for `orders-value`) — `BACKWARD`, `FORWARD`, or `FULL`
   determines what direction is actually enforced.
2. **Check whether `amount` has a default.** In today's lab schema it does
   not — a plain `"double"`. Removing it is a required-field removal with
   no fallback, exactly the unsafe case from Theory.
3. **Don't stop at "the registry would reject it" — find who actually
   reads it.** A rejection confirms the change is unsafe in the abstract; it
   doesn't tell you who breaks. List `orders`' registered consumer groups
   and check what schema version each is pinned to — a producer team can
   forget a field an old consumer code path still depends on.
4. **Test the real registration**, not just reasoning about it — attempt
   it against a non-prod subject or compatibility-test endpoint and observe
   the actual accept/reject.
5. **If unsafe, propose deprecation instead of a flat no**: give `amount` a
   default if semantically acceptable, set a timeline, confirm every
   identified consumer has migrated, remove later once it's actually safe.

## Exercises

1. A team adds `shippingAddress` to `Order` with no `default`. Under
   `BACKWARD`, accepted or rejected? Why?
2. Renaming `customerId` to `custId`, no `aliases` added. Safe or unsafe
   under `BACKWARD`? Justify in terms of what an old-schema reader does
   with new-schema data.
3. Widening `amount` from `"int"` to `"long"`. Safe or unsafe under
   `BACKWARD`?
4. A topic has three consumer teams that coordinate deploys with no one.
   Which compatibility mode should the subject use by default, and why?
5. True or false: an accepted registration guarantees no currently-running
   consumer will ever throw a deserialization error against that schema's
   data.
6. Name one factor pushing you toward a Confluent-managed connector and one
   pushing you toward a custom MSK Connect plugin.

## Answers

1. **Rejected.** A new-schema reader decoding old-written data (lacking the
   field) needs a fallback value; with no default declared, none exists.
2. **Unsafe.** Without `aliases`, the checker treats this as removing
   `customerId` (unsafe — no default) plus adding required `custId` (also
   unsafe — no default). An old-schema reader expecting `customerId` in
   new-schema data finds neither the field nor a fallback.
3. **Safe.** `int`→`long` is a defined Avro promotion; a `long`-schema
   reader correctly resolves `int`-written data — exactly the direction
   `BACKWARD` checks.
4. **`FULL`.** With no coordinated deploy order across teams, you can't
   assume producers always upgrade after consumers (`BACKWARD` alone) or
   always before (`FORWARD` alone). `FULL` doesn't depend on knowing deploy
   order, at the cost of ruling out more changes.
5. **False.** The check is a structural schema-to-schema comparison; it
   doesn't inspect what any specific running consumer's code does at
   runtime, nor whether that consumer is pinned to a compatible version. A
   consumer with non-standard deserialization logic outside the registry's
   own client integration can still fail.
6. **Toward managed:** a common, well-supported pattern already in the
   catalog — no plugin to build, no IAM role to wire, faster to flowing
   data. **Toward self-managed:** a bespoke integration (internal system,
   unusual auth, unsupported data shape) with no catalog entry to select.

## Hands-on lab

Today's lab wires up Confluent Cloud's Schema Registry and a fully-managed
connector, on Day 11's cluster:

- `kafka_practice/labs/schemas/orders-value.avsc` — the `Order` Avro
  schema used throughout. Note `amount` has no default, which is exactly
  why Step 5's "remove `amount`" exercise gets rejected, and why adding
  `discountCode` with `"default": ""` is accepted.
- `kafka_practice/labs/src/main/java/com/kafkapractice/AvroProducerDemo.java`
  — the Java-track Avro producer, using `KafkaAvroSerializer` against the
  registry endpoint in `confluent-sr.properties`.
- `kafka_practice/labs-go/cmd/avroproducerdemo/` — the Go-track equivalent,
  using `confluent-kafka-go`'s Schema Registry client. If it doesn't exist
  yet in your checkout, it may still be landing from parallel work; use the
  Java track meanwhile.

Follow **Day 12** in
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` for
the exact `confluent` CLI sequence — enabling Schema Registry, API keys and
`confluent-sr.properties`, registering the schema, running the Avro
producer, the evolution exercise, and the fully-managed Datagen connector.
This document is the *why*; the plan has the exact commands — work from it
directly rather than duplicating them here.

## Journal template

```
## Day 12 — Schema Registry & managed Connect
Key idea in my own words: ...
What confused me: ...
```
