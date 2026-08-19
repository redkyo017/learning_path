# Day 12 — IR capstone: defend + gap-fill

## Why this matters at work

Anyone can write a policy that looks tight on paper. What separates a
security engineer who gets paged at 2am and actually closes an
incident from one who just watches dashboards is the ability to move
through contain → eradicate → recover *in that order*, under time
pressure, without either freezing production forever (over-containing)
or declaring victory before the actual hole is closed (under-eradicating).
Today you run that discipline end to end against the exact incident
Day 11 ran against your own workload — then you close the loop on
twelve days of learning with an honest self-assessment against the
SCS-C02 blueprint, and you tear down every single billable resource
this sprint created, in every region you touched.

## The engine lens

Every prior day attached to one door of the evaluation order —
identity policy, trust policy, resource policy, SCP. Today attaches to
**all of them at once**, because a real incident doesn't announce
which door it's using. The discipline for today is: identify which
door the attacker actually walked through (here: the **identity
policy** on the task role — the door that *grants*, sitting after SCP
and resource policy but before permission boundary and session policy
in `explicit Deny → SCP/RCP → resource-based policy → identity-based
policy → permission boundary → session policy`), then use the
**fastest** door available to shut it — which today is **explicit
Deny**, the door checked first, because you can lay a Deny down on top
of an existing Allow you don't want to touch (or can't touch fast
enough) and it wins immediately, no race with any other policy layer.
That's not a workaround — it's the correct move once you understand
the order: Deny doesn't compete with the broad Allow, it overrides it,
unconditionally, from the first checkpoint in the chain.

## Core concepts

### The incident, restated as a chain of doors

Days 8, 9, and 11 built and then exercised this exact chain against
`labs/base`:

