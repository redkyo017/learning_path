# Day 10 — Review (Days 6–9) + AWS Phase 2 Teardown

## Purpose

Today introduces no new theory. It is closed-book retrieval practice on
everything from Days 6–9: provisioning and securing an MSK cluster with
IAM authentication, wiring Kafka Connect source/sink connectors plus schema
registry integration, standing up monitoring and alerting, and exercising
MirrorMaker2-based DR alongside partition/broker scaling levers. Phase 2
moved everything off the free local Docker cluster and onto real, metered AWS
infrastructure, which is exactly why this review day also carries a second,
non-optional job: tearing that infrastructure back down before it accrues any
more cost.

Review days are placed every 4–5 days rather than saved for the end of the
plan because spaced retrieval outperforms a single linear pass through the
material. The forgetting curve is steepest in the first few days after
first exposure — Day 6's IAM policy shape and Day 8's exact metric names are
already fading by Day 10 unless they're actively pulled back out of memory
before that happens. Cramming everything into a single review at Day 15
would mean rediscovering forgotten material instead of merely refreshing it,
which is far more expensive in time. The work below is that retrieval:
struggling to reproduce Days 6–9 from memory *now*, while the gaps are still
cheap to find and fix.

Today also differs from a typical review day in one respect: because Days
6–9 all ran against a shared, live MSK cluster, "review" and "cleanup" are
temporally coupled — there's no safe way to defer teardown to a later day
without either leaving a paid cluster running unattended, or tearing it down
before finishing retrieval that depends on it still existing (e.g.
cross-checking a remembered IAM action list against the actual attached
policy). Do the retrieval work first, then tear down.

## Consolidated summary of Days 6–9

Day 6 moved the security model built in Docker (Day 5's SASL/SCRAM plus
ACLs) onto AWS's own authentication/authorization mechanism: IAM. MSK's
provisioned mode is configured through one JSON document — broker instance
type and count, per-broker EBS volume, subnet/security-group placement
across two AZs, and a `ClientAuthentication` block turning on SASL/IAM.
Enabling IAM auth fixes the broker port at 9098 and forces TLS: MSK's
public-access mode (`SERVICE_PROVIDED_EIPS`, needed to reach the cluster
from a laptop rather than a bastion host) will not allow a plaintext
listener, since exposing unauthenticated, unencrypted broker traffic to the
public internet is the one configuration AWS refuses to hand you by
default — IAM or mutual TLS are the only mechanisms compatible with that
exposure. IAM authorization is then granted the same way Day 5's ACLs
were: a principal is mapped to specific actions on a specific resource.
The syntax is AWS's own (`kafka-cluster:WriteData`, `ReadData`,
`DescribeCluster`, `AlterGroup`, scoped to a cluster ARN) rather than
Kafka's ACL CLI, but the shape — principal, resource, allowed operations —
is identical to Day 5. The payoff of Day 2's config-file-driven client
design showed up immediately: the same `ProducerDemo`/`ConsumerDemo` Java
classes ran against MSK unmodified, just pointed at a new
`msk-iam.properties` file with the IAM login module wired in.

Day 7 put Kafka Connect at the center, correctly framed as the integration
team's first tool, not a nice-to-have: connectors move data between Kafka
and external systems without anyone writing bespoke producer/consumer code.
MSK Connect needs a custom plugin uploaded to S3 (a zipped connector JAR
registered via `create-custom-plugin`), an IAM role granting the connector
both Kafka access and access to whatever it reads from/writes to, and a
worker configuration describing capacity and the target cluster. The
datagen source connector produced synthetic order records with no producer
code running; the S3 sink connector read from `orders` and periodically
flushed batches to S3 on its own schedule. Layered onto both was the Glue
Schema Registry: switching a connector's converter to
`AWSKafkaAvroConverter` and pointing it at a Glue registry auto-registers a
schema on write, giving Connect pipelines the same schema-evolution
guarantee a manually-managed registry gives hand-written clients.

Day 8 turned on visibility into all of this. Enhanced monitoring
(`PER_TOPIC_PER_PARTITION`) plus open monitoring (Prometheus JMX/node
exporters) feed a small set of metrics that matter disproportionately:
`UnderReplicatedPartitions` and `OfflinePartitionsCount` should be zero at
rest — any positive value means the replication guarantee is currently
being violated (or worse, a partition has no leader) and should page
someone. `MaxOffsetLag` per consumer group is the CloudWatch-side view of
the CLI's `LAG` column — non-zero and growing means a consumer is falling
behind, from either a slow consumer or a produce-rate burst.
`KafkaDataLogsDiskUsed` climbing toward 100% is a hard failure waiting to
happen, since brokers that run out of disk stop accepting writes.
`BytesInPerSec`/`BytesOutPerSec` feed capacity planning directly — Day 8's
arithmetic exercise used an observed `BytesInPerSec` against the 100 GB
broker volume and 7-day retention to project days-until-full. The CLI and
CloudWatch dashboard trade off latency for history: the CLI is faster
during an active incident, the dashboard retains trend data the CLI's live
query doesn't.

