# Day 1 — The engine + target deploy

## Why this matters at work

Every AWS service you'll meet for the rest of this sprint — S3, KMS,
WAF, VPC endpoints, Organizations SCPs — speaks a different policy
*syntax* but runs on exactly one authorization *engine*. If you learn
that engine cold today, every later day is "which door does this
attach to, and where does it sit in the order?" instead of "what's this
service's syntax?" Skip that and you'll spend the rest of your career
relearning the same six-step decision from scratch, once per service —
that's [anti-pattern #1](ANTIPATTERNS.md#1-treating-each-services-policy-language-as-its-own-topic),
and it's the single biggest time-sink for people learning AWS security.
Today installs the engine, using the real over-broad task role sitting
in your own deployed workload as the specimen.

## The engine lens

Today *is* the engine, taught end-to-end, in one sitting — every door
in the canonical order, not just one of them:

```
explicit Deny → Organizations SCP/RCP → resource-based policy →
identity-based policy → permission boundary → session policy
```

Focus service: IAM/STS. Tools: the IAM policy simulator and IAM Access
Analyzer — the two things that answer "will this actually be allowed?"
before you find out the hard way.

## Core concepts

### The full evaluation order (memorize this cold)

For every single API call, to every single AWS service, the same six
checks run in the same fixed order:

