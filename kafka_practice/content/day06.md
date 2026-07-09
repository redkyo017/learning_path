# Day 6 — AWS MSK: Provisioning a Secured, Cost-Conscious Cluster

## Learning objectives

By the end of today you should be able to:
- Explain the division of responsibility between AWS and you on a
  provisioned MSK cluster — what AWS manages vs. what you still configure.
- Describe how MSK's IAM authentication model maps onto the
  authentication/authorization split from Day 5's SASL/SCRAM + ACLs.
- Explain what MSK's public access mode does, and why AWS requires a
  TLS-based auth mechanism (IAM or mTLS) to use it.
- Reason about MSK's cost model (broker-hour + storage vs. Serverless
  per-request pricing) well enough to justify an instance-size choice.
- Diagnose a "policy looks right but the client still gets denied" IAM
  authorization failure.

## Reference material

- AWS MSK docs — *Getting Started* guide
- AWS MSK docs — *IAM Access Control for Amazon MSK*
- AWS MSK — *Pricing* page (broker-hour rates by instance type, storage
  rate, and the separate MSK Serverless pricing model)

Today's primer reading is these three pages; the theory below assumes you've
skimmed them and fills in the "why," not the click-by-click "how." The exact
CLI commands for provisioning live in Day 6 of
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`, not
here.

## Theory

### What MSK actually manages, and what's still yours

"Managed Kafka" is a narrower promise than it sounds. MSK takes over the
**broker software lifecycle** (AWS runs the broker process, patches the OS
and Kafka version, replaces failed hardware), the **metadata/consensus
layer** (ZooKeeper or KRaft controllers, run and healed by AWS — you never
SSH into a controller, unlike the cluster you hand-built on Day 1), and the
**ENIs/broker networking plumbing** that gives each broker an address inside
your VPC.

What AWS does **not** take off your plate: **broker sizing and count**
(instance type and node count are your call — get it wrong and you either
throttle throughput or waste broker-hour spend); **storage** (EBS volume
size per broker, and whether to auto-scale it — retention settings still
determine how fast it fills, as on Day 4); **networking and security
groups** (MSK deploys into subnets/security groups *you* specify;
reachability, including public access, is entirely your configuration —
AWS's default is "private unless you say otherwise"); **topic configs**
(partitions, replication factor, `min.insync.replicas`, compaction vs.
deletion, same as Days 2 and 4); and **client-side auth and identities**
(MSK offers a *mechanism* — IAM, SASL/SCRAM, or mTLS — but which principals
get access and what they can do is a policy you write, same as Day 5's
ACLs).

MSK removes the operational toil of keeping brokers and metadata alive, but
every architectural decision you'd make self-hosting is still yours to make
here — it's managed infrastructure, not managed opinions.

### IAM authentication as AWS-native SASL/SCRAM + ACLs

Day 5 established a two-part model: **authentication** proves who's
connecting (SASL/SCRAM verified a password; mTLS verified a certificate),
and **authorization** decides what that identity can do (ACLs granted
operations on resources to principals). MSK's IAM auth mode is the same
model in AWS clothes. For **authentication**, the client signs its
connection with AWS SigV4 (the same request-signing scheme as every other
AWS API call) using an IAM user or role's credentials; the broker verifies
that signature against IAM rather than a Kafka-internal store — hence the
different port/protocol (`SASL_SSL` + `AWS_MSK_IAM` mechanism on port
9098), even though it's conceptually still "prove who you are." For
**authorization**, instead of ACLs granting `Read`/`Write`/`Create` to a
`User:principal` on a `Topic:resource`, an **IAM policy** grants
`kafka-cluster:*` actions (`ReadData`, `WriteData`, `AlterGroup`, etc.)
scoped to a cluster **ARN**, attached to an IAM user or role. IAM evaluates
it exactly like an S3 or EC2 policy — there's no separate "Kafka authorizer"
to learn, because MSK plugs Kafka's authorization hook into IAM's existing
engine.

Same shape, different vocabulary: `Effect`/`Resource`/`Action` plays the role
`--operation`/`--topic`/`--allow-principal` played in `kafka-acls.sh`. The
payoff: an AWS-native shop doesn't need a second identity system just for
Kafka — the IAM users, roles, and rotation/audit tooling that already govern
S3 now govern Kafka too.

### Public access mode and why it demands strong auth

By default, a provisioned MSK cluster is **VPC-internal only** — broker
ENIs get private IPs, reachable only from inside the VPC (or anything
peered/VPN'd into it), the safe default you'd expect from any internal
database.

**Public access mode** (`ConnectivityInfo.PublicAccess.Type:
SERVICE_PROVIDED_EIPS` for this lab) is an explicit opt-in that assigns each
broker a public IP, so a laptop can reach the cluster with no VPN or bastion
in the path. Convenient for a lab — and exactly the kind of convenience that
would be reckless without a guardrail, since it makes Kafka's wire protocol
reachable from the entire internet.

AWS's guardrail: **public access is only permitted if client authentication
is IAM or mutual TLS** — plaintext or SASL/SCRAM-over-plaintext brokers
cannot be exposed publicly. Both allowed mechanisms bring TLS to the
connection, so a publicly reachable broker never hands out data over an
unencrypted, weakly-authenticated channel — the same instinct behind Day 5's
`SASL_PLAINTEXT` listener staying bound to `localhost`, just enforced by AWS
policy instead of relying on every account to remember.

### The cost model, and why it shapes your instance choice

Provisioned MSK bills two largely independent things: **broker-hours** (a
per-hour rate by instance type, times broker count, running continuously
whether or not messages flow) and **storage** (per-GB-month on each
broker's EBS volume, accruing regardless of how full it is).

**MSK Serverless** is a different model: pay per partition-hour and per GB
actually written/read, no broker-hour charge, no instance type to pick — AWS
scales capacity behind the scenes. Good for spiky workloads, but it hides
most of the per-broker config knobs this plan is built around inspecting.
That's why this lab uses provisioned `kafka.t3.small`: cheapest provisioned
option, but still provisioned, so Days 4–5's knobs remain comparable.

For a learning cluster that exists a few days, the smallest representative
instance keeps the running bill low no matter how many hours it's left up by
accident. A production cluster sizes for sustained throughput, accepting a
larger rate — but you'd never want to learn a new instance type's failure
characteristics for the first time in production.

## Best practices

- **Scope IAM policies to the specific cluster ARN and only the needed
  actions** — not `kafka-cluster:*` on `Resource: "*"`. A policy scoped to
  `cluster/kafka-practice-msk/*` can't touch other clusters in the account.
- **Treat a budget alert as a smoke detector, not a safeguard.** It flags
  that the bill crossed a threshold; it doesn't stop the meter. The real
  guardrail is a scheduled teardown (Day 10) — decide when the cluster dies
  up front, don't rely on noticing an email.
- **Pick the smallest broker size representative of what you're testing**,
  not the biggest available "to be safe." `kafka.t3.small` teaches the same
  IAM/ACL/topic-config concepts as `kafka.m5.4xlarge` for a fraction of the
  cost — size up only when specifically testing throughput.
- **Spread broker subnets across multiple AZs**, same durability instinct
  as Day 4's replication factor.
- **Name security groups and policies for their exact purpose**
  (`msk-lab-sg`, `kafka-practice-msk-access`) so a later audit — including
  your own Day 10 teardown — can tell at a glance what's safe to delete.

## Common pitfalls

- **Assuming a fresh MSK cluster is internet-reachable by default.** It's
  VPC-internal unless you explicitly opt into public access with a
  compatible auth mechanism.
- **Forgetting broker-hour billing runs whether or not you're using the
  cluster.** Unlike Serverless's usage-based billing, a cluster provisioned
  Monday and forgotten until Friday bills the full elapsed time, idle or not.
- **Granting an overly broad IAM policy "to get unblocked," then never
  narrowing it.** `kafka-cluster:*` on `Resource: "*"` gets you moving fast
  and becomes a standing liability the moment nobody tightens it.
- **Typo'ing the cluster ARN's region or account ID** in a hand-written
  policy — a wrong region silently matches nothing, and IAM's default-deny
  gives no hint the ARN itself was wrong.
- **Confusing "cluster is ACTIVE" with "cluster is reachable."** `ACTIVE`
  means provisioning finished, not that your security group or IAM policy
  lets a client through — check them independently.

## Real-world use cases

- **Standardizing on IAM auth to piggyback on existing governance.** A team
  already using IAM roles and credential rotation for S3/RDS gains little
  from a second, Kafka-specific identity system. IAM auth puts Kafka access
  in the same policy reviews and audit trail as everything else.
- **Serverless vs. provisioned for a bursty workload.** A workload that
  spikes 50x during a launch and sits idle otherwise: provisioned brokers
  sized for peak sit expensively idle most of the time; Serverless absorbs
  the variance but loses fine-grained broker-level tuning. The decision
  hinges on whether anyone's actually using that tuning today.

## Worked example: "my IAM policy looks right but I still get denied"

**Ticket:** *"I attached the policy exactly as documented, scoped to my
cluster's ARN, with `Connect` and `ReadData` granted. My producer connects
and writes fine, but my consumer gets an authorization exception reading.
The policy is definitely attached to my user."*

Verify each link in the chain independently rather than re-reading the
policy again:

1. **ARN region/account mismatch?** A policy scoped to the wrong region or
   account grants nothing — IAM does exact-string matching, not "close
   enough." The single most common cause of "policy looks fine, denied
   anyway."
2. **Attached to the identity the client actually assumes?** "Attached to
   my user" doesn't help if the client authenticates as an assumed *role*
   (EC2 instance profile, ECS task, Lambda). Confirm the principal in the
   actual denial/CloudTrail event, not the one you intended.
3. **Does the policy cover the action actually denied?** Consumer group
   operations need `DescribeGroup`/`AlterGroup` in addition to `ReadData` —
   joining a group alters membership. A policy granting topic read but
   omitting group actions lets a consumer connect and fetch, then fail at
   group coordination, which looks like a plain read denial.
4. **Typo in the resource path** — cluster name, a missing/extra `/*`, a
   mismatched topic suffix? One wrong character makes the statement not
   apply, and default-deny gives silent rejection, not a helpful message.

**Most likely resolution:** writing works but reading (which needs the
group actions) doesn't, so #3 is strongest — the policy is probably missing
`AlterGroup`/`DescribeGroup`. Confirm by diffing granted actions against
Kafka's own consumer-group operations, same as diffing an ACL grant on
Day 5.

## Exercises

1. Your cluster has no `ConnectivityInfo.PublicAccess` block specified at
   all. A teammate insists they should be able to reach it from their home
   laptop over the internet. Are they right?
2. You try to enable public access on a cluster whose
   `ClientAuthentication` only has `Unauthenticated: {Enabled: true}` set.
   What happens, and why does AWS enforce that?
3. In one or two sentences, explain how an IAM policy's
   `Resource: "arn:aws:kafka:us-east-1:123456789012:cluster/kafka-practice-msk/*"`
   is functionally equivalent to a piece of a Day 5 `kafka-acls.sh` command.
   Which piece?
4. You provision a `kafka.t3.small`, 2-broker cluster Monday morning for a
   lab and forget about it until Friday. Which cost model — provisioned
   broker-hour or MSK Serverless — would have cost more, and why?
5. A client authenticates successfully but every operation returns an
   authorization exception. Give two distinct, independently-checkable
   reasons unrelated to whether the policy's `Action` list is correct.
6. Your lead asks: "why not just use MSK Serverless for everything, so we
   never think about broker sizing?" Give one legitimate reason this plan
   avoids Serverless for the next several days of labs.

## Answers

1. **Likely wrong.** With no `PublicAccess` block, MSK defaults to
   VPC-internal — brokers get private IPs only. Unless the teammate
   connects through something inside the VPC (VPN, peering, bastion), a
   plain internet connection has no route at all. Public access is a
   separate, explicit opt-in.
2. **The request should fail/be rejected.** MSK requires IAM or mTLS
   client authentication before allowing public access; `Unauthenticated`
   is exactly the case the restriction blocks. A publicly reachable,
   unauthenticated broker would let anyone on the internet read and write
   your topics — the restriction makes that impossible, not just
   discouraged.
3. It plays the role of the `--topic <name>` (plus the cluster identified
   via `--bootstrap-server`) portion of `kafka-acls.sh --add
   --allow-principal ... --operation Read --topic orders` — it identifies
   *which resource* the grant applies to. `Action` (e.g. `ReadData`)
   mirrors `--operation Read`; the attached principal mirrors
   `--allow-principal`.
4. **Provisioned broker-hour billing costs more here**, because it never
   stops: two brokers plus EBS storage bill continuously Monday-to-Friday
   regardless of lab activity. Serverless's per-request/partition-hour
   model would have billed near-zero during the idle stretches — why the
   real fix is a scheduled teardown, not a budget alert.
5. Any two of: the policy is attached to a different principal than the one
   the client actually authenticates as; the resource ARN's
   region/account/cluster name doesn't exactly match; the policy was
   drafted and saved but never actually attached to the calling identity;
   the client is pointed at the wrong cluster ARN/bootstrap string entirely.
6. Serverless hides per-broker configuration knobs (Days 4–5's segment
   sizing, replication internals, security settings) this plan is designed
   to let you inspect and tune. Comparing "the same knob on self-hosted
   Kafka vs. MSK" — the point of Day 6 following Day 5 — is much harder if
   Serverless abstracted that knob away. Serverless is a legitimate
   production choice for the right workload; it's just the wrong choice for
   a plan built around comparing configuration surfaces.

## Hands-on lab

The exact `aws` CLI commands live in Day 6 of
`kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` —
follow those verbatim. This section only orients you to the files involved:

- **`kafka_practice/aws/msk-cluster-config.json`** — the cluster spec for
  `create-cluster-v2`. Note `ClientAuthentication.Sasl.Iam.Enabled: true`
  (turns on IAM auth) and `ConnectivityInfo.PublicAccess.Type:
  SERVICE_PROVIDED_EIPS` (the public-access opt-in discussed above); fill in
  your own subnet/security-group IDs from the plan's networking step.
- **`kafka_practice/aws/iam-policy.json`** — the policy from the worked
  example above, made concrete: `Action` entries map onto Kafka operations
  (`Connect`, `ReadData`, `WriteData`, `AlterGroup`/`DescribeGroup`, plus
  topic-management actions); `Resource` is the cluster ARN, available only
  once the cluster finishes provisioning — hence drafting this file in
  parallel with provisioning rather than before it.
- **`kafka_practice/labs/config/msk-iam.properties`** — the Java config
  that switches `ProducerDemo`/`ConsumerDemo` from Days 2–3 onto MSK:
  `security.protocol=SASL_SSL`, `sasl.mechanism=AWS_MSK_IAM`, and the AWS
  MSK IAM auth library wired in via `sasl.jaas.config`. No code changes —
  Day 2's config-file design paying off as intended.
- **`kafka_practice/labs-go/config/msk-iam.properties`** — the Go
  equivalent, with a wrinkle: it only sets `auth.mode=aws-msk-iam` and
  `aws.region=<AWS_REGION>`, not `security.protocol`/`sasl.mechanism`
  directly. Those are set *in code* by `kafkaclient.MaybeConfigureAWSIAM`
  (`kafka_practice/labs-go/internal/kafkaclient/iam.go`), which reads
  `auth.mode` and, if `aws-msk-iam`, attaches AWS SigV4 signing to the
  `kafka.ConfigMap` before connecting — a convenience key a Go call site
  must explicitly honor. Skip calling `MaybeConfigureAWSIAM` in a new entry
  point and `auth.mode` silently does nothing, producing a confusing
  plaintext-connection failure instead of an IAM error.

## Journal template

```
## Day 6 — AWS MSK provisioning
Key idea in my own words: ...
What confused me: ...
```
