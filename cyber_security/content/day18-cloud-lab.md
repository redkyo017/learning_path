# Day 18 — Cloud Consolidation Lab

## Objectives

By the end of today you should be able to:

- Chain three separate Phase 3 skills — low-privilege IAM enumeration (Day
  14), SSRF-to-instance-credentials (Day 15), and CloudTrail-based detection
  (Day 16) — into one continuous attack path, and explain *why* each stage
  depends on the one before it succeeding.
- Say precisely what a cloud "flag" is when there's no CTF engine handing out
  `CTF{...}` strings: a **proof-of-access artifact** — something you can only
  read, or an API call that only succeeds, once you actually hold the right
  credentials or permissions, not a string you could type from memory.
- Identify, from read-only enumeration alone, exactly which single IAM
  permission (`iam:CreatePolicyVersion` on a policy attached to itself) turns
  "steal this role's temporary credentials" into "grant this role's
  credentials anything at all."
- Name the one field in a CloudTrail event (`sourceIPAddress`) that proves a
  role's temporary credentials were used somewhere other than the instance
  they were issued to — and the GuardDuty finding type built entirely around
  that same signal.
- State, for each of today's four stages, the single control that would have
  stopped it, without needing to look it up.

## 1. Concept — Why Chains Beat Any Single Bug

### This day teaches nothing new on purpose

Every other day in this path introduces a new attack class. Today doesn't —
it's a **consolidation lab**, the Phase 3 counterpart to Day 6's
fundamentals CTF and Day 12's web CTF. The purple-team spiral this whole path
follows (`STRATEGY.md`) predicts exactly this shape: knowledge compounds, and
periodically you prove it compounds by using several days' worth of separate
skills *together*, unaided, instead of one at a time with the day's own
lesson telling you which tool to reach for.

Today's chain, concretely:

- **Day 13** gave you IAM's mental model (principals, policies, policy
  evaluation) — assumed fluent here, not re-taught.
- **Day 14** gave you IAM enumeration as a low-privilege user, and the
  specific `iam:CreatePolicyVersion`-on-self privilege-escalation class —
  reused directly in Stage 1 and Stage 3 below.
- **Day 15** gave you the SSRF → `169.254.169.254` → stolen temporary
  credentials technique — reused directly in Stage 2.
- **Day 16** gave you CloudTrail/GuardDuty as the way to catch both of the
  above — reused directly in Stage 4.

If any one of those feels shaky, that's the actual signal to revisit that
day's content before continuing — today's lab is built assuming you can
execute each piece without a fresh tutorial.

### Why real breaches look like this, not like one CVE

A single misconfigured permission is rarely enough on its own to matter. What
turns a low-severity finding into a real incident is almost always a
**chain**: one weakness *reveals* a target, a second weakness *reaches* it,
and a third turns limited access into broader access. Today's scenario is a
small, honest model of that shape:

1. A low-privilege identity can **read** an IAM role's policy (not exploit
   it) — revealing that the role, if compromised, could escalate itself.
2. A completely unrelated bug — an SSRF-vulnerable app on an EC2 instance —
   is the actual way to *get* that role's credentials, with no connection to
   the IAM read at all except that enumeration told you which role was worth
   getting.
3. Once you hold those credentials, the escalation permission enumeration
   already found becomes directly usable.

None of steps 1–3 alone gets you anywhere near the final impact. Together,
they do. This is also exactly why Day 16-style detection has to correlate
across identities and API calls, not just alert on one suspicious-looking
call in isolation — Stage 4 below asks you to do precisely that correlation
by hand once, so you know what an automated version is actually checking for.

### What a cloud "flag" is, here

There's no game engine issuing tokens. Instead, each stage has a **proof-of-
access artifact** — something that is only readable, or only succeeds, once
you've actually done the stage's work:

- **Flag 1** — a private string in an S3 object, unreadable by the
  low-privilege enumeration identity, readable only once you hold the stolen
  role credentials from Stage 2.
- **Flag 2** — a specific API call (`iam:ListUsers`) that is denied under the
  role's *original* permissions and succeeds under its *escalated* ones —
  proof the Stage 3 escalation actually worked, not just that a command ran
  without erroring.

Both are real, live checks against your own AWS sandbox account — not
strings you could produce without doing the work.

