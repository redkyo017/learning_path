# Day 8 — Detection

> **⏱ FREE-TRIAL CLOCK STARTS TODAY.** GuardDuty, Security Hub, Macie, and
> Detective each come with a 30-day free trial, and this path treats all
> four as **one shared clock that starts the moment you enable the first
> one today.** The plan: **enable now (Day 8), keep them on through Day 9's
> response-automation lab, disable at the end of Day 9.** They come back
> only for the Day 11–12 capstone, and Day 12 ends with a final sweep
> confirming everything is off. If you stop partway through today and pick
> this back up tomorrow, that's fine — but do not let this clock run past
> Day 9 without a deliberate decision to keep paying for it. See
> [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #9 for what "past Day 9" actually
> costs.

## Why this matters at work

Every control you've built through Day 7 answers "can this happen?" Today
answers a different question: "if it happens anyway, will you know?" That
gap is where real incidents live — the median time to *discover* a cloud
credential compromise is measured in days, not the minutes an automated
pipeline actually needs to exfiltrate data, and the difference between
those two numbers is entirely a function of whether logging and detection
were switched on *before* the incident, not scrambled into place during
it. The workload you've been attacking since Day 1 has a real,
exploitable SSRF hole in it right now — today you finally get to see what
that hole looks like from the defender's side of the glass.

## The engine lens

Today is different from every day before it: CloudTrail, GuardDuty,
Security Hub, and Macie don't sit anywhere *in* the evaluation order
(explicit Deny → SCP/RCP → resource policy → identity policy → permission
boundary → session policy) — they **read it**. Every one of those six
doors produces an outcome (an `Allow`, a `Deny`, an API call that
actually executed), and CloudTrail is the record of that outcome,
regardless of which door produced it. GuardDuty, Security Hub, and Macie
are progressively higher-level lenses trained on that same record:
GuardDuty asks "does this specific sequence of recorded events look like
an attack?", Security Hub asks "how does my whole account's posture score
against a checklist?", and Macie asks "do I even know what's sitting in
this bucket?" None of them change what the engine allows or denies — they
change how fast you find out the engine allowed something it shouldn't
have.

## Core concepts

### CloudTrail — the foundation everything else reads

CloudTrail is not optional infrastructure you bolt on later; it's the
record every other service in this list depends on. Two tiers matter:

- **Management events** — control-plane actions: creating a role,
  changing a bucket policy, calling `AssumeRole`, launching a task. Logged
  **by default, at no extra cost**, the moment any trail exists. There is
  no excuse to skip these — see
  [`ANTIPATTERNS.md`](ANTIPATTERNS.md#4-pushing-detection-off-until-later)
  #4.
- **[Data events](GLOSSARY.md#c)** — data-plane activity *inside* a
  resource: an individual S3 `GetObject`/`PutObject`, a Lambda `Invoke`.
  Not logged by default, billed per event, because the volume is orders
  of magnitude higher than management events. Today's lab turns these on
  for exactly one resource — the base workload's `app_data` bucket — not
  the whole account. Scoping data events to the one bucket you're actually
  studying, instead of "all S3 buckets," is the same discipline
  [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #2 and #9 are both about: cheap and
  auditable beats broad and expensive.

**Log file validation** is a CloudTrail feature (`enable_log_file_validation
= true`) that writes a cryptographic digest file alongside each batch of
log files, letting you later prove a given log file was not altered or
deleted after the fact — the difference between "we have logs" and "we
have logs an attacker (or a bad actor with console access) couldn't have
quietly edited." Turn it on every time; it costs nothing extra and it's
exactly the kind of control an auditor — or your own Day 12 IR write-up —
will ask you to point to.

### GuardDuty — does this look like an attack?

GuardDuty is a managed threat-detection service that continuously
analyzes CloudTrail management events, VPC Flow Logs, and DNS query logs
(all included automatically the moment you enable a detector — no
separate wiring) against AWS threat-intelligence feeds and anomaly-
detection models, and emits a **[finding](GLOSSARY.md#g)** whenever
something matches. Two finding families matter for today's shared
incident:

- `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS` —
  fires when a role's temporary credentials, which GuardDuty has learned
  are normally only used *from inside* the AWS network (an EC2 instance
  or an ECS task), are suddenly used from an external IP address. This is
  precisely the signature the shared incident produces: the task role's
  stolen credentials, replayed from the attacker's own machine.
- `CryptoCurrency:EC2/BitcoinTool.B!DNS` — fires on DNS queries or API
  activity consistent with cryptocurrency-mining tooling, matching the
  "and/or a crypto-mining API call" branch of the shared incident.

**Why Fargate credential theft isn't "just point at a fixed URL":** EC2's
classic instance-metadata credential path
(`/latest/meta-data/iam/security-credentials/<role-name>`) is a
*guessable, fixed* path — this is exactly why the older, unauthenticated
IMDSv1 was such a gift to SSRF attackers. AWS deliberately did **not**
repeat that mistake on ECS/Fargate: the task's credential endpoint lives
at a per-task, randomly generated path
(`http://169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`) that
isn't enumerable from outside the task. An attacker still needs *some*
way to learn that path — a leaked debug endpoint, a stack trace, or (as
in today's lab, standing in for the shared incident's opening move) a
foothold from the already-leaked IAM key with just enough ECS visibility
to look it up. The SSRF bug is still the thing that turns "I know the
path" into "I have the credentials," but it is one link in a chain, not
the whole chain — a distinction worth having cold for the exam and for a
real triage.

**Triggering a real finding takes time you may not have in one sitting.**
GuardDuty's models need the anomaly to actually be anomalous relative to
a baseline, and publishing can lag behind the underlying event by minutes
to hours depending on the finding type and how much history the detector
has. Today's lab therefore runs the real exploit (for the CloudTrail
signal, which is immediate) *and* falls back to GuardDuty's own official
`create-sample-findings` API for a **guaranteed**, real, finding-ID-
bearing record of both finding types above — see the lab.

### Security Hub — how does the whole account score?

Security Hub aggregates findings from GuardDuty, Macie, Config, Inspector,
and others into one normalized format
([ASFF](GLOSSARY.md#s) — AWS Security Finding Format) and continuously
evaluates the account against named
**[standards](GLOSSARY.md#s)** — checklists of best-practice controls,
each control itself a Config rule under the hood. This path enables the
**AWS Foundational Security Best Practices** standard only; the CIS AWS
Foundations Benchmark is a second, similarly-priced standard you could add
the same way, deliberately skipped here to keep both cost and finding
volume down for a 2-day trial window (over-index on the mechanism, not on
running every checklist AWS offers — see
[`STRATEGY.md`](STRATEGY.md#how-to-compress)). Once both GuardDuty and
Security Hub are enabled in the same account and region, GuardDuty
findings flow into Security Hub automatically — no separate subscription
resource required.

### Macie — do I even know what's in this bucket?

Macie is a different question from GuardDuty's. GuardDuty asks "is
something actively attacking me right now?" Macie asks "do I have
sensitive data sitting somewhere I've forgotten about?" — it runs
machine-learning and pattern-matching classification jobs against S3
objects and flags PII, credentials, and financial data it finds, plus
bucket-level posture issues (public access, missing encryption). Today's
lab runs a **one-time** classification job against the `app_data`
bucket — the same bucket the stolen task-role credentials are used to
read in the break. A one-time job, scoped to one bucket, is the cheap,
scoped way to run this; a recurring job scanning every bucket in the
account is the anti-pattern #9 way to blow through the trial's value
without extra teaching benefit.

### Detective — how did this happen, and what else did it touch?

Detective is the odd one out today: it doesn't generate new findings, it
builds a queryable behavior graph out of CloudTrail, VPC Flow Logs, and
GuardDuty findings you *already* have, purpose-built for the question an
investigator asks *after* a finding fires — "what did this principal do
before and after this event, and what else did it touch?" It needs data
to accumulate before its graph is useful (AWS's own guidance is to expect
it to need real history, not instant results), so today's lab enables the
Detective graph conceptually — the graph exists and starts accumulating —
without a dedicated exercise; the Day 11–12 capstone is where you'll
actually query it against a real incident timeline.

## Break → Harden lab

See `labs/day08/`. **The break:** enable CloudTrail, GuardDuty, Security
Hub, and Macie via Terraform, then run the shared incident's SSRF →
task-role-credential-theft chain against your own deployed workload and
use the stolen credentials from outside AWS, generating a real CloudTrail
data-event trail; back that with GuardDuty's official sample-findings API
for two guaranteed, real finding records. **The harden is Day 9** —
today only detects. **Success signal:** ≥2 GuardDuty findings visible
with finding IDs, and the CloudTrail record of the SSRF-driven credential
theft and subsequent `GetObject` traceable end to end (both recorded in
`labs/day08/SOLUTION.md`).

## Exercises

1. **Given this CloudTrail event, what happened and who did it?**

   ```json
   {
     "eventTime": "2026-08-19T14:32:07Z",
     "eventName": "GetObject",
     "eventSource": "s3.amazonaws.com",
     "userIdentity": {
       "type": "AssumedRole",
       "arn": "arn:aws:sts::111122223333:assumed-role/aws-sec-lab-task-role/i-am-a-session",
       "accessKeyId": "ASIAEXAMPLE0000STOLEN"
     },
     "sourceIPAddress": "203.0.113.42",
     "userAgent": "aws-cli/2.15.0 Python/3.11.6 Linux/x86_64",
     "requestParameters": {
       "bucketName": "aws-sec-lab-appdata-111122223333",
       "key": "customer-export.csv"
     },
     "resources": [{"ARN": "arn:aws:s3:::aws-sec-lab-appdata-111122223333/customer-export.csv"}]
   }
   ```

   **Hint:** compare `sourceIPAddress` against where you'd expect
   `aws-sec-lab-task-role` to normally call AWS from, and compare
   `userAgent` against what the Flask app itself would send.
   **Solution sketch:** the ECS task role's temporary credentials were
   used to `GetObject` a specific S3 key, but the call came from a public
   internet IP (`203.0.113.42`, not an AWS-internal ENI address) using the
   AWS CLI — not from the Flask app's own `requests` library, and not from
   inside the VPC. That mismatch (task-role identity + external source +
   non-app tooling) is exactly the pattern
   `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
   is built to catch: the credentials were stolen via the SSRF hole and
   replayed from the attacker's own machine.

2. **Why does Macie ask a different question than GuardDuty, and what
   does that mean for which one you'd check first after a breach vs.
   before one?**
   **Hint:** one answers "is something attacking me right now," the other
   answers "what sensitive data do I even have."
   **Solution sketch:** GuardDuty is the "is this happening" alarm — check
   it first *during* or right after a suspected incident, to see if
   there's an active signal. Macie is the "what do I have" inventory —
   run it *before* an incident, proactively, so you already know whether
   the bucket an attacker just reached actually contained anything
   sensitive, instead of finding out for the first time during the
   post-incident scramble.

3. **You scoped today's CloudTrail data-event selector to just the
   `app_data` bucket's ARN instead of "all S3 buckets, account-wide." Two
   other buckets get created next month. What's the tradeoff you just
   accepted, and how would you catch it?**
   **Hint:** think about what anti-pattern #9 says about scope vs. cost,
   and what would tell you a new bucket exists that isn't covered.
   **Solution sketch:** you accepted that data-plane activity on any
   future bucket is invisible to this trail until someone deliberately
   widens the event selector — a real gap if "we forgot to extend
   coverage" is how a future bucket goes unmonitored. The corrective
   isn't "scope everything from day one" (that reproduces anti-pattern #9
   — data events at account-wide scope get expensive fast); it's pairing
   the narrow-by-default trail with a Config rule or Security Hub check
   that flags any new bucket lacking a matching data-event selector, so
   the gap surfaces as a finding instead of staying silent.

4. **The free-trial clock:** GuardDuty, Security Hub, Macie, and Detective
   are all inside one 30-day trial that opened today. If you got busy and
   didn't run Day 9's teardown until 3 weeks later, roughly what would
   you be on the hook for, using this lab's actual footprint (one small
   S3 bucket, one DynamoDB table, one Fargate task's worth of CloudTrail/
   VPC Flow/DNS log volume)?
   **Hint:** GuardDuty bills per-GB of the log sources it analyzes
   (order of a few dollars per GB after the trial, with a generous free
   tier that a single small lab workload would likely still clear even
   post-trial at this volume) plus Security Hub's per-finding-ingested
   and per-check charges (fractions of a cent each, but they accumulate
   with every automated re-check) plus Macie's per-GB-scanned and
   per-bucket-monitored fees (roughly $0.10 per 10,000 S3 objects
   monitored per month, plus per-GB classification charges for any job
   you re-run) — check the current AWS pricing pages for this lab's region
   before treating any of these as exact.
   **Solution sketch:** at this lab's tiny data volume, 3 extra weeks past
   the trial is unlikely to be a shocking bill on its own — but it is
   real, recurring, and entirely avoidable money for zero extra teaching
   value, which is the actual point of anti-pattern #9: the risk isn't
   "one small lab left on a few weeks," it's that this is the single most
   common way learners (and production accounts) accumulate *several*
   forgotten always-on detection services across projects, at which point
   the sum stops being a rounding error. Track the clock in writing (a
   calendar reminder, a note in `journal.md`), not in memory.

## Anti-patterns today

- [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #4 — detection pushed off "until
  later." Today is the corrective in action: CloudTrail management events
  have actually been recording since Day 1 (they're on by default the
  moment any trail exists), so today's real exploit already has signal to
  land against, instead of a blank log.
- [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #9 — the free-trial clock. Today
  is the day this anti-pattern becomes live risk, not theory — see the
  callout at the top of this file and Exercise 4 above for real numbers.

## Cert corner (SCS-C02)

- **Threat Detection and Incident Response** — GuardDuty finding types
  and data sources, Security Hub finding aggregation, the sample-findings
  API as a legitimate testing mechanism, Detective's role in
  investigation (not alerting).
- **Security Logging and Monitoring** — CloudTrail management vs. data
  events, log file validation, trail scope decisions (data-event cost vs.
  coverage), Security Hub standards and the ASFF finding format.

## Teardown

**Today is the one exception to "destroy everything at end of day" — and
`labs/day08` itself has two different lifespans inside it, not one.**
GuardDuty, Security Hub, Macie, and Detective are the trial-window
services and come down at the **end of Day 9**. CloudTrail (and its log
bucket) is not part of that trial-window clock at all — it's free-tier
logging infrastructure, and the Day 11-12 capstone needs the same trail
that recorded today's incident — so it stays up through **Day 12**, well
past Day 9's teardown.

- [ ] **Leave `labs/day08` up.** Do **not** run `terraform destroy` in
      `labs/day08` today — nothing in this module comes down today.
- [ ] If you're stopping for the night, tear down only base's normal
      hourly-billing pieces per `labs/base/README.md`'s daily teardown
      (ALB, ECS service, CloudFront) — that's an ordinary nightly step,
      unrelated to today's detection services.
- [ ] Confirm nothing *else* day-specific is left running: today's module
      creates no ALB/ECS/CloudFront of its own, so there should be nothing
      hourly-billing beyond base's own pieces.
- [ ] **End of Day 9:** a **targeted** destroy of just the four trial-
      window services (GuardDuty, Security Hub, Macie, Detective) — see
      `labs/day08/README.md` and Day 9's own teardown checklist for the
      exact `-target` list. The CloudTrail trail and its log bucket are
      explicitly **not** included in that destroy.
- [ ] **End of Day 12:** the full, untargeted `terraform destroy` of
      `labs/day08` — this is the only point where the CloudTrail trail and
      its log bucket actually come down.
