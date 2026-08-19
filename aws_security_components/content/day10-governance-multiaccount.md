# Day 10 — Governance & multi-account

## Why this matters at work

A single security team cannot hand-review every IAM policy in every
account once an org has more than a handful of them. Governance
controls — SCPs, permission boundaries, ABAC, centralized SSO — let a
small team set a guardrail *once*, at the org or OU level, and have it
apply everywhere beneath it, enforced by the exact same policy engine
you already learned on Day 1. Concretely: a careless or compromised
developer credential in a member account still cannot disable
CloudTrail, because an SCP denies it at the OU, and that denial is
checked before that account's own IAM ever gets a say. Today is about
building that guardrail layer, and the tagging discipline (ABAC) that
lets it scale to hundreds of resources without hand-naming each one.

## The engine lens

Restate the canonical order, because today's door is the one at the
very top:

```
explicit Deny → SCP/RCP → resource-based policy → identity-based policy
                  ^^^^^^                              ^^^^^^^^^^^^^^^^^^
              TODAY'S DOOR                    → permission boundary → session policy
                                                   ^^^^^^^^^^^^^^^^^    ^^^^^^^^^^^^^^
                                                   also revisited today (via ABAC)
```

**SCP/RCP is checked second, right after an explicit deny, and before
any resource or identity policy in the account is even consulted.**
That ordering is the entire reason SCPs are worth learning as a
separate topic instead of "IAM but for orgs": an SCP deny is *decided*
before the account's own Allow is ever read. No identity policy,
however permissive, can claw back a permission an SCP has removed.

Today also revisits the two "cap" doors from Day 2 — permission
boundary and session policy — because ABAC is implemented at exactly
those layers: a boundary or an identity policy with a
`Condition` block that compares a **principal tag** to a **resource
tag**, rather than naming resources one by one.

## Core concepts

### 1. Organizations structure

An AWS Organization has one **management account** (root of the org,
where Organizations itself is administered — never where workloads
run) and any number of **member accounts**, optionally grouped into
**Organizational Units (OUs)** — a tree, not a flat list, so a guardrail
attached at a parent OU applies to every account and every child OU
beneath it. SCPs and RCPs attach to the org root, an OU, or an
individual account.

### 2. SCP anatomy

A **Service Control Policy (SCP)** is written in the same JSON policy
language as every identity/resource policy you've already written —
same `Effect`/`Action`/`Resource`/`Condition` shape — but it can
**only ever remove permissions, never grant them.** Every account in
an org starts with the AWS-managed `FullAWSAccess` SCP attached (an
`Allow *` on everything), and every SCP you attach after that narrows
what's left. There are two common strategies:

- **Deny-list** (most common in practice): keep `FullAWSAccess`
  attached, add targeted `Deny` statements for specific dangerous
  actions. Low friction, easy to reason about one guardrail at a time.
- **Allow-list**: remove `FullAWSAccess`, attach an SCP that
  `Allow`s only an approved action set. Much stronger ceiling, much
  higher chance of an unexpected `AccessDenied` on something a team
  actually needed — reserve for tightly scoped OUs (e.g., a sandbox OU
  with a hard security ceiling).

