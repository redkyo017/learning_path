# Day 3 — Consumer Groups & Rebalancing

## Learning objectives

By the end of today you should be able to:
- Explain how a consumer group coordinator assigns partitions to group
  members, and name the concrete events that force it to redo that
  assignment.
- Distinguish eager rebalancing from cooperative-sticky rebalancing
  (KIP-429) in terms of which partitions actually stop processing during a
  rebalance.
- State precisely what consumer lag measures, and read it correctly off
  `kafka-consumer-groups.sh --describe` output.
- Explain what `group.instance.id` (static group membership) buys you, and
  when it's worth configuring.
- Given a lag-spike timeline, distinguish "a rebalance caused this" from
  "the consumer genuinely can't keep up."

## Reference material

- Apache Kafka docs: **Consumer Groups** and `partition.assignment.strategy`
  (kafka.apache.org/documentation/#consumerconfigs, plus the operations
  chapter's group-management discussion).
- **KIP-429: Kafka Consumer Incremental Rebalance Protocol** — abstract only
  (cwiki.apache.org). The abstract states the problem (stop-the-world eager
  rebalancing) and the fix (incremental/cooperative rebalancing that only
  moves partitions that must move) — that's all today's primer needs.

## Theory

### How consumer group coordination works

Every consumer group has exactly one **group coordinator** broker at a time
(the broker leading the `__consumer_offsets` partition the group ID hashes
to). The coordinator is the source of truth for: **membership** (who's in
the group), **assignment** (who owns which partitions), and **committed
offsets** (durably stored in `__consumer_offsets`). One elected member — the
"group leader," an ordinary consumer, not a broker — runs the actual
assignment algorithm (`RangeAssignor`, `CooperativeStickyAssignor`, etc.) and
hands the result to the coordinator to distribute. The coordinator decides
*when* to rebalance and enforces liveness; it doesn't compute *who gets
what*.

### What triggers a rebalance

- **A member joins** — `subscribe()` sends a `JoinGroup` request.
- **A member leaves cleanly** — `consumer.close()` releases its partitions.
- **A member is declared dead** — no heartbeat for longer than
  `session.timeout.ms` (crash, GC pause, network blip all look identical to
  the coordinator).
- **A subscription or partition-count change** — e.g. an admin adds
  partitions to a subscribed topic.

Notably absent: normal `poll()` calls and offset commits never trigger a
rebalance. A rebalance is always about group membership or topic metadata
changing, never about message throughput.

### Eager rebalancing: "stop the world"

Under `RangeAssignor`/`RoundRobinAssignor` (still the default in some
versions), a rebalance: (1) tells **every** member to revoke **all** its
partitions, unconditionally; (2) every member rejoins holding nothing; (3)
the leader computes a fresh assignment from scratch; (4) partitions are
handed back out. Between steps 1 and 4, no partition anywhere in the group
is being consumed — a single member joining or leaving pauses the *entire
group*, including members whose ownership doesn't actually change.

### Cooperative-sticky rebalancing (KIP-429)

`CooperativeStickyAssignor` changes the protocol itself, not just the
algorithm: (1) the leader computes a new assignment using the previous one
as a sticky starting point; (2) each member is told to revoke only the
specific partitions that need to move — often zero for most members; (3)
members with nothing to revoke keep polling uninterrupted; (4) a second,
lightweight round hands the freed partitions to their new owners. If 1
partition out of 9 needs to move, 8 keep flowing without interruption —
eager would have stopped all 9. This matters most in groups with several
members or frequent restarts.

### Consumer lag, precisely

Per partition:

```
LAG = LOG-END-OFFSET − CURRENT-OFFSET
```

- `LOG-END-OFFSET`: the next offset the broker will assign — how far
  production has gotten.
- `CURRENT-OFFSET`: the last offset the group has **committed** — how far
  it has confirmed processing.

Lag measures the *gap* between production and confirmed consumption, not
consumer speed in isolation. It climbs identically whether the cause is a
production burst, a rebalance pause (consumer can't poll at all), or genuine
processing slowness — telling these apart requires the *shape* of the lag
curve plus correlation against rebalance logs or deploy timestamps (see
Worked example). `kafka-consumer-groups.sh --describe --group <group>`
prints `CURRENT-OFFSET`, `LOG-END-OFFSET`, `LAG` per partition, plus
`CONSUMER-ID`/`HOST`/`CLIENT-ID` showing current ownership.

### Static group membership (`group.instance.id`)

By default a consumer is a **dynamic** member with no identity across
restarts — a quick restart looks like "member left, member joined" to the
coordinator, triggering two rebalances even for a two-second gap. Setting
`group.instance.id` to a fixed, unique string per instance makes it a
**static** member: on a restart within `session.timeout.ms`, the
coordinator recognizes the same identity returning and simply resumes its
previous assignment — no rebalance at all. This matters most in
orchestrated environments (Kubernetes) where benign restarts (rolling
deploys, rescheduling, autoscaling) are frequent. It only helps the
"member briefly disappears" case — a genuine new member, a subscription
change, or a restart that overruns `session.timeout.ms` still rebalances
correctly.

## Best practices

- Default to `CooperativeStickyAssignor` for any group with more than a
  couple of members or any regular restart churn — low downside, and it
  removes exactly the failure mode production incidents are made of.
- Set `group.instance.id` (derived from something stable per replica, e.g.
  pod name — not a fresh UUID per restart) in Kubernetes/ECS environments
  where pods restart routinely.
- Treat consumer lag as a first-class monitored metric with alerts on
  *sustained* growth, graphed per-partition (a group average can hide one
  stuck partition).
- Tune `session.timeout.ms` and `max.poll.interval.ms` deliberately: too
  short turns GC pauses into eviction rebalances; too long delays detecting
  a genuinely dead consumer. `max.poll.interval.ms` is a separate timeout
  for a single `poll()` call taking too long.
- Pin `partition.assignment.strategy` explicitly in config rather than
  relying on the version-dependent default — it silently differs across
  client versions.

## Common pitfalls

- Blaming "Kafka is slow" for a lag spike that's actually a rebalance storm
  from a too-aggressive rolling-restart deploy. The fix is deploy pacing or
  assignor choice, not more broker/consumer capacity.
- Not distinguishing "lag climbing from a rebalance" (self-limiting, drains
  once churn stops; fixed by reducing churn) from "lag climbing because the
  consumer can't keep up" (fixed by adding consumers/partitions or speeding
  up processing) — these need opposite fixes, and applying one to the
  other's problem burns an incident on the wrong hypothesis.
- Assuming a spike that fully drains means no real impact — a brief
  availability gap can still matter to freshness-sensitive downstream
  consumers.
- Forgetting that adding partitions to a topic rebalances every subscribed
  group, even with zero membership change.
- Setting `group.instance.id` without also raising `session.timeout.ms` to
  exceed the actual restart duration — otherwise the coordinator evicts the
  "static" member anyway.

## Real-world use cases

1. **Rolling-restart rebalance storm.** A page fires for lag right after a
   Kubernetes rollout. Diagnosis: correlate the spike's start against
   rollout start time, check `--describe` for rapidly churning
   `CONSUMER-ID`/`HOST` ownership, and check logs for
   `[rebalance] revoked`/`assigned` bursts. Fix: slow the rollout
   (`maxUnavailable: 1`), switch to cooperative-sticky, and/or set
   `group.instance.id` keyed on pod name.
2. **Static membership for a financial-events consumer.** A team processing
   payment/order events with a non-idempotent downstream side effect asks
   whether routine pod restarts pose a reprocessing risk. If restarts are
   frequent and the side effect isn't safely idempotent, static membership
   (or making the side effect idempotent) becomes a real requirement.
3. **Sizing before a partition-count increase.** Before running
   `kafka-topics.sh --alter --partitions N`, the team confirms the group's
   assignor is cooperative-sticky so the metadata-change rebalance it
   triggers doesn't stop-the-world an unrelated group.

## Worked example

**Timeline:** deploy at `T0`; lag spikes from 50 to 8000 at `T0+10s`; drains
back to ~50 by `T0+90s`.

1. **Rule in a rebalance first, given the timing.** The spike starts right
   after the deploy and *fully self-drains* with no intervention — a
   genuine throughput shortfall doesn't self-heal like this unless
   production also happened to slow at the same instant. A backlog of 8000
   draining in ~80 seconds at normal consumption speed is consistent with a
   brief pause followed by catch-up, not a sustained capacity problem.
2. **Confirm via `--describe`.** Poll repeatedly right after the page.
   Rapidly changing `CONSUMER-ID`/`HOST` ownership of the same partitions
   across consecutive calls is direct evidence of membership churn — a pure
   throughput problem would instead show *stable* ownership with
   `LOG-END-OFFSET` steadily outpacing `CURRENT-OFFSET`, not one abrupt
   jump.
3. **Confirm via logs.** If `ConsumerRebalanceListener` logging is wired up,
   a burst of `onPartitionsRevoked`/`onPartitionsAssigned` lines clustered
   at `T0`–`T0+10s` is the smoking gun. A *full* revoke of all partitions
   (not just moved ones) also tells you the group was on eager assignment.
4. **Rule out the alternative.** Check whether the deploy also changed
   producer-side rate — if only the consumer fleet redeployed, that further
   narrows the cause to consumer-side churn.
5. **Conclusion.** The rollout's restart cadence evicted and re-added
   members faster than the group could settle, triggering eager
   stop-the-world rebalances; the backlog is the group briefly consuming
   nothing while production kept arriving. Cheapest fix: switch to
   `CooperativeStickyAssignor` and/or slow the rollout relative to
   `session.timeout.ms`; add `group.instance.id` if restarts fit inside the
   session timeout window.

## Exercises

1. A group has 6 partitions, 3 members (2 each). One member restarts
   cleanly under **eager** assignment. How many partitions across the whole
   group stop being consumed during the rebalance — 2, or 6? Why?
2. Same scenario under `CooperativeStickyAssignor`. How many partitions stop
   this time?
3. `--describe` shows `CURRENT-OFFSET=14500`, `LOG-END-OFFSET=14500`,
   `LAG=0`, but the consumer hasn't logged a processed message in 10
   minutes and production is definitely ongoing. What does `LAG=0` tell you
   here, and what does it not tell you?
4. You set `group.instance.id` correctly, but rebalances still happen on
   every restart, which takes 45 seconds. What's the likely
   misconfiguration?
5. Your team adds 3 partitions to a topic (6 → 9) with no consumer joining
   or leaving. Does this trigger a rebalance? Why?
6. A lag graph climbs steadily over 20 minutes (not an abrupt jump) and
   never recovers. Rebalance or throughput shortfall? What single piece of
   `--describe` output confirms it fastest?

## Answers

1. **All 6.** Eager revokes all partitions from all members unconditionally,
   even the 4 belonging to the two members who did nothing — that's the
   "stop the world" behavior.
2. **At most 2** — only the partitions that need to move. The sticky
   assignor can often hand the same 2 straight back to the restarting
   member; the other 4, owned by members who never left, are never
   revoked.
3. `LAG=0` only means the last committed offset equals the log end offset
   *as of the last commit* — it says nothing about activity in the last 10
   minutes. Check whether `LOG-END-OFFSET` itself has moved across repeated
   `--describe` calls: if it's also frozen, production has stalled on that
   partition (explaining the "healthy" `LAG=0`); if it's climbing while
   `CURRENT-OFFSET` stays put, the consumer has actually stalled despite the
   last-known `LAG=0`.
4. `session.timeout.ms` is likely shorter than the 45-second restart. Once
   the timeout elapses without a heartbeat, the coordinator evicts the
   static member exactly as it would a dynamic one, and the eventual
   rejoin is treated as a new member — raise `session.timeout.ms` above the
   restart duration.
5. **Yes.** This is the "subscription/partition-count change" trigger:
   every member's subscription metadata changes (more partitions to
   potentially own), forcing a rebalance even with zero membership change.
