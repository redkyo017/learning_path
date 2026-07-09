# Day 15 — Final Exam & Gap Analysis

## Purpose

Today introduces no new theory, no new build, and no new chaos lab. It is a
single self-administered exam: a closed-book, timed, CCAAK-style practice test
covering all 14 days, followed by scoring and a targeted gap analysis. The
question bank below is organized under the same six CCAAK domains the spec's
domain-overlay table uses — Kafka fundamentals & architecture, cluster
configuration & deployment, security, monitoring & operations, Kafka Connect,
and multi-cluster/disaster recovery — and every scenario is drawn from a
chaos lab, a config decision, or a diagnostic you actually ran during Days
1–14, not abstract trivia lifted from a study guide.

Closed-book and timed are both load-bearing constraints, not just exam
theater. Open-book review lets you recognize a correct answer once you're
looking at it — the journal entry, the config file, the `--describe` output
are all right there, so re-reading them feels like fluency. That feeling is
mostly an illusion: recognition and recall are different cognitive
operations, and production incidents never hand you the answer to recognize
— they hand you a paging alert at 3am and demand you *produce* the diagnosis
from nothing. Closed-book forces the same retrieval you'll need under
pressure. Timing it adds the second failure mode open-book review can't
surface at all: knowing the right answer eventually versus knowing it fast
enough to matter. A domain you can reason through in untimed comfort but not
under a clock is exactly the kind of gap that turns a 5-minute incident into
a 45-minute one — worth finding now, while the cost of finding it is just
your own time on a Tuesday, not a production outage.

Treat a wrong or slow answer as data, not a verdict. The point of this exam
isn't the score — it's the list of specific gaps it produces, each traceable
back to one of the 14 days behind you. Work the full bank closed-book first,
then grade against the answer key, then use the gap analysis guide to send
yourself back to exactly the chaos lab that covers each miss. Only after that
loop closes does the 15-day plan actually end.

## Practice exam question bank

30 questions, 5 per domain, interleaved difficulty. Write your answer to
every question closed-book before looking at the Answer key section. Aim for
roughly 5 minutes per question (~150 minutes total), matching the plan's Day
15 pacing.

### Domain 1 — Kafka fundamentals & architecture

**1.1.** `kafka-topics.sh --describe --topic orders` shows
`Replicas: 1,2,3` and `Isr: 1,3` for partition 0. A teammate says "that's
broken, page someone." Is it? What two things do `Replicas` and `Isr` each
tell you, and what's the one number that would actually make this urgent?

**1.2.** A developer coming from RabbitMQ asks: "if I have three consumers in
a group, why don't all three get every message like a fanout exchange?"
Explain the actual mechanism (not an analogy) that determines which consumer
in a group sees a given record, and what config would give every consumer
its own full copy of the stream instead.

**1.3.** A topic has RF=3, `min.insync.replicas=1`, and every producer uses
`acks=all`. The leader accepts a write, acks it, then crashes immediately
before any follower replicates it. Is the write durable? What is the actual
job of `min.insync.replicas` versus `acks=all`, and which one failed here?

**1.4.** A compacted topic `user-profiles` has `min.cleanable.dirty.ratio =
0.01` and you produce 5 updates for the same key within 50ms, then
immediately consume from the beginning. Are you guaranteed to see only the
latest value? Name the two separate reasons you might not.

**1.5.** A teammate proposes setting `unclean.leader.election.enable=true`
"just for the `orders` topic" so an all-brokers-down scenario doesn't block
writes. What's wrong with this plan, both mechanically (can you even scope it
per-topic?) and in terms of what it actually trades away?

### Domain 2 — Cluster configuration & deployment

**2.1.** Explain, precisely, what problem KRaft mode solves and why Kafka
moved away from a separate ZooKeeper cluster for metadata. What would you
have needed to run alongside your brokers under the old architecture that
you don't need now?

**2.2.** You're sizing an MSK cluster for a workload you don't yet have
production traffic numbers for. Why does the plan default to provisioned
`kafka.t3.small` brokers rather than MSK Serverless for this kind of
learning/low-traffic cluster, and what capability do you lose by picking
Serverless instead?