A deny-list SCP that blocks disabling CloudTrail org-wide (this day's
"write an SCP" exercise) looks like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailTamper",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    }
  ]
}
```

Note it denies three actions, not one: `StopLogging` and `DeleteTrail`
are the obvious ones, but `UpdateTrail` can also silently narrow a
trail (turn off multi-region logging, drop a target S3 bucket) without
technically "stopping" or "deleting" anything — an SCP that only
covers the first two still leaves that gap open.

### 3. RCP — the resource-side sibling

A **Resource Control Policy (RCP)** is SCP's newer counterpart: same
"can only remove, never grant" ceiling, evaluated at the same stage of
the order, but it caps what a **resource-based** policy (an S3 bucket
policy, a KMS key policy) can grant across the org — for example, "no
resource policy in this org may grant access to a principal outside
this org's account list," even if a specific bucket's own policy says
otherwise. SCP caps identities; RCP caps resources. Same door, two
sides of the same coin.

### 4. Precedence, proven

This is the load-bearing fact of the day: **an SCP `Deny` wins over an
identity policy `Allow`, unconditionally, with no exception path.**
Walk the evaluation for a concrete case using the base workload's task
role:

> Suppose the task role's identity policy `Allow`s
> `s3:DeleteObject` on the app-data bucket (today it doesn't — Day 1
> already scoped this down — but suppose it did). Suppose the account
> this role lives in sits under an OU with an SCP that `Deny`s
> `s3:DeleteObject` account-wide. Walk the request:
> 1. **Explicit deny?** None on the identity policy itself.
> 2. **SCP/RCP?** The OU's SCP has an explicit `Deny` matching this
>    action → **evaluation stops here.** Final decision: **Deny.**
> 3. Steps 3–6 (resource policy, identity policy, boundary, session
>    policy) are never reached — once a `Deny` fires at any earlier
>    layer, no `Allow` at a later layer can undo it.

This is proven concretely (written trace + policy-simulator note) in
`labs/day10/SOLUTION.md`.

### 5. IAM Identity Center (successor to AWS SSO)

**IAM Identity Center** is the centralized answer to "how do a hundred
humans get access to a hundred accounts without a hundred sets of IAM
users." A user signs into one place; an admin assigns them a
**permission set** — a reusable, named bundle of permissions — against
specific accounts. Under the hood, Identity Center provisions that
permission set as an actual IAM role in each target account (named
`AWSReservedSSO_<permission-set-name>_<hash>`), so once assigned, it's
still the same IAM role mechanics you already know — Identity Center's
value is doing that provisioning and assignment centrally instead of
per-account, and giving every human exactly one set of credentials
instead of one per account. See [glossary](GLOSSARY.md#p) — "Permission
set."

### 6. Control Tower / landing zone (concept only)

**Control Tower** automates the pattern that governance work converges
on anyway once an org has more than a few accounts: a **landing
zone** with a dedicated log-archive account (CloudTrail/Config
aggregated from every member account), a dedicated audit/security
account (read access into every other account, for the security team),
a baseline set of SCP **guardrails** pre-attached to every OU, and an
**Account Factory** for standing up new, pre-hardened accounts on a
template instead of by hand. A single-account learner cannot stand
this up (it needs an Organization with real member accounts) — the
value today is recognizing the shape: everything Control Tower
automates is SCPs, a log-aggregation design, and delegated
administration, all of which you now understand individually.

### 7. Tagging strategy + ABAC at scale

The tag-per-resource-then-write-a-condition pattern is called
**Attribute-Based Access Control (ABAC)** (see
[glossary](GLOSSARY.md#a)). Instead of an identity policy naming every
resource a team is allowed to touch (which needs an edit every time a
resource is added), ABAC grants access based on a **matching tag**
between the caller and the resource:

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/Project": "${aws:PrincipalTag/Project}"
    }
  }
}
```

This single statement replaces a per-resource `Allow` list — as long
as every principal and every resource carries a consistent `Project`
tag, adding a new resource with the right tag is enough; no policy
edit required. The precondition is a **tag taxonomy** applied
consistently from day one:

