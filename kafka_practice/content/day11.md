# Day 11 — Confluent Cloud: RBAC vs. Day 5's ACLs vs. Day 6's IAM

## Learning objectives

By the end of today you should be able to:
- Explain what a Confluent Cloud **role binding** is (principal + role +
  resource scope) and pick the right predefined role for a need
  (`CloudClusterAdmin` vs. `DeveloperRead` vs. `DeveloperWrite`).
- Show that RBAC role bindings, Day 5's Kafka ACLs, and Day 6's AWS IAM
  policies are the same access-control model — WHO (principal) / WHAT
  (operation) / WHICH (resource) — in three different vendor syntaxes.
- Explain what a **service account** is and why an API key is a
  *credential belonging to* an account, not the account itself.
- Diagnose a "connects fine, everything denied" failure as an
  authorization gap rather than an authentication failure — the same
  triage Day 5 used for ACLs, now applied to role bindings.
- Map one access requirement into all three systems' native syntax.

## Reference material

- Confluent Cloud docs: **Quick Start** — environment/cluster concepts,
  API keys, `confluent` CLI basics.
- Confluent Cloud docs: **Role-Based Access Control** — the predefined
  role list and role-binding syntax.

The ACL/IAM mechanics are recapped below just enough to make today's
three-way comparison concrete; if either feels shaky, revisit Day 5's or
Day 6's journal entry first.

## Theory

### Predefined roles and the role binding

Confluent Cloud RBAC ships a fixed catalog of roles instead of letting you
assemble a permission set operation-by-operation. Today's three:

- **`CloudClusterAdmin`** — full administrative control over a cluster
  (topics, configs, ACLs/role bindings). Give this to a platform-team
  automation account or human operator, never an application.
- **`DeveloperRead`** — read scoped to one resource: a named topic
  (consume + describe) or a named consumer group (join + commit offsets).
  No access to any other topic/group — scope is per-binding.
- **`DeveloperWrite`** — write scoped to one named topic. Narrow by
  design, same as `DeveloperRead`.

A role name alone isn't a grant — it becomes one only once attached to a
specific principal and resource. That attachment is the **role binding**,
a triple: `principal (WHO) + role (WHAT) + resource scope (WHICH)`.
Concretely: `User:$SA_ID` bound to `DeveloperRead` scoped to
`Topic:orders`. That triple is not a Confluent invention — it's exactly:

