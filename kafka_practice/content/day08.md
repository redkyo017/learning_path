# Day 8 — Monitoring & Operations on MSK

## Learning objectives

By the end of today you should be able to:
- Explain what each of the five core metrics (`UnderReplicatedPartitions`,
  `OfflinePartitionsCount`, `BytesInPerSec`/`BytesOutPerSec`, `MaxOffsetLag`,
  `KafkaDataLogsDiskUsed`) actually measures, not just its name.
- Distinguish a metric indicating degraded-but-serving from one indicating an
  active outage, and alert on each accordingly.
- State the difference between CloudWatch basic, enhanced, and open
  (Prometheus/JMX) monitoring, and justify which tier fits a given cluster.
- Do a back-of-envelope storage capacity calculation from an observed
  `BytesInPerSec` figure and a retention window.
- Walk a consumer-lag page through a structured diagnostic order instead of
  guessing.

## Reference material

- MSK monitoring docs: **Enhanced Monitoring** (per-broker/per-topic/
  per-partition CloudWatch tiers) and **Open Monitoring with Prometheus**
  (JMX Exporter + Node Exporter endpoints on brokers) — the two ways MSK
  exposes metrics beyond the basic tier.
- Kafka JMX metrics reference — the underlying MBean names (e.g.
  `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions`,
  `kafka.controller:type=KafkaController,name=OfflinePartitionsCount`) that
  both enhanced CloudWatch and open monitoring ultimately expose.
- The Day 8 implementation plan for this course:
  `kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`
  (exact `aws kafka`/`aws cloudwatch`/load-generation commands; this doc is
  the theory to pair with them).

## Theory

**`UnderReplicatedPartitions`** counts partitions where at least one assigned
replica has fallen out of the ISR — it's in `Replicas` but not `Isr` because
it hasn't fetched from the leader within `replica.lag.time.max.ms` (default
30s). The partition is still fully readable/writable through its leader: you
have lost *redundancy*, not *availability*. Rolling restarts, a broker under
heavy disk I/O, or a brief network blip all cause expected, transient spikes
— it's a leading risk indicator, not proof anything is currently broken.

**`OfflinePartitionsCount`** counts partitions with **no available leader at
all**. Unlike under-replication, there's no degraded-but-serving middle
ground: a leaderless partition cannot accept produces or serve reads. Any
nonzero value is, by definition, active data unavailability for whatever
keys hash into it — the sharpest line in this metric set between "watch it"
and "it's broken right now."

**`BytesInPerSec`/`BytesOutPerSec`** are produced/consumed bytes per second,
the only metrics here that answer "how much data are we actually moving."
They're the basis for two kinds of capacity planning: storage (sustained
`BytesInPerSec` × retention = disk needed) and network/CPU (a broker must
keep up with both directions at once; `BytesOutPerSec` legitimately exceeds
`BytesInPerSec` whenever more than one consumer group reads the same topic,
since every byte is read once per group). Always pull these from observed
traffic, never estimate them.

**`MaxOffsetLag`** is the *maximum* offset lag across a consumer group's
partitions, not an average — averaging would hide a single badly-behind
partition (e.g. a hot key) behind otherwise-healthy ones. It's a pure
rate-mismatch signal: it grows whenever consumption is slower than
production, for any reason — slow downstream calls, an under-provisioned
group, a rebalance loop, or a crashed consumer. It tells you *that*
something's wrong, never *why*, which is why a lag alert always needs
follow-up investigation (see Worked example).

**`KafkaDataLogsDiskUsed`** reports per-broker disk utilization for the
volume holding log segments. Arguably the most important metric here for
avoiding a self-inflicted outage: running out of disk isn't
degraded-but-functioning, it's a broker that can no longer accept writes for
partitions it leads. It's also a slow, monotonic trend rather than a sudden
spike, which gives real lead time — exactly why it belongs in proactive
capacity planning, not just a reactive near-full alert.

**CloudWatch tiers.** *Basic monitoring* (default, free) gives cluster/
broker-level metrics at 5-minute granularity with no per-topic or
per-partition breakdown — you can't isolate which topic drives
`BytesInPerSec`, or see `MaxOffsetLag` per group at all. *Enhanced
monitoring* (`PER_BROKER` / `PER_TOPIC_PER_BROKER` / `PER_TOPIC_PER_PARTITION`)
adds 1-minute granularity and per-topic/partition dimensions for a small
incremental CloudWatch cost — this is what makes per-group `MaxOffsetLag`
and topic-scoped throughput visible at all. *Open monitoring* exposes every
native JMX MBean (plus host metrics) via a Prometheus-scrapeable endpoint on
each broker — strictly more detail than enhanced CloudWatch, and the right
choice if your org already runs Prometheus/Grafana. For anything beyond a
throwaway cluster, enhanced monitoring is close to a default-on decision:
the cost is trivial next to the cluster's own hourly cost, and basic-only
monitoring means you can't isolate which topic or group is responsible for a
problem you can already see is happening.