**2.3.** Your `orders` topic needs more throughput headroom right now, mid-
incident. Do you add partitions or add brokers first? Justify the choice in
terms of what each operation actually requires the cluster to do.

**2.4.** You're about to do a one-broker-at-a-time rolling upgrade of a
3-broker cluster with RF=3, `min.insync.replicas=2`. What specific
relationship between those two numbers is what makes taking one broker down
at a time actually safe, and what would make it unsafe?

**2.5.** An MSK cluster is provisioned with `PublicAccess.Type:
SERVICE_PROVIDED_EIPS` so it's reachable directly from your laptop. Why does
MSK require a TLS-based auth mechanism (IAM or TLS client certs) rather than
allowing a plaintext listener in this configuration, when your local Docker
cluster was allowed to run `PLAINTEXT` for a while?

### Domain 3 — Security

**3.1.** A client connects over `SASL_PLAINTEXT` with valid SCRAM
credentials — no authentication error in the logs. Five seconds later,
`poll()` throws `TopicAuthorizationException`. Is this an authentication
failure, an authorization failure, or could it be either? Justify from the
symptom alone.

**3.2.** While a consumer is actively polling and processing messages, an
operator revokes its `Read` ACL on the topic it's consuming. Does the
client's connection drop immediately, keep working until it reconnects, or
fail on its next request without disconnecting? What does your answer imply
about ACL revocation as an incident-response tool?

**3.3.** You're comparing three access-control systems you've now configured
by hand: Kafka ACLs (`kafka-acls.sh`), an AWS IAM policy for MSK IAM auth,
and a Confluent Cloud RBAC role binding. What's the one underlying model all
three share, and name one concrete syntactic difference between at least two
of them.

**3.4.** On Confluent Cloud, a service account is bound to the
`DeveloperRead` role on `Topic:orders`. Running `ConsumerDemo` against its
API key succeeds. Running `ProducerDemo` against the same key fails with
`TopicAuthorizationException`. Explain why, and name the specific role or
role-binding change that would let it produce too.

**3.5.** On a brand-new cluster with an authorizer configured and zero ACLs
created yet, an admin successfully runs `kafka-acls.sh --add` over a plain
`PLAINTEXT` connection. Given that the authorizer denies by default, explain
how this succeeded, and name the specific broker-level setting responsible.

### Domain 4 — Monitoring & operations

**4.1.** The under-replicated-partitions alarm fires at 3am. What are the
first three things you check, in order, and why — specifically, what would
each check rule in or rule out before you decide whether to escalate?

**4.2.** A consumer group's lag spikes right after a rolling deploy. Name the
two most likely causes and describe the one piece of `kafka-consumer-
groups.sh --describe` evidence that distinguishes between them fastest.

**4.3.** During an active incident, do you trust the CLI's live `LAG` column
or a CloudWatch/Prometheus dashboard's lag metric more? Which do you trust
more for historical trend analysis across the last week? Justify both
answers from what each tool actually measures and how quickly.

**4.4.** Using an observed `BytesInPerSec` of roughly 2 MB/s sustained, a
100 GB broker storage volume, and `retention.ms` at its 7-day default, is
100 GB enough headroom? Show the arithmetic and state what you'd change
first if it isn't.

**4.5.** `--describe` on a consumer group shows `LAG=0` on every partition,
but the consumer hasn't logged a processed message in ten minutes, and
production is definitely ongoing elsewhere in the system. What does
`LAG=0` actually tell you here, and what single additional check resolves
whether this is healthy or broken?

### Domain 5 — Kafka Connect

**5.1.** A teammate asks why their Kafka Connect sink connector's schema
registration is failing after a field removal. What's your diagnosis, and
what compatibility mode would have caught this before it ever reached the
connector?

**5.2.** You configure an MSK Connect S3 sink connector pointed at the
`orders` topic, produce several messages via `ProducerDemo`, and wait five
minutes. `aws s3 ls` on the sink bucket shows nothing. Name three plausible
causes to check, in the order you'd check them.

