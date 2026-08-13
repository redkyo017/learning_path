# Day 16 — Cloud Detection & Response

## Objectives

By the end of today you should be able to:

- Name what each of **CloudTrail**, **GuardDuty**, **AWS Config**, and **EventBridge**
  actually records or does, precisely enough to say which one you'd reach for to answer
  a specific question ("who called this API," "is anything actively malicious happening
  right now," "has this resource's configuration drifted," "route this event
  somewhere").
- Write a CloudTrail/Athena query (and the equivalent `aws cloudtrail lookup-events`
  CLI form) that finds a specific IAM API call — the exact `CreatePolicyVersion` misuse
  pattern that is the escalation technique named in Day 14's substance — in raw
  CloudTrail history.
- Name the exact GuardDuty finding *type* that corresponds to stealing an EC2 instance
  role's temporary credentials via IMDS and using them from outside the instance — Day
  15's substance — and explain why the "outside AWS" and "inside AWS" variants of that
  finding are different findings, not the same one.
- Wire an EventBridge rule that turns a GuardDuty finding, or a specific CloudTrail API
  call, into an SNS notification — the minimum viable version of "someone gets paged."
- State, from memory and without re-deriving it, the free-tier/cost boundary on
  GuardDuty specifically, and why "detection tooling has an ongoing dollar cost that
  offense and pure IAM work mostly don't" is itself a fact worth knowing before you
  enable it in any account, lab or real.
- Design (not necessarily build end-to-end) one auto-remediation response to a
  privilege-escalation finding, and say honestly which part of your design is
  standard/proven practice versus your own reasoning under today's time box.

## 1. Concept — CloudTrail, GuardDuty, Config, and EventBridge as one detection stack

### The question each service answers

Four different AWS services show up in every cloud SOC, and the single most common
early confusion is treating them as interchangeable "logging" — they answer four
genuinely different questions, and knowing which one to reach for is the actual skill:

- **CloudTrail** answers *"what API call happened, when, and who made it?"* — it is a
  record of **control-plane actions**: every `CreatePolicyVersion`, every
  `AssumeRole`, every `GetObject` (if you turn on data events), each with a principal
  ARN, a source IP, a timestamp, and the full request/response JSON. CloudTrail does
  not judge whether an action was malicious — it is a complete, neutral audit log. It
  is the single source of truth for "prove this happened," and it is what a forensic
  timeline (Day 19) is built from in a cloud context.
- **GuardDuty** answers *"is something actively suspicious happening?"* — it is a
  managed **threat-detection** service that continuously analyzes CloudTrail
  management events, VPC Flow Logs, and DNS query logs (plus, if enabled, S3/EKS/RDS
  data-plane signals) against AWS's own threat intelligence and behavioral models, and
  emits **findings** — pre-classified, named, severity-scored alerts — instead of
  making you write the detection logic yourself. GuardDuty does not log raw events; it
  is a correlation and judgment layer sitting *on top of* CloudTrail (among other
  inputs).
- **AWS Config** answers *"what does this resource's configuration look like right now,
  and has it drifted from what we said was compliant?"* — it continuously records
  **resource state** (an IAM policy's current document, an S3 bucket's current public-
  access settings) as a time series of configuration snapshots, and **Config rules**
  evaluate that state against a condition (`iam-policy-no-statements-with-admin-access`,
  `s3-bucket-public-read-prohibited` are real, AWS-managed rule names) and flag
  **noncompliant** resources. This is the one genuinely different axis from the other
  three: Config doesn't care whether an *action* happened — it cares whether a
  *resource's current state* is bad, even if it's been sitting that way, unchanged, for
  three days with zero new API calls to explain it. Drill 4 below asks you to reason
  through exactly this case.
- **EventBridge** answers *"now that something interesting happened, where does it
  go?"* — it's the event bus that **routes** events (GuardDuty findings, and — this
  surprises people the first time — most CloudTrail-recorded API calls too, delivered
  automatically as "AWS API Call via CloudTrail" events on the default bus) to targets:
  an SNS topic (a human gets paged), a Lambda function (an automated response runs), a
  Step Functions workflow, another account's bus. EventBridge itself detects nothing —
  it is pure plumbing between "something happened" and "something should happen next."