## Best practices

- Alert on `OfflinePartitionsCount` as page-worthy — any nonzero value
  longer than a leader-election blip is an active outage.
- Treat `UnderReplicatedPartitions` as a slower-response signal: transient
  during rolling restarts/deploys is normal; sustained (minutes) or
  recurring outside maintenance windows points to a chronically struggling
  broker and deserves investigation.
- Track `MaxOffsetLag` per consumer group as a first-class SLO input wired
  into dashboards/alerting, with thresholds derived from what "too far
  behind" means for that specific downstream — not a copied generic number.
- Capacity-plan from observed `BytesInPerSec` under real or realistic
  load-test traffic, never an assumed number.
- Run at least `PER_TOPIC_PER_BROKER` enhanced monitoring on any
  production-track cluster so per-topic throughput and per-group lag are
  visible before an incident, not discovered during one.

## Common pitfalls

- Treating every `UnderReplicatedPartitions` blip as an incident — routine
  rolling restarts cause this by design, and paging on every blip trains
  on-call to ignore the alert.
- Trusting a 1-minute-granularity dashboard over the CLI during an active
  incident. CloudWatch (even enhanced) reflects data up to a minute old plus
  dashboard refresh delay; `kafka-consumer-groups.sh --describe` gives
  current state with far lower latency. Dashboards win for trend analysis;
  CLI wins for "what's true right now."
- Sizing storage for average throughput and getting blindsided by a
  sustained peak (campaign, backfill, month-end) that runs above average for
  hours or days — long enough to matter for a metric that accumulates.
- Confusing high `MaxOffsetLag` with lost data — it's a processing-speed
  signal; the records are still durably on disk, unread by that group.
- Assuming `BytesOutPerSec` should equal `BytesInPerSec` — with N consumer
  groups reading a topic, `BytesOutPerSec` legitimately runs near N times
  `BytesInPerSec`.

## Real-world use cases

- **On-call runbook over tribal knowledge.** Writing down "check
  `OfflinePartitionsCount` first, then `UnderReplicatedPartitions`, then
  `MaxOffsetLag` for the affected group" means a 3am page gets handled the
  same way regardless of who's holding the pager.
- **Catching a downstream integration silently falling behind.** A
  partner-facing consumer calling a degrading partner API shows up as
  climbing `MaxOffsetLag` well before any customer complaint — watching the
  *trend*, not just a threshold, buys an integration team lead time.
- **Justifying a storage/retention change with data, not intuition.** When
  someone proposes extending retention or asks if broker volumes are sized
  right, the answer comes from `BytesInPerSec` trends and
  `KafkaDataLogsDiskUsed` history — the same arithmetic as the Worked
  example below, run against real cluster numbers.

## Worked example: a 3am `MaxOffsetLag` page

Paged: `msk-consumer-lag` fired, `MaxOffsetLag` for `orders-group` exceeded
1000. Diagnostic order:

1. **Is the group even running?** Check member count via `--describe` first
   — a crashed/disconnected consumer produces unbounded lag that looks like
   "just slow" but needs a restart, not a scale-up.
2. **One partition or all of them?** `MaxOffsetLag` is the worst single
   partition. Concentrated-on-one points at a hot key or a stuck instance;
   spread-evenly points at an across-the-board problem.
3. **Rebalancing or looping?** A single quick rebalance (post-deploy) is
   normal. A rebalance *loop* — members repeatedly leaving/rejoining, often
   from `max.poll.interval.ms` timeouts caused by slow per-record
   processing — shows lag climbing with churning membership. Fix upstream
   (consumer config or the slow processing), don't wait it out.
4. **Group stable but downstream slow?** With crashes and rebalance loops
   ruled out, check per-record latency (DB write, API call). Fix the
   dependency, or add consumer instances up to the partition count to
   parallelize the existing per-record cost.
5. **Genuine throughput mismatch?** If nothing downstream is slow,
   production has simply outgrown the group's provisioning. Fix is adding
   partitions and instances — a capacity decision, only reached after 1–4
   are ruled out, not guessed first.

