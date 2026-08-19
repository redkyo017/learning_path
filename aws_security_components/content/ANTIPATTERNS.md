# ANTIPATTERNS.md — The 10 Mistakes That Waste 80% of Beginners' Time

*Numbered 1–10, in this fixed order — day files cite these numbers, so
the numbering is a contract and will not be reshuffled as content is
added.*

Each entry follows the same shape: **the mistake → why it wastes
time → the corrective.**

---

### 1. Treating each service's policy language as its own topic

**The mistake:** Learning S3 bucket policy syntax, then KMS key policy
syntax, then WAF rule syntax, then SCP syntax, as unrelated subjects,
each memorized fresh.

**Why it wastes time:** Every one of those is the same evaluation order
— explicit deny → SCP/RCP → resource-based policy → identity-based
policy → permission boundary → session policy — wearing a different
service's syntax. Relearning the *order* ten times, once per service,
means you never build the one transferable mental model that makes the
eleventh service fast to pick up.

**The corrective:** Learn the IAM evaluation order once, cold (Day 1).
For every new service after that, the first question is "which door is
this, and where does it sit in the order?" — not "what's the syntax?"
See [`STRATEGY.md`](STRATEGY.md) spine principle 1.

---

### 2. Console-clicking instead of Terraform

**The mistake:** Building and fixing resources by clicking through the
AWS Console because it feels faster in the moment.

**Why it wastes time:** Console state isn't diffable (you can't see
exactly what changed between "broken" and "fixed"), isn't reproducible
(you can't re-run the exact break on demand), and isn't reliably
destroyable (orphaned resources from forgotten clicks are how free
accounts turn into surprise bills).

**The corrective:** Terraform every lab. The console is a read-only
inspection tour, never the primary way you create or change anything.

---

### 3. Never actually testing a deny

**The mistake:** Testing only that access works (the allow path), and
assuming a policy is "locked down" because it looks restrictive on
paper.

**Why it wastes time:** A policy that reads as tight can still leak —
an unexpected `Allow` from another policy layer, a missing condition
key, an SCP that doesn't cover the case you assumed it did. Without
testing the deny path you ship false confidence, and the gap surfaces
later, in a real incident, instead of now, in a lab.

**The corrective:** Every lab pairs an allow-path test with an
explicit deny-path test. `AccessDenied` is a success signal when you're
proving a control works, not a bug to chase away.

---

### 4. Pushing detection off "until later"

**The mistake:** Treating CloudTrail, GuardDuty, and Security Hub as
end-of-project polish, to be wired up once everything else is "done."

**Why it wastes time:** There's no signal to correlate against the
break/harden work you already did — you can't retroactively generate a
CloudTrail event for an attack you ran three days ago. Bolting on
detection at the end also compresses it into far less time than it
needs.

**The corrective:** Stand up logging (CloudTrail) from Day 1 so
signal exists from the start, even before the paid detection services
(GuardDuty, Security Hub, Macie, Detective) come on in their single
tracked trial window on Day 8.

---

### 5. Trusting default encryption without asking "who can decrypt?"

**The mistake:** Seeing "encryption at rest: enabled" and treating that
as the end of the question.

**Why it wastes time:** Encryption at rest is not security at rest if
the key policy, a grant, or a missing `kms:ViaService` condition lets a
principal you didn't intend actually decrypt the data. The checkbox
gives false comfort; the misconfiguration surfaces only when someone
(you, in a break lab, or an attacker, for real) actually tries to
decrypt.

**The corrective:** For every CMK you touch, explicitly ask and test
"who can decrypt this right now?" — walk the key policy, grants, and
`kms:ViaService` conditions, don't just confirm the encrypted flag.

---

### 6. `iam:PassRole` and wildcards as silent privilege escalation

**The mistake:** Granting broad `iam:PassRole` or wildcard
actions/resources (`iam:*`, `Resource: "*"`) "for convenience," meaning
to tighten it later.

**Why it wastes time:** These combinations are one of the most common
real-world privilege-escalation paths, and they look completely benign
in a policy review — nothing about `iam:PassRole` on its own looks
dangerous until you notice what role it can be paired with. Retrofitting
a scope-down after the fact means re-auditing every place that relied on
the broad grant.

**The corrective:** Scope `iam:PassRole` to specific role ARNs with
condition keys from the start; avoid `iam:*` / `Resource: "*"`
combinations; test that the escalation path is actually closed, not
just that the policy reads narrower.

---

### 7. WAF as a checkbox instead of tuned and tested

**The mistake:** Attaching AWS Managed Rule Groups to a Web ACL and
considering WAF "done."

**Why it wastes time:** Untuned managed rules produce false positives
(blocking real traffic) and leave gaps for false negatives (letting
real attack payloads through) — and nobody notices either failure mode
until it shows up as a production incident or a support ticket.

**The corrective:** After attaching rules, actually run attack payloads
against the Web ACL and confirm they're blocked, and run legitimate
traffic through and confirm it isn't. Tune based on both observed
signals, not on the rule group's name alone.

---

### 8. Long-lived access keys instead of roles and short-lived credentials

**The mistake:** Creating an IAM user with a permanent access key
because it's the fastest way to get a script working right now.

**Why it wastes time:** Long-lived keys leak (into git history, into
logs, into env vars), rotation is a manual step that's routinely
skipped, and there's no automatic expiry to bound the damage if one
does leak. Every leaked long-lived key becomes its own incident later.

**The corrective:** Use roles and STS `AssumeRole` (or IAM Identity
Center) everywhere a human or a service needs access. Where a static
credential is genuinely unavoidable, treat it as a ticking liability —
rotation schedule, monitoring, and a plan to remove it.

---

### 9. Ignoring the free-trial clock — surprise bills

**The mistake:** Enabling GuardDuty, Security Hub, Macie, and/or
Detective without tracking that they're inside a single 30-day free
trial, and forgetting to disable them when the trial's usefulness for
this sprint is over.

**Why it wastes time (and money):** These services bill continuously
once the trial window closes. The single most common way to blow past
this path's <$15 budget is leaving one of them on past Day 9.

**The corrective:** Track the trial window explicitly — this path
opens it Day 8 and closes it at the end of Day 9, re-opening it only
for the Day 11–12 capstone, with a final sweep on Day 12 confirming
everything is off.

---

### 10. Secret sprawl

**The mistake:** Copying credentials, API keys, or connection strings
into task-definition environment variables, application code,
`.tfvars` files that get committed, or multiple duplicated locations
"just for this test."

**Why it wastes time:** Once a secret exists in more than one place,
there's no single point of rotation or audit — you can't be confident
you've actually removed it everywhere when it's time to rotate or
revoke, and every extra copy is another way for it to leak.

**The corrective:** One source of truth (Secrets Manager or Parameter
Store), referenced by ARN wherever it's needed, never hardcoded.
`.tfvars`, `.env`, and Terraform state are always gitignored; ship only
`*.tfvars.example` / `*.env.example` placeholders.

---

## Authorized-testing statement

**Every offensive technique in this path — every "break" half of a
break→harden lab, the Day 11–12 IR capstone attack included — targets
only the learner's own AWS account and the learner's own Terraform-
deployed workload (`labs/base/` and its day-by-day modules).** Nothing
here is to be run against any account, resource, or workload you do not
own and are not explicitly authorized to test. Every offensive lab's
`README.md` repeats this statement; this file is the canonical source
it links back to.