| Tag key | Example values | Purpose |
|---|---|---|
| `Project` | `aws-sec-lab` | the ABAC matching key used in this lab |
| `Environment` | `sandbox`, `prod` | blast-radius / change-control scoping |
| `DataClassification` | `internal`, `confidential` | pairs with ABAC on data-tier resources |
| `Owner` | a team name (never a person's email) | who to page |

Today's lab applies `Project`, `Environment`, and
`DataClassification` onto the base workload's task role, S3 bucket,
Secrets Manager secret, and DynamoDB table, then writes an ABAC policy
that keys off `Project`.

### 8. Delegated administration

Some AWS services (GuardDuty, Security Hub, Config, Macie — the
services this path already stood up on Day 8/9) support **delegated
admin**: the management account grants one specific member account
administrative rights over that service *org-wide*, without handing
that account the management account's own root-level control over
Organizations itself. It's the governance answer to "the security team
needs to see every account's findings, but should not be the account
that can dissolve the org" — splitting *who runs the org* from *who
owns the security tooling* onto two different accounts.

## Break → Harden lab

See `labs/day10/`. **The break:** a demo IAM role's identity policy
alone grants a broad `s3:Get/PutObject` `Allow` across *any* bucket —
if that were the only control, it would work regardless of which
bucket it touched. **The harden:** a permission boundary keyed on
ABAC (only permits the action when the resource's `Project` tag
matches the role's own `Project` tag) narrows that grant down to just
the correctly tagged bucket; separately, a written+simulated trace
proves an org-level SCP `Deny` on a CloudTrail-tamper action wins
outright over any identity `Allow`, with no exception path. **Success
signal:** `SOLUTION.md`'s written trace shows the SCP scenario
resolving to Deny at step 2 of the evaluation (before identity is ever
read); the applied ABAC tags + permission boundary are live on the
demo role, and the policy simulator's recorded output shows the
tag-mismatched resource returning `implicitDeny` while the
tag-matched one returns `allowed`.

## Exercises

1. **Write an SCP that denies disabling CloudTrail org-wide.**
   — **Hint:** `StopLogging` isn't the only API call that neutralizes
   a trail — what else could quietly turn off multi-region logging or
   redirect its destination without "stopping" or "deleting" it?
   — **Solution sketch:** deny `cloudtrail:StopLogging`,
   `cloudtrail:DeleteTrail`, **and** `cloudtrail:UpdateTrail` with
   `Resource: "*"`, attached at the org root (or the OU containing
   every workload account) — see the full JSON in Core concept 2 above
   and `labs/day10/main.tf`'s `deny_cloudtrail_tamper` policy.

2. **Design an ABAC tag scheme for the base workload and write the
   `Condition` block that keys on it.**
   — **Hint:** you need at least two tags applied consistently — one
   on the principal, the same key on the resource — before any
   `Condition` can compare them.
   — **Solution sketch:** tag key `Project` on both the demo IAM role
   and the base workload's S3 bucket/Secrets Manager secret/DynamoDB
   table (`labs/day10/scripts/tag-base-resources.sh` applies this for
   real); condition:
   `"StringEquals": {"aws:ResourceTag/Project": "${aws:PrincipalTag/Project}"}`.

3. **Trace the effective permission for this conflict:** an identity
   policy `Allow`s `s3:DeleteObject` on the app bucket; an SCP at the
   account's OU `Deny`s `s3:DeleteObject` account-wide. What happens,
   and *why* is the order the reason, not just "deny wins ties"?
   — **Hint:** re-read the six-step order — does the identity policy's
   `Allow` even get read once step 2 has already produced a decision?
   — **Solution sketch:** **Denied.** SCP/RCP is step 2; the identity
   policy is step 4. Evaluation stops the instant an earlier step
   produces an explicit `Deny` — the identity policy's `Allow` at step
   4 is never reached, so it isn't "outvoted," it's simply never
   consulted. This is why an SCP is a true ceiling and not just
   another vote in a majority.

4. **A team wants to self-service-create IAM roles for their own
   project, but must never be able to create (or escalate into) an IAM
   administrator role. Do you use a permission boundary or a session
   policy — and why not the other one?**
   — **Hint:** which of the two is attached once, persists across many
   future role-creation events, versus which one only exists for the
   lifetime of a single temporary credential?
   — **Solution sketch:** **permission boundary**, attached at
   role-creation time (`iam:CreateRole` conditioned on
   `iam:PermissionsBoundary` being set to your approved boundary ARN)
   so it persists on every role that team creates from then on. A
   session policy only scopes one already-issued set of temporary
   credentials — it can't reach forward to cap a *new* role someone
   creates five minutes later.

## Anti-patterns today

- [**#1 — treating each service's policy language as its own
  topic**](ANTIPATTERNS.md#1-treating-each-services-policy-language-as-its-own-topic):
  SCP JSON looks identical to every other policy you've written this
  sprint because it *is* the same engine — it's just the door checked
  earliest. If you found yourself hunting for "SCP-specific syntax,"
  that's the tell you're relearning the order instead of applying it.

- **Governance-as-afterthought** (candidate anti-pattern — not yet
  numbered in `ANTIPATTERNS.md`; flagged in this day's report): tagging
  a resource *after* it already has three IAM policies, two data
  consumers, and a dashboard hard-coding its ARN costs real, measurable
  time — the `tag-base-resources.sh` script in this lab needed a
  merge-safe read-before-write specifically because the base bucket
  *already* carried `Project`/`ManagedBy`/`Layer` tags from
  `labs/base`'s original `common_tags`, and a naive
  `put-bucket-tagging` call would have silently wiped them. That
  three-line defensive read-merge-write is the cost of retrofitting
  tags onto one bucket, one time, in a one-workload lab. Multiply that
  by every resource type across dozens of pre-existing production
  accounts with no retrofit script written yet, and the "we'll add
  tags later" decision is the single biggest reason ABAC rollouts stall
  for months instead of shipping in days.

## Cert corner (SCS-C02)

- **Domain 6 — Management and Governance:** SCP/RCP guardrails and
  where they sit in the evaluation order; Control Tower landing-zone
  concepts (log-archive account, audit account, Account Factory,
  baseline guardrails); this pairs directly with Day 9's Config rules
  and conformance packs — one is "detect drift," the other is
  "structurally prevent the drift from being possible."
- **Domain 4 — Identity and Access Management:** ABAC via
  `aws:PrincipalTag`/`aws:ResourceTag` conditions; permission
  boundaries as a persistent cap vs. session policies as a
  per-credential cap; IAM Identity Center permission sets as
  centrally-assigned, per-account IAM roles under the hood.
- **Domain 2 — Security Logging and Monitoring:** delegated
  administration for GuardDuty/Security Hub/Config — one account with
  org-wide read access to findings, without granting Organizations
  root control.

## Teardown

`cd labs/day10 && terraform destroy` — destroys the demo IAM role, the
permission-boundary policy, and the ABAC identity policy this lab
created. The ABAC tags applied to base-workload resources
(`task_role`, S3 bucket, Secrets Manager secret, DynamoDB table) are
free to leave in place — tags carry no cost — but the `null_resource`
tagging step is also torn down cleanly by `destroy` (it re-runs no
untag step; tags simply persist on the base resources, which is fine
and expected since base's own lifecycle owns those resources, not
today's module).

**Org-level resources (the SCP, and any RCP) are `terraform plan`-only
for a single-account learner** — `enable_org_resources` defaults to
`false` specifically so nothing attempts to create against an
Organization that doesn't exist. There is nothing to destroy at the
org level today; if you *do* have a real Organization and flipped that
variable on to actually attach the SCP, destroy it same-day like every
other day-specific resource.
