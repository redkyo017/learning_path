# Day 9 — Multi-Region DR & Scaling: MirrorMaker2, Broker Scaling, Rolling Upgrades

## Learning objectives

By the end of today you should be able to:
- Explain why cross-cluster replication is a distinct problem from
  within-cluster replication, and name three concrete reasons a team stands
  up MirrorMaker2 (disaster recovery, cluster migration, data aggregation).
- Explain MirrorMaker2's default topic-renaming convention and why it exists
  (loop prevention, provenance for consumers).
- Explain why offset translation is necessary, and why it's approximate.
- State why adding partitions is usually the first scaling lever, versus
  adding brokers, and what "adding brokers" actually requires to pay off.
- Read a mirroring pipeline's consumer-group lag as a distinct health signal
  from source/target cluster health, and diagnose a broker-reboot lag spike
  without panicking.
- Connect `min.insync.replicas` (Day 4) to why a one-broker-at-a-time rolling
  upgrade is actually safe.

## Reference material

- **MirrorMaker2 / KIP-382** — the `KIP-382: MirrorMaker 2.0` proposal is the
  primary source for cluster aliasing, the default `DefaultReplicationPolicy`
  topic-naming scheme, checkpoint-based offset translation, and consumer-group
  replication.
- **Apache Kafka docs: Geo-Replication (Cross-Cluster Data Mirroring)** —
  operator-facing page for `mm2.properties` syntax, `connect-mirror-maker.sh`,
  and MM2's internal topics (`mm2-offset-syncs.*`, heartbeat, `checkpoints.*`).
- **AWS MSK docs: updating broker count/type, rebooting brokers** — the
  `update-broker-count`, `update-broker-type`, and `reboot-broker` pages,
  which frame today's scale-up exercise and chaos lab in MSK-specific terms.

## Theory

### Why cross-cluster replication exists at all

Day 4's ISR replication answers "what happens if one broker in my cluster
dies?" — leader/followers all live in the *same* cluster, sharing one
controller and one offset space. It does not answer:

- **Disaster recovery across regions/providers.** If a whole region or
  account goes down, not just one broker, you need an independent second
  cluster elsewhere with the data already on it. ISR never leaves the
  cluster, so it can't help here.
- **Migrating between clusters.** Moving to MSK, changing accounts, or
  upgrading to an incompatible config all require getting existing data from
  cluster A to cluster B without downtime.
- **Aggregating data from independent clusters.** Central analytics or
  monitoring clusters often need a subset of topics fed in from several
  otherwise-unrelated clusters.

**MirrorMaker2 (MM2)** is Kafka's tool for all three. It replicates topic
data **between two independent clusters** — separate brokers, separate
offsets, separate consumer groups, no shared controller. It is built on
Kafka Connect: a source connector on the target side consumes from the
source cluster and produces into the target cluster as an ordinary client.
There is no cluster-peering protocol; Kafka's internal replication protocol
never crosses that boundary at all.

### The topic-renaming convention, and why it exists

By default MM2 prefixes a mirrored topic with the **source cluster's
alias**: `orders` on cluster `msk` becomes `msk.orders` on the target. This
solves two real problems:

1. **Loop prevention in bidirectional replication.** With `msk->docker` and
   `docker->msk` both enabled, an unrenamed topic would mirror back and
   forth forever. Tagging each topic with its origin lets
   `DefaultReplicationPolicy` recognize "this already came from `docker`,
   don't send it back" — breaking the cycle with no extra coordination.
2. **Provenance for consumers.** A consumer reading `msk.orders` knows
   unambiguously where the data came from, distinct from any natively
   produced `orders` topic. This matters most in aggregation setups where a
   central cluster ingests `region-a.events`, `region-b.events`, etc.

Cost: a consumer expecting a literal `orders` topic on the target finds
nothing there unless it's pointed at `msk.orders` — a frequent failover-drill
surprise (see Pitfalls).

### Why offset translation is necessary — and only approximate

Source and target are independent logs, so the same logical message has
different offsets on each side (e.g. offset 4500 on source, 3120 on target,
interleaved differently). Failing a consumer group over from the source to
`msk.orders` means its committed source offset (4500) is meaningless in the
target's offset space.

MM2 solves this with **offset translation**: alongside mirroring messages, it
writes checkpoint records mapping source offsets to target offsets, and a
`MirrorCheckpointConnector` uses that mapping to translate a consumer group's
offsets across clusters, so a failover doesn't mean "restart from the
beginning" or "restart from an arbitrary point."