Day 9 covered multi-region durability and elastic capacity. MirrorMaker2
(KIP-382) replicates topics across clusters — MSK as source, the Docker
cluster as target, avoiding a second MSK cluster's cost — renaming
replicated topics with a `<source-alias>.<topic>` prefix (`orders` on MSK
becomes `msk.orders` on the target) so a bidirectional or multi-hop
topology never collides names. Offset translation exists because "the
same" message does not carry the same offset on both sides: the target
assigns its own offsets as it appends mirrored records, so a consumer
failing over from source to target needs a translated offset to resume in
the right place. The chaos lab rebooted a live MSK broker mid-replication
and watched Day 8's metrics move — transient under-replication on the
rebooting broker's partitions, a brief uptick in MirrorMaker2's internal
lag — followed by self-healing with no manual intervention, the entire
point of replication factor and ISR tracking. Scaling is a two-tier
decision: adding partitions is near-instant with no data movement, so it's
tried first; adding brokers requires a follow-on partition reassignment to
actually shift load, making it heavier. Rolling upgrades (one broker at a
time) are safe only because `min.insync.replicas` set below the full
replication factor guarantees enough in-sync replicas survive one broker
going offline to satisfy every acked write — the mechanism Day 4's chaos
labs exercised directly.

## Closed-book mixed review questions

1. A client application connecting to the MSK cluster from Day 6 reports
   authentication failures on port 9098. What two things does IAM auth on
   MSK require that a plaintext connection wouldn't, and why does MSK's
   public-access mode make one of them mandatory?
2. Write, from memory, the specific `kafka-cluster:*` IAM actions a
   producer-and-consumer client needs to both produce and consume against a
   topic it doesn't administer. What's the AWS-side resource these actions
   are scoped to?
3. `UnderReplicatedPartitions` on the CloudWatch dashboard just went from 0
   to 4 and stayed there for the last ten minutes (not a brief blip). What
   does this indicate, and what would you check first?
4. Explain how MirrorMaker2 names a replicated topic, and give a concrete
   example: if a topic named `payments` is replicated from a cluster aliased
   `east` to a cluster aliased `west`, what does the topic get called on
   `west`?
5. A colleague says "offset translation in MirrorMaker2 is unnecessary — the
   target cluster just keeps the same offsets as the source." What's wrong
   with this claim?
6. You need to add a new sink target for Kafka data — say, writing topic
   data into an external object store — without writing a custom consumer.
   What Kafka Connect concept covers this, and what are the three pieces of
   AWS-specific setup MSK Connect needs before the connector itself can be
   created?
7. Why does switching a connector's `value.converter` to
   `AWSKafkaAvroConverter` pointed at a Glue registry matter operationally,
   beyond just "it registers a schema"?
8. `OfflinePartitionsCount` is at 0 but `KafkaDataLogsDiskUsed` is climbing
   toward 90% across all brokers. Is this urgent? What are your two options,
   and which one is usually preferable to try first and why?
9. During Day 9's chaos lab, MirrorMaker2's internal consumer group lag
   ticked up but MirrorMaker2 itself never stopped or errored. Connect this
   observation to a specific cluster configuration from Day 4/6 that made
   this self-healing possible.
10. Contrast why you'd trust `kafka-consumer-groups.sh --describe` over the
    CloudWatch dashboard during an active incident, versus why you'd trust
    the dashboard over the CLI a week later when writing an incident
    postmortem.
11. A topic currently has 6 partitions and its consumer group is falling
    behind. You could either add partitions or add a broker. Which is the
    first lever to try, and why is the other one a heavier operation?
12. Why does `min.insync.replicas=2` with replication factor 3 (or 2 with RF
    matching your Day 6 topic config) make a one-broker-at-a-time rolling
    upgrade safe? What would break if `min.insync.replicas` equaled the full
    replication factor instead?

## Answers

**1.** IAM auth requires SASL/SSL — an authenticated, encrypted session — which
a plaintext connection has neither of. MSK's public-access mode makes TLS
(via IAM or mTLS certs) mandatory because exposing broker traffic to the
public internet with no encryption and no identity check would let anyone
who finds the broker address read/write data; AWS's `ClientAuthentication`
schema doesn't offer plaintext when `PublicAccess.Type` is
`SERVICE_PROVIDED_EIPS`.

**2.** At minimum: `kafka-cluster:Connect`, `WriteData`, `ReadData`,
`DescribeGroup`, and `AlterGroup` (to commit offsets); `DescribeCluster` is
typically included too. Scoped to a cluster ARN resource, e.g.
`arn:aws:kafka:<region>:<account>:cluster/kafka-practice-msk/*`. If your
Day 6 policy also granted `AlterCluster` or `*Topic*` actions, those exceed
what a pure client needs and belong on an admin principal instead.

**3.** Sustained (not transient) under-replication means some replica set
has lost sync with its leader and isn't catching up on its own — page
someone, don't wait. Check first: is a broker down/unreachable
(`aws kafka list-nodes`), is there a VPC network partition, or is a broker
too overloaded (disk/CPU/network) to keep up with replication traffic. This
is the "should be zero at rest" metric from Day 8 — sustained non-zero is a
live incident.

