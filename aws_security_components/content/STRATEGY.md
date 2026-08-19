# STRATEGY.md — The Unconventional Strategy

*Read this before Day 1. It won't teach you a single AWS service — it
tells you how to learn all of them in 12 days without drowning.*

Most people study AWS security service-by-service: an S3 policy
tutorial, then a KMS tutorial, then a WAF tutorial, each treated as an
unrelated topic with its own syntax to memorize. That's why most people
take six months to get comfortable and still feel shaky on the exam and
in an incident. The top 1% do two things differently, and everything
else in this path is built to force those two things into habit.

## Spine principle 1 — One engine, many doors

AWS authorization is **one evaluation order**, checked the same way for
every single request, in every single service:

```
explicit Deny  →  SCP/RCP  →  resource-based policy  →  identity-based policy
                                            →  permission boundary  →  session policy
```

Learn that order once — really learn it, until you can trace a denied
request through it without looking anything up — and you have already
learned 80% of every service you'll meet for the rest of your career.
IAM policies, S3 bucket policies, KMS key policies, WAF Web ACLs, VPC
endpoint policies, Organizations SCPs — every one of them is just a new
**door** onto this same engine, not a new thing to memorize from
scratch. When you hit a service you've never seen, the first question
is never "what's the syntax?" — it's "which door is this, and where
does it sit in the order?" Day 1 exists entirely to install this lens;
every day after that exercises it against a new door.

The corollary: if you ever catch yourself learning a service's policy
language as if it were unrelated to everything before it, stop — you're
doing it the slow way. Cross-reference against
[`ANTIPATTERNS.md`](ANTIPATTERNS.md) anti-pattern #1.

## Spine principle 2 — One persistent workload, attacked daily

This path does not spin up a disposable toy for each topic and throw it
away. `labs/base/` stands up **one** small, real 3-tier workload —
VPC, ALB, ECS Fargate service, CloudFront, S3, Secrets Manager, a
starter task role — on Day 1, and it stays up for the whole sprint.
Every day layers a Terraform module on top of it, attacks it from a
different angle, hardens it, and tears down *that day's module* —
never the base.

This matters more than it sounds like it should. A fresh lab environment
every day means you re-learn the topology every day and never build
real intuition for how one system's failure surface compounds. A
persistent workload means that by Day 8, when you turn on GuardDuty and
Security Hub, you're pointing detection at infrastructure you've
already attacked seven times and understand at a level no tutorial VPC
diagram gives you. The workload becomes a character in the story, not a
disposable prop — and that's also why the Day 11–12 capstone can chain
every prior day's control into one incident: they were never separate
sandboxes to begin with.

## Break-to-learn

Every lab is a pair: **break it, then harden it, with an observable
signal for both halves.** You don't understand a control until you've
personally defeated it — reading that an overly broad task role "could"
reach a bucket it shouldn't is not the same as watching it actually
reach that bucket, then tightening the policy and watching the same
call come back `AccessDenied`. The break proves the control was
missing; the harden proves your fix is the reason it's gone, not a
guess. If a day ever feels like "just read and configure," something's
missing — go find the break.

## Terraform, not console

Every lab in this path is Terraform. The console shows up only as a
read-only inspection tour — never as the primary way you create or
change anything. Three reasons this isn't optional:

- **Reproducible** — the exact misconfiguration you broke is a diff
  away from the exact fix that hardened it; you can re-run either on
  demand instead of hoping you remember which checkbox you clicked.
- **Diffable** — a policy change is a code review, not a screenshot;
  you can see precisely which line flipped `Allow` to `Deny`, or which
  condition key got added.
- **Destroyable** — `terraform destroy` is a teardown you can trust.
  Console-built resources accumulate orphans nobody remembers creating,
  which is how free accounts turn into surprise bills.

Cross-reference [`ANTIPATTERNS.md`](ANTIPATTERNS.md) anti-pattern #2.

## How to compress — what to over-index on, what to skip

Twelve days is not enough time to go deep on everything AWS security
touches, and trying to is how people stall out. Spend your depth budget
here:

**Over-index on:**
- **The IAM policy evaluation order**, cold — explicit deny, SCP/RCP,
  resource-based policy, identity-based policy, permission boundary,
  session policy, in that order, and *why* each one sits where it does.
  This is the one piece of knowledge every other day depends on.
- **KMS "who can decrypt?"** as a standing question, not a one-time
  checkbox. Encryption-at-rest is not security-at-rest if the key
  policy, grants, and `kms:ViaService` conditions let the wrong
  principal decrypt. Ask this question about every key you ever touch,
  in this path and after it.
- **Detection → response wiring** — the mechanics of a GuardDuty
  finding landing on an EventBridge rule that invokes a Lambda that
  actually does something (quarantine a role, isolate a resource).
  Detection without automated response is just a more expensive log.

**Skip on a first pass:**
- **Marketplace security tooling** — third-party WAF rule packs, CSPM
  dashboards, and the like. They're valuable in a real job, but they
  sit *on top of* the native controls this path teaches; learn the
  native layer first or the tooling is a black box.
- **Full AWS Control Tower / multi-account landing-zone builds.**
  Day 10 teaches the *concepts* (SCPs, delegated administration, ABAC)
  that Control Tower automates, but standing up a real landing zone is
  a multi-week infrastructure project in its own right, not a 12-day
  lab.
- **Compliance-framework minutiae** — memorizing which PCI-DSS or
  HIPAA control number maps to which AWS setting. The underlying
  control (encryption, logging, access control) is what this path
  teaches; the framework crosswalk is a lookup exercise once you already
  understand the control, not before.

This is deliberate breadth-vs-depth triage, not laziness — the skipped
items are wide but shallow from a first-pass perspective; the
over-indexed items are the load-bearing 20% that the other 80%
ultimately reduces to.

## How to keep it cheap

The whole 12-day sprint targets **under $15**, and that's achievable
because of a few disciplined habits, not luck:

- **Tear down daily.** Every day's Terraform module is destroyed at the
  end of the session; only `labs/base` stays up across the sprint, and
  it's deliberately small (one ALB, one small Fargate task, CloudFront,
  S3, Secrets Manager).
- **One free-trial window, tracked explicitly.** GuardDuty, Security
  Hub, Macie, and Detective are enabled once (Day 8) and disabled once
  (end of Day 9) inside a single 30-day trial — never left running
  "just in case." Missing this step is the single most likely way to
  blow the budget; it's called out again in
  [`ANTIPATTERNS.md`](ANTIPATTERNS.md) anti-pattern #9.
- **A budget alarm and a billing alarm before Day 1**, not after — see
  `README.md` STEP 0. Catching a runaway resource within hours is the
  difference between a rounding error and a real bill.
- **One region for the whole sprint.** Fewer moving parts, easier to
  audit what's actually running, easier to sweep clean at the end.
- **Day 12 runs a final sweep** — every module destroyed, detection
  services confirmed off, every CMK on a scheduled-deletion timer (KMS
  bills for the pending-deletion window, so this genuinely matters).

Read `ANTIPATTERNS.md` next — it's the same two principles above, seen
from the failure side: the ten specific mistakes that eat most
learners' time, and the corrective for each.