## 2. Attack Lab — The Scenario

**Authorized use only:** every stage below runs against resources
`labs/day18/setup.sh` creates in **your own** AWS sandbox account. Never run
any of this against an account you don't own or don't have explicit written
authorization to test. Bring the lab up first — full mechanics in
[`labs/day18/README.md`](../labs/day18/README.md):

```sh
cd cyber_security/labs/day18
./setup.sh --profile <your-aws-profile> \
  --allowed-cidr "$(curl -s https://checkip.amazonaws.com)/32" \
  --region us-east-1
```

Work each stage yourself using the hints ladder below before opening
[`labs/day18/SOLUTION.md`](../labs/day18/SOLUTION.md), which has the exact
commands for all four stages, including the detection queries.

### Stage 1 — Enumerate as `day18-learner`

**Objective:** using only the low-privilege `day18-learner` credentials
`setup.sh` generated (`aws-credentials-day18.txt`), find the target EC2
instance and determine exactly which single IAM permission would let
*whoever holds the attached role's credentials* grant themselves more access
than the role currently has.

**Hints ladder:**
- **Nudge:** you have exactly two categories of permission as
  `day18-learner` — EC2 description and IAM read-only. Use both; the EC2 side
  tells you *what* to look at next, the IAM side tells you *why it matters*.
- **Bigger nudge:** an EC2 instance's `IamInstanceProfile` field names the
  instance profile attached to it — from there, one more read call gets you
  from "profile" to "role," and from "role" to "which policy is attached to
  it." Read that policy's actual JSON document, not just its name.
- **Answer:** the attached role's policy grants `s3:GetObject` on one
  specific object, and — separately — `iam:CreatePolicyVersion` (plus the
  read actions needed to use it) scoped to **the policy's own ARN**. That
  second grant is the finding: any principal holding this role's credentials
  can create a new default version of its own policy, and IAM will enforce
  whatever that new version says, including permissions nowhere in the
  original.

### Stage 2 — SSRF the target, steal the role's credentials

**Objective:** using the SSRF-vulnerable `/fetch?url=` endpoint on the EC2
instance's public IP (found in Stage 1), reach the instance metadata service
and obtain `day18-app-role`'s live temporary credentials — with no
credentials of your own beyond `curl` and the target's IP.

**Hints ladder:**
- **Nudge:** the endpoint takes a `url` query parameter and fetches it
  server-side, with no allowlist. What's the one IP address every EC2
  instance can reach that a random SSRF target usually can't — the same
  address Day 9's drill asked you to name?
- **Bigger nudge:** IMDS's credential path lists role names before it hands
  out any actual credentials — hit the metadata service's
  `iam/security-credentials/` path with no role name first to confirm which
  role is attached, exactly as Stage 1's enumeration already told you it
  should be, then append that role's name to the same path.
- **Answer:** `curl` the target's `/fetch?url=` endpoint with
  `url=http://169.254.169.254/latest/meta-data/iam/security-credentials/day18-app-role`
  — the response body is a JSON object with `AccessKeyId`, `SecretAccessKey`,
  and `Token`. Export all three as `AWS_ACCESS_KEY_ID` /
  `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` and you are now authenticated
  as `day18-app-role`, with zero requests ever sent to the instance's own
  SSH/shell. This works with a bare `GET` and no token because the instance
  was launched with IMDSv1 allowed (`HttpTokens=optional`) — IMDSv2 would
  have required a `PUT` step this app's `urlopen`-based fetch can't perform.
  **Proof of access (Flag 1):** with these credentials, the S3 object Stage
  1 found is now readable — it wasn't, and isn't, readable by
  `day18-learner`.

### Stage 3 — Escalate using the stolen credentials

**Objective:** using the stolen `day18-app-role` credentials from Stage 2,
turn Stage 1's finding into a real, provable escalation: grant those same
credentials a permission they did not start with, and prove it with a
before/after API call.

**Hints ladder:**
- **Nudge:** Stage 1 already named the exact IAM action you need
  (`iam:CreatePolicyVersion`) and the exact resource it's scoped to (the app
  policy's own ARN). You don't need to discover anything new here — you need
  to *use* what you already found, now that you hold credentials that can.
  Pick one clearly-absent permission first and confirm the denial, so your
  before/after is honest.
