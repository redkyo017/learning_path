# Day 9 — Response automation

## Why this matters at work

Day 8 turned the lights on: CloudTrail, GuardDuty, Security Hub, and
Macie are all watching the workload, and at least two real findings are
sitting in the console right now — the leaked key → SSRF → stolen
task-role credential story generating `UnauthorizedAccess`-flavored
signal. A finding that just sits there is worth nothing. The gap
between "a finding exists" and "the compromised principal can no longer
do anything" is measured in minutes if it's automated and in days —
sometimes months — if a human has to notice the alert, understand it,
and manually type the fix at 2am. Today closes that gap with code:
[EventBridge rule](GLOSSARY.md#e) → Lambda → contained,
with an [AWS Config](#config-rules--conformance-packs) rule
and a built-in remediation doing the equivalent job for a public S3
bucket. This is also the day the detection stack you turned on
yesterday gets turned back **off** — the free-trial clock closes
tonight.

## The engine lens

Day 9 doesn't open a new door in the evaluation order
(`explicit Deny → SCP/RCP → resource-based policy → identity-based
policy → permission boundary → session policy`) — it automates code
that *writes to* two of the doors you already know, the two that sit
closest to "nothing gets through, no matter what else says yes":

- **Explicit Deny** — the revoke-active-sessions technique below is
  nothing but an explicit-deny statement, generated and attached by a
  Lambda function instead of typed by a human. It wins over every
  other `Allow` in the account for the same reason it always does:
  explicit deny is checked first and unconditionally.
- **Permission boundary** — quarantining a role by attaching a
  deny-all boundary doesn't touch a single line of that role's
  identity policy. It caps the *intersection* down to nothing. Same
  mechanism Day 2 taught, now driven by an `EventBridge Finding`
  instead of a Terraform apply.

The reason this matters beyond "cool automation demo": once you see
containment as "write to the Deny door or the boundary door,
programmatically, the instant a trigger fires," you can build the same
pattern against *any* finding source — GuardDuty today, but the same
Lambda shape works for a Config non-compliance event, an Access
Analyzer finding, or a custom detection you write yourself later.

## Core concepts

### The detective → corrective pattern

Every auto-remediation pipeline in AWS is the same four-stage shape:

```
DETECT              ROUTE                    ACT                    RECORD
(GuardDuty /     →   (EventBridge rule    →   (Lambda function   →   (tag the
 Config finding)      matches a pattern,       or SSM Automation      resource,
                      picks a target)          document runs)         log, notify)
```

Today wires two instances of it against the base workload:

1. **GuardDuty finding → EventBridge → Lambda.** GuardDuty has no
   built-in remediation of its own — every finding it emits is also
   published, automatically, to the account's default EventBridge
   event bus as a `source: "aws.guardduty"`, `detail-type: "GuardDuty
   Finding"` event. You write the rule that matches the findings you
   care about and the Lambda that acts on them. Nothing needs to
   change on the GuardDuty side — this pipeline is pure "route +
   act" bolted onto detection that's already running.
2. **Config non-compliance → built-in remediation.** [Config
   rule](GLOSSARY.md#c) is different: AWS Config lets you
   attach a `remediation_configuration` directly to a rule, pointing
   at an SSM Automation document, with `automatic = true`. No
   EventBridge rule required — Config's own "a resource just became
   non-compliant" trigger *is* the route step, wired in by Config
   itself. Same four-stage shape, one fewer piece of glue.

Both patterns end the same way: a corrective action ran, and something
observable changed. If you can't point to that observable change, you
built an alert, not a response — see Anti-patterns below.

### EventBridge rules on GuardDuty findings

An EventBridge rule is a pattern match against the event's JSON, not a
subscription to "everything GuardDuty says." The pattern that matters
most for a response pipeline is filtering by severity, because most
GuardDuty findings are Low/Medium noise you don't want paging anyone at
2am. GuardDuty's severity scale buckets as Low `0.1–3.9`, Medium
`4.0–6.9`, High `7.0–8.9`+ — so "only act automatically on High or
above" is a numeric-range content filter:

```json
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"],
  "detail": {
    "severity": [{ "numeric": [">=", 7] }]
  }
}
```

Route that to a Lambda target (or several targets — EventBridge rules
support multiple targets from one rule, e.g. the remediation Lambda
*and* a notification topic in parallel).

### The Lambda: what "auto-quarantine" actually does

For the specific incident this path is built around — a stolen
ECS task-role credential, used via the app's `/fetch?url=` SSRF to hit
the task credential endpoint — the finding's `detail.resource` carries
the compromised principal (an `AccessKey`/assumed-role identity, not an
EC2 instance ID, because this is a Fargate task, not EC2 IMDS). The
Lambda has exactly one job when that finding lands: make that principal
unable to do anything further, fast, and leave an audit trail proving
it happened. Two containment techniques, and they're not
interchangeable:

| Technique | Mechanism | Effect | Best for |
|---|---|---|---|
| **Deny-all permission boundary** | `iam:PutRolePermissionsBoundary` with a policy whose only statement is `Effect: Deny, Action: "*", Resource: "*"` | Blocks the role entirely — every existing *and* every future session, until someone removes the boundary | A single-purpose role (like this workload's ECS task role) where nothing legitimate is lost by a full lockout |
| **Revoke-active-sessions inline deny** | `iam:PutRolePolicy` with `Effect: Deny, Action: "*", Resource: "*"`, `Condition: {DateLessThan: {"aws:TokenIssueTime": "<now>"}}` | Denies only requests using credentials issued *before* the timestamp — the stolen session dies, but a fresh `AssumeRole` call issued after the timestamp still works | A role many legitimate callers share, where you must kill one leaked session without locking out everyone else |

Both are IAM writes evaluated live on every subsequent API call — there
is no token to "revoke" the way you'd revoke a JWT; the credential
itself stays valid until it expires on its own, but every request it
makes gets checked against whatever policy exists *right now*. That's
why either technique takes effect on the attacker's very next API call,
not just on future logins.

Today's lab does **both**, because the base workload's task role is
genuinely single-purpose (nothing else legitimately assumes it), so the
lab can demonstrate the full lockout *and* the surgical technique on
the same principal without one masking the other's effect.

**The Lambda's own permissions are the real risk here.** A
remediation function wired to fire automatically, with
`iam:PutRolePermissionsBoundary`/`iam:PutRolePolicy` rights, is one of
the most sensitive identities in the account — a bug or a
[wildcard grant](ANTIPATTERNS.md#6-iampassrole-and-wildcards-as-silent-privilege-escalation)
here doesn't just fail quietly, it can lock out (or worse, unlock)
anything in scope. The lab scopes the Lambda's execution role to
exactly one resource ARN — the base workload's task role — never
`iam:*` / `Resource: "*"`.

### Config rules + conformance packs

AWS Config continuously evaluates resource configuration against a
rule you define — "flag any S3 bucket that isn't private" is the
AWS-managed [Config rule](GLOSSARY.md#c) `S3_BUCKET_PUBLIC_READ_PROHIBITED`,
no custom code required. A [conformance pack](GLOSSARY.md#c)
is a bundle of Config rules (plus their remediations) deployed as one
unit — instead of hand-wiring forty individual rules for, say, the CIS
AWS Foundations Benchmark, you deploy one conformance pack and get all
forty at once. This path only wires one rule by hand today so the
mechanics are visible, but recognize the conformance pack as "this,
scaled" the moment you see one on the exam or at work.

Config's remediation is the part worth lingering on: `automatic = true`
on a `remediation_configuration` means Config itself invokes an SSM
Automation document the moment a resource goes non-compliant — no
Lambda, no EventBridge rule, nothing you wrote by hand executes the
fix. AWS ships a library of ready-made remediation documents
(`AWSConfigRemediation-*`) for exactly this kind of common
misconfiguration; today's lab uses
`AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock` to re-lock a
bucket the moment Config sees it's publicly readable.

### Quarantine patterns, the fuller picture

Identity quarantine (today's lab) is one slice of a broader taxonomy
worth knowing by name, even where this path doesn't build all of them:

- **Identity isolation** — permission boundary / session revocation
  (today).
- **Compute isolation** — pull a compromised ECS task out of its
  target group, or stop it outright, so it stops serving traffic
  without necessarily destroying forensic evidence on it (Day 12
  touches this in the IR runbook).
- **Network isolation** — swap a compromised resource's security group
  for a quarantine SG with no egress rules at all, cutting off C2/exfil
  while leaving the resource itself inspectable.

## Break → Harden lab

See `labs/day09/`. **The break** already happened on Day 8 and is
still live: the stolen task-role credential can still call AWS right
now. **The harden:** wire GuardDuty (High-severity findings) →
EventBridge → a Lambda that attaches a deny-all permission boundary
*and* a token-time-scoped revoke-sessions deny to the task role;
separately, wire a Config rule that flags a deliberately-public demo
bucket to an automatic SSM remediation. **Success signal:** an AWS CLI
call made with the (simulated) stolen credential succeeds before the
Lambda runs and returns `AccessDenied` after it runs; the demo bucket's
Config compliance flips `NON_COMPLIANT` → `COMPLIANT` and its public
access block is back on, with both transitions and the exact CLI output
recorded in `labs/day09/SOLUTION.md`.

## Exercises

1. Write the EventBridge event pattern that matches **only**
   High-or-above-severity GuardDuty findings (not Low/Medium).
   — **Hint:** GuardDuty severity is numeric; EventBridge supports a
   `numeric` content filter inside `detail`. — **Solution sketch:**
   ```json
   {
     "source": ["aws.guardduty"],
     "detail-type": ["GuardDuty Finding"],
     "detail": { "severity": [{ "numeric": [">=", 7] }] }
   }
   ```
   (`7` is the Medium/High boundary on GuardDuty's 0.1–8.9+ scale.)

2. Explain why attaching a deny-all **permission boundary** is a
   safer first response than editing or deleting the role's existing
   identity policy. — **Hint:** think about what's reversible with one
   API call versus what's destructive and easy to get subtly wrong. —
   **Solution sketch:** The boundary is additive and orthogonal to the
   identity policy — one `PutRolePermissionsBoundary` call locks
   everything down, one `DeleteRolePermissionsBoundary` call reverses
   it exactly, and the original identity policy (and the forensic value
   of reading it later) is never touched. Editing the identity policy
   directly risks losing statements you'll need to reconstruct during
   the investigation, and there's no single call that cleanly undoes
   an edit once it's applied.

3. The task role in this workload is single-purpose (only the ECS
   service assumes it). Describe a role where the **token-time revoke**
   technique would be clearly better than the deny-all boundary. —
   **Hint:** think about a role many different legitimate callers
   assume concurrently. — **Solution sketch:** A broadly shared
   federated human role (e.g. everyone on a team assumes
   `DeveloperRole` via IAM Identity Center). If one person's session
   leaks, a deny-all boundary locks out the whole team until someone
   removes it. A token-time deny keyed to the leak's approximate
   `TokenIssueTime` kills only sessions issued before that moment —
   the leaked one — while anyone re-authenticating afterward gets a
   working session immediately.

4. Sketch the Terraform for wiring a Config rule to an **automatic**
   SSM remediation, without writing any custom Lambda. — **Hint:**
   `aws_config_remediation_configuration`, `target_type =
   "SSM_DOCUMENT"`, `automatic = true`. — **Solution sketch:**
   ```hcl
   resource "aws_config_remediation_configuration" "fix" {
     config_rule_name = aws_config_config_rule.s3_public.name
     target_type      = "SSM_DOCUMENT"
     target_id        = "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"
     resource_type     = "AWS::S3::Bucket"
     automatic         = true
     maximum_automatic_attempts = 3
     retry_attempt_seconds      = 60

     parameter {
       name         = "AutomationAssumeRole"
       static_value = aws_iam_role.remediation.arn
     }
     parameter {
       name           = "BucketName"
       resource_value = "RESOURCE_ID"
     }
     parameter {
       name         = "RestrictPublicBuckets"
       static_value = "true"
     }
   }
   ```

## Anti-patterns today

- [#4 — Pushing detection off "until later"](ANTIPATTERNS.md#4-pushing-detection-off-until-later):
  today is the direct payoff of *not* having done that — the findings
  driving this lab exist because Day 8 didn't defer detection, and the
  automation built today only has something real to react to because
  of that choice.
- **Alert-without-action, with real numbers.** IBM's annual *Cost of a
  Data Breach* report has, across multiple years, put the mean time to
  *identify* a breach in the ~200-day range and mean time to *contain*
  it, once identified, at another ~70 days on top of that — months,
  for organizations that generate the alert but rely on a human to act
  on it. Separately, SOC-industry surveys routinely report that a
  meaningful share of daily alert volume at a typical security
  operations center is never triaged at all — analysts can't keep up
  with the queue. A Lambda wired to an EventBridge rule doesn't get
  tired, doesn't triage a backlog, and acts in seconds. The gap between
  "finding exists" and "finding acted on" is exactly the gap this day
  closes — an unwired GuardDuty finding sitting in a console tab is
  functionally the same as no detection at all until a human notices it.
- [#9 — Ignoring the free-trial clock](ANTIPATTERNS.md#9-ignoring-the-free-trial-clock--surprise-bills):
  tonight is the deadline this anti-pattern is named for. See Teardown.

## Cert corner (SCS-C02)

- **Domain 1 — Threat Detection and Incident Response:** EventBridge
  rules on GuardDuty findings routed to Lambda is the canonical
  automated-response pattern the exam expects you to recognize;
  know the shape (detect → route → act → record) cold.
- **Domain 6 — Management and Governance:** Config rules, conformance
  packs, and `remediation_configuration` with `automatic = true` are
  Config's own governance-as-code answer to the same detect-and-fix
  problem, independent of EventBridge.
- Expect exam questions that describe a symptom ("a finding exists but
  nothing happened") and ask you to pick the missing piece — usually
  either "no EventBridge rule routes it" or "the remediation isn't
  marked automatic."

## Teardown

**CRITICAL — this is the last day of the detection free-trial window.**
GuardDuty, Security Hub, Macie, and Detective were enabled ~Day 8
specifically inside a single 30-day free trial, and this path's budget
depends on them coming back off tonight, not "eventually." Work through
this checklist in order — don't skip straight to `terraform destroy`:

1. `cd labs/day09 && terraform destroy` — removes everything built
   today: the EventBridge rule/target, the quarantine Lambda + its log
   group, the deny-all boundary policy, the Config recorder/delivery
   channel/rule/remediation, the remediation automation role, and the
   throwaway public-bucket demo resource. None of this is part of the
   persistent base workload — full destroy is correct here, no
   `-target` needed.
2. **Disable GuardDuty, Security Hub, Macie, and Detective — WITHOUT
   touching CloudTrail.** Day 8's module (`labs/day08/`) contains both
   the detection services AND CloudTrail (`aws_cloudtrail.this` +
   its log bucket `aws_s3_bucket.trail_logs`). CloudTrail must stay up
   through Day 12 — it is not part of the trial window.

   > **⚠️ Do NOT run a bare `terraform destroy` in `labs/day08`.** That
   > would also destroy CloudTrail (and would error out on the
   > non-empty log bucket besides). Tear down only the detection
   > resources, by name, using `-target`:

   ```bash
   cd labs/day08
   terraform destroy \
     -target=aws_guardduty_detector.this \
     -target=aws_securityhub_standards_subscription.fsbp \
     -target=aws_securityhub_account.this \
     -target=aws_macie2_classification_job.app_data \
     -target=aws_macie2_account.this \
     -target=aws_detective_graph.this
   ```

   If Day 8 was not Terraform-managed (or the state is unavailable),
   use the direct CLI fallback instead — it's equally safe and touches
   nothing CloudTrail-related:
   ```bash
   aws guardduty list-detectors --query 'DetectorIds' --output text
   aws guardduty delete-detector --detector-id <id>

   aws securityhub disable-security-hub

   aws macie2 disable-macie

   aws detective list-graphs --query 'GraphList[].Arn' --output text
   aws detective delete-graph --graph-arn <arn>
   ```
3. **CloudTrail stays on.** It is not part of the trial window — it's
   the free logging foundation from Day 1 and keeps running,
   untouched, all the way through Day 12's final sweep. Confirm after
   step 2 that `labs/day08`'s `aws_cloudtrail.this` and
   `aws_s3_bucket.trail_logs` are both still present in
   `terraform state list` — if either is gone, something destroyed
   more than intended and CloudTrail needs to be re-created before you
   move on.
4. Confirm, before closing the session:
   - [ ] `terraform state list` in `labs/day09` is empty (or the state
         file is gone).
   - [ ] `aws guardduty list-detectors` returns an empty list.
   - [ ] `aws securityhub describe-hub` errors (Security Hub is not
         subscribed) rather than returning a hub ARN.
   - [ ] `aws macie2 get-macie-session` returns a disabled/not-found
         status.
   - [ ] `aws detective list-graphs` returns an empty list.
   - [ ] CloudTrail's trail is still logging (this one should stay
         **on** — confirm you didn't touch it).
   - [ ] `labs/base`'s persistent resources (KMS key, S3 bucket,
         DynamoDB table, secret) are untouched — this teardown never
         targets base.
