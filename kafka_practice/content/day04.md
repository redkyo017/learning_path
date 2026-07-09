# Day 4 — Log internals, replication guarantees, broker-kill chaos lab

## Learning objectives

By the end of today you should be able to:
- Explain what a log segment is, why segments roll over, and why that
  design bounds recovery and indexing cost.
- Distinguish `cleanup.policy=delete` (retention) from
  `cleanup.policy=compact` (compaction) and state which topics should use
  which.
- State precisely what durability guarantee `acks=all` +
  `min.insync.replicas=N` provides — and what it does not provide.
- Explain what unclean leader election is, why it is disabled by default,
  and what data loss it would cause if enabled.
- Read `kafka-topics.sh --describe` output and correctly interpret
  `Replicas` vs. `Isr` during a broker outage.

## Reference material

- Kafka docs, **Log Compaction** — https://kafka.apache.org/documentation/#compaction
- Kafka docs, **Topic Configs** — https://kafka.apache.org/documentation/#topicconfigs
  (focus: `retention.ms`, `retention.bytes`, `segment.bytes`, `segment.ms`,
  `cleanup.policy`, `min.cleanable.dirty.ratio`)
- Kafka docs, **Broker Configs**, replication section —
  https://kafka.apache.org/documentation/#brokerconfigs (focus:
  `min.insync.replicas`, `unclean.leader.election.enable`,
  `default.replication.factor`)

You already have `min.insync.replicas=2` set on the Day 1 cluster (Day 2's
compose file); today you find out what that number actually buys you.

## Theory

### What a log segment actually is

A partition is not one giant file. On disk it's a **directory** (e.g.
`orders-0/`) containing a sequence of **segments**, each a triple of files
sharing a base offset as their name: `<base-offset>.log` (the actual
record batches, append-only), `<base-offset>.index` (offset →
byte-position index into the `.log`, so a fetch doesn't scan from the
start of the segment), and `<base-offset>.timeindex` (timestamp → offset,
for time-based lookups and retention).

Only the **active** (newest) segment is open for writes; every older one
is immutable. A segment rolls over — closed, new active segment opened —
when either threshold hits, whichever comes first: `log.segment.bytes`
(default 1 GiB, "too big") or `log.segment.ms` (default 7 days, "too old").

This is what makes log management tractable: **deletion is cheap** (unlink
a whole closed segment file once every record in it is past retention,
never an in-place rewrite of a live file); **compaction is cheap and
incremental** (the cleaner rewrites one segment, or a contiguous eligible
range, at a time, not the whole partition in memory); and **crash
recovery is bounded** (only the active segment's index needs rebuilding on
restart). Segment size is a tunable trade-off: smaller segments become
deletable/compactable sooner but add file-handle/index overhead; larger
ones amortize that overhead but delay reclaiming space.

### Retention vs. compaction: two different cleanup policies, two different topic shapes