1. **Explicit Deny** — if *any* applicable policy, in *any* of the
   layers below, contains an explicit `Deny` that matches this
   principal/action/resource/condition, the call is denied. Full stop.
   Nothing later gets consulted. This is checked first because it's
   the one thing that can never be overridden by anything else in the
   stack — that property is exactly what makes it useful as a
   retrofit tool (see "Least privilege without editing the original
   grant" below).
2. **Organizations SCP/RCP** — an account-, OU-, or org-wide ceiling.
   [SCPs](GLOSSARY.md#s) can only *remove* permissions, never grant
   them; they're checked second, before any resource or identity
   policy gets a say, which is why "the SCP blocks it" beats any
   `Allow` written anywhere else in the account.
3. **Resource-based policy** — a policy attached to the *resource*
   itself (an S3 bucket policy, a KMS key policy, an IAM role's trust
   policy). It can grant access a principal's own identity policy
   never mentions (the whole basis of cross-account access), or it can
   carry its own explicit `Deny`.
4. **Identity-based policy** — a policy attached to the *principal*
   (user, group, or role). This is the tier that actually *grants*
   permissions in the common same-account case — everything after
   this tier can only cap what's already been granted, never add to
   it.
5. **Permission boundary** — a managed policy attached to the
   principal that sets the *maximum* its identity policies can ever
   grant. Effective permission at this point = the **intersection**
   of what the identity policy allows and what the boundary allows.
6. **Session policy** — passed inline at the moment of `AssumeRole`
   (or similar STS call), scoped to just that one temporary session.
   Same intersection logic as the boundary, checked last.

Steps 5 and 6 are checked *after* step 4 specifically because they are
restrictive **caps**, not grants — a boundary or session policy that
never mentions `s3:PutObject` doesn't need an explicit `Deny` to block
it; the intersection with an identity policy that *does* grant it is
still "no." That's the one nuance that trips people up: absence of a
mention in a cap tier is enough to deny, even with zero explicit
`Deny` statements anywhere.

### The four things every policy statement is about

Every statement in every policy, in every tier above, answers the same
four questions:

- **Principal** — *who* is asking. An IAM user, an IAM role (including
  one just assumed via STS), another AWS service acting on your
  behalf, or a federated identity. ([glossary](GLOSSARY.md#p))
- **Action** — *what API call* (`s3:GetObject`, `dynamodb:DeleteItem`,
  `iam:PassRole`). Wildcards (`s3:*`) are legal and are exactly the
  habit [anti-pattern #6](ANTIPATTERNS.md#6-iampassrole-and-wildcards-as-silent-privilege-escalation)
  warns about.
- **Resource** — *what specifically* the action targets, almost always
  an ARN, often with a wildcard suffix (`arn:aws:s3:::bucket/*`).
  `NotResource` is the inverse: "every resource except these."
- **Condition** — *under what circumstances* the statement applies —
  source IP, MFA presence, a request tag, `kms:ViaService`, and so on.
  A statement with no `Condition` block simply always applies.

### Identity-based vs. resource-based policies

| | Identity-based policy | Resource-based policy |
|---|---|---|
| Attached to | a user, group, or role | the resource itself (bucket, key, queue, role's trust doc) |
| Answers | "what can *this principal* do?" | "who can reach *this resource*, and how?" |
| Can grant cross-account access alone? | No — the other account's principal also needs *something* that resolves to Allow | **Yes** — this is the only way a principal with zero identity-policy grant in your account can still be allowed in |
| Evaluation order position | 4th | 3rd (checked *before* identity) |
| Silent (no statement about this principal)? | N/A — if there's no identity policy at all, there's no grant | Neither blocks nor grants — evaluation falls through to the identity tier |

See [glossary: identity policy](GLOSSARY.md#i) and
[glossary: resource policy](GLOSSARY.md#r).

### Walking the engine, tier by tier, against the real task role

`labs/base/iam.tf` defines `aws_iam_role.task` — the app's runtime
identity — with an inline policy statement (`BroadButWorkloadScopedAppDataAccess`)
that grants `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, and
`s3:ListBucket` across the **entire** `app_data` bucket, when the app
only actually needs `Get`/`Put` on one object prefix. Walking every
tier of the order against this one role makes each tier concrete —
some traces below are real (this workload), some are hypothetical
(this is a single-account lab with no AWS Organizations), and each is
marked accordingly.

**Trace A — explicit Deny (hypothetical).** Suppose an operator
attached an account-wide "break glass" policy with an explicit `Deny`
on `s3:*` while investigating an incident. Would today's harden (Trace
D below) matter while that's in effect? **No** — the explicit Deny at
tier 1 stops evaluation before tier 4 (identity) is even reached. This
is *why* explicit Deny is checked first: nothing downstream, including
a perfectly tightened identity policy, can ever override it.

**Trace B — SCP/RCP (hypothetical).** Suppose this account sat under
an OU with an SCP that denies `dynamodb:DeleteItem` org-wide. The task
role's identity policy *does* Allow `dynamodb:DeleteItem` on the app
table (`iam.tf`'s `AppDataTable` statement). Is the call allowed? **No**
— the SCP is checked at tier 2, before the identity Allow at tier 4 is
ever consulted, and an SCP can only remove permissions, never restore
them. The identity policy's `Allow` is irrelevant once the SCP has
already said no.

**Trace C — resource-based policy (real).** `aws_s3_bucket.app_data`
has no bucket policy at all — only a public-access block, which is a
separate control, not a resource policy statement about this
principal. A resource policy that never mentions this principal is
**silent**: it neither grants nor blocks, and evaluation falls through
to tier 4. Contrast: if that bucket policy *did* carry an explicit
`Deny` naming the task role's ARN, tier 3 would end the evaluation
before the identity policy's `Allow` at tier 4 mattered at all — same
shape as Trace B, one tier later.

**Trace D — identity-based policy (real, before/after today's lab).**
*Before* (base, as deployed): the only identity policy in force is the
broad inline statement above → `s3:DeleteObject` on any key in the
bucket = **allowed**. This is the break. *After* (`labs/day01/` applied):
a **second** identity-based policy is now also attached to the same
role — an explicit-Deny overlay — so tier 4 now has two policies to
reconcile, and the explicit Deny inside one of them wins (per tier 1's
rule, which applies *within* a tier too, not just across tiers) →
`s3:DeleteObject` = **explicitDeny**. This is the harden. See
`labs/day01/` for the exact commands and expected output.

**Trace E — permission boundary (hypothetical).** Suppose a permission
boundary were attached to the task role that capped it to `s3:GetObject`
only. Would today's harden change anything about whether `s3:PutObject`
is allowed? **No** — `s3:PutObject` was never *in* the boundary, so the
intersection of "identity policy allows it" and "boundary doesn't
mention it" is already "no," with zero explicit `Deny` statements
required anywhere. This is the tier where "capped by omission" first
appears in the order.

**Trace F — session policy (hypothetical).** Session policies only
attach to STS-vended temporary credentials that had one passed inline
at `AssumeRole` time. The Fargate agent vends the task role's
credentials automatically, with no session policy attached — so this
tier is a no-op for the task role today. It becomes real on Day 2,
when you deliberately pass one at `AssumeRole` time.

### The tools that answer "will this be allowed?"

- **IAM policy simulator** (`aws iam simulate-principal-policy` for a
  real principal's attached/inline policies; `simulate-custom-policy`
  for a draft policy you haven't attached yet) — give it a principal
  ARN (or a policy document), a list of actions, and a list of resource
  ARNs; it returns an `EvalDecision` (`allowed` / `explicitDeny` /
  `implicitDeny`) per action/resource pair, plus which statement(s)
  decided it. It never makes the real API call and never needs live
  credentials for the principal being tested, which is what makes it
  safe to point at a production identity. **Caveat that matters:** the
  simulator evaluates identity-based policies and permission
  boundaries for the principal — it does **not** evaluate Organizations
  SCPs/RCPs, and does not evaluate resource-based policies for most
  services unless you explicitly supply one. A simulator `allowed`
  verdict is necessary but not sufficient on its own; it's telling you
  about tiers 4–5, not the whole engine. Today's exercises come back to
  this gap on purpose.
- **IAM Access Analyzer** — a different, complementary question: "does
  any resource-based policy I already have grant access to someone
  *outside* my trust zone (another account, the public internet, an
  unintended org)?" It's a continuous auditor of tier 3 (resource
  policies) — bucket policies, key policies, role trust policies — not
  a one-time check at write time. Its policy-generation feature can
  also draft a least-privilege identity policy from observed CloudTrail
  activity, which is the automated version of what today's lab does by
  hand (on purpose — do it manually once so the mechanics are real
  before you let a tool do it for you).

### Least privilege without editing the original grant

Today's lab tightens the task role **without touching `labs/base/iam.tf`**
— every other day of this sprint layers on that same base, so it can't
be edited out from under them. The technique: attach a **second**
identity-based policy to the same role containing explicit `Deny`
statements for exactly the actions/scope that shouldn't be there. Per
tier 1's rule — explicit Deny beats any Allow, from *any* policy, in
*any* tier — this reliably cancels out the unwanted breadth of the
original grant without modifying it. This is a real, documented AWS
pattern for retrofitting least privilege onto infrastructure you can't
or don't want to rewrite, and it's a direct, hands-on demonstration of
why explicit Deny sits first in the order: it's the one tool guaranteed
to win no matter what else is layered underneath it.

## Break → Harden lab

See `labs/day01/`. **The break:** the base task role's S3 grant is
broad across the *entire* `app_data` bucket, so unneeded actions
(`s3:DeleteObject`, `s3:ListBucket` — the app never calls either) and
unneeded scope (every object prefix, not just the one the app actually
uses) currently simulate as `allowed`. **The harden:** layer a scoped
explicit-Deny identity policy onto the same role that removes the
unneeded actions entirely and restricts `GetObject`/`PutObject` to the
app's documented object prefix. **Success signal:** the same simulator
calls that returned `allowed` before now return `explicitDeny`, while
an in-prefix `GetObject`/`PutObject` still returns `allowed` — the
app's actual usage keeps working; everything else is now blocked.

## Exercises

1. **The account sits under an OU with an SCP that has a single
   statement: `Effect: Deny`, `Action: ["s3:DeleteObject"]`,
   `Resource: "*"`. The task role's identity policy (base, before
   today's lab) allows `s3:DeleteObject` on the `app_data` bucket. Is
   `s3:DeleteObject` on that bucket allowed?** — **Hint:** which tier
   is checked first between an SCP and an identity policy, and what's
   the one thing that tier can never lose to? — **Solution sketch:**
   Denied. The SCP is tier 2, the identity policy is tier 4 — the SCP
   is consulted first and, having an explicit `Deny` that matches,
   ends the evaluation there. The winning statement is the SCP's
   `Deny`; the identity policy's `Allow` is never reached.

2. **The `app_data` bucket gets a bucket policy with one statement:
   `Effect: Allow`, `Principal: {"AWS": "<task_role_arn>"}`,
   `Action: ["s3:GetObject"]`, `Resource: "<bucket_arn>/reports/*"`.
   Nothing else changes. Is `s3:GetObject` on
   `<bucket_arn>/reports/q1.csv` allowed?** — **Hint:** a resource
   policy can grant on its own; it doesn't need the identity policy to
   agree. Does the *existing* identity policy also have to allow it? —
   **Solution sketch:** Allowed. The resource-based policy (tier 3)
   independently grants this specific access, and same-account access
   only needs *one* tier — resource or identity — to say yes (a
   resource-policy grant doesn't require a matching identity-policy
   grant for a principal in the same account, unlike the cross-account
   case). The winning statement is the bucket policy's `Allow`, even
   though the identity policy never mentions `reports/*` at all.

3. **A permission boundary is attached to the task role:
   `Effect: Allow`, `Action: ["s3:GetObject", "s3:PutObject"]`,
   `Resource: "<bucket_arn>/*"` (nothing else — no `DeleteObject`, no
   `ListBucket`). The identity policy is the *original* base grant
   (Get/Put/Delete/List across the whole bucket). Is `s3:DeleteObject`
   allowed?** — **Hint:** effective permission past tier 4 is an
   intersection, not an additional grant. Does the boundary need an
   explicit `Deny` to block something? — **Solution sketch:** Denied
   — but as an **implicit** deny, not an explicit one. The boundary
   (tier 5) simply never lists `DeleteObject`, so the intersection of
   "identity allows it" ∩ "boundary allows it" is empty for that
   action. No statement anywhere said `Deny`; absence from the cap
   tier is sufficient on its own. Contrast this with Trace D in the
   content above, where the day01 lab instead uses an *explicit* Deny
   overlay — different mechanism, same practical result.

4. **You call `aws iam simulate-principal-policy` against the task
   role for `s3:DeleteObject` on the bucket and it returns `allowed`.
   Does that fully prove the live API call would succeed?** — **Hint:**
   re-read the simulator's caveat in "The tools that answer 'will this
   be allowed?'" above — which tiers does the simulator actually
   evaluate? — **Solution sketch:** No. The simulator checked tiers 4–5
   (identity policy + permission boundary) for that principal. It does
   not evaluate SCPs/RCPs (tier 2) or resource-based policies (tier 3)
   for most services. If an SCP or a bucket policy carried a `Deny`
   that the simulator can't see, the real call would still fail with
   `AccessDenied` despite a clean simulator `allowed` verdict. Treat a
   simulator "allowed" as "not blocked by tiers 4–5," not as a full
   guarantee.

## Anti-patterns today

- [#1 — Treating each service's policy language as its own topic](ANTIPATTERNS.md#1-treating-each-services-policy-language-as-its-own-topic)
  — today exists specifically to install the one transferable model
  (the six-tier order) instead of relearning syntax per service.
- [#6 — `iam:PassRole` and wildcards as silent privilege escalation](ANTIPATTERNS.md#6-iampassrole-and-wildcards-as-silent-privilege-escalation)
  — the base task role's `Action: [Get/Put/Delete/List]` +
  `Resource: [bucket_arn, bucket_arn/*]` combo is the "wildcard within
  a workload" flavor of exactly this mistake: broad "for convenience,"
  meant to be tightened later. Today's lab is the corrective, in
  miniature, on the real resource.

## Cert corner (SCS-C02)

Maps to **Domain 4 — Identity and Access Management** (see
[`CERT-MAP.md`](CERT-MAP.md)):

- The full evaluation order, cold — this is the domain's spine, and
  the exam tests it with exactly the kind of "given policy X + SCP Y,
  is action Z allowed" questions in the exercises above.
- Identity-based vs. resource-based policies, and specifically when a
  resource policy is *required* (cross-account access) vs. when either
  tier alone is sufficient (same-account).
- The policy simulator and Access Analyzer as the tools the domain
  expects you to know exist and to know the *limits* of (simulator
  doesn't cover SCPs/resource policies; Access Analyzer audits
  resource policies, not identity policies).
- `iam:PassRole` + wildcard combinations as a named privilege-escalation
  pattern, not just a style nitpick.

## Teardown

`cd labs/day01 && terraform destroy` — this destroys only the day01
explicit-Deny policy overlay, a free IAM control-plane resource with no
billing impact. The base task role's original over-broad `Allow`
statement in `labs/base/iam.tf` is untouched by this — base stays up
for the whole sprint, and the lesson can be re-run from a clean
"before" state at any time. Full checklist in `labs/day01/README.md`.
