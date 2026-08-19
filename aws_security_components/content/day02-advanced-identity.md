# Day 2 — Advanced identity

## Why this matters at work

Every cross-account integration, every CI/CD pipeline deploying into a
different account, every SaaS vendor asking to "assume a role in your
account" runs on the same primitive: `sts:AssumeRole` against a trust
policy. Get the trust policy wrong and you've built a confused-deputy hole
that any customer of that same vendor can walk through. Get the
*downstream* controls wrong — no permission boundary on the roles your
team can create — and a single mis-scoped `iam:PassRole` grant turns a
low-privileged pipeline role into a path to anything in the account. Both
failure modes are invisible in a policy read-through; both are common
enough to have their own name in the security literature. Today gives you
the STS mental model and the two "ceiling" tools (permission boundaries,
session policies) that keep either mistake from becoming full account
compromise.

## The engine lens

Day 1 fixed the evaluation order cold:

```
explicit Deny → SCP/RCP → resource policy → identity policy →
permission boundary → session policy
```

Today lives at three doors in that chain, all downstream of the identity
policy:

- **The trust policy is a resource policy** — attached to the role, not
  the caller, evaluated as the *resource-based policy* door, checked
  **on the `AssumeRole` call itself**, before anything about the caller's
  own identity policy is even consulted for that call. It answers one
  question only: "is this caller allowed to assume this role at all?"
- **The permission boundary** and **the session policy** are the two
  doors *after* the identity policy — both are pure **caps**, never
  grants. `effective permission = intersection(identity policy,
  boundary, session policy)`. A boundary is attached to the role/user
  persistently; a session policy is passed inline at `AssumeRole` time
  and applies only to that one set of temporary credentials.

Why identity comes before both caps: a cap can only narrow something that
was already granted. If the identity policy never granted an action, it
doesn't matter what the boundary or session policy say — there's nothing
to narrow. That's the whole reason ANTIPATTERNS.md #6's `iam:PassRole`
mistake is dangerous: the identity policy *does* grant it, broadly, so
there's something for an attacker to use, and — until you add a boundary —
nothing capping it.

## Core concepts

### `sts:AssumeRole` and trust policies

`AssumeRole` exchanges a caller's current identity for a temporary
credential set (access key, secret key, session token — expiring, never
long-lived) scoped to a target role. The base workload already has two
examples, in `labs/base/iam.tf`:

```hcl
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
```