**5.3.** Schema Registry rejects re-registering a schema after you remove a
required field with no default value, but accepted an earlier change that
added a field with a default. Explain both outcomes in terms of what an
*old* consumer, still expecting the previous schema, would actually do when
it reads a record written under each new schema.

**5.4.** You switch a connector's `value.converter` from the default JSON
converter to an Avro converter backed by a schema registry. What
specifically changes about what gets written to the topic, and what
breaks for any existing consumer that was reading the raw JSON bytes
directly?

**5.5.** Compare provisioning a source connector via MSK Connect (custom
plugin ZIP uploaded to S3, IAM role per connector) against provisioning the
equivalent connector from Confluent Cloud's managed connector catalog. What
operational burden does the managed catalog remove, and what do you lose in
exchange?

### Domain 6 — Multi-cluster / disaster recovery

**6.1.** MirrorMaker2 is replicating `orders` from cluster `msk` to cluster
`docker`. On the target cluster you see topic `msk.orders`, not `orders`.
Explain the naming convention and why offset translation between source and
target is necessary at all — what's different about "the same" message's
offset on each side?

**6.2.** While MirrorMaker2 is actively replicating, you reboot one broker
on the source cluster. The MM2 internal consumer group's lag ticks up
briefly but MM2 doesn't stop or error. Explain what's happening during the
reboot and why no manual restart of MirrorMaker2 is needed once the broker
recovers.

**6.3.** Your organization wants to fail traffic over to the DR cluster
(`docker`) if the primary (`msk`) becomes unavailable. Beyond MM2 already
replicating the data, what else has to be true about consumer group offsets
on the target cluster before consumers can resume from the correct
position after a failover, rather than reprocessing everything from the
beginning?

**6.4.** You run `kafka-topics.sh --alter --topic orders --partitions 12`
on the source cluster while MirrorMaker2 is actively replicating that
topic. What happens on the target side, and does anything need to be
manually reconfigured on MirrorMaker2 to pick up the new partitions?

**6.5.** A colleague argues for active-active replication (both clusters
accepting writes, mirrored both directions) instead of the active-passive
setup (`msk->docker` only) you built. What operational problem does
active-active introduce that active-passive avoids entirely, and under what
circumstance would the added complexity still be worth it?

## Answer key

### Domain 1

**1.1.** Not automatically an emergency. `Replicas` lists the assigned
replica set regardless of whether each member is currently alive and caught
up; `Isr` lists only the replicas that are actually in sync right now. Here,
replica 2 has dropped out of the ISR — that's exactly the under-replicated-
partition state, and it's the *expected* transient condition during a
rolling restart or a brief broker blip. The number that would make it
urgent is `Isr` shrinking to (or below) `min.insync.replicas` — at that
point new writes with `acks=all` start failing with
`NotEnoughReplicasException` instead of just running with reduced
redundancy.

**1.2.** Partition assignment, not fanout. Kafka has no per-consumer
delivery tracking or exchange-style routing; a topic's partitions are
divided up among the members of one consumer group, so each partition is
owned by exactly one member of that group at a time — that's why three
consumers in one group split the six partitions of a topic rather than each
seeing everything. To give every consumer its own full copy of the stream,
put each consumer in its **own** consumer group (a distinct `group.id`);
each group tracks its own independent set of committed offsets against the
same partitions.

**1.3.** No, it is not durable, and that's the expected mechanism, not a
bug. `acks=all` only means "wait for every replica *currently in the ISR*"
— it says nothing about how large the ISR has to be. `min.insync.replicas`
is the config that actually sets that floor, and here it's set to 1, so the
ISR's minimum size can be just the leader itself. The leader acknowledging
alone satisfies both `acks=all` and `min.insync.replicas=1` before any
follower has the record, so the leader's crash loses it. RF=3 was
irrelevant — only 1 replica was ever required to hold the data before ack.