`cleanup.policy` controls what happens to segments once they age out of
the *active* one. There are two policies (they can technically be
combined, but that's unusual):

**`cleanup.policy=delete` (default) — retention.** Once every record in a
closed segment is older than `retention.ms` (default 7 days) *or* total
partition size exceeds `retention.bytes` (default unlimited), the whole
segment file is unlinked. This is bulk, segment-granularity deletion —
Kafka never deletes individual records, only whole aged-out files. Right
policy for **event streams** (orders, clicks, sensor readings): an
unbounded sequence of independent facts where "keep the last N days/GB"
is the desired semantics.

**`cleanup.policy=compact` — compaction.** Instead of deleting by age, the
cleaner periodically rewrites eligible segments to keep only the **most
recent record per key**, discarding every earlier record for that key.
Read such a topic from the beginning and you eventually see exactly one
(latest) record per key — a snapshot of current state, not a full change
history. Right policy for **changelog / latest-state topics**: "current
customer profile," "current price per SKU," Kafka Streams' own internal
state-store changelogs. Rebuilding a `KTable` from one of these gives
correct current state without replaying every historical update.

Two practical wrinkles: compaction isn't instantaneous — the cleaner only
compacts a segment once its dirty ratio (uncompacted bytes / total) passes
`min.cleanable.dirty.ratio` (default 0.5), so a compacted topic can hold
superseded values right after a write burst, until the next cleaner pass.
And compaction never touches the *active* segment, so the newest writes
are always fully readable regardless of cleanup policy.

### `min.insync.replicas` + `acks=all`: what durability guarantee you actually get

Replication factor (RF) alone tells you how many copies of a partition
*exist*; it says nothing about how many must be *caught up* before a
write counts as durable. Two configs together define that:

- **`acks=all`** (producer config): the request isn't acknowledged until
  every replica currently in the ISR (in-sync replica set) has the record
  — not just the leader.
- **`min.insync.replicas=N`** (broker/topic config): the minimum ISR size
  required for a write to be accepted at all. If fewer than `N` replicas
  (leader included) are in the ISR at write time, the broker rejects it
  with `NotEnoughReplicasException` instead of accepting it.

Together: with RF=3, `min.insync.replicas=2`, an `acks=all` write is
durable once it's on at least 2 of 3 replicas. If a failure drops ISR
below 2, **new writes are refused, not silently accepted and then lost**
— the system fails closed. That's the core guarantee: trade some
availability (writes can block) for a durability floor (no acknowledged
write vanishes unless failures exceed what `min.insync.replicas` covers).

### Unclean leader election: why it's off by default

Every partition has a leader (serves all reads/writes) and followers that
replicate from it. If the leader dies, a new one is elected from the
remaining replicas — normally restricted to replicas currently in the
ISR, i.e. fully caught up. That's a **clean** election: no data is lost,
because the new leader already had everything the old one had.

`unclean.leader.election.enable` (default `false`) governs what happens
if *no* in-sync replica survives — every ISR member is down, but an
out-of-sync replica (one that had already fallen behind and dropped out
of the ISR) is still alive. Set to `true`, Kafka elects that lagging
replica anyway, to restore availability. The catch: that replica, by
definition, never received some tail of the committed log — those records
are gone, silently — no exception to the producer, consumers simply never
see them, and if the old leader later returns, its extra records get
truncated to match. This is exactly the scenario the chaos lab's Step 5
sets up (stopping enough brokers to trip `min.insync.replicas`) without
flipping this flag — the default `false` is what makes Kafka refuse to
paper over the gap and fail the write instead.

## Best practices

- **Never set `unclean.leader.election.enable=true`** where correctness
  matters more than uptime (most topics). Needing it usually signals a
  `min.insync.replicas` or cluster-sizing problem to fix instead — it's
  also a cluster-wide broker default, not something to toggle per topic
  or per incident.
- **Choose `cleanup.policy` by topic shape, not habit.** Compaction for
  "latest value per key" state; deletion-based retention for event
  streams. Compacting an event-history topic loses the history you
  wanted; time-retaining a changelog topic loses old keys' current values
  once they age out, even though they're still "current."
- **Size retention around consumer worst-case lag, not a round number.**
  `retention.ms`/`retention.bytes` should let the slowest realistic
  consumer (a batch job running every N hours, one that might be down for
  a deploy) catch up before its data disappears — "7 days because that's
  the default" is not a sizing decision.
- **Set `min.insync.replicas` deliberately relative to RF.**
  `min.insync.replicas = RF` maximizes durability but any single replica
  failure blocks writes; `= 1` sets no real floor at all (see pitfalls).
  `RF - 1` (2 of 3) is the common middle ground: tolerate one failure
  without blocking writes, still refuse writes if two fail at once.

## Common pitfalls

- **Reading a compacted topic like an ordered event log.** Compaction is
  destructive by design — superseded values are gone once cleaned, not
  just hidden. Needing full history *and* latest-state means two topics
  (or a compacted "materialized view" fed from the event stream), not one
  compacted topic doing both jobs.
- **Assuming replication factor alone prevents data loss.** RF=3 with
  `acks=1` (or `acks=0`) means the producer considers the write done as
  soon as the *leader* has it, before any follower replicates. If that
  leader dies first, the write is gone despite RF=3. Durability comes
  from `acks=all` + `min.insync.replicas`; RF alone only bounds how many
  copies *could* exist.
- **Panicking at an under-replicated-partitions alert.** URP > 0 is the
  *expected* transient state during any rolling restart or brief broker
  blip — a follower drops out of ISR, then catches up within seconds to
  minutes. What actually matters is URP staying elevated for a long
  stretch, or ISR shrinking to exactly `min.insync.replicas` (one more
  failure from blocked writes) or below — not URP being momentarily
  nonzero.

## Real-world use cases

- **"Latest customer profile" cache topic.** An integration team streaming
  profile updates into a topic a downstream service reads to populate a
  cache (or rebuild a `KTable` on startup) should compact it. With
  deletion-based retention, a customer who hasn't updated their profile
  within `retention.ms` would have their record vanish entirely — cache
  rebuilds would silently lose stale-but-still-valid customers. Compaction
  guarantees every key ever written has *some* current value indefinitely.
- **Rolling broker upgrade, done by an infra team.** Before restarting
  brokers one at a time for a patch or version upgrade, the team needs to
  know it's *safe*, not just hope so: check `min.insync.replicas` against
  RF, confirm ISR is fully caught up (URP=0) before touching the next
  broker, and pace restarts so no more than "RF − min.insync.replicas"
  brokers are ever down at once. This turns "restart and see what
  happens" into a verifiable, low-risk procedure.
- **Multi-datacenter / DR sign-off.** A platform team verifying a topic
  meets an SLA like "no acknowledged write is lost if one AZ fails" needs
  to translate that into configs: RF ≥ 3 across failure domains,
  `min.insync.replicas=2`, `acks=all` everywhere, and
  `unclean.leader.election.enable=false`. Each piece of today's theory
  maps to one line item on that checklist.

## Worked example

**Setup:** 3-broker cluster, topic `orders` with RF=3,
`min.insync.replicas=2`, all producers using `acks=all`. Broker `kafka2`
is taken down for a 10-minute OS patch.

**Immediately after `kafka2` stops:** every partition that had `kafka2` in
its replica set now has an ISR of 2 instead of 3. `kafka-topics.sh
--describe --topic orders` shows `Replicas: 1,2,3` but `Isr: 1,3` —
`Replicas` lists the assigned set regardless of liveness, `Isr` lists only
the currently caught-up, reachable ones. Any partition whose *leader* was
`kafka2` gets a clean election among the remaining ISR members (`kafka1`
or `kafka3`), visible as a new value in the `Leader` column. This is
exactly the under-replicated-partition state — `Isr` a strict subset of
`Replicas` — and it correctly fires a URP alert, but not an emergency one.

**What's guaranteed to keep working:** producers with `acks=all` keep
succeeding, since ISR size (2) still meets `min.insync.replicas` (2).
Consumers are unaffected. No acknowledged data is at risk — everything
committed had 2 live replicas.

**What a second failure would do:** if `kafka3` also fails mid-patch,
every partition that had both `kafka2` and `kafka3` as replicas drops to
ISR size 1 (just `kafka1`) — below `min.insync.replicas=2`. New produce
requests to those partitions fail with `NotEnoughReplicasException`: the
broker refuses writes it can't guarantee durable, rather than accepting
them on one copy. Existing data isn't lost and reads still work, but
those partitions are write-unavailable until `kafka2` or `kafka3` rejoins
the ISR (or `min.insync.replicas` is deliberately lowered — trading away
the durability guarantee under incident pressure, not by default).

**When `kafka2` returns:** it replicates from whichever broker is now
leader for each partition it hosts. Repeated `--describe` polling shows
`Isr` growing back to match `Replicas` as catch-up finishes — timing this
in the lab beats assuming it's instant, since it scales with how much
write volume was missed.

## Exercises

1. RF=3, `min.insync.replicas=1`, producer uses `acks=all`. The leader
   accepts a write, acknowledges it, then immediately crashes before any
   follower replicates it. Is this write actually durable? Why did
   `min.insync.replicas=1` fail to prevent the outcome you'd expect from
   "acks=all with RF=3"?
2. `--describe` shows `Replicas: 1,2,3` and `Isr: 1,2,3` for a partition,
   but `Leader` is `2`, and broker 2 was restarted 30 seconds ago. Sign of
   a problem, or consistent? Explain.
3. Compacted topic with `min.cleanable.dirty.ratio=0.01` and
   `segment.ms=100`. You produce 5 updates for the same key within 50ms,
   then immediately consume from the beginning. Guaranteed to see only
   the latest value? Why or why not?
4. In terms of segments, why doesn't deleting old data in a
   `cleanup.policy=delete` topic ever require rewriting a file that still
   contains live data?
5. On-call alert: "under-replicated partitions > 0" for `orders`. `Isr`
   has 2 of 3 for every affected partition; a rolling restart started 4
   minutes ago. Page anyone? What would make this genuinely urgent?
6. A teammate proposes `unclean.leader.election.enable=true` "just for
   the `orders` topic" so an all-brokers-down scenario won't block
   writes. What's wrong with this, technically (can it be scoped
   per-topic?) and in terms of what it trades away?