1. **Initial access** — a long-lived IAM access key (simulated —
   [Antipattern #8](ANTIPATTERNS.md#8-long-lived-access-keys-instead-of-roles-and-short-lived-credentials))
   leaks, giving the attacker a low-privilege, recon-only identity.
   *No door of the evaluation order stops this* — the key is valid,
   its own identity policy is deliberately narrow (recon actions only:
   `sts:GetCallerIdentity`, `iam:GetUser`, `s3:ListAllMyBuckets`). This
   step's lesson isn't "which door failed," it's "this door should
   never have existed at all" — see Exercise 1.
2. **Recon** — the leaked identity enumerates the account. Still no
   door failing; recon within granted permissions is indistinguishable
   from a curious engineer until GuardDuty correlates it with what
   comes next.
3. **SSRF → credential theft** — the attacker calls the base app's
   `/fetch?url=` endpoint (`labs/base/app/app.py`) with
   `url=http://169.254.170.2/v2/credentials/<GUID>` — the ECS Fargate
   task-credential endpoint. The app, with zero URL validation, fetches
   it and echoes the response: the **task role's live temporary
   credentials**, verbatim, in the HTTP body. This is not a door in the
   IAM evaluation order at all — it's a request-layer flaw (no
   allow-list on outbound URLs) that hands the attacker a **key that
   opens every door the task role's identity policy opens**.
4. **Exfil via the [identity-policy](GLOSSARY.md#i) door** — with the stolen
   credentials, the attacker calls S3 (`GetObject`/`PutObject`/
   `DeleteObject`/`ListBucket` — the base workload's task role grants
   all four, across the *entire* bucket, not just the prefix the app
   uses) and DynamoDB (`Scan` — the whole table, not the single-item
   reads the app performs). Both succeed, because the task role's
   identity policy is the door that actually *grants* here, and it was
   over-broad. A third pivot — a `--dry-run` `ec2:RunInstances` call
   for crypto-mining — is attempted (Day 11's `attack-SOLUTION.md`
   records the exact `errorCode` your account returned: `DryRunOperation`
   means the permission check *passed*, `UnauthorizedOperation` means it
   was already denied). Either result is a live finding worth reacting
   to today — see the eradication table below, which closes this pivot
   with an explicit Deny regardless of which one you got, rather than
   relying on an absence-of-grant that's easy to widen by accident later.

### Contain → eradicate → recover, mapped to doors

| Phase | Action | Door / mechanism | Why this order |
|---|---|---|---|
| **Contain** | Deactivate + delete the leaked access key | Removes the *principal*, not a policy — upstream of every door | Fastest way to stop *new* attacker actions with that identity; doesn't touch the stolen task-role creds, which are already out |
| **Contain** | Attach a break-glass `Deny *` inline policy to the task role, via CLI, immediately | Explicit Deny — first door checked, wins over everything | An incident in progress cannot wait for a `terraform plan`/`apply` cycle; this is the one place in this path CLI-first is correct — see Anti-patterns below |
| **Contain** (optional) | Scale the ECS service to 0 | Removes the compute, not a policy | Stops the *vulnerable process* itself while you work, if the app can't be trusted to stay up safely |
| **Eradicate** | Terraform: Deny-layer the task role (no bucket-wide Delete, no reads/writes outside the app's real prefix, no DynamoDB `Scan`, no EC2 action at all, KMS `Decrypt`/`GenerateDataKey` gated to [`kms:ViaService`](GLOSSARY.md#k)) | Explicit Deny, permanent, codified | Fixes the identity-policy door itself — the actual root cause, not just a symptom |
| **Eradicate** | Terraform: WAF rule on the ALB blocking `169.254.169.254` / `169.254.170.2` / `/v2/credentials` / `/latest/meta-data` substrings in the `url` query parameter | Request-layer control in front of the app — not an IAM door at all, but the door that should have stopped step 3 before it ever reached the identity layer | SSRF is not an IAM problem; layering a control at the door the attack *actually* used (the request) closes the entry point, while the IAM Deny closes the blast radius *if* entry ever happens again through a door you haven't thought of yet |
| **Recover** | Remove the break-glass Deny (CLI), confirm the permanent Terraform Deny is what's now doing the job, restore desired count, force a new ECS deployment | — | Break-glass is temporary by design; leaving it in place forever is just a slower way of saying "the app is down," which isn't recovery |
| **Recover** | Re-test the full attack chain against the now-hardened workload | All of the above | "Fixed" is a claim; `AccessDenied` and WAF `403` are evidence — see [Antipattern #3](ANTIPATTERNS.md#3-never-actually-testing-a-deny) |

### Why WAF and not a network control for the SSRF hop

On Fargate, the task-credential endpoint (`169.254.170.2`) is served
by the Fargate infrastructure itself, off the ENI path your security
groups and NACLs actually govern — there is no `awsvpc`-network hop
for a security group to see and block. The vulnerable request
originates *inside* the app process (the Flask server making an
outbound `requests.get(url)` call), so the only places that can
intervene are (a) the app's own code — out of Terraform's reach today
— or (b) a control in front of the *inbound* request that carries the
malicious `url` value, before it ever reaches the vulnerable code path.
That's exactly what a WAF rule on the ALB is. It also has to sit on
the **ALB**, not (only) on CloudFront: the base workload's ALB has a
public DNS name that bypasses CloudFront entirely (documented in
`labs/base/outputs.tf`), so a CloudFront-only Web ACL would leave that
direct path wide open — the regional WAF on the ALB is the one
chokepoint both paths share.

### The retro (five whys, abbreviated)

1. Why did the attacker get task-role creds? → SSRF endpoint fetched an
   attacker-controlled URL with no validation.
2. Why did that matter? → The URL could reach the ECS credential
   endpoint, which has no authentication of *who* is asking on the
   task's own local network path.
3. Why did stolen creds do damage? → The task role's identity policy
   granted far more than the app itself calls (whole-bucket Delete,
   whole-table Scan).
4. Why was the policy that broad *right now*, if Day 1 already fixed
   it once? → Day 1's fix (the same Deny-overlay technique reapplied
   today) was torn down at the end of Day 1, per this sprint's own
   daily-teardown rhythm — only `labs/base` persists between days.
   That rebuild-daily design is the right tradeoff for a *learning*
   sprint (it keeps cost near zero), but it's also exactly the gap a
   real production environment can't afford: a control that only
   exists while its own day's lab happens to be applied isn't a
   control. Today's fix is written to stay up — the final sweep, not
   tomorrow's daily teardown, is what removes it.
5. Why didn't an automated control catch and contain it immediately? →
   Not because it fired on the wrong finding type — it never had the
   chance to fire at all. Day 9's EventBridge → Lambda auto-quarantine
   is destroyed by Day 9's own teardown checklist at the end of Day 9;
   the Day 11–12 capstone re-enables only the underlying GuardDuty/
   Security Hub *services*, not Day 9's response automation layered on
   top of them. That's its own finding, worth naming explicitly: in a
   real environment, response automation has to be a standing control,
   not a per-lab artifact that gets torn down at the end of its
   teaching day.

## Break → Harden lab

See `labs/day12/`. There is no new *break* today — the break already
happened on Day 11 against your own workload. The **harden**: run
contain → eradicate → recover, in that order, using the Terraform in
`labs/day12/` and the CLI steps in the runbook (`labs/capstone/defend-runbook.md`).
**Success signal:** re-attempt the exact Day-11 attack steps against
the hardened workload — stolen-credential `s3:DeleteObject` and
`dynamodb:Scan` now return `AccessDenied`; a repeat SSRF request
carrying the metadata URL now returns WAF `403` before the app ever
sees it. Record both in `labs/capstone/defend-SOLUTION.md`.

## Exercises

1. **Which single control, added earlier in the path, would have
   prevented the whole incident — not just slowed it down — and why,
   argued strictly from the engine order?**
   **Hint:** the SSRF hole is a request-layer flaw the IAM engine can't
   see at all. Ask instead: which door determines *what the stolen
   credentials are worth* once they're stolen?
   **Solution sketch:** Day 1's task-role least-privilege tightening —
   scoping the identity policy to exactly the app's real prefix and
   actions (no bucket-wide Delete/List, no table-wide Scan). The
   identity policy is the door that *grants* permissions (SCP and
   resource policy can only restrict further; permission boundary and
   session policy can only cap what identity already granted); it's
   the one door whose value is entirely independent of whether the
   SSRF hole is ever found. If Day 1's fix had been in place and never
   drifted, the exact same successful SSRF and the exact same stolen
   credentials would have been worth almost nothing — the attacker
   would get `AccessDenied` on `DeleteObject` and `Scan` on Day 11,
   with the entry point still wide open. Closing the entry point (WAF,
   today) matters too, but it's the second-highest-leverage fix, not
   the first, because a new entry point you haven't imagined yet is
   always possible; a correctly scoped grant caps the damage no matter
   which door the next entry point turns out to be.

2. **Why can't a security group or NACL stop the SSRF → credential-theft
   hop on Fargate, and what does that imply for where SSRF defenses
   belong?**
   **Hint:** think about which network path the ECS task-credential
   endpoint actually uses.
   **Solution sketch:** `169.254.170.2` is a link-local address served
   by the Fargate control plane directly to the task, not routed
   through the task's `awsvpc` ENI that security groups/NACLs actually
   filter — those tools have no visibility into that hop at all. The
   vulnerable action (the outbound fetch) happens inside the
   application process. The only layers that can intervene are
   upstream of the vulnerable code path: input validation in the app
   itself, or a request-inspection control (WAF) in front of the app
   that blocks the malicious `url` value before the app ever acts on
   it. This generalizes: SSRF defenses belong at the request boundary
   and in application code, never at the network-ACL layer, because by
   the time a network control could see anything, the vulnerable
   action has often already happened locally to the compute resource.

3. **Day 8/11 captured GuardDuty/Security Hub findings for this
   incident. For each of the six SCS-C02 domains, name one artifact
   from this path (a lab, a finding, a policy) that is your evidence
   you can defend a "3" or "4" self-score, not just recognize the
   term.**
   **Hint:** use the domain → day map in `CERT-MAP.md`; for each
   domain, the strongest evidence is the day where you personally
   broke *and* hardened that exact door.
   **Solution sketch:** e.g. Domain 4 (IAM) → Day 1's `AccessDenied` on
   the tightened task role, re-provable today; Domain 1 (Threat
   Detection & IR) → today's contain/eradicate/recover run itself, plus
   the specific GuardDuty finding ID from Day 11; Domain 5 (Data
   Protection) → the `kms:ViaService` Deny added today, traceable back
   to Day 3/4's key-policy work; Domain 3 (Infrastructure Security) →
   today's WAF rule, traceable to Day 6; Domain 2 (Logging &
   Monitoring) → the CloudTrail event for the stolen-credential API
   calls, from Day 8; Domain 6 (Governance) → Day 10's SCP concept plus
   today's final-sweep governance checklist. If you can't name a
   specific lab or artifact for a domain — not just the concept — that
   domain is your honest gap; see the Cert corner below.

## Anti-patterns today

- [**#8 — long-lived access keys**](ANTIPATTERNS.md#8-long-lived-access-keys-instead-of-roles-and-short-lived-credentials):
  the entire incident starts with one. Today's containment step 1
  (deactivate + delete) is the reactive fix; the durable fix is never
  creating one for a real workload in the first place.
- [**#3 — never actually testing a deny**](ANTIPATTERNS.md#3-never-actually-testing-a-deny):
  today's whole success signal *is* a deny (`AccessDenied`, WAF `403`).
  A runbook that stops at "I applied the fix" without re-running the
  attack step is exactly the failure mode this antipattern warns about.
- [**#2 — console-clicking instead of Terraform**](ANTIPATTERNS.md#2-console-clicking-instead-of-terraform):
  today's containment steps are deliberately **CLI**, not Terraform —
  the one justified exception in this whole path. An incident in
  progress can't wait on a `plan`/`apply` cycle; the rule still holds
  for anything meant to be *permanent* (eradication goes back into
  Terraform, same day, and the CLI break-glass policy is removed once
  it does).
- [**#9 — ignoring the free-trial clock**](ANTIPATTERNS.md#9-ignoring-the-free-trial-clock--surprise-bills):
  today's final sweep is the last chance to disable GuardDuty/Security
  Hub/Macie/Detective before they bill past the trial window for good.

## Cert corner (SCS-C02) — the final self-assessment

Today is the day to actually run `CERT-MAP.md`'s self-scored checklist,
not just read it. Walk all six domains:

1. **Threat Detection and Incident Response (14%)** — today's contain/
   eradicate/recover *is* this domain, live. Score yourself against
   whether you could re-run today's runbook from memory on a different
   finding type.
2. **Security Logging and Monitoring (18%)** — can you point to the
   exact CloudTrail event name for the stolen-credential API calls and
   explain management- vs. data-event tiering without notes?
3. **Infrastructure Security (20%)** — can you justify, unprompted, why
   the WAF rule added today has to sit on the ALB and not only on
   CloudFront?
4. **Identity and Access Management (16%)** — can you write the Deny
   statement for the DynamoDB `Scan` closure from memory, including why
   Deny beats the pre-existing Allow regardless of evaluation order
   nuance?
5. **Data Protection (18%)** — can you explain what [`kms:ViaService`](GLOSSARY.md#k)
   does and why `Decrypt` alone, without it, isn't "locked down"?
6. **Management and Governance (14%)** — can you describe how an SCP
   would have made today's whole incident structurally impossible
   rather than merely detected?

**If any domain scores below 3, that's the finding of the day** — name
it in `journal.md`, re-open that domain's day file(s), and re-run its
lab before deciding whether to schedule the exam. That's a more honest
outcome than a clean scorecard you can't actually defend.

## Teardown — FINAL SWEEP (critical, do not skip any item)

This is the last day of the sprint. Unlike every prior day, teardown
today includes **`labs/base` itself** — nothing is meant to survive
past Day 12. Full exhaustive checklist (Terraform destroy order,
detection-service disable + confirmation, CMK scheduled-deletion with
its 7-day billing note, and a global cross-region sweep) lives in
`labs/day12/README.md` — run every item, in order, before you consider
the sprint closed.