**1.4.** No, not guaranteed, for two independent reasons. First, the log
cleaner runs periodically, not synchronously with every write — even an
aggressive dirty ratio only makes a segment *eligible* for compaction
sooner, it doesn't force an immediate rewrite. Second, compaction never
touches the *active* (currently open) segment; if all 5 updates landed in
the still-open active segment, none of them are compaction-eligible yet
regardless of dirty ratio. Reading immediately after writing can legitimately
surface more than one value per key until a cleaner pass actually runs.

**1.5.** Two separate problems. Mechanically, `unclean.leader.election.enable`
is a broker-level (cluster-wide) setting in standard Kafka — there's no
per-topic override, so "just for `orders`" isn't actually available; turning
it on exposes every topic on that broker to unclean elections. Substantively,
even if it could be scoped, it trades the wrong direction: it converts
"writes block until enough replicas are healthy" (annoying, zero data loss)
into "writes keep flowing, but any committed record the newly-elected lagging
replica never received is silently and permanently gone." The actual fix is
right-sizing `min.insync.replicas` against RF, or fixing whatever keeps
taking every in-sync replica down at once.

### Domain 2

**2.1.** Before KRaft, cluster metadata (broker membership, topic/partition
configuration, ACLs, controller election) lived in a separate ZooKeeper
ensemble that had to be run, secured, and operated independently of the
Kafka brokers themselves — effectively two distributed systems to keep
healthy for one Kafka cluster. KRaft moves that metadata into a Raft-based
quorum of Kafka's own controller nodes, so a Kafka cluster is
self-contained: no separate ZooKeeper cluster to provision, secure, upgrade,
or troubleshoot in parallel.

**2.2.** Provisioned `kafka.t3.small` keeps the exact config knobs from Days
1–5 (broker sizing, storage, retention, `min.insync.replicas`, and so on)
directly visible and comparable to what you configured locally — the point
of this phase is transferring concepts, not hiding them behind abstraction.
MSK Serverless trades that visibility for pay-per-request convenience: it
auto-scales and eliminates broker-sizing decisions entirely, which is
genuinely useful operationally but hides most of the config surface a
learner (or an operator doing capacity planning) needs to reason about
directly.

**2.3.** Add partitions first. Increasing partition count is a near-instant
metadata operation — the cluster doesn't need to move any existing data,
just start assigning new records to the new partitions going forward.
Adding a broker requires the cluster to actually rebalance existing
partition *replicas* onto it via partition reassignment, which is a real
data-movement operation and doesn't relieve pressure until that reassignment
completes. Mid-incident, partitions buy headroom now; brokers buy headroom
later.

**2.4.** The relationship is: with RF=3 and `min.insync.replicas=2`, the
cluster can tolerate exactly one broker being down (the ISR shrinks to 2,
still meeting the floor, so `acks=all` writes keep succeeding) while you
patch/restart it. Taking brokers down one at a time, waiting for the
previous one's partitions to fully rejoin the ISR before touching the next,
guarantees you never have more than one broker's worth of replicas missing
at once. It becomes unsafe the moment you either take down two brokers
before the first rejoins, or `min.insync.replicas` is already equal to RF
(then even one broker down blocks writes for any partition it hosted, since
the ISR can no longer meet the floor at all).

**2.5.** Because with public accessibility, the broker is reachable from
outside the VPC's private network boundary — the network-level isolation
that made an unauthenticated local listener acceptable on an isolated
Docker network no longer exists. Anyone who can route to the public
endpoint could otherwise connect with zero credentials. IAM auth or mutual
TLS both establish a verified identity and, critically, are only offered
over encrypted (`SASL_SSL`/`SSL`) listeners — MSK doesn't expose a public
plaintext listener at all, precisely because that combination (public
reachability, no auth) is the one to never allow.

### Domain 3

**3.1.** Authorization failure. If authentication had failed, the client
would never get past session setup — it would fail immediately with a
`SaslAuthenticationException` (or an equivalent handshake error), and it
would never reach a working `poll()` loop at all. Reaching `poll()` cleanly
means a principal was already established; the exception moments later is
the separate, per-request authorization check finding no matching ACL for
that principal on that topic.