The caveat: translation is **approximate**, built on periodic checkpoints,
not an exact per-message mapping. A failed-over consumer can land slightly
before or after its true position, meaning a small window of reprocessing
(rarely, a small gap) — this is expected, and it directly bounds what RPO
promise you can honestly make (see Real-world use cases).

### Why partitions, not brokers, are the first scaling lever

- **Adding partitions** (`--alter --partitions N`) is a near-instant,
  metadata-only change: the controller assigns the new partitions among
  *existing* brokers, and no existing data moves. Cheap, fast — the default
  first move when a topic needs more parallelism.
- **Adding brokers** rebalances nothing by itself. A new broker starts with
  zero partitions; every existing partition is still on the brokers that
  existed before it joined. Using the new capacity requires a **partition
  reassignment** (`kafka-reassign-partitions.sh` or MSK's managed version),
  which physically copies replicas onto the new broker — real I/O, real
  wall-clock time.

So scaling almost always starts with partitions before brokers, because one
is instant metadata and the other is a data-migration project. Partition
increases aren't free either — they permanently change `hash(key) mod N`
(Day 2) for every existing key.

## Best practices

- **Test failover before you need it in a real incident.** A DR pipeline
  never actually failed over to is a hypothesis, not a plan — today's
  broker-kill lab is a small rehearsal of that discipline.
- **Monitor the mirror's own consumer-group lag as a distinct signal.** A
  healthy source and healthy target can still have a badly lagging mirror
  (too few MM2 tasks, cross-region bandwidth limits); that lag number is your
  real-time RPO exposure, not source/target health.
- **Size partition counts with growth in mind.** Repartitioning keyed topics
  later isn't free — it changes the key-to-partition mapping — so headroom
  up front avoids a forced tradeoff later.
- **Rolling-upgrade safety comes from `min.insync.replicas`, not the word
  "rolling."** Verify the setting protects you before trusting the
  procedure.

## Common pitfalls

- **Assuming MM2 is synchronous.** It's an async Connect pipeline; there is
  always some lag between a source write and its target-side appearance.
  That lag *is* your RPO — not zero.
- **Treating offset translation as exact.** It's checkpoint-based and
  approximate; failover means reprocessing a small window, not a perfect
  resume. Downstream systems still need their own idempotency (Day 2).
- **Forgetting the topic is renamed.** A runbook that says "read `orders` on
  the DR cluster" finds nothing unless it accounts for `msk.orders`.
- **Assuming "rolling" is automatically safe.** With `min.insync.replicas=1`
  or RF=1, taking down one broker at a time can still zero out a partition's
  effective durability if the ISR had already shrunk beforehand. The
  guarantee comes from Day 4's ISR mechanics, not the rolling procedure.
- **Conflating the two scaling levers.** New partitions land on existing
  brokers unless broker count also grows; a new broker gets no partitions
  until a reassignment runs. Assuming either does the other's job
  automatically is a common "added capacity, nothing got faster" surprise.

## Real-world use cases

- **Justifying cross-region MM2 in RPO/RTO terms.** Instead of "it
  replicates data," give numbers: "our MM2 lag is typically under 5 seconds,
  so our RPO is seconds, not the hours a nightly backup would give; RTO is
  bounded by how fast we redirect traffic and translate offsets, not by a
  restore job." That's what lets non-Kafka stakeholders evaluate the DR
  posture against their actual requirements.
- **Justifying a rolling-upgrade maintenance window.** With RF=3 and
  `min.insync.replicas=2`, taking one broker down at a time never drops a
  partition below its durability floor — the other two replicas keep serving
  reads and `acks=all` writes. That mechanism, not just "it's safer," is what
  justifies a week-long staged upgrade over one all-at-once weekend.
- **Explaining a lag spike during a scheduled reboot without raising a false
  alarm.** An on-call engineer needs to distinguish expected, self-healing
  behavior tied to a planned reboot from a genuinely new problem — exactly
  the call the worked example below walks through.

## Worked example

Scenario: MM2 is mirroring `orders` from the `msk` source cluster to
`msk.orders` on the target. A scheduled reboot hits one MSK broker mid-
replication. Dashboards show MM2's lag tick up briefly, then recover with no
manual intervention.

1. **Reboot begins.** Partitions led by that broker stop responding to
   in-flight requests — including MM2's own fetches, since MM2 is just an
   ordinary consumer against the source.
2. **Leader failover on the source.** The controller detects the broker is
   gone and elects a new leader from the remaining ISR members per affected
   partition, automatically, within seconds — the same mechanism from Day 4.
3. **Transient under-replication.** Until the broker returns, affected
   partitions show a shrunk ISR (what the lab's `--describe` watch loop
   surfaces). As long as `min.insync.replicas` is still met, reads and
   writes continue normally — not a durability violation.
4. **MM2's consumer retries.** It hits the same `NOT_LEADER_OR_FOLLOWER`/
   timeout errors any consumer would, and the standard client retry +
   metadata-refresh logic (same as any consumer since Day 2) finds the new
   leader and resumes — no MM2-specific failure handling needed.
5. **Lag ticks up, then drains.** While MM2 was blocked, the source kept
   accepting other writes, widening the gap between latest-source-offset and
   latest-mirrored-offset — the visible spike. Once MM2 resumes, it consumes
   faster than new data arrives and catches up on its own.
6. **Why no intervention was needed.** Every step — election, retry,
   catch-up — is ordinary Kafka client/broker behavior; MM2 inherits it for
   free by being built as a normal Connect consumer/producer pair. Manual
   action would only be needed if ISR fell below `min.insync.replicas` (writes
   start failing) or the broker never came back (needing replacement).

## Exercises

1. A teammate says: "Mirroring means our data's basically always in sync, so
   RPO isn't something we need to worry about." What's wrong, and what
   should you ask them to measure instead?
2. With bidirectional MM2 between `cluster-a` and `cluster-b`, a message is
   produced to `orders` on `cluster-a`. What topic name does it land under on
   `cluster-b`, and why doesn't it bounce back and forth forever?
3. A consumer group was at offset 88,204 on the source when it went
   unreachable. Beyond changing bootstrap servers, name two things that must
   be handled for failover to the mirrored topic to work.
4. A 6-partition topic is nearing its throughput ceiling. What's the first
   thing to check before adding a broker, and why is it cheaper/faster?
5. A cluster has RF=3 and `min.insync.replicas=1`. Someone calls a
   one-broker-at-a-time rolling upgrade "safe because it's rolling." What's
   the flaw?
6. During a scheduled reboot, MM2's lag rises from near-zero to a few
   thousand messages, then falls back to near-zero over two minutes, no
   errors logged, no manual action taken. Page someone? Why or why not?

## Answers

1. "In sync" implies synchronous replication; MM2 is async, so there's
   always some lag, and that lag *is* the RPO. Ask them to measure and track
   MM2's own consumer-group lag under normal load instead of assuming zero.
2. `cluster-a.orders`. `DefaultReplicationPolicy` sees the topic name already
   carries the `cluster-a.` origin tag when considering whether to mirror it
   from `cluster-b` back toward `cluster-a`, and skips it — that's the
   loop-prevention role of the renaming convention. It never nests further.
3. (a) Point the consumer at the renamed topic (`msk.orders`, not `orders`);
   (b) seed the group's offsets from MM2's checkpoint-based translation of
   88,204 rather than `auto.offset.reset` defaults — and still expect to
   reprocess a small window, since translation is approximate.
4. Check whether adding partitions (e.g. 6 to 12) solves it — a near-instant
   metadata change with no data movement, versus adding a broker, which
   contributes nothing until a partition reassignment physically moves
   replicas onto it.
5. Safety comes from `min.insync.replicas`, not "rolling." With
   `min.insync.replicas=1`, an ISR that had already shrunk before the
   upgrade began can leave a partition durable via only the one broker about
   to be restarted. Bump it to at least 2 (per Day 4) before trusting the
   procedure.
6. No page needed, based on what's described. This is exactly the expected
   pattern: leader failover causes MM2's consumer to retry, lag builds while
   blocked, then drains once the new leader is available. Signals that
   *would* warrant paging: lag that never recovers, persistent (not
   transient) errors in the MM2 logs, or a reboot that wasn't scheduled.

## Hands-on lab

The full steps — bringing the Docker cluster back up, writing
`kafka_practice/mm2/mm2.properties`, running `connect-mirror-maker.sh`,
verifying replication via `msk.orders`, the broker-failure chaos lab against
MSK (`aws kafka reboot-broker`), the partition scale-up exercise, and the
rolling-upgrade journal writeup — are specified with exact commands in
**Day 9** of `kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`;
the config file itself already exists at `kafka_practice/mm2/mm2.properties`.

Note before starting: MirrorMaker2 has no per-language client. Unlike the
Producer/Consumer demos (Java, and possibly a parallel Go track), MM2 is a
Kafka Connect–based tool run via `connect-mirror-maker.sh` from the Kafka
distribution, regardless of which language track your own lab code uses.
There's nothing to port to Go here — today is entirely about configuring and
operating that one tool against your Day 6 MSK cluster (source) and Day 1–5
Docker cluster (target).

## Journal template

```
## Day 9 — Multi-region DR & scaling
Key idea in my own words: ...
What confused me: ...
```