This is `aws_iam_role.task`'s (and `task_execution`'s) **trust policy** —
it says "the `ecs-tasks.amazonaws.com` service principal may assume this
role," which is how a launched Fargate task ends up holding the task
role's temporary credentials without ever touching a long-lived secret.
[**AssumeRole**](GLOSSARY.md#a) and [**Trust policy**](GLOSSARY.md#t) are
both in the glossary if you need the one-line refresher.

A cross-account trust policy looks the same shape, just with a different
principal:

```json
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::111122223333:root" },
  "Action": "sts:AssumeRole"
}
```

Anyone in account `111122223333` with `sts:AssumeRole` in their own
identity policy can now assume this role. That's the setup for the next
problem.

### The confused-deputy problem and `ExternalId`

[**Confused deputy**](GLOSSARY.md#c): a trusted, more-privileged party
(here, the role owner accepting `AssumeRole` calls) is tricked into acting
on behalf of the wrong caller, because trust was granted on identity alone
— "any principal with this ARN" — not on *which specific relationship*
that principal is calling on behalf of.

Concretely: you run a SaaS product. Customer A gives you a role ARN to
assume in their account so your service can do its job. You hardcode
"assume `arn:aws:iam::111122223333:role/YourSaaSRole`" into your product.
Customer B, using the same product, could be handed the exact same trust
relationship shape by a *different* SaaS vendor using your same AWS
account ID as their intermediary (a real, documented pattern — the
"third-party access" problem AWS's own docs describe). Without anything
distinguishing "this AssumeRole call is on behalf of Customer A" from
"...on behalf of Customer B," your service could be tricked into acting
in the wrong customer's account, or a malicious third party could
construct a call your role trusts without ever having been given the
role's ARN by the real owner.

The fix is [**ExternalId**](GLOSSARY.md#e) — a caller-supplied string
required via a condition key:

```json
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::999999999999:root" },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": { "sts:ExternalId": "customer-a-unique-token" }
  }
}
```

It isn't a secret in the cryptographic sense — it's a shared token that
forces the caller to prove they know *which specific relationship* they're
invoking `AssumeRole` for. Without it, `Principal` alone is the only check,
and `Principal` doesn't know about relationships, only ARNs.

### Permission boundaries — the ceiling, not the grant

[**Permission boundary**](GLOSSARY.md#p): a managed policy attached to a
role or user that sets the maximum an identity policy can ever grant that
principal. It never grants anything itself. Written as an ALLOW-list, and
anything the allow-list doesn't mention is outside the ceiling — no
explicit `Deny` needed for the boundary to block it.

This is the exact mechanism the lab below exercises: `low_priv`'s
identity policy grants a wildcarded `iam:PassRole` (`Resource: "*"`) —
genuinely dangerous, genuinely still there after the fix — and the
boundary caps it anyway, because the boundary's allow-list never mentions
`iam:PassRole` at all. `effective = intersection(identity, boundary)`, and
the intersection of "everything" and "an allow-list missing this action"
is nothing.

The standard real-world use: letting a team create their own IAM roles
(so you're not the bottleneck for every role-creation request) without
letting them create a role more powerful than you're comfortable with —
attach the boundary to any role *they* create, and no policy they write
for it, ever, can exceed the ceiling.

### Session policies

[**Session policy**](GLOSSARY.md#s): the same capping idea as a
permission boundary, but passed inline at the moment of `AssumeRole` (or
`GetFederationToken`) rather than attached persistently. It caps just that
one set of temporary credentials, and disappears when they expire.

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/some-role \
  --role-session-name readonly-window \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{ "Effect": "Allow", "Action": "s3:GetObject", "Resource": "*" }]
  }'
```

Even if `some-role`'s identity policy allows writes and deletes, this one
session can only read — for exactly as long as this one credential set is
valid. It's the tool for "hand out a narrow, temporary window of access
without creating a new role for every use case" — a support engineer
debugging one incident, an automation run that should only ever read.

### ABAC preview (`aws:PrincipalTag`)

A brief preview — Day 10 goes deep. [**ABAC**](GLOSSARY.md#a) grants
access by matching *tags* between principal and resource instead of
naming every resource. The condition key that makes this work for the
principal side is `aws:PrincipalTag/<key>`:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::some-bucket/*",
  "Condition": {
    "StringEquals": { "aws:PrincipalTag/project": "${aws:ResourceTag/project}" }
  }
}
```

One policy, written once, that scales to every future resource tagged
with a matching `project` value — no policy edit needed when the tenth
resource shows up. File this away; Day 10 is where you build one for
real.

### Access Analyzer for external access

IAM Access Analyzer continuously scans your account's resource policies
(S3 bucket policies, KMS key policies, IAM role trust policies, and more)
and flags any that grant access to a principal *outside* a zone of trust
you define (typically: outside your AWS Organization). It's the automated
answer to "did any of today's trust-policy or resource-policy edits
accidentally open this up to an account I didn't intend" — the same
question the confused-deputy discussion above raises manually, but run
continuously instead of only when you remember to ask it. A finding here
doesn't mean something is broken; it means something is reachable from
outside your trust zone and you should confirm that's intentional (e.g.
the cross-account role you set up on purpose, with its `ExternalId`
already in place) rather than an accident.

## Break → Harden lab

See `labs/day02/`. **The break:** `low_priv`'s mis-scoped `iam:PassRole`
(`Resource: "*"`) plus its ECS run permissions let it register and run an
ECS task that assumes `high_priv` — a role it could never use directly —
and that task successfully reads a secret `low_priv` was denied
moments earlier. **The harden:** attach a permission boundary to
`low_priv` whose allow-list never mentions `iam:PassRole`; re-run the
identical attempt and it now fails with `AccessDenied`, citing the
boundary by name, without editing `low_priv`'s identity policy at all.
**Success signal:** the caller identity inside the escalation task's logs
shows the `high-priv-role` ARN (break), then the exact same registration
attempt returns `AccessDenied ... because no permissions boundary allows
the iam:PassRole action` (harden) — see `labs/day02/SOLUTION.md` for the
full expected strings.

## Exercises

1. **Write the trust policy that prevents the confused deputy.** You run a
   service that assumes a role in customer accounts. Write the trust
   policy (JSON) for a role `CustomerXIntegrationRole` that only your
   service's account (`444455556666`) can assume, and only when the
   caller supplies the exact `ExternalId` `"cust-x-9f3a"`. — **Hint:** you
   need a `Principal` block naming your account and a `Condition` block
   using `StringEquals` on `sts:ExternalId`; both conditions must hold,
   which in a single statement just means both go under one `Condition`
   block. — **Solution sketch:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": { "AWS": "arn:aws:iam::444455556666:root" },
       "Action": "sts:AssumeRole",
       "Condition": {
         "StringEquals": { "sts:ExternalId": "cust-x-9f3a" }
       }
     }]
   }
   ```
   Note `Principal` is still your account root, not a specific role/user —
   that's normal; least-privilege for *which of your own principals* can
   assume it belongs in *your* account's identity policies, not in the
   trust policy. The `ExternalId` condition is what's actually closing the
   confused-deputy gap here.

2. **Diagnose which door is blocking a call.** A teammate's role has an
   identity policy that clearly allows `s3:PutObject` on the bucket they're
   targeting, and they get `AccessDenied`. Where do you look next, in
   order, and what's the fastest way to tell a boundary/session-policy
   denial apart from an SCP or identity-policy denial? — **Hint:** the
   evaluation order tells you what to check and in what order; the exact
   wording of the `AccessDenied` message is diagnostic (see
   `labs/day02/SOLUTION.md` for two real contrasting examples). — **Solution
   sketch:** check, in order: (1) any explicit `Deny` naming this action —
   read the message, it names the source; (2) an Organizations SCP — the
   message says "explicit deny in a service control policy"; (3) is there a
   permission boundary or session policy on this principal/session, and
   does *its* allow-list include `s3:PutObject`? The `AccessDenied` text
   itself says which door blocked it — "because no identity-based policy
   allows..." vs. "because no permissions boundary allows..." vs. an SCP
   message — so read the exact string before guessing.

3. **Write a permission boundary for a "role-creating" team.** Your
   platform team is allowed to create IAM roles for their own service, but
   you want a hard ceiling: never IAM admin actions, never
   account-wide `Resource: "*"` S3 access, and never anything outside your
   region. Sketch the boundary policy's `Statement` array (2-3 statements
   is enough — you don't need every action enumerated). — **Hint:** think
   allow-list, not deny-list — what's the smallest set of services/actions
   this team's roles could plausibly ever need, and does a `Deny` for the
   wrong region even help here (region isn't a resource-shape problem, it's
   a `Condition`)? — **Solution sketch:** one `Allow` statement scoping the
   services this team actually uses (e.g. `dynamodb:*`, `s3:GetObject`,
   `s3:PutObject` — deliberately not `s3:*`) with resource ARNs scoped to
   their own bucket/table prefix; a second explicit `Deny` on `iam:*` and
   any `sts:AssumeRole` targeting roles outside their own naming prefix, to
   close off self-escalation via a role *they* create; a `Condition` using
   `aws:RequestedRegion` on the allow statement if you want the region
   ceiling enforced there rather than via SCP.

4. **Write a session policy for a one-hour, read-only debugging window.**
   An on-call engineer needs to assume `prod-app-role` (which normally has
   read/write S3 and DynamoDB access) to debug an incident, but you want
   this specific session capped to read-only, no matter what the role's
   own identity policy allows. Write the `--policy` JSON you'd pass to
   `aws sts assume-role`. — **Hint:** session policies use the same JSON
   shape as any other IAM policy document; you're not touching
   `prod-app-role`'s own identity policy or creating a new role at all. —
   **Solution sketch:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": ["s3:GetObject", "s3:ListBucket", "dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"],
       "Resource": "*"
     }]
   }
   ```
   Pass it via `--policy` (inline) or `--policy-arns` (a managed policy
   ARN) on the `assume-role` call. The role's own identity policy is
   unchanged for every *other* caller who assumes it without this session
   policy attached — this caps only this one session.

## Anti-patterns today

- [**#6 — `iam:PassRole` and wildcards as silent privilege
  escalation**](ANTIPATTERNS.md#6-iampassrole-and-wildcards-as-silent-privilege-escalation):
  the entire break half of today's lab *is* this anti-pattern, live, in
  your own account. `low_priv`'s `Resource: "*"` on `iam:PassRole` reads as
  completely benign in isolation — nothing flags it until you notice what
  role it can be paired with, which is exactly why it survives code review
  so often.
- [**#8 — Long-lived access keys instead of roles and short-lived
  credentials**](ANTIPATTERNS.md#8-long-lived-access-keys-instead-of-roles-and-short-lived-credentials):
  every credential in today's lab — `low_priv`'s, `high_priv`'s, the
  escalation task's — is an STS temporary credential that expires. None of
  this pattern is available to you if the starting point were a static
  IAM user access key instead of a role; that's precisely why `AssumeRole`
  is the default access pattern this whole path uses, not an incidental
  choice.
- [**#1 — Treating each service's policy language as its own
  topic**](ANTIPATTERNS.md#1-treating-each-services-policy-language-as-its-own-topic):
  a permission boundary, a session policy, and an SCP are three different
  *syntaxes* for the same idea — "a ceiling that can only remove, never
  add." Learn the shape once (today, for boundary/session) and Day 10's
  SCPs are almost free.

## Cert corner (SCS-C02)

- **Domain 4 — Identity and Access Management (~16%):** this day is the
  cross-account/trust-policy/boundary half of that domain's coverage —
  pair with Day 1 (evaluation order) and Day 10 (SCPs, ABAC, permission
  sets) for the full domain; see `content/CERT-MAP.md`.
- Expect exam scenarios phrased as "a role can be assumed by X but the
  resulting session can't do Y" — that's a session-policy or boundary
  question, not an identity-policy question; the fastest tell is the exact
  `AccessDenied` wording, same as Exercise 2 above.
- **Federation edges are explicitly out of scope for today** (SAML/OIDC
  federation, IAM Identity Center permission sets) — those get their real
  treatment on Day 10; today's STS coverage stops at `AssumeRole` between
  IAM principals/services.

## Teardown

`cd labs/day02 && terraform destroy` — confirm zero billable resources
(checklist in `labs/day02/README.md`). This destroys only day-02's own
`low_priv`/`high_priv` roles, the boundary policy, its security group, and
its log group — `labs/base` is never touched by this day's teardown; leave
it up per the sprint's teardown model in `labs/base/README.md`.
