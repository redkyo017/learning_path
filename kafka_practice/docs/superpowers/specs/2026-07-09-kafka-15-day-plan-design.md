# 15-Day Kafka Mastery Plan

**Date:** 2026-07-09
**Status:** Approved design

## Purpose

Reach production-credible Kafka competence in 15 days (5–6 hours/day, ~80–90
hours total) for an integration/infrastructure role that owns queue systems and
messaging infrastructure. The goal is administration and integration fluency —
able to secure, operate, and integrate against a Kafka cluster — not just the
ability to write producer/consumer application code. The plan is anchored
against the **Confluent Certified Administrator for Apache Kafka (CCAAK)** exam
objectives as an external scope check: this aligns tighter with cluster
operations, security, Kafka Connect, and monitoring than the Developer-track
certification. Day 15 ends with a self-administered, closed-book practice exam.

## Learner context

- Background: adjacent distributed-systems / message-broker experience, plus
  some direct Kafka exposure, but shaky depth on internals (replication, ISR,
  rebalancing, exactly-once semantics).
- Role: integration team, responsible for queue systems and messaging
  infrastructure. Primary motivation is fast, job-relevant catch-up; secondary
  motivation is longer-term specialization in streaming data platforms.
- Strong Go background, light Python, but the employer's primary stack is Java
  Spring Boot — so lab code is written in Java, which also transfers directly
  to Kafka Streams and Kafka Connect plugin development (both JVM-native).
- Explicit requirement: full coverage across cluster architecture/internals,
  security & operations, Kafka Connect/integration, and stream processing — no
  topic dropped, even though 15 days is aggressive. Time management across
  topics is the learner's responsibility; the plan should be comprehensive
  rather than pre-trimmed.