6. **Genuine throughput shortfall.** Rebalance-driven spikes are abrupt and
   self-draining once churn stops; a steady, non-recovering climb describes
   sustained under-capacity. Fastest confirmation: stable
   `CONSUMER-ID`/`HOST` ownership throughout in `--describe` (no membership
   churn) while `LOG-END-OFFSET` keeps outpacing `CURRENT-OFFSET`.

## Hands-on lab

Today's lab is the rebalance-storm chaos exercise. The exact commands, churn
procedure, and expected `LAG`/log output for both the eager and
`CooperativeStickyAssignor` runs are in Day 3 of
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` —
follow that plan rather than a re-derivation of it here.

The lab uses two Java classes in the shared lab project:

- `kafka_practice/labs/src/main/java/com/kafkapractice/ConsumerDemo.java` —
  gets a `ConsumerRebalanceListener` logging every
  `onPartitionsRevoked`/`onPartitionsAssigned` call, then gets
  `partition.assignment.strategy` set to `CooperativeStickyAssignor` for the
  comparison run.
- `kafka_practice/labs/src/main/java/com/kafkapractice/ProducerLoop.java` —
  a continuous producer keeping a steady message rate flowing so lag has
  something to measure against during the churn window.

Go equivalents (if present from parallel work) live at
`kafka_practice/labs-go/cmd/consumerdemo/` and
`kafka_practice/labs-go/cmd/producerloop/`, same roles via the Go client.

Core exercise: run three `ConsumerDemo` instances in one group, churn one
process every 5 seconds for a minute while watching `--describe` and the
`[rebalance]` log lines under eager assignment, then repeat under
`CooperativeStickyAssignor`, and compare the two peak `LAG` numbers and
revoked-partition sets — that comparison is the concrete evidence behind
the Theory section above.

## Journal template

```
## Day 3 — Consumer groups & rebalancing
Key idea in my own words: ...
What confused me: ...
```