- **Day 5's ACL**: `--allow-principal User:app-consumer --operation Read
  --topic orders` → principal, operation (WHAT), resource (WHICH).
- **Day 6's IAM statement**: `"Effect": "Allow"`, `"Action":
  ["kafka-cluster:ReadData"]` (WHAT), `"Resource": "arn:...cluster/..."`
  (WHICH), attached to a principal via policy/role attachment (WHO).

Three vendors, three syntaxes, one model: **an identity is granted a set
of operations against a bounded resource.** That's the fact worth stating
confidently in a review: ACLs, IAM, and RBAC are one authorization
primitive with different vendor packaging — not three things to relearn
from scratch each time the infrastructure changes.

### Why managed RBAC trades flexibility for operability

Day 5's ACL model is maximally flexible — grant `Read` without
`Describe`, mix per-topic grants arbitrarily, one `--operation` flag at a
time. That flexibility has a cost: someone must correctly assemble the
right operation list every time, and mistakes (over-broad grants, a
missing `Describe`) are easy to make and easy to miss in review.

RBAC's predefined roles simplify that same design space: pick from a
short, audited list instead of hand-assembling operations. You lose the
ability to construct exotic combinations RBAC didn't anticipate, but you
gain a system where "what does `DeveloperRead` mean" has one documented
answer, not one that depends on whoever wrote a particular ACL. This is
the standard managed-service trade — less flexibility, more consistency
and fewer operational mistakes — the same trade AWS makes with managed
IAM policies vs. hand-rolled inline policies.

### Service accounts: a non-human identity

A **service account** represents an application, connector, or automated
process — not a person. It's Confluent Cloud's analogue of Day 5's
`app-consumer` SASL principal and Day 6's IAM role for a workload:
something software authenticates *as*, distinct from a human's `User:`
identity.

Why this matters: a personal API key grants whatever role bindings *you*
have, likely broad if you do admin work. Wiring that into an application
means the app now runs with your blast radius, and offboarding means
finding every place that key was pasted. A service account scoped to only
what one application needs decouples its access from any human's — it can
be rotated, audited, and revoked independently, and it outlives the person
who created it. This is why the Day 11 lab creates `app-consumer-sa`
rather than reusing a personal login — the same principle as Day 6's
dedicated connector IAM role instead of personal AWS credentials.

## Best practices

- **One service account per application/connector, never shared.**
  Sharing an account (and its key) across unrelated consumers means you
  can't revoke or rotate one without affecting the other. Mirrors Day 5's
  "own SASL principal per application."
- **Grant the narrowest role that covers the need.** A read-only consumer
  gets `DeveloperRead` on its specific topic/group, not `CloudClusterAdmin`
  — same principle as Day 5 (no `Write` for a read-only principal) and
  Day 6 (no `AdministratorAccess` when a scoped policy suffices).
- **Rotate API keys on a schedule**, and immediately on suspected
  exposure — same hygiene as rotating a SASL password or IAM access key.
  Because an account can hold multiple keys, provision the new one, cut
  the app over, then deactivate the old — zero-downtime rotation.
- **Name accounts and bindings for what they're for**, not generically.
  During an audit six months later, the name is the only context anyone
  has.

## Common pitfalls

- **Assuming a fresh service account has any access by default.**
  Confluent RBAC is deny-by-default, identically to Day 5's authorizer
  once ACLs are enabled — zero bindings means everything is denied, even
  though the API key authenticates fine.
- **Confusing "key belongs to a service account" with "key IS the
  account."** The account holds the role bindings; a key is one of
  potentially several credentials that authenticate *as* it. Revoking one
  key doesn't touch the account's bindings, and a new key for the same
  account inherits all its existing access.
- **Treating RBAC roles as infinitely fine-grained like hand-rolled
  ACLs.** If a need doesn't map cleanly onto a predefined role, that
  granularity may just not exist — accept the closest role, or (self-
  managed Kafka only) fall back to ACLs. Don't hunt for a role matching an
  ACL-level distinction RBAC wasn't built to express.
- **Scoping a binding at the wrong resource level.** A binding scoped at
  the cluster instead of a specific `Topic:`/`Group:` grants that role
  across every resource of that type — easy to do by omitting resource
  scoping and getting a far broader grant than intended.

## Real-world use cases

- **Onboarding a SaaS integration.** A partner's webhook relay needs to
  publish to one topic: new service account, `DeveloperWrite` scoped to
  that one topic, its own key — not `CloudClusterAdmin`, and not sharing
  an account with any other integration, so a leaked key's blast radius is
  one topic's write access.
- **Handing a Connect worker its credentials.** A sink connector reading a
  topic gets `DeveloperRead` on that topic and its consumer group — never
  the operator's personal key. The RBAC-flavored version of Day 6's
  dedicated connector IAM role and Day 5's dedicated SASL principal.
- **Briefing a security reviewer.** When asked "how do you control writes
  to production topics," answering "principal, permission, resource — same
  model as our IAM policies and Kafka ACLs, expressed as role bindings"
  signals a coherent access-control story across the stack, not three
  disconnected systems that happen to coexist.

## Worked example

**Setup:** `app-consumer-sa` has an API key that authenticates fine (no
SASL/TLS error), but every produce attempt fails with
`TopicAuthorizationException`, and consuming also fails until a binding is
added.

**Diagnosis, same authenticated-vs.-authorized split as Day 5:**

1. **Authentication or authorization?** Connection succeeds; the error is
   `TopicAuthorizationException`, not a handshake failure — so the key is
   valid and the principal is identified correctly. Points at the
   authorizer layer, exactly like Day 5's ACL lab.
2. **What bindings does this principal have?** Check with `confluent iam
   rbac role-binding list --principal User:$SA_ID`. An empty list means
   zero access — deny-by-default, not a bug.
3. **Add the binding matching the intended access**: `DeveloperRead` on
   `Topic:orders` and `Group:orders-group` for consuming; `DeveloperWrite`
   on `Topic:orders` only if produce was actually intended. If the goal is
   read-only, the write denial after adding just `DeveloperRead` is
   correct behavior, not a bug — `DeveloperRead` deliberately excludes
   write.
4. **Re-test.** Consume now succeeds; produce should still fail, confirming
   the role does exactly what it says and nothing more.

"Connects, authenticates, everything denied" is structurally identical to
Day 5's `app-consumer` hanging with zero ACLs, and to an IAM principal with
no matching policy statement. In all three systems the fix is "grant the
binding/ACL/statement matching the intended access," never "the
credential is broken."

## Exercises

1. A service account has one binding, `DeveloperRead` on `Topic:payments`,
   and tries to consume via group `payments-group`. What happens, and why?
2. From Exercise 1, what's the minimum additional change for the consumer
   to actually make progress?
3. Map *"Allow principal `billing-app` to produce to topic `invoices`
   only"* into all three syntaxes: (a) `kafka-acls.sh` command, (b) IAM
   policy statement shape, (c) `confluent iam rbac role-binding create`
   command. Exact ARNs/IDs not required — show the structural shape.
4. A teammate gives a new connector's service account `CloudClusterAdmin`
   "so I don't have to debug more permission errors." What's wrong, and
   what should they do instead?
5. True or false, with justification: revoking one API key belonging to a
   service account removes that account's role bindings.
6. A binding for `DeveloperWrite` on `Topic:orders` exists, but the app
   still can't produce. Name two non-role-binding explanations to check
   first.

## Answers

1. **Fails**, likely `GroupAuthorizationException` — the binding covers
   the *topic*, but group membership is a separate resource
   (`Group:payments-group`) needing its own `DeveloperRead` binding. Same
   as Day 5, where topic read and group read are separate ACL grants.
2. **Add a second binding**: `DeveloperRead` on `Group:payments-group` for
   the same principal — topic-level and group-level read are independent
   grants in both ACLs and RBAC.
3. (a) `kafka-acls.sh --add --allow-principal User:billing-app --operation
   Write --operation Describe --topic invoices`. (b) IAM statement,
   `"Effect": "Allow"`, `"Action": ["kafka-cluster:WriteData",
   "kafka-cluster:DescribeTopic"]`, `"Resource"` scoped to the topic ARN,
   attached to the `billing-app` principal. (c) `confluent iam rbac
   role-binding create --principal User:<billing-app-SA-id> --role
   DeveloperWrite --resource Topic:invoices --cluster <CLUSTER_ID>`. All
   three express the same triple — differing only in syntax.
4. **Defeats least privilege to save debugging time**, the RBAC-world
   version of pasting a personal admin key into an app config.
   `CloudClusterAdmin` is far beyond what a connector needs, so a
   compromised connector gets cluster-wide blast radius. Instead: check
   `role-binding list`, compare against the connector's actual
   reads/writes, and grant the specific `DeveloperRead`/`DeveloperWrite`
   bindings needed — the same triage as the Worked example.
5. **False.** Bindings attach to the service account, not any one key. An
   account can hold multiple keys (e.g. during rotation); revoking one
   removes only that credential's ability to authenticate — bindings and
   other keys are unaffected.
6. (a) **Wrong resource scope** — bound to the wrong cluster, or a typo in
   the topic name, so the binding exists but doesn't cover the resource
   actually being written to. (b) **Stale/mismatched credentials** — the
   app's config points at the wrong cluster/bootstrap-server (wrong
   environment/cluster ID), so the request never reaches the cluster the
   binding was created on. Neither is an RBAC bug — both are
   configuration-matching problems producing the same symptom.

## Hands-on lab

Run today's Confluent Cloud setup and RBAC lab exactly as specified in
**Day 11** of `kafka_practice/docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md`
— it has the exact `confluent` CLI commands for the environment, cluster,
API keys, the `app-consumer-sa` service account, and its role bindings, so
they aren't repeated here.

Once you have the service account's API key/secret and the cluster's
bootstrap endpoint, fill them into:

- `kafka_practice/labs/config/confluent-app-consumer.properties` — Java,
  JAAS-style (`sasl.jaas.config=...PlainLoginModule required
  username="..." password="...";`), used by `ConsumerDemo`/`ProducerDemo`.
- `kafka_practice/labs-go/config/confluent-app-consumer.properties` — Go,
  flat `sasl.username`/`sasl.password` keys instead of a JAAS string (the
  Go client doesn't use JAAS — same SASL/PLAIN mechanism, different config
  surface). Use whichever language tree you've been running.

Expected per the plan: the consumer succeeds against the `DeveloperRead`
binding; the producer fails with `TopicAuthorizationException` — walk that
through the Worked example's diagnosis steps rather than just noting
"expected" and moving on.

Finish with the plan's Step 6: a three-way table in `journal.md`, Day 5
ACLs vs. Day 6 IAM vs. today's RBAC — same principal+operation+resource
model, three syntaxes.

## Journal template

```
## Day 11 — Confluent Cloud, RBAC comparison
Key idea in my own words: ...
What confused me: ...
```