## Exercises

1. `UnderReplicatedPartitions` spikes to 2 for ~90 seconds during a
   scheduled broker patch, then returns to 0. Should this have paged anyone?
2. `OfflinePartitionsCount` shows 1 for 10 minutes. What can/can't happen
   for that partition right now, and how does urgency compare to Q1?
3. `MaxOffsetLag` for `orders-group` sits at a stable 50 for days, then jumps
   to 40,000 and keeps climbing over 20 minutes, while member count stays
   constant. Name two plausible causes and the evidence that distinguishes
   them.
4. During an active incident, dashboard or CLI — which do you trust more,
   and why?
5. **Capacity arithmetic.** Enhanced monitoring shows sustained
   `BytesInPerSec` of 5 MB/s (5,000,000 bytes/sec) for topic `orders`.
   Retention is 7 days, replication factor 3, each broker's data volume is
   100 GB. Ignoring compaction, roughly how many days until a single 100 GB
   broker volume fills from this topic's data alone? Is 100 GB adequate
   headroom for the full 7-day window?
6. A teammate proposes basic-only CloudWatch monitoring on a production
   cluster to save cost. What capability would you concretely lose? Push
   back or not?

## Answers

1. No. A brief, self-resolving spike during *scheduled* maintenance is the
   expected side effect of followers briefly falling out of the ISR while a
   broker restarts — sustained or recurring-outside-maintenance would
   warrant a look; a 90-second blip during a planned patch doesn't.
2. The partition has no leader: no produces, no consumes, for that
   partition — active unavailability (data intact, just unreachable), not
   mere reduced redundancy. This is materially more urgent than Q1's
   transient under-replication and should already be under active
   investigation at 10 minutes.
3. (a) A downstream dependency degraded, slowing every member's effective
   rate without anyone leaving the group, or (b) a genuine upstream
   production burst outgrowing the stable-membership group. Distinguishing
   evidence: check whether `BytesInPerSec`/message rate for the topic also
   jumped at the same time. Flat production + growing lag → (a); production
   also jumped → (b). Per-record processing latency in consumer logs would
   confirm (a) directly.
4. The CLI. CloudWatch — even enhanced, at 1-minute granularity — reflects
   data up to a minute old plus dashboard refresh delay; a direct CLI query
   reflects current state with far lower latency, which is what you need for
   in-the-moment decisions. The dashboard wins once the incident is over and
   you want the shape of what happened over time, or a single view across
   many partitions/topics at once.
5. 5,000,000 bytes/sec × 86,400 sec/day ≈ 432,000,000,000 bytes/day ≈ 432
   GB/day of logical data written. Replication factor 3 triples *total
   cluster* storage need, but each broker holding a replica still stores a
   full copy of its share of partitions — so per-broker growth from this
   topic is also ~432 GB/day. A 100 GB volume fills in 100 ÷ 432 ≈ 0.23 days
   (~5.5 hours) — nowhere near covering 7 days of retention. Full 7-day
   retention at this rate needs roughly 432 × 7 ≈ 3,024 GB (~3 TB) per
   broker for this topic alone. Conclusion: shorten `retention.ms`
   drastically or grow storage roughly 30x before running this load for a
   full week.
6. You'd lose per-topic/per-partition granularity entirely: no per-group
   `MaxOffsetLag`, no way to see which topic drives `BytesInPerSec`, and 5x
   coarser (5-minute) resolution on everything else. Push back for
   production — the incremental CloudWatch cost is trivial next to running
   MSK at all, and losing that visibility means every incident starts with
   far less information than it should.

## Hands-on lab

Follow Day 8 in the implementation plan
(`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`) for
the exact `aws kafka update-monitoring`, `aws cloudwatch put-dashboard`, and
`aws cloudwatch put-metric-alarm` commands, the CLI-vs-dashboard cross-check,
and the capacity-planning step — this doc is the theory to have in mind
while you do that. Load generation reuses `ProducerLoop` from
`kafka_practice/labs/src/main/java/com/kafkapractice/ProducerLoop.java` (or
the Go equivalent at `kafka_practice/labs-go/cmd/producerloop/`, if present)
at a higher throughput than earlier days, so you have a real `BytesInPerSec`
figure to run the Exercise 5-style arithmetic against your own numbers.

## Journal template

```
## Day 8 — Monitoring & operations
Key idea in my own words: ...
What confused me: ...
```