### Detective vs. preventive controls

Today's whole day sits on one side of a distinction worth naming precisely: a
**preventive control** stops an attack from succeeding in the first place (a tight IAM
policy that never grants `CreatePolicyVersion` to a low-privileged user — Day 14's
defense; enforcing IMDSv2 — Day 15's defense). A **detective control** — everything in
today's stack — doesn't stop the attack; it notices it happened, ideally fast enough to
act. Both matter, and they fail independently: Day 14/15's defenses can (and should) be
in place *and* you still want detection, because a defense you got subtly wrong, or a
brand-new technique nobody's written a preventive control for yet, is exactly what a
detective control is there to catch when prevention fails. Neither substitutes for the
other.

This is the same purple-team habit Day 11 built, not a new one: attack something
(Day 2's port scan, Day 4's brute force, Day 8's injection), then write the detection
that catches it, then verify the detection actually fires. Day 11 did that loop against
host-based logs; today's CloudTrail/GuardDuty work is that identical habit — attack,
then detect, then verify — pointed at cloud telemetry instead of a syslog file. The
loop doesn't change; only the log source does.

### Mapping Day 14's escalation to CloudTrail + GuardDuty

Day 14's substance is a low-privileged IAM principal escalating via
`iam:CreatePolicyVersion` — creating a new version of a policy already attached to
itself (or another entity it controls) that grants far broader permissions than the
original, then setting that version as the policy's default (`--set-as-default`, or a
separate `SetDefaultPolicyVersion` call). This is one of a well-known, finite list of
IAM privilege-escalation paths (others include `iam:AttachUserPolicy`,
`iam:PutUserPolicy`, `iam:AddUserToGroup`, `iam:PassRole` combined with a privileged
service call) — the list matters here because GuardDuty's IAM-focused finding category
is explicitly built around watching for exactly these APIs being called by a principal
that didn't already have administrative permissions:

- **CloudTrail** records the raw fact: an `eventName: "CreatePolicyVersion"` (or
  `SetDefaultPolicyVersion`) entry, with the calling principal's ARN, the target policy
  ARN, and — critically for later drills — the new policy document itself, in the
  request parameters.
- **GuardDuty**'s finding type **`PrivilegeEscalation:IAMUser/AdministrativePermissions`**
  is the one built for exactly this pattern: it fires when an IAM entity that did not
  previously hold administrative permissions invokes one of the known privilege-
  escalation-enabling APIs. This is the finding this lab's Drill 2-adjacent work (and
  Section 2's replay) targets — naming it precisely here so you recognize it rather
  than guessing at a plausible-sounding finding name later.

### Mapping Day 15's IMDS credential theft to GuardDuty

Day 15's substance is SSRF reaching `169.254.169.254`, retrieving an EC2 instance
role's temporary credentials from the metadata service, and using those credentials —
the whole point of the attack — from somewhere the instance itself isn't. GuardDuty has
two distinct finding types for this, and the distinction between them is a real signal,
not a technicality:

- **`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`** — the
  stolen instance credentials were used from an IP address **outside the AWS network
  entirely** (the attacker's own machine, a VPS, home network). This is the classic
  "SSRF, steal the token, `curl` it back to my laptop, run AWS CLI from there" pattern —
  what Day 15's attack actually does end to end.
- **`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS`** — the same
  stolen credentials, but used from **within AWS's network** — a different EC2
  instance, or even a different AWS account. This variant matters because "the call
  came from an AWS IP" is *not* the same fact as "the call came from *this* instance" —
  an attacker who exfiltrates creds to their *own* AWS account and calls from there
  still trips this finding, not the OutsideAWS one, and conflating the two in an
  incident writeup would misdescribe where the attacker actually was.

Drill 2 asks you to reason through which variant a specific scenario produces — the
answer depends on where the *use* of the stolen credentials happened, not where the
*theft* happened.

## 2. Lab — Enable Telemetry, Replay Both Attacks, Detect Both, Wire an Alert

**Authorized use only, your own sandbox account.** Every command and script below
targets **your own AWS sandbox account and a named CLI profile you control** —
`setup.sh` refuses to run without an explicit `--profile` argument and never reads or
writes credentials itself. Never point any of this at a shared, production, or
employer-owned account.

**A scope note, stated plainly:** whether or not you've already built and run Day
14/15's own labs, `setup.sh` below stages a small, self-contained reproduction of each
attack's *signature API call* — the `CreatePolicyVersion` escalation and (via
GuardDuty's own sample-findings mechanism, not a live EC2 exploit) the IMDS-credential-
exfiltration pattern — so that today's detection queries work against a freshly
bootstrapped sandbox on their own. If Day 14/15's resources are *also* still live in
your account, the exact same CloudTrail/GuardDuty queries below find those real events
too; today's lab doesn't require them to still exist.

**Full setup/teardown detail:** [`labs/day16/README.md`](../labs/day16/README.md).
**Cost note up front, repeated because it matters:** CloudTrail's first trail and IAM
API calls are effectively free at this scale; **GuardDuty is not** — read the boxed
warning in that README before running anything.

### Step 1 — Enable the telemetry (`setup.sh`)

```sh
cd cyber_security/labs/day16
./setup.sh --profile my-sandbox-profile --region us-east-1 --email you@example.com
```

`setup.sh` (read it before running it — it's short and every AWS call is inline, no
hidden includes):

1. Refuses to proceed without `--profile`; never accepts or embeds a credential itself.
2. Prints the GuardDuty cost/free-trial warning and requires you to type `yes` to
   continue (or pass `--yes` non-interactively, once you've actually read the warning).
3. Creates a private S3 bucket + bucket policy for CloudTrail log delivery, then a
   single-region CloudTrail trail writing management events to it.
4. Enables (or reuses, if already enabled) a GuardDuty detector in the target region.
5. Creates a minimal, disposable IAM user + policy (`day16-lab-user` /
   `day16-lab-policy`) whose only purpose is to be the principal that performs the
   `CreatePolicyVersion` replay in Step 2 — self-contained, so this lab doesn't need
   Day 14's own lab user to still exist.
6. Creates an SNS topic and subscribes the `--email` address you passed (you'll get a
   subscription-confirmation email from AWS — confirm it, or the topic won't deliver).
7. Creates two EventBridge rules targeting that SNS topic (Step 4 below).
8. Writes every resource ID it created to `.day16-state.env` — `teardown.sh` reads this
   file to know exactly what to remove; **don't delete it before running teardown.**

### Step 2 — Replay Day 14's escalation (real CloudTrail event)

```sh
POLICY_ARN=$(grep LAB_POLICY_ARN .day16-state.env | cut -d= -f2)
aws --profile my-sandbox-profile iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}' \
  --set-as-default
```

**What this produces:** one real `CreatePolicyVersion` CloudTrail event, with
`requestParameters.policyDocument` containing the `"Action":"*","Resource":"*"`
statement — the exact escalation shape Day 14 names (a policy version granting
administrative permissions, set as the default, by a principal that didn't already
have them). This is a genuine API call against your own sandbox account, not a
simulation — which is why `setup.sh` used a disposable, lab-only policy for it rather
than touching anything else in your account.

### Step 3 — Replay Day 15's IMDS credential theft (GuardDuty sample finding)

Standing up a real EC2 instance, SSRF-ing it, and exfiltrating its role credentials
purely to trigger a GuardDuty finding is expensive, slow (GuardDuty's real-world
detection latency is minutes, not instant), and unnecessary — GuardDuty ships an
official mechanism for exactly this: generating one real, fully-formed sample finding
of any type, indistinguishable in the console/API from a genuine detection, without any
attack actually occurring:

```sh
DETECTOR_ID=$(grep DETECTOR_ID .day16-state.env | cut -d= -f2)
aws --profile my-sandbox-profile guardduty create-sample-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-types \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS" \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS" \
    "PrivilegeEscalation:IAMUser/AdministrativePermissions"
```

**What this produces:** three findings in GuardDuty, tagged `sample: true` in their
finding detail (so they're clearly distinguishable from a real detection if you ever
need to filter them back out), covering both IMDS-theft variants named in Section 1 and
the privilege-escalation finding type that would also fire for Step 2's real
`CreatePolicyVersion` call once GuardDuty's own correlation catches up to it.

### Step 4 — Find both in CloudTrail and GuardDuty

**CloudTrail, quick path (CLI, works immediately, last 90 days):**

```sh
aws --profile my-sandbox-profile cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreatePolicyVersion \
  --max-results 5
```

**CloudTrail, Athena path (the query this day's Drill 1 asks you to produce yourself —
solution in [`labs/day16/SOLUTION.md`](../labs/day16/SOLUTION.md)):** once your trail's
logs have landed in S3 and you've pointed an Athena table at them (setup detail in the
lab README), the same lookup as SQL, plus the extra reach Athena gives you that
`lookup-events` doesn't (joining across users, aggregating counts, or an `alg :=` search
in the request body):

```sql
SELECT eventtime, useridentity.arn, requestparameters
FROM cloudtrail_logs
WHERE eventname = 'CreatePolicyVersion'
  AND eventtime > '2026-08-01T00:00:00Z'
ORDER BY eventtime DESC;
```

**GuardDuty findings:**

```sh
aws --profile my-sandbox-profile guardduty list-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"type":{"Eq":["PrivilegeEscalation:IAMUser/AdministrativePermissions","UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS","UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS"]}}}'
```

Then `get-findings` with the returned IDs to see full finding detail, including the
`sample: true` flag on Step 3's synthetic ones.

### Step 5 — Wire EventBridge → SNS

`setup.sh` already created these two rules; here's what they actually contain, so
you're not treating them as a black box:

**Rule 1 — any GuardDuty finding:**

```json
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"]
}
```

**Rule 2 — specifically a `CreatePolicyVersion` call, via CloudTrail's automatic
delivery of API-call events to the default EventBridge bus** (no CloudWatch Logs
subscription filter needed — this is a built-in EventBridge source, not something you
have to plumb yourself):

```json
{
  "source": ["aws.iam"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": { "eventName": ["CreatePolicyVersion", "SetDefaultPolicyVersion"] }
}
```

Both rules target the SNS topic from Step 1. **Verify:** re-run Step 2's
`create-policy-version` call once more (a second policy version, same principal) and
confirm an email arrives within a few minutes — EventBridge/SNS delivery isn't
instantaneous, and "no email yet" at the 30-second mark is not yet a failure.

## 3. Defense / Response — From Alert to Action

### Fidelity vs. noise, revisited for the cloud

Day 11 named this for host-based detection; it applies identically here, and Drill 5
below asks you to work through a concrete instance of it. Rule 2 above (any
`CreatePolicyVersion`/`SetDefaultPolicyVersion` call, from anyone) is deliberately
broad-brush for this lab — in a real account with a CI/CD pipeline that manages IAM
policies as part of normal deploys, that exact rule would page someone every single
deploy, and a detection that pages on routine, expected activity trains the humans
receiving it to ignore it — the single worst outcome for any detective control. A
production version of Rule 2 narrows the `detail` match to exclude a known-good
principal (a specific CI role ARN) via a `detail.userIdentity.arn` condition, or —
better — asks a different question entirely: not "did this API get called" but "did
this API get called by a principal that *doesn't already have* administrative
permissions," which is exactly the extra correlation GuardDuty's finding already does
for you and a raw EventBridge/CloudTrail rule cannot, on its own, replicate.

### Auto-remediation: designing one response, honestly scoped

A **detective control** that only emails a human is still fully manual response.
**Auto-remediation** closes the loop: the EventBridge rule's target is a **Lambda
function**, not (or not only) SNS, and that function takes an automatic, reversible-if-
wrong containment action the moment the finding fires. One concrete design for today's
exact finding (`PrivilegeEscalation:IAMUser/AdministrativePermissions`), stated as a
design — this lab does not build and deploy this Lambda, and says so plainly rather
than implying it does:

1. **Trigger:** the same EventBridge rule pattern as Rule 1 above, filtered to this one
   finding type, targeting a Lambda instead of (or in addition to) the SNS topic.
2. **First action — contain, don't yet delete:** the Lambda reads the finding's
   `resource.accessKeyDetails` / the offending principal's ARN from the event detail,
   and calls `iam:DeletePolicyVersion` on the *specific version* the finding names (not
   the whole policy — the original, pre-escalation version stays intact), rolling back
   the privilege grant within seconds of detection rather than waiting for a human to
   read an email.
3. **Second action — evidence before further action:** before doing anything more
   aggressive (deactivating the principal's access keys, attaching an explicit deny),
   the Lambda writes the full finding JSON plus the deleted policy version's document to
   a dedicated, access-restricted S3 bucket — preserving exactly what Day 19's chain-of-
   custody concept demands, before any state changes further.
4. **Notify regardless:** the same SNS publish as the manual path, now carrying "auto-
   remediated: policy version rolled back" instead of just "alert fired" — a human still
   needs to know it happened, investigate *why* that principal had `CreatePolicyVersion`
   in the first place, and decide whether the account itself needs deactivating.
5. **What this design deliberately leaves out, on purpose:** auto-*disabling* the
   principal's credentials as a first action, rather than second, was considered and
   rejected here — rolling back the escalation itself is the smaller, safer,
   near-zero-blast-radius action; disabling a principal's access automatically on a
   single finding (which could, rarely, be a false positive) is a larger, harder-to-
   instantly-reverse action better left as a human's second step once they've seen the
   evidence in step 3. Naming this trade-off explicitly is the actual point of a design
   review, not just listing steps.

### Config as the complementary, state-based layer

Everything above is **event-triggered** — something has to *happen* for CloudTrail,
GuardDuty, or an EventBridge rule to notice it. A Config rule
(`iam-policy-no-statements-with-admin-access`) evaluates continuously against current
*state*, which is precisely the gap Drill 4 below asks you to reason through: a policy
that already grants `Action:"*"` before today's detection stack ever existed, with no
new API call to trigger anything, is invisible to Rules 1/2 above and *only* caught by
a Config rule's periodic (or configuration-change-triggered) re-evaluation.

### What's genuinely out of today's scope, named rather than glossed over

- **Security Hub** — aggregates GuardDuty/Config/Inspector findings across accounts
  into one dashboard with a standardized finding format; not stood up today, one line
  each way to add once GuardDuty/Config are already running.
- **Multi-account detection (AWS Organizations)** — a delegated GuardDuty administrator
  account seeing findings across every member account; today's lab is single-account by
  design (Global Constraints: free-tier-friendly, minimal blast radius).
- **A real, deployed remediation Lambda** — Section 3's auto-remediation is a design,
  not shipped code; building and testing it safely is exactly the kind of follow-on work
  the **Cloud IR & detection engineering at scale** extension module (see
  [`ROADMAP.md`](../ROADMAP.md)) is for.

## 4. Drills

Attempt each drill yourself before reading its solution sketch. Full worked answers
(including the exact Athena query and CLI form) are also in
[`labs/day16/SOLUTION.md`](../labs/day16/SOLUTION.md).

### Drill 1 — The CloudTrail/Athena query that catches `CreatePolicyVersion` abuse

Write the query (Athena SQL, or the equivalent `aws cloudtrail lookup-events` CLI
invocation) that finds every `CreatePolicyVersion` call in your trail's history, and
say what one extra field in the output tells you whether that specific call was the
*escalating* kind (grants broad new permissions) versus a routine, narrow policy
update.

**Hint:** the event name alone doesn't distinguish "made a policy slightly narrower" from
"granted `Action:"*"` " — where in the event does the actual new policy content live?

**Solution sketch:**

```sql
SELECT eventtime, useridentity.arn AS caller, requestparameters
FROM cloudtrail_logs
WHERE eventname = 'CreatePolicyVersion'
ORDER BY eventtime DESC;
```

CLI equivalent: `aws cloudtrail lookup-events --lookup-attributes
AttributeKey=EventName,AttributeValue=CreatePolicyVersion`. The event name matches
*every* `CreatePolicyVersion` call, escalating or not — the field that tells you which
kind happened is `requestparameters.policyDocument` (Athena) /
`CloudTrailEvent.requestParameters.policyDocument` (CLI JSON): read the actual new
policy's `Statement` list and check whether any statement grants a broad `Action`
(`"*"`, or a wildcard like `"iam:*"`) with `Resource: "*"` — that's the substantive
signal, not the event name.

### Drill 2 — Which GuardDuty finding maps to Day 15's IMDS cred theft

Two AWS accounts belong to the same organization, both yours (a lab and a "prod" you
also control). An attacker SSRFs a box in the *lab* account, steals its instance role's
IMDS credentials, and then calls `s3:ListBuckets` with those stolen credentials **from
an EC2 instance sitting in the "prod" account**. Which exact GuardDuty finding type
fires, and specifically why is it not the other IMDS-exfiltration variant?

**Hint:** the finding name distinguishes based on *where the stolen credentials were
used*, not where they were *stolen from* — re-read Section 1's two finding types with
that distinction in mind.

**Solution sketch:**
`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS` fires, not
`.OutsideAWS`. The theft happened via SSRF against the lab account's instance — that
part matches Day 15 exactly — but the *use* of those stolen credentials came from
another EC2 instance, inside AWS's own network (even though it's a different AWS
account than the one the credentials belong to). `.OutsideAWS` is specifically for use
from an IP address outside AWS's network entirely (an attacker's laptop, a home
connection, a non-AWS VPS) — which is what Day 15's own attack chain does, but is not
what this drill describes.

### Drill 3 — Design an auto-response

For the `PrivilegeEscalation:IAMUser/AdministrativePermissions` finding, name the single
first automated action you'd have a Lambda take, and justify why you picked that action
over the more aggressive alternative of immediately deactivating the offending
principal's credentials.

**Hint:** think about blast radius and reversibility — which of "roll back the specific
policy version" and "disable the whole principal" is smaller, safer, and easier to undo
if the finding turns out to be a false positive?

**Solution sketch:** call `iam:DeletePolicyVersion` on the exact version ID the finding
identifies as the escalating one (leaving the pre-escalation default version intact),
not a blanket disable of the principal. This is the smaller, more reversible action: if
the finding is somehow a false positive, rolling back a policy version that was
legitimately needed is a quick, low-drama fix (re-create the version); disabling a
principal's access keys or deactivating a user automatically, on a single automated
trigger, risks breaking a legitimate workflow (a CI pipeline, a scheduled job) with a
much larger, harder-to-quickly-undo blast radius. The more aggressive action belongs to
a human's next step once they've reviewed the evidence (Section 3's step 3), not to the
first automated response.

### Drill 4 — CloudTrail/GuardDuty vs. Config: the case with no new API call

An S3 bucket has been publicly readable for the past three days. No `PutBucketPolicy`,
`PutBucketAcl`, or any other API call touching that bucket has happened in that window
— it was misconfigured once, long ago, and nothing about it has changed since.
CloudTrail and GuardDuty are both fully enabled and healthy. Will either of them alert
on this bucket today? What will?

**Hint:** re-read Section 1's description of what makes AWS Config's detection model
different from the other three services — what does it evaluate against, that doesn't
require anything to *happen*?

**Solution sketch:** no — CloudTrail has nothing to log (no new API call occurred to
record), and GuardDuty's relevant signals are triggered by *activity* (anomalous access
patterns, threat-intel-matched calls), not by a static configuration sitting unchanged.
Neither is watching *state* the way this scenario needs. An AWS Config rule
(`s3-bucket-public-read-prohibited`) is what catches this: Config continuously records
the bucket's actual current configuration and re-evaluates that rule against it on a
periodic or configuration-change-triggered basis, flagging the bucket as
**noncompliant** regardless of whether anything happened today, yesterday, or three
days ago — exactly the event-vs-state distinction Section 1 names.

### Drill 5 — Tune out a false positive

Section 3 notes that Rule 2 (any `CreatePolicyVersion`/`SetDefaultPolicyVersion` call,
from anyone) would page someone on every routine CI/CD deploy in a real account with an
automated IAM-policy pipeline. Rewrite the rule's `detail` block to stop matching a
known CI role, `arn:aws:iam::111122223333:role/ci-deploy-role`, while still matching
every other principal.

**Hint:** EventBridge event patterns support an "anything-but" style exclusion —
you don't need to enumerate every *other* legitimate principal, only exclude the one
you already know is expected.

**Solution sketch:**

```json
{
  "source": ["aws.iam"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["CreatePolicyVersion", "SetDefaultPolicyVersion"],
    "userIdentity": {
      "arn": [{ "anything-but": "arn:aws:iam::111122223333:role/ci-deploy-role" }]
    }
  }
}
```

This keeps the rule broad (still catches *any* other principal calling either API) while
suppressing the one specific, already-verified-legitimate source of noise — the
narrower, more correct fix Section 3 points at (asking "does this principal already have
admin permissions" via GuardDuty's own correlation) is the better long-term answer, but
this drill's exclusion is the minimal, immediate fix to a concrete, named false
positive, which is the more common real-world first move.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name specifically which API call you replayed
  (`CreatePolicyVersion`) versus which finding types you generated via GuardDuty's
  sample-findings mechanism rather than a live exploit — being precise about which was
  a real event you caused versus a synthetic one, the same honesty habit earlier days
  established.
- **How:** walk through where you actually found the `CreatePolicyVersion` event —
  `lookup-events` or Athena — and whether the EventBridge → SNS alert actually reached
  your inbox, and how long it took.
- **What defended it:** you didn't apply a preventive fix today (that's Day 14's role) —
  instead, name the *detective* control you stood up, and which one auto-remediation
  design choice from Section 3 you'd actually build first if this were a real account.
- **What confused me:** anything about *why* GuardDuty has two separate finding types
  for what feels like "the same" credential theft, or about the event-vs-state
  distinction between CloudTrail/GuardDuty and Config (Drill 4), that didn't click on
  first pass.
- **One thing to revisit:** pick one term from today (CloudTrail, GuardDuty, AWS
  Config, EventBridge, detective control, auto-remediation) to re-explain from memory
  before Day 17, without looking back at this file.

**Before you close this out:** if you ran `setup.sh` against a real account, run
`teardown.sh` now — see [`labs/day16/README.md`](../labs/day16/README.md)'s teardown
section and its explicit GuardDuty cost/free-trial warning. GuardDuty billing continues
accruing for as long as the detector stays enabled, independent of whether you're
actively using this lab.