## Answers

1. **Not durable — expected, not a bug.** `min.insync.replicas=1` means
   the ISR only needs 1 replica (possibly just the leader) for a write to
   be accepted. `acks=all` only waits on replicas *currently in the ISR*
   — if the required minimum is 1, that can be the leader alone, before
   any follower replicates. RF=3 was irrelevant; only 1 replica had to ack.
2. **Consistent, not a problem.** Full ISR means every replica is caught
   up. Broker 2 as leader 30s post-restart is plausible if it re-synced
   fast, or was never out of the ISR long, and got re-elected (e.g.
   preferred-leader rebalancing). A shrunken `Isr` would be the actual
   red flag — not present here.
3. **No, not guaranteed at that moment.** The cleaner runs periodically,
   not synchronously with writes — a real gap exists between "eligible"
   and "cleaner ran." Compaction also never touches the *active* segment;
   if all 5 updates are still there, none are eligible regardless of
   dirty ratio. You'd need to wait for a cleaner pass (~30s in the lab).
4. **Segments are immutable, closed files.** `cleanup.policy=delete`
   unlinks a whole *closed segment file* once every record in it ages
   out; live data sits in separate (newer/active) files untouched by that
   op. No in-place rewrite of a file mixing old and new records — that
   per-segment boundary is what makes deletion an O(1) filesystem op.
