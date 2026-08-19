# Day 11 — IR capstone: attack

> **⚠️ Authorized testing only.** Every action in this day targets **your
> own AWS account and your own Terraform-deployed `labs/base` workload** —
> nothing else. This is the same statement `ANTIPATTERNS.md` makes for
> every offensive lab in this path, repeated here because today's incident
> is the biggest one you'll run. See
> [`ANTIPATTERNS.md`](ANTIPATTERNS.md#authorized-testing-statement).

## Why this matters at work

Every day before this one taught you one control at a time: a policy,
a key, a rule, a finding type. Real incidents don't arrive one control at
a time — they arrive as a chain, and the chain is exactly as strong as
its weakest link, not its strongest one. A team that can recite what
GuardDuty detects but has never watched a real, multi-stage incident
produce a real CloudTrail trail, a real finding ID, and a real Security
Hub entry — all for the *same* fifteen minutes of attacker activity — is
still guessing at how those artifacts relate to each other under
pressure. Today you build that muscle by being both the attacker and the
first responder gathering evidence, against infrastructure you already
know intimately because you've been breaking and hardening it for ten
days.

## The engine lens

Day 11 doesn't open a new door in the evaluation order — it walks
through several doors you already opened this sprint, in the order a
real attacker would actually hit them, and lands on the one door that
watches all the others: the detective layer Day 8 installed and Day 9
wired to automation. Specifically, today's chain touches:

- **Identity-based policy** — the task role's S3 grant (broad-within-
  workload since Day 1, and the reason step 4 below can reach the
  bucket at all once the attacker holds that role's credentials).
- **No door at all** — the SSRF bug itself isn't a policy layer, it's
  an application flaw that lets an outside caller make the *task* issue
  a request on its own behalf. This is the reminder that the evaluation
  order only protects you if every caller reaching it is who you think
  it is; SSRF is exactly the class of bug that breaks that assumption.
- **The detective door** — CloudTrail, GuardDuty, Security Hub, and
  Config don't grant or deny anything; they watch what the other doors
  did (or failed to do) and leave a record. Today's lens is: a chain
  that defeats every preventive door still has to walk past this one,
  and it can't avoid leaving footprints while it does.

## Core concepts

### The shared incident, end to end

This is the full version of the smaller trigger Day 8 ran. The chain:

```
1. Leaked IAM access key   (initial access — see ANTIPATTERNS.md #10)
        │
        ▼
2. Recon                   (attacker maps the workload with that key's
   │                        read access — finds the public app, the
   │                        ALB/CloudFront front door, the SSRF hole)
        ▼
3. SSRF exploit             (GET /fetch?url=<credentials endpoint> —
   │                         the app fetches server-side, on the
   │                         attacker's behalf, from inside the task)
        ▼
4. Task-role credential     (the ECS credential endpoint returns the
   theft                     task role's live temporary AccessKeyId/
   │                         SecretAccessKey/SessionToken)
        ▼
5. Data exfil               (those stolen temp credentials read/copy
   │                         from the base S3 bucket and DynamoDB table
   │                         — the same S3 grant Day 1 discussed)
        ▼
6. Crypto-mining-flavored   (the same stolen credentials attempt an
   API call                  unusual, high-cost API call — this lab
                              uses a safe --dry-run EC2 call as the
                              stand-in, never a real mining workload)
```

Every arrow in that diagram is a control gap; every box is a step that
should leave a record somewhere. The point of today isn't running the
chain — it's proving, artifact by artifact, that the chain left a trail
a defender could reconstruct without having watched it happen live. Day
12 is the mirror image: it uses that same trail to contain, eradicate,
and recover.

### Why the credential endpoint isn't quite "just SSRF"

AWS deliberately makes the ECS task credentials endpoint
(`http://169.254.170.2` + the task's `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`)
require an unguessable, per-task path segment — precisely so that a pure
blind SSRF bug (a URL-fetch flaw with no way to read environment
variables) isn't, by itself, enough to steal credentials. This is a real
mitigation, not an oversight in the lab. In a genuine incident an
attacker closes that gap with a *second* leak — a log line, an error
message, a debug endpoint, or (as scoped here, to keep today's lab
focused on the chain's back half rather than a second research project)
the same access that let them recon the workload in step 2. The lab
below treats the exact relative-URI value as already in the attacker's
hand for that reason, and says so out loud in `attack-runbook.md` rather
than pretending pure SSRF alone solved it.

### The free-trial window, re-opened

GuardDuty, Security Hub, Macie, and Detective went dark at the end of
Day 9 to respect the single 30-day free-trial window (`ANTIPATTERNS.md`
#9). Today re-enables **GuardDuty and Security Hub** (Macie and
Detective stay off — this incident's artifact list is CloudTrail,
GuardDuty, Security Hub, and Config, not sensitive-data discovery) for
the Day 11–12 capstone specifically. This is still the *same* 30-day
trial, not a second one — Days 8–9 used roughly two of its thirty days,
so re-opening it for Days 11–12 stays well inside the original window,
provided Day 12 sweeps it closed on schedule as planned. That "provided"
is load-bearing: re-enabling and forgetting to disable again is
precisely anti-pattern #9, at capstone scale. Config's rules from Day 9
were never part of that trial clock and can simply keep running.

## Break → Harden lab

See `labs/day11/README.md`, which points to the shared attack assets in
`labs/capstone/` (`attack-runbook.md`, `attack.sh`, `attack-SOLUTION.md`).

**The break:** the full six-stage incident chain above lands, end to
end, against your own `labs/base` workload, and each stage is captured
as a real artifact from a real detection control.

**The harden:** deliberately not today. Day 11 and Day 12 are one
break→harden pair split across two days — today is attack-and-capture
only; Day 12 is contain→eradicate→recover, using exactly the evidence
you gather today.

**Success signal:** a completed attack timeline in `attack-SOLUTION.md`
with every stage cross-referenced to at least one real artifact — a
CloudTrail event, a GuardDuty finding ID, a Security Hub finding ARN, or
a Config resource-history entry — captured from your own account, not
copied from this document.

## Exercises

1. **Reconstruct the attacker's path from CloudTrail alone.** You're
   handed a CloudTrail Event history export (a set of events with
   `eventName`, `sourceIPAddress`, `userIdentity.arn`, and `errorCode`
   fields — no narrative, no timestamps labeled "step 1/2/3") covering a
   window that includes this incident. Without re-reading the runbook,
   order the events into stages 2–6 above and name the pivot event (the
   one event that changes *which* credentials every subsequent event
   uses).
   **Hint:** the pivot is the one event whose `userIdentity.arn` changes
   from the leaked key's user ARN to something containing the task
   role's session name — everything on the far side of that boundary
   used stolen credentials, not the leaked key.
   **Solution sketch:** stage 2 (recon) events carry the leaked key's
   `userIdentity.arn` and are read-only (`Describe*`/`List*`) API calls
   with no errors. The `fetch` HTTP request itself isn't a CloudTrail
   event (CloudTrail doesn't see application-layer HTTP to your own
   ALB) — the *first* CloudTrail event bearing the task role's assumed-
   role ARN is the pivot, and it should be the earliest `s3:*` or
   `dynamodb:*` call (stage 5). The `ec2:RunInstances` call with
   `errorCode: DryRunOperation` is stage 6 and should be the last (or
   near-last) event in the window with that role's ARN.

2. **Reconstruct which control fired first, from GuardDuty + Security
   Hub + Config alone (no CloudTrail this time).** You're given: one
   GuardDuty finding JSON (type, severity, `createdAt`, the resource
   block naming the task role), one Security Hub finding ARN with a
   `CreatedAt` timestamp a few seconds later than GuardDuty's, and a
   Config resource-history query on the S3 bucket and the task role's
   IAM policy showing **no configuration changes** in the incident
   window. What does the *absence* of a Config change tell you that the
   other two artifacts can't?
   **Hint:** Config's configuration-history timeline answers "did
   something get *reconfigured*," which is a different question from
   "did something get *used* differently."
   **Solution sketch:** GuardDuty fires first because it's the primary
   detector evaluating the raw signal (the anomalous credential use);
   Security Hub's finding appears seconds later because Security Hub
   ingests GuardDuty findings rather than generating this one itself.
   The flat Config history rules out a misconfiguration as the root
   cause — nobody widened the bucket policy or the task role's grant
   during the window — which tells you this was **pure credential
   theft and abuse of an existing (if over-broad) grant**, not a
   configuration-drift incident. That distinction changes what Day 12's
   eradication step needs to fix: revoke/rotate and tighten the grant,
   not "find and revert a bad config change," because there isn't one.

## Anti-patterns today

- **#3 — never actually testing a deny.** Everything you exfiltrated
  today, the task role's identity policy allowed. Nowhere in this
  chain did anyone test whether an *unintended* caller could be denied
  — that's exactly the gap the attack walked through, and exactly why
  Day 12's harden must end with a deny-path test on the same call this
  attack made, not just a tighter-looking policy. See
  [`ANTIPATTERNS.md`](ANTIPATTERNS.md#3-never-actually-testing-a-deny).
- **#4 — pushing detection off "until later."** This capstone is only
  possible to run meaningfully because CloudTrail has been logging
  since Day 1 and GuardDuty/Security Hub came up in their tracked
  window on Day 8 — if detection had been left for "later," there would
  be nothing to reconstruct today. See
  [`ANTIPATTERNS.md`](ANTIPATTERNS.md#4-pushing-detection-off-until-later).
- **Authorized-testing statement, with real numbers.** This entire
  chain — SSRF exploitation, credential theft, S3/DynamoDB exfil, the
  EC2 dry-run call — runs only against your own `labs/base` deployment
  in your own account. The whole 12-day sprint's budget target is
  **under ~$15 total**; re-enabling GuardDuty and Security Hub for
  Days 11–12 is designed to cost **$0 incremental** because it reuses
  the same single 30-day trial Days 8–9 already opened (roughly 2 of
  30 days used before today). That number stops being true the moment
  the trial's disable step gets skipped — Day 12's final sweep is not
  optional bookkeeping, it's the only thing keeping this at $0.

## Cert corner (SCS-C02)

- **Domain 1 — Threat Detection and Incident Response (14%):** this day
  *is* the domain — a multi-stage incident with a real GuardDuty
  finding, a real Security Hub aggregation, and a reconstruction
  exercise that mirrors exactly what the exam's IR scenario questions
  ask you to do from a description of artifacts.
- **Domain 2 — Security Logging and Monitoring (18%):** the CloudTrail
  reconstruction exercise (Exercise 1) and the Config resource-history
  technique (Exercise 2) are both direct exam-relevant skills — knowing
  which log answers "who did what" versus "what changed."
- Cross-check `CERT-MAP.md` — Day 11 is one of four days feeding Domain
  1, and Day 12's self-assessment is where you score yourself against
  it honestly.

## Teardown

Nothing new was created today — Day 11 layers no Terraform of its own
on top of `labs/base`. The only state change is that GuardDuty and
Security Hub are running again (re-applied from the Day 8 detection
module). **Leave them running** — they stay up into Day 12 by design,
which is the day that sweeps them, along with everything else, back to
zero. Nothing else lingers: no new IAM users, no new infrastructure, no
new stray credentials (the "leaked key" in this lab was never a real
second credential — see `labs/capstone/attack-runbook.md`).