**4.** `<source-alias>.<topic>`. Replicating `payments` from `east` to
`west` produces `east.payments` on `west` — the *source* alias, not the
target, prefixes the name, which is what lets multi-hop/bidirectional
topologies avoid collisions.

**5.** Wrong: the target is a separate log with its own offset sequence.
As MirrorMaker2 appends mirrored records, the target assigns brand-new
offsets independent of the source's. "The same" message has two different
offsets, one per cluster, so a consumer failing over needs a *translated*
offset to resume correctly — otherwise it either rereads processed messages
or skips unprocessed ones.

**6.** A sink connector. MSK Connect needs, before creation: (1) a custom
plugin registered from a zipped connector JAR in S3 (`create-custom-plugin`),
(2) an IAM role for the connector granting both Kafka access and the
destination permission (e.g. `s3:PutObject`), and (3) a worker configuration
(capacity, cluster connection info with IAM auth, plugin ARN, connector
settings) passed to `create-connector`.

**7.** Beyond registering a schema, the Glue-backed Avro converter gives a
Connect pipeline the same schema-evolution guarantee a manually-integrated
registry gives hand-written clients: compatibility is checked at write time,
so a breaking schema change is caught immediately rather than discovered
later when a consumer fails to deserialize a record — meaningful precisely
because Connect pipelines have no custom code to bolt registry calls onto.

**8.** Urgent but not yet an outage — act before brokers hit 100% and stop
accepting writes. Two options: shorten `retention.ms` (fast, free, no
infra change) or grow broker storage (a capacity change, not instant).
Shortening retention is usually tried first when the data doesn't need to
be kept that long; growing storage is the fallback when it does.

**9.** Same mechanism as Day 4's chaos labs: replication factor and ISR
tracking mean the rebooting broker's partitions still have other in-sync
replicas serving traffic, so MirrorMaker2's internal consumer sees only a
transient dip, not a hard failure. Once the broker rejoins and re-enters
the ISR, lag drains with no manual restart — nothing about group
membership or topic availability was ever fully lost.

**10.** During an incident, the CLI queries the cluster directly with no
refresh delay — critical when seconds matter — while CloudWatch has ~1-minute
granularity plus dashboard lag. A week later writing a postmortem, the CLI
is useless (it only ever showed a live snapshot) while CloudWatch's
retained time series lets you reconstruct exactly when and how a metric
trended.

**11.** Add partitions first: `--alter --partitions N` is near-instant with
no data migration — only new records land on the new partitions, and
consumers pick them up on the next rebalance. Adding a broker is heavier:
capacity alone doesn't rebalance anything, so a separate partition
reassignment is needed to actually move data onto the new broker.

**12.** With RF 3 and `min.insync.replicas=2`, a write needs acks from only
2 of 3 replicas, so taking one broker offline for an upgrade still leaves 2
in-sync replicas and writes keep succeeding. If `min.insync.replicas`
equaled the full RF (3 of 3), taking any broker offline would drop the
in-sync count below the minimum and every produce request would start
failing the moment the upgrade touched the first broker.

## CCAAK domain self-check

Cross-reference how the questions above went against the CCAAK domain table
in `kafka_practice/docs/superpowers/specs/2026-07-09-kafka-15-day-plan-design.md`:
cluster configuration & deployment (Days 1, 6, 9 — questions 1, 3, 8, 9, 11,
12 above), security (Days 5, 6, 11 — questions 1, 2), monitoring & operations
(Days 8, 10 — questions 3, 8, 10), Kafka Connect (Days 7, 12 — questions 6,
7), and multi-cluster/disaster recovery (Day 9 — questions 4, 5, 9). If any
one of these domains produced more wrong or shaky answers than the others,
write that domain down explicitly now, by name — Day 15's gap analysis is
built to come back to exactly this note, and a vague "I was a bit fuzzy on
DR" is much less useful three weeks from now than "MirrorMaker2 offset
translation, specifically."

## Hands-on: AWS teardown

Everything provisioned since Day 6 — the MSK cluster's brokers, the Connect
plugin/connector infrastructure, S3 buckets, CloudWatch alarms and
dashboard, the Glue registry — bills or persists regardless of whether it's
being actively used right now. MSK in particular is billed by broker-hour:
a `kafka.t3.small` two-broker cluster left running over a weekend costs the
same whether or not a single message crosses it, and there is no idle
shutdown or auto-pause the way there might be for, say, a serverless
function. The Day 6 budget alert is a smoke detector, not a fire suppressor
— it notifies after spend has already happened; it doesn't stop it. The only
real guardrail is doing the teardown itself, in full, today, rather than
"later." The exact commands, in the order that matters (connectors and
plugins before the cluster, since some resources depend on others existing),
are in Day 10's step 4 in
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` —
run every one of them, then run the verification queries at the end of that
step and confirm both come back empty before considering today done. Leave
the AWS Budget itself in place; it costs nothing and is harmless to keep
watching the account through the rest of the plan.

## Journal template

```
## Day 10 — Review (Days 6-9)
Score: __/__
Concept gaps found: ...
```