**3.2.** Fails on its next request, without disconnecting. Authorization in
Kafka's authorizer model is evaluated per-request, not tied to connection or
session lifecycle — the TCP connection and session stay intact, but the
client's next `Fetch` (or any other) request against the now-unauthorized
resource gets denied. This is exactly why ACL revocation is an effective,
immediate incident-response tool: you don't need to force-disconnect a
compromised or misbehaving client, revocation takes effect on its very next
call.

**3.3.** All three implement the same underlying model: a **principal**
(identity), a **resource** (topic, consumer group, cluster), and a set of
**allowed operations**, checked on every request. The syntax differs
concretely — Kafka ACLs are granted with `kafka-acls.sh --add
--allow-principal User:<name> --operation Read --topic <name>`; an AWS IAM
policy for MSK expresses the same idea as a JSON `Statement` with
`kafka-cluster:*` actions scoped to a cluster ARN resource; Confluent RBAC
expresses it as a role binding (`confluent iam rbac role-binding create
--principal ... --role DeveloperRead --resource Topic:...`) using
predefined role bundles instead of individual operations.

**3.4.** `DeveloperRead` grants read-only access — `Read`/`Describe`-class
operations on the bound topic — and nothing write-related, so a producer
using that identity is denied exactly as designed, not because of a
misconfiguration. Getting write access requires an additional (or
different) role binding — either adding a `DeveloperWrite` binding on the
same `Topic:orders` resource for that service account, or using a role that
already bundles both.

**3.5.** The `super.users` broker configuration, which typically includes
`User:ANONYMOUS` — the principal Kafka assigns to any connection over an
unauthenticated `PLAINTEXT` listener. Superusers bypass the authorizer
entirely rather than needing an ACL that grants everything; this is the
general solution to deny-by-default's bootstrap problem: some principal has
to be trusted unconditionally, outside the normal ACL-checked path, in order
to create the first real ACLs for everyone else.

### Domain 4