- Hands-on environments: local Docker first, then AWS MSK (matches the
  employer's cloud provider), then Confluent Cloud (career breadth). Personal
  AWS and Confluent accounts exist; cost must be minimized via free tiers and
  explicit teardown steps.

## Structure — four phases, environment complexity ramps as concepts solidify

Rather than jumping straight to a managed cloud platform, the plan builds core
concepts on free, fast-iteration local infrastructure first, then carries the
same skills onto increasingly production-like environments. This mirrors the
proven structure of the learner's linear algebra plan: complexity ramps step by
step, and environment switches happen only after the underlying concept is
already solid.

| Phase | Days | Environment | Focus |
|---|---|---|---|
| 1. Foundation | 1–5 | Local Docker | Core internals, producer/consumer semantics, rebalancing, log/replication mechanics, security fundamentals (SASL/mTLS/ACLs) |
| 2. Company platform | 6–10 | AWS MSK | Provisioning, IAM auth, Kafka Connect/integration, monitoring, multi-region/DR, scaling |
| 3. Career breadth | 11–13 | Confluent Cloud | Comparative cluster admin (RBAC vs IAM), Schema Registry, Kafka Streams/ksqlDB |
| 4. Capstone | 14–15 | Local Docker | End-to-end integration project + closed-book CCAAK-style practice exam |

**Language:** Java for all client, Streams, and Connect code — direct transfer
to the employer's Spring Boot stack, and required for Kafka Streams and Connect
plugin development regardless of prior language background.

**Interface style:** CLI-first for administration tasks (`kafka-topics.sh`,
`kafka-consumer-groups.sh`, `kafka-configs.sh`, etc.), not GUI tools. Typing the
actual commands builds a mental model that transfers to any environment,
including ones without a GUI — which is most real incident response.

**Cost control:** The MSK phase uses the smallest viable broker sizing (or MSK
Serverless) and runs only for the 4 days it's actually needed (Days 6–9),
torn down immediately at the start of Day 10's review rather than left running
into the Confluent phase. The Confluent phase runs inside free-tier credits and
is torn down at the end of Day 13. Neither cluster is provisioned before it's
needed or kept running past the phase that uses it — the multi-day windows
(Days 6–9, Days 11–13) are the accepted cost trade-off for not rebuilding a
cluster from scratch every morning; if spend during that window becomes a
concern, scale broker count/size down further before shortening the window.

## Daily rhythm

**Content day**, ~5-hour block:

- **0:00–0:20 — Primer from primary sources.** Read the relevant Apache Kafka
  or Confluent documentation, or the governing KIP, directly — not a blog
  summary. Secondary sources paraphrase and drift from the actual semantics
  (exactly-once semantics is one of the most commonly misexplained concepts in
  the ecosystem); primary sources are what a production incident actually gets
  debugged against.
- **0:20–1:30 — Hands-on build/config.** Stand up or configure the day's
  cluster feature.
- **1:30–2:15 — Deliberate-failure lab.** Break the thing on purpose (kill a
  broker mid-write, force a rebalance storm, revoke an ACL mid-session) and
  diagnose what happens. This is the highest-leverage technique in the plan:
  reading about a failure mode builds recognition; causing and debugging it
  builds instinct.
- **2:15–2:30 — Break.**
- **2:30–3:30 — Integration coding.** Java producer/consumer/Streams/Connect
  work tied to the day's concept.
- **3:30–4:00 — Teach-it-back.** Write the day's concept as an incident
  postmortem or onboarding-doc paragraph, as if explaining it to a teammate who
  just paged about it at 2am. This forces retrieval and exposes gaps
  immediately — far more diagnostic than re-reading notes.
- **4:00–4:30 — Journal entry, CCAAK domain checklist tick, and a save point**
  (the learner handles their own version control; this step is just "make sure
  today's work is captured somewhere durable").

**Review day** (end of each phase — Days 5, 10, 13): no new primer or new
build. Entirely closed-book mixed problems from the phase's days, plus
re-derivation of anything flagged in the journal, then the phase's cloud
teardown if applicable.

## 15-day sequence

| Day | Environment | Focus |
|---|---|---|
| 1 | Docker | Kafka's log/partition model vs. generic pub/sub (RabbitMQ/SQS mental models are explicitly contrasted and discarded here); brokers, topics, partitions, offsets, replication factor, ISR, leader/follower. CLI-first single- and multi-broker cluster setup. |
| 2 | Docker | Producer/consumer semantics: delivery guarantees (at-least-once, at-most-once, exactly-once), idempotent producer, acks, partitioning/key strategy and its consequences. Java client labs. |
| 3 | Docker | Consumer groups & rebalancing: partition assignment strategies (eager vs. cooperative-sticky), offset management, consumer lag. **Chaos lab: force a rebalance storm by rapidly joining/leaving consumers; observe and diagnose the lag spike.** |
| 4 | Docker | Log internals: segments, retention vs. compaction, `min.insync.replicas`, unclean leader election. **Chaos lab: kill a broker mid-write and induce an under-replicated partition; recover it.** |
| 5 | Docker | Security fundamentals: SASL/SCRAM, mTLS, ACLs on the local cluster. **Chaos lab: deliberately misconfigure an ACL and diagnose the resulting auth failure.** Phase 1 closed-book review of Days 1–4. |
| 6 | AWS MSK | Provisioning a secured cluster: IAM auth, VPC/security groups, minimal-cost broker sizing (or MSK Serverless). |
| 7 | AWS MSK | Kafka Connect & integration patterns: MSK Connect, source/sink connectors (e.g. S3 sink, JDBC source), schema registry — the core "integration team" skill. |
| 8 | AWS MSK | Monitoring & operations: CloudWatch metrics, JMX/Prometheus exporter, alerting on consumer lag and under-replicated partitions, capacity planning. |
| 9 | AWS MSK | Multi-region/DR & scaling: MirrorMaker2 replication, adding brokers/partitions, rolling upgrades. **Chaos lab: simulate a broker failure in MSK and drive the recovery.** |
| 10 | AWS MSK | Phase 2 closed-book review (cluster admin, security, Connect, monitoring, DR) covering Days 6–9, then **full teardown of all AWS resources.** |
| 11 | Confluent Cloud | Setup + comparative cluster admin: RBAC vs. IAM/ACLs, Confluent CLI, active tracking of free-tier usage. |
| 12 | Confluent Cloud | Schema Registry (Avro/Protobuf, schema evolution rules) and fully-managed Kafka Connect. |
| 13 | Confluent Cloud | Kafka Streams (Java) and ksqlDB: build one stateful, windowed-aggregation stream-processing app. Phase 3 closed-book review, then **teardown of all Confluent Cloud resources.** |
| 14 | Local Docker (no cloud resources needed) | Capstone: design and build one end-to-end pipeline (source connector → topic → stream processing → sink connector) touching security and monitoring, with every design decision traceable to a specific Day 1–13 concept. |
| 15 | — | Self-administered, closed-book CCAAK-style practice exam, followed by gap analysis against the full 15-day journal and the CCAAK domain checklist below. |

## Unconventional strategies (what the plan deliberately does differently)

| Strategy | Why it works |
|---|---|
| Primary sources over blog summaries | Blog posts paraphrase and frequently misstate subtle semantics (exactly-once semantics being the canonical example). Reading the actual docs/KIPs avoids inheriting someone else's misunderstanding. |
| Break things on purpose (chaos labs) | Passive reading about "what happens when a broker dies" builds recognition, not instinct. Causing it and watching the cluster react builds the pattern-matching that real debugging requires. |
| CLI-first, GUI-never during learning | GUI tools hide the actual commands and config flags being sent. Typing them builds a mental model that transfers to any environment, including ones without a GUI — which is most production incident response. |
| Teach-it-back instead of re-reading | Forces retrieval and exposes gaps immediately, instead of the false confidence of "I remember reading that." |
| Certification objectives as a scope boundary | Replaces the guesswork of "have I gone deep enough" with an external, industry-validated checklist. |
| Security and cost-control from Day 1, not bolted on later | Beginners commonly treat auth and cost limits as an afterthought, then get blocked when MSK/Confluent enforce them by default. Practicing both locally first makes them a habit before the cloud phases. |

## Mistakes this plan is designed to block

| Mistake | Why it wastes time | How the plan blocks it |
|---|---|---|
| Mental model borrowed from RabbitMQ/SQS ("it's just a queue") | Leads to wrong assumptions about ordering guarantees, delivery semantics, and consumer groups — the most common confusion for people with adjacent message-broker experience | Day 1 explicitly contrasts Kafka's log/partition model against generic pub/sub before anything else is introduced |
| Ignoring partitioning/key strategy until it causes hot partitions in production | Silent performance/ordering bugs that only surface at scale, long after "producer basics" is considered done | Day 2 makes partition key choice and its consequences a hands-on lab, not a paragraph of theory |
| Shaky understanding of consumer offsets & rebalancing | The most common source of "messages got lost or duplicated" confusion; most tutorials wave their hands here | Day 3 is dedicated to rebalancing, including a deliberate rebalance-storm chaos lab |
| Treating security as an afterthought | Local practice with no auth builds habits that break the moment MSK/Confluent enforce IAM/RBAC by default | Day 5 secures the local cluster before any cloud platform is touched |
| Producer/consumer code fluency with zero cluster-admin command fluency | Can write an application but can't diagnose or operate the cluster it depends on — exactly backwards for an infrastructure role | CLI-first admin commands are used every day starting Day 1, not deferred to an "ops week" |
| No cost/teardown discipline in cloud experimentation | Either a surprise bill, or fear of touching cloud resources at all, which kills hands-on practice | Explicit teardown step at the end of every MSK day (Day 10) and every Confluent day (Day 13) |
| Building Kafka Streams apps before core producer/consumer/broker semantics are solid | Streams' abstractions (topology, state stores) are much harder to reason about without the underlying model, leading to cargo-culted code | Streams/ksqlDB is deliberately placed last (Day 13), after 12 days of foundation |

## CCAAK domain overlay

A lookup/checklist cross-referencing the day-by-day plan against CCAAK exam
domains — not the plan's primary sequencing axis, but a fast way to jump around
or verify coverage before the Day 15 practice exam. Domain names are
approximate; verify against Confluent's current official exam guide before Day
15, since exam objectives can change.

| CCAAK exam domain (approximate) | Covered by |
|---|---|
| Kafka fundamentals & architecture | Days 1, 4 |
| Cluster configuration & deployment | Days 1, 6, 9 |
| Security | Days 5, 6, 11 |
| Monitoring & operations | Days 8, 10 |
| Kafka Connect | Days 7, 12 |
| Multi-cluster / disaster recovery | Day 9 |

Use this table during the Day 15 gap analysis: for any domain where the
practice exam exposes a weak spot, trace it back to its day and redo that
day's chaos lab before considering the plan complete.

## Success criteria

- Can stand up a secured (SASL/mTLS or IAM-authenticated) Kafka cluster from
  scratch on both Docker and MSK, without notes.
- Can diagnose and recover from each of the four chaos labs (broker kill,
  rebalance storm, under-replication, ACL misconfiguration) by reasoning from
  first principles, not memorized steps.
- Can configure at least one working source connector and one working sink
  connector end-to-end, including schema registry integration.
- Passes the Day 15 self-administered CCAAK-style practice exam closed-book.
- Can produce a teach-it-back explanation (postmortem-style) for every major
  concept from the 15 days without referring to notes.

## Out of scope (deliberately deferred)

- Kafka Streams/ksqlDB depth beyond the one working app built on Day 13 — full
  stream-processing mastery is a separate follow-on track, not part of this
  15-day sprint.
- KRaft internals beyond a conceptual understanding (no hand-building a KRaft
  controller quorum from scratch).
- Non-Java client ecosystems (Go, Python), despite the learner's Go background
  — deliberately excluded to avoid diluting the 15 days. A reasonable fast
  follow-on, since Kafka concepts transfer directly across client languages
  once the underlying model is solid.
- Confluent-specific enterprise features outside the free tier (e.g. Cluster
  Linking, Tiered Storage beyond defaults).