- **Bigger nudge:** `iam:CreatePolicyVersion` takes a full new policy
  document, not a diff — your new version has to restate everything you want
  to keep (the S3 read, the self-escalation grant itself, if you want to
  reuse this path again) plus whatever new permission you're adding, and be
  set as the default version.
- **Answer:** create a new default version of the app policy that adds an
  action the original never granted — `iam:ListUsers` is a clean, safe,
  clearly-attributable choice. Call `iam:ListUsers` once before (denied) and
  once after (succeeds) with the identical stolen credentials. **Proof of
  access (Flag 2):** the after-call succeeds and lists at least
  `day18-learner` — proof the same credentials now hold a permission that
  was nowhere in `day18-app-role`'s original policy.

### Stage 4 — Detect the whole chain

**Objective:** using only your own (account-owner) profile and AWS-native
telemetry — CloudTrail, no paid trail required — find both the enumeration
(Stage 1) and the credential theft (Stages 2–3) after the fact, and name the
single field that proves the theft, not just that some suspicious-looking API
call happened.

**Hints ladder:**
- **Nudge:** CloudTrail retains 90 days of management events for free with
  no trail configured at all — "Event History." You don't need Day 16's paid
  trail to do this stage; you need to know what to filter for and what to
  read once you find it.
- **Bigger nudge:** filter first by the `CreatePolicyVersion` event name to
  find Stage 3's escalation call directly, then look at that single event's
  full JSON, not just its name and timestamp. Two fields matter: who the
  caller claims to be (`userIdentity`), and where the call actually came
  from.