**4.1. (mirrors the brief's own example)** First, check `Isr` size against
`min.insync.replicas` on the affected partitions via `--describe` — this
tells you whether writes are still succeeding or already blocked, which
sets the urgency. Second, check whether a planned operation (rolling
restart, broker patch, reassignment) is in progress — expected,
self-healing under-replication looks identical to a real failure in this
metric alone. Third, check how long it's been elevated and whether it's
still shrinking, growing, or holding steady — a brief dip that's already
recovering needs no action, while a sustained or worsening one needs
immediate escalation.

**4.2. (mirrors the brief's own example)** The two likely causes are a
rebalance storm (redeploy churned consumer group membership faster than the
group could settle, most common under an eager assignor) and a genuine
throughput shortfall (deploy changed something that slowed real processing).
The fastest distinguishing evidence: repeated `--describe` calls showing
rapidly changing `CONSUMER-ID`/`HOST` ownership of the same partitions means
membership churn (rebalance); stable ownership with `LOG-END-OFFSET`
steadily outpacing `CURRENT-OFFSET` means the consumer itself can't keep up.

**4.3.** Trust the CLI more during an active incident — it reflects current
state with no dashboard refresh/scrape delay, and every second matters
mid-incident. Trust the dashboard more for historical/trend analysis — it
retains a queryable time series across days or weeks, which the CLI's
point-in-time `--describe` output does not provide at all, so it's the only
practical way to see a trend, not just a snapshot.

**4.4.** 2 MB/s sustained for 7 days (604,800 seconds) is roughly
1.2 TB of retained data (2 MB/s × 604,800s ≈ 1.21 million MB ≈ 1.2 TB) —
far beyond a 100 GB volume. 100 GB is not enough headroom at this rate; the
volume fills in roughly 100,000 MB / 2 MB/s ≈ 50,000 seconds, under 14 hours,
long before the 7-day retention window is reached. The fix is to shorten
`retention.ms` to fit the available storage, or grow the storage/broker
count — sized to the actual observed throughput, not the default.

**4.5.** `LAG=0` only means the last *committed* offset equaled the log-end
offset as of the last commit — it says nothing about activity since then.
The one check that resolves it: poll `--describe` again and watch whether
`LOG-END-OFFSET` itself has moved. If it's also frozen, production has
stalled on that partition (which is why lag still reads 0 — nothing new has
arrived to fall behind on). If `LOG-END-OFFSET` is climbing while
`CURRENT-OFFSET` stays put, the consumer has actually stalled and the
"healthy" `LAG=0` is stale, about to jump the moment a new commit is
attempted (or never, if the consumer is dead).

**4.6. (Connect cross-reference, mirrors the brief's own example)** See
Domain 5, question 5.1 — the same scenario is asked there since it's a
Connect/schema question at heart, not a monitoring one; listed here only as
a reminder that "why did this integration break" questions often span
domains in practice.

### Domain 5

**5.1. (mirrors the brief's own example)** Removing a field without a
default breaks schema compatibility for any consumer still expecting that
field's presence — under `BACKWARD` compatibility (Schema Registry's most
common default), a new schema must remain readable by consumers using the
*previous* schema, and dropping a required field with no default value
means old consumer code that reads it directly would fail or get an
unexpected null. The registry rejects the registration attempt outright
rather than letting an incompatible schema through, which is exactly what
`BACKWARD` compatibility mode is for — it should have (and did, in Day 12's
lab) caught this before the connector ever saw the new schema.

**5.2.** Check, in order: (1) whether the connector itself reached `RUNNING`
state and isn't stuck in a failed/paused state (`aws kafkaconnect
describe-connector` or `confluent connect cluster describe`) — a connector
that never started successfully never writes anything; (2) whether the
connector's IAM role actually has `s3:PutObject` on the target bucket — a
silent permissions failure often shows up as "nothing appears" rather than a
loud error in a quick glance; (3) whether the connector's flush interval has
actually elapsed — sink connectors commonly buffer for a configured interval
before writing an object, so five minutes of silence may just mean the
flush hasn't fired yet.

**5.3.** Adding a field with a default: an old consumer, still using the
previous schema, reading a record written under the new schema simply never
looks for the new field — it's absent from what the old consumer cares
about, so nothing breaks; that's exactly what `BACKWARD` compatibility
guarantees and why the registry accepted it. Removing a required field with
no default: an old consumer still expects that field to be present and
would either throw a deserialization error or silently receive a
null/missing value it never coded a fallback for — a real correctness
break, which is why the registry rejects the change outright rather than
letting it through.

**5.4.** The converter controls how bytes on the topic are serialized;
switching to an Avro converter backed by a schema registry means the
connector registers (or looks up) a schema and writes Avro-encoded bytes,
typically with a small schema-ID prefix on each record, instead of raw JSON
text. Any existing consumer hard-coded to parse the bytes as JSON will
break immediately — it will either fail to parse or produce garbage,
because the wire format changed entirely, not just the logical schema. Every
consumer needs to move to an Avro deserializer (and schema registry client)
in lockstep with the connector's converter change.

**5.5.** The managed catalog removes plugin packaging and hosting (no
uploading a ZIP to S3, no `create-custom-plugin` step) and removes per-
connector IAM role wiring — Confluent handles the connector's own
credentials to reach the cluster. In exchange, you're limited to whatever
connectors Confluent has published to the catalog; a connector not in that
catalog (a custom or less-common one) isn't an option the way it is on MSK
Connect, where any Kafka Connect-compatible plugin can be uploaded and run.

### Domain 6

**6.1.** MirrorMaker2's default naming convention prefixes the replicated
topic with the source cluster's alias (`<source-alias>.<topic>` — here,
`msk.orders`), so a target cluster can distinguish "topic named `orders`
that originated locally" from "topic named `orders` that arrived via
replication," even if both exist. Offset translation is necessary because a
record's offset is purely local bookkeeping for one partition's log — the
same message written to `msk`'s `orders` topic and mirrored into
`docker`'s `msk.orders` topic almost certainly lands at a different offset
on the target, since the target's log has its own independent, incrementing
offset sequence. MM2 maintains an internal offset-mapping so consumer group
positions can be translated between the two, rather than assuming offsets
match across clusters.

**6.2.** During the reboot, partitions the rebooting broker leads (or
replicates) briefly show reduced ISR on the source cluster — the same
under-replicated-partition condition from Domain 1/2's questions, just
observed from the replication pipeline's perspective. MirrorMaker2's own
internal consumer (reading from the source to produce into the target) sees
temporarily higher fetch latency or brief unavailability on those
partitions, which shows up as its consumer group's lag ticking up — but MM2
itself isn't different from any other consumer client here: it keeps
retrying and resumes normal consumption once the broker rejoins the ISR, with
no special recovery logic needed, because nothing about the failure broke
MM2's own process, only slowed its source temporarily.

**6.3.** Consumer groups need to exist on the target cluster with committed
offsets that correspond, via MM2's offset translation, to where each group
actually left off on the source — not simply "start reading `msk.orders`
from the beginning" (which reprocesses everything) or "start from the
end" (which skips whatever hadn't been mirrored yet at cutover). MM2's
checkpoint/offset-sync feature is what translates and periodically syncs
source consumer-group offsets into equivalent target-cluster offsets, so a
failed-over consumer resuming against the target cluster picks up from
approximately where it left off on the source, rather than from an
arbitrary point.

**6.4.** The target side does not automatically restructure to match; MM2
detects the partition-count change on its next metadata refresh and begins
mirroring the new partitions' data into the corresponding target topic, but
whether the target topic's own partition count needs to change depends on
MM2's configuration — by default MM2 can create the target topic with a
partition count that tracks the source, but an already-existing target
topic with a fixed partition count won't silently grow to match. No manual
restart of MM2 is required either way; it picks up new source partitions on
its regular topic/partition discovery cycle, the same way `ConsumerDemo`
picks up new partitions on its next rebalance.

**6.5.** Active-active introduces the risk of replication loops and
conflicting writes to "the same" logical topic from two directions at
once — without careful topic-renaming/filtering (and usually some
conflict-resolution or partitioning-by-region strategy on the application
side), you can end up re-mirroring a message back to the cluster it came
from, or losing a clear answer to "which write is authoritative" when both
sides accept writes for overlapping keys concurrently. Active-passive avoids
this entirely by only ever replicating in one direction. Active-active is
still worth the complexity when both regions need genuinely low-latency
local writes and can partition write ownership cleanly (e.g. by customer
region) so conflicting concurrent writes to the same key essentially never
happen in practice.

## Gap analysis guide

For any domain where the practice exam surfaced two or more misses, don't
just reread the theory — redo the actual chaos lab or hands-on exercise that
domain came from, closed-book again, right now. Recognition from a second
read doesn't fix a retrieval gap; another live attempt does.

- **Kafka fundamentals & architecture weak → redo Day 1 and Day 4.** Day 1's
  core exercise is standing up the local KRaft cluster and reading
  `kafka-topics --describe` output (`Leader`/`Replicas`/`Isr`) cold. Day 4's
  chaos lab is killing a broker mid-write to induce and recover from an
  under-replicated partition — rerun both parts (the 2-of-3-alive case and
  the `NotEnoughReplicasException` case) without the plan doc open.

- **Cluster configuration & deployment weak → redo Day 1, Day 6, and Day 9.**
  Day 1 for the base cluster commands; Day 6 for provisioning a secured MSK
  cluster from scratch (networking, IAM policy, bootstrap brokers) with no
  notes; Day 9's scale-up exercise (`--alter --partitions`) and rolling-
  upgrade reasoning for the deployment-under-load half of this domain.

- **Security weak → redo Day 5, Day 6, and Day 11.** Day 5's ACL-revocation
  chaos lab is the core exercise — deliberately misconfigure or revoke an
  ACL mid-session and diagnose the resulting `TopicAuthorizationException`
  without looking at the answer key first. Day 6 for the IAM-policy side,
  Day 11 for the RBAC comparison — redo the three-way ACL/IAM/RBAC table
  from memory before checking it against the journal.

- **Monitoring & operations weak → redo Day 8 and Day 10.** Day 8's core
  exercise is generating load and cross-checking the CLI's live `LAG` column
  against the CloudWatch/Prometheus dashboard side by side, plus the
  capacity-planning arithmetic from `BytesInPerSec`. Day 10 is the closed-
  book Phase 2 review itself — rerun its mixed review list (IAM actions,
  what each metric indicates, MirrorMaker2 naming) from memory.

- **Kafka Connect weak → redo Day 7 and Day 12.** Day 7's core exercise is
  standing up a source connector (Datagen) and a sink connector (S3) against
  MSK Connect and verifying data actually flows through both, unassisted.
  Day 12's schema-evolution exercise — adding a field with a default (should
  succeed) versus removing a required field (should be rejected) — is the
  single most concrete way to re-test this domain; rerun both halves.

- **Multi-cluster / disaster recovery weak → redo Day 9.** Day 9 is the only
  day mapped to this domain and it's the busiest one: configure
  MirrorMaker2 replication, verify it end-to-end, then rerun the chaos lab
  (reboot a source broker mid-replication and confirm MM2 self-heals without
  manual intervention) closed-book.

This second pass is closed-book too — that's the whole point. If you need
notes to get through it a second time, the first pass's "fixed" answer was
memorized, not understood, and this is exactly the cheap moment to notice
that before it matters in production.

## Success criteria checklist

Reproduced from the plan's spec. Mark off only what you can actually
demonstrate right now, not what you expect you could do with a warm-up.

- [ ] Can stand up a secured (SASL/mTLS or IAM-authenticated) Kafka cluster
  from scratch on both Docker and MSK, without notes.
- [ ] Can diagnose and recover from each of the four chaos labs (broker
  kill, rebalance storm, under-replication, ACL misconfiguration) by
  reasoning from first principles, not memorized steps.
- [ ] Can configure at least one working source connector and one working
  sink connector end-to-end, including schema registry integration.
- [ ] Passed the Day 15 self-administered CCAAK-style practice exam
  closed-book.
- [ ] Can produce a teach-it-back explanation (postmortem-style) for every
  major concept from the 15 days without referring to notes.

Any unchecked box is exactly what the gap analysis guide above is for — go
close it before calling the plan done, using the same day-to-domain mapping.

## What's next (deferred topics)

The spec deliberately scoped four things out of these 15 days, all of which
remain live, reasonable follow-on tracks now that the foundation is solid:
Kafka Streams/ksqlDB depth beyond the one windowed-aggregation app built on
Day 13 (full stream-processing mastery — joins, more complex state stores,
exactly-once processing guarantees at the Streams layer — is its own
multi-week track); non-Java client ecosystems, despite this learner's Go
background, since building fluency in one client language first and
transferring the underlying model afterward is faster than splitting focus
across two from day one; KRaft internals beyond the conceptual level covered
on Day 1 (no hand-building a KRaft controller quorum); and Confluent's
enterprise-only features outside the free tier (Cluster Linking, Tiered
Storage beyond defaults). None of these were dropped because they're
unimportant — they were deferred because 15 days was already an aggressive
scope for administration and integration fluency, and diluting it further
would have cost depth on the material that actually shipped.

The Go lab track built in parallel throughout this plan (`kafka_practice/
labs-go/`) is a genuine head start on the Streams-only gap specifically. Go
has no first-party Kafka Streams equivalent from Confluent/Apache, but the
underlying concepts this plan built — `KStream`/`KTable` semantics, windowed
aggregation with grace periods, state-store-backed processing — transfer
directly to whichever Go-ecosystem approach eventually gets chosen (hand-
rolled consumer-group-based processing, a community stream-processing
library, or simply staying on the Java Streams app and integrating it as a
service boundary from Go-based systems). The Go client fluency already built
this way means that follow-on work starts from "port a design I understand,"
not "learn Go Kafka clients from zero while also learning stream processing
for the first time."

## Journal template

```
## Day 15 — Final exam & gap analysis
Domains scoring well: ...
Domains needing more practice: ...
Follow-on plan: ...
```