5. **No page needed.** ISR at 2 of 3 with `min.insync.replicas=2` means
   writes still fully succeed, and a rolling restart is the expected
   cause. Urgent would be: `Isr` drops to 1, URP stays elevated well past
   when the restart should finish, or no restart is actually in progress.
6. **Two problems.** Technically, `unclean.leader.election.enable` is a
   broker-level, cluster-wide config — it can't be scoped to one topic;
   enabling it exposes every topic on that broker. Substantively, the
   trade runs backward: "writes block until replicas are healthy" (no
   data loss) becomes "writes flow but records the lagging replica never
   received vanish silently and permanently." Fix the real problem —
   right-size `min.insync.replicas` vs. RF — instead of trading
   correctness for uptime.

## Hands-on lab

Run the primer reading, log-segment inspection, compacted-topic lab, and
both parts of the broker-kill chaos lab exactly as specified in **Day 4**
of `kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`
— that file has the exact commands (`docker exec … ls`, the
`kafka-topics.sh --create --config cleanup.policy=compact …` invocation,
and the `docker stop`/`docker start` sequences for both the
under-replication test and the `NotEnoughReplicasException` data-loss
guard test), so they aren't repeated here.

The compacted producer for Step 3 is
`kafka_practice/labs/src/main/java/com/kafkapractice/CompactedProducer.java`
— it writes 5 rounds of updates for 3 keys (`user-1`..`user-3`) to the
`user-profiles` topic with `acks=all`, which is what compacts down to 3
messages once the cleaner runs. A Go port may exist at
`kafka_practice/labs-go/cmd/compactedproducer/` from parallel work on this
plan; if so it follows the same 5-rounds/3-keys pattern against the same
topic — use whichever language matches the rest of your work.

For the chaos lab parts A and B, reuse `ProducerDemo` (already built on
Day 2) as the producer under test — it already sets `acks=all`, so it's
the right tool to demonstrate both the "still works with 2 of 3 alive"
and the "fails with `NotEnoughReplicasException` at 1 of 3 alive" cases.

## Journal template

```
## Day 4 — Log internals, replication
Key idea in my own words: ...
What confused me: ...
```