- **Answer:** the `CreatePolicyVersion` event's `userIdentity.arn` correctly
  shows an `assumed-role/day18-app-role/...` identity — that part looks
  completely legitimate on its own. The tell is `sourceIPAddress`: a role's
  temporary credentials being used from a source IP that isn't the instance
  they were issued to is, by itself, proof those credentials were exfiltrated
  and used elsewhere. This is exactly the signal GuardDuty's
  `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
  finding type automates for Stage 2's theft — name that finding type as your
  answer even if you don't have GuardDuty enabled to confirm it live. Stage
  3's escalation call maps to a second, distinct finding type worth naming
  too: `PrivilegeEscalation:IAMUser/AdministrativePermissions` — the same
  type Day 16 mapped Day 14's escalation to, since the underlying API call
  (`CreatePolicyVersion`, set as default, granting new permissions) is
  identical in shape.

## 3. Defense Lab — One Control per Stage, Named Precisely

Today doesn't re-verify a live before/after defense the way Day 4 did
(that would mean rebuilding the target with each fix applied and re-running
the whole chain — a full capstone-sized exercise Day 20–21 owns instead).
Today's job is narrower and just as important: **name the exact control that
breaks each stage, precisely**, reusing each control from the day that
introduced it rather than inventing a new one.

- **Stage 1 (enumeration):** least-privilege IAM policies. `day18-learner`'s
  read access to the role's policy JSON is itself normal and often
  necessary (auditors need it) — the actual fix isn't hiding the policy,
  it's making sure the policy it reveals isn't self-escalating in the first
  place (Stage 3's fix, below). Enumeration finding a real problem is a
  successful audit, not a bug to suppress.
- **Stage 2 (SSRF-to-creds):** **enforce IMDSv2** (`HttpTokens=required` at
  launch, or account-wide via an SCP/Config rule) — Day 15's core defense.
  This app's `/fetch?url=` bug would still exist, but a `GET`-only SSRF
  primitive cannot perform IMDSv2's required `PUT` token-request step, so the
  credential theft specifically stops here even though the underlying SSRF
  vulnerability doesn't.
- **Stage 3 (self-escalation):** never attach a policy to a role/user that
  grants `iam:CreatePolicyVersion` (or `iam:PutUserPolicy`,
  `iam:AttachUserPolicy`, `iam:CreatePolicyVersion` on itself, or the other
  Day 14 privesc actions) scoped to that same principal's own policy —
  least-privilege at authoring time, plus IAM Access Analyzer flagging
  exactly this pattern before it ships (Day 14's defense, unchanged here).
- **Stage 4 (detection):** already a detection, not a preventive control —
  its "fix" is making sure it's wired to fire automatically (the EventBridge
  → SNS pattern named in Stage 4 and built for real in Day 16) rather than
  relying on a human running `cloudtrail lookup-events` by hand after the
  fact, which is what today's manual walkthrough intentionally simulates.

## 4. Drills

The scenario above **is** the drill — there's no separate exercise set
today. These three questions are a self-check on what the chain actually
proved, not a new task:

### Drill 1 — Which single enumeration call was load-bearing?

Of everything `day18-learner` was allowed to call in Stage 1, which one
specific call is the one that made the rest of the chain worth pursuing at
all — i.e., without that one answer, would you have had any reason to target
`day18-app-role` specifically?

**Hint:** distinguish "found a target exists" from "found a target worth
escalating to."

**Solution sketch:** `iam:GetPolicyVersion` (via `iam:GetPolicy` to find the
default version ID first) on the app policy's document. `ec2:DescribeInstances`
told you a target *exists* and which role it uses; that alone is no more
interesting than any other EC2 instance. Reading the actual policy document
is what revealed the self-escalation grant — without it, Stage 2's stolen
credentials would just be "read one S3 object," with no reason to attempt
Stage 3 at all.

### Drill 2 — Why did the attacker never need `day18-learner`'s credentials again after Stage 2?

Once Stage 2 succeeds, `day18-learner`'s original access key is never used
again in Stages 3–4. Explain precisely why, in terms of what each identity
can and can't do.

**Hint:** compare what each identity's *own* policy grants, not what either
identity "feels like" it can do.

**Solution sketch:** `day18-learner`'s policy is deliberately enumeration-only
— no `s3:GetObject`, no `iam:CreatePolicyVersion`. Everything from Stage 2
onward requires permissions only `day18-app-role` has. The chain's whole
point is that the *enumeration* identity and the *escalation* identity are
different principals connected only by a stolen set of credentials in
between — exactly why Stage 4's detection has to correlate across two
separate identities' CloudTrail events (Stage 1's `day18-learner` calls,
Stage 3's `assumed-role/day18-app-role` calls) rather than watching only one.

### Drill 3 — What would Stage 4 have missed if you only checked `userIdentity.arn`?

Stage 4's answer hinges on `sourceIPAddress`, not `userIdentity.arn`. Explain
why checking only the identity field, without the source IP, would have
missed the theft entirely.

**Hint:** ask what a *legitimate* call from the actual EC2 instance using its
own role would look like in CloudTrail, field by field, compared to the
stolen-credential call.

**Solution sketch:** a completely legitimate API call made by the app
running on the actual EC2 instance, using its own instance role, produces the
exact same `userIdentity.arn`
(`assumed-role/day18-app-role/i-<instance-id>`) as the stolen-credential call
does — the identity field alone cannot distinguish "the instance itself,
doing its job" from "someone else, using the instance's stolen credentials."
Only `sourceIPAddress` (or, more generally, comparing where a role's traffic
should originate against where it actually did) carries the signal that
separates the two — which is exactly the field GuardDuty's
`InstanceCredentialExfiltration` finding type is built around, and precisely
why Day 16 teaches source-IP correlation as a first-class detection
technique rather than an afterthought.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of
that file:

- **What I attacked:** name which stage felt like genuinely new work versus
  which stage was "just" re-executing a command you'd already run on an
  earlier day — being honest about that split is the point of a
  consolidation day, not a gap to hide.
- **How:** walk through the one hint (per stage) you actually needed versus
  the ones you didn't — which stage's "answer" rung did you reach fastest,
  and which took the longest?
- **What defended it:** of the four stages, which control (least-privilege
  IAM, IMDSv2, never self-escalating policies, automated detection) do you
  think is most likely to already be missing in a real environment you've
  seen or worked with?
- **What confused me:** anything about why `userIdentity.arn` looks identical
  for a legitimate instance call and a stolen-credential call, or about why
  the escalation call needed a full policy document instead of a diff, that
  didn't click on first pass.
- **One thing to revisit:** pick one of the four chained skills (IAM
  enumeration, SSRF-to-IMDS, self-policy escalation, source-IP correlation)
  to re-explain from memory, without looking back at this file, before Day
  19.
