# IR Runbook — Defend (Day 12 capstone)

**Authorized testing only.** This runbook is executed against the
learner's own AWS account and own Terraform-deployed workload
(`labs/base/` + day modules) only — see
[`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md)'s authorized-testing
statement. This is a *narrative* companion to
[`labs/day12/README.md`](../day12/README.md)'s executable checklist —
read this for the *why* and the order; run the commands from there.

This file is owned by Day 12. Day 11 owns every `attack*`-prefixed file
in this same directory — this runbook does not read, modify, or depend
on their exact contents beyond the shared incident description below
("Incident summary (as handed to the responder)").

## Incident summary (as handed to the responder)

> Alert: anomalous API activity from the ECS task role
> `aws-sec-lab-task-role`. Recent CloudTrail events show
> `s3:DeleteObject`, `s3:GetObject` outside the app's normal key
> pattern, and `dynamodb:Scan` against the app-data table, all
> attributed to an assumed-role session, occurring shortly after
> repeated requests to `/fetch?url=` carrying a link-local
> (`169.254.x.x`) target. GuardDuty/Security Hub findings from the
> Day 8–9/11 detection window correlate. A separate, low-privilege IAM
> user's access key shows recon-only API calls (`GetCallerIdentity`,
> `ListAllMyBuckets`) in the hours prior.

The responder's job: contain first, confirm the actual root cause
before declaring it fixed, eradicate that root cause (not a symptom),
recover service, and write the retro.

## Phase 1 — CONTAIN

**Goal:** stop new damage, immediately, without waiting for a full
root-cause understanding. Contain first; you can be wrong about scope
and still be right to contain.

1. **Kill the leaked identity.** Deactivate then delete the leaked
   IAM user's access key. This stops *that* identity from doing
   anything further — it does not address the stolen task-role
   credentials, which are a separate, already-issued grant.
2. **Break-glass the task role.** Attach a `Deny *` inline policy to
   the task role directly via the AWS CLI — not Terraform. This is
   the one place in this entire path where reaching for the CLI
   instead of `plan`/`apply` is the *correct* call: an incident in
   progress has no time for a review cycle, and the policy is
   explicitly temporary (removed in Phase 3, once the permanent fix
   replaces it). Accept the app going fully down as the cost of
   certainty that nothing more can happen through this role while you
   investigate.
3. **Optional: stop the compute.** If you don't trust the running
   process at all (not just its permissions), scale the ECS service to
   0. This is belt-and-suspenders on top of step 2, not a substitute
   for it — step 2 is what actually closes the permission door;
   scaling to 0 just stops the process from trying.

**Do not skip to eradication yet.** A common IR mistake is jumping
straight to "fix the policy" without first stopping the bleeding —
if root-cause analysis takes 20 minutes, that's 20 more minutes of
exposure with an un-contained credential.

## Phase 2 — ERADICATE

**Goal:** close the *actual* root cause — not the symptom, and not
just the specific action you happened to see in the logs.

Ask, explicitly, before writing any fix: **which door did the
attacker use, and is today's fix closing that door, or just this one
attack's specific footprint through it?** Here, the door is the task
role's identity policy (over-broad relative to what the app calls) —
closing only `s3:DeleteObject` because that's what you saw in
CloudTrail, while leaving `s3:GetObject`/`PutObject` bucket-wide and
`dynamodb:Scan` open, would be exactly this mistake: fixing the
footprint, not the door.

1. **Apply the Terraform in `labs/day12/`.** This adds (does not
   replace) an explicit-Deny policy on the existing task role: no
   bucket-wide delete, no read/write outside the app's real prefix, no
   table-wide `Scan`, and `Decrypt`/`GenerateDataKey` gated to calls
   arriving via a trusted AWS service (`kms:ViaService`), not direct
   calls with the raw credential.
2. **Apply the WAF rule.** Same module, same apply — a Web ACL on the
   ALB (not CloudFront-only; the ALB's public DNS name bypasses
   CloudFront, so the WAF has to sit at the shared chokepoint) blocking
   the metadata/credential-endpoint substrings in the `/fetch?url=`
   query parameter. This closes the entry point itself, not just the
   blast radius.
3. **Note what's out of scope for Terraform, and say so out loud:**
   the app's own code still has no URL allow-list. The WAF rule is a
   compensating control at the edge, not a substitute for fixing the
   `/fetch` handler to validate/allow-list destinations server-side.
   File that as a follow-up with the app owner; don't let "we added a
   WAF rule" read as "the SSRF is fixed" in the retro.
4. **Remove the break-glass policy** from Phase 1 now that the
   permanent fix is in place and verified (see Phase 4's blocked-signal
   checks) — leaving a `Deny *` in place forever is not recovery, it's
   a slower way of saying "still down."

## Phase 3 — RECOVER

**Goal:** restore the service, with the fix in place, and prove
nothing regressed.

1. Restore desired task count if you scaled to 0.
2. Force a new ECS deployment — bounds how long any task instance
   keeps running with pre-incident state in memory.
3. **Test both paths, not just one.** Confirm the legitimate allow
   path still works (`/whoami`, `/fetch` against a legitimate host,
   the app's own S3/DynamoDB calls within its real prefix) *and* the
   attack path is now denied (Phase 4). A fix that only ever gets
   tested on the deny side risks having quietly broken the app too —
   [Antipattern #3](../../content/ANTIPATTERNS.md#3-never-actually-testing-a-deny)
   cuts both ways.

## Phase 4 — verify: the attack, re-run, now blocked

This is the concrete signal this capstone requires — re-run the exact
Day 11 steps against the hardened workload and confirm each one now
fails the way it should.

**Credentials note before you start:** the stolen creds are STS
temporary credentials — an access key/secret pair alone isn't enough,
you need the session token too, or every call below fails on an
invalid-token error regardless of the Deny policy. There's no CLI
profile defined for this anywhere; reuse Day 11's own `attack.sh`
pattern and export all three in your shell:
```bash
export AWS_ACCESS_KEY_ID="<stolen AccessKeyId>"
export AWS_SECRET_ACCESS_KEY="<stolen SecretAccessKey>"
export AWS_SESSION_TOKEN="<stolen SessionToken>"
```

| Day 11 step | Re-run now | Expected |
|---|---|---|
| SSRF request for the credential endpoint | `curl .../fetch?url=http://169.254.170.2/v2/credentials/<GUID>` | HTTP `403` from WAF, before the app ever runs |
| `s3:DeleteObject` with stolen creds | `aws s3api delete-object ...` | `AccessDenied` — explicit deny |
| `s3:GetObject` outside the app's prefix | `aws s3api get-object ...` on a key outside `app-data/` | `AccessDenied` — explicit deny |
| `dynamodb:Scan` with stolen creds | `aws dynamodb scan ...` | `AccessDenied` — explicit deny |
| `kms:Decrypt` direct call with stolen creds | `aws kms decrypt ...` | `AccessDenied` — explicit deny (`kms:ViaService` condition) |
| `ec2:RunInstances --dry-run` (the crypto-mining pivot attempt) | re-run the same dry-run call from `attack-runbook.md` stage 6 | `UnauthorizedOperation` — **not** `AccessDenied`. EC2's dry-run convention is its own: `DryRunOperation` means the call would have succeeded, `UnauthorizedOperation` means the permission check failed — that's the correct post-fix signal here, regardless of whether your Day 11 `attack-SOLUTION.md` recorded `DryRunOperation` or `UnauthorizedOperation` for the pre-fix run. `DenyEc2ComputePivot` closes it either way |

Record every actual output in `defend-SOLUTION.md`, then
`unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`.

## Phase 5 — retro

Write the retro as five whys (see the content file's version for the
worked example), and answer, explicitly, in `journal.md`:

1. Which door did the attacker actually use? (identity policy on the
   task role — the door that grants, once the request-layer SSRF
   handed over valid credentials)
2. Which single earlier control would have prevented the *damage*,
   independent of whether the entry point is ever found? (Day 1's
   least-privilege task-role scoping — see the content file's
   Exercise 1)
3. Which control closes the *entry point* itself, and why can't a
   network-layer control do that job here? (the WAF rule; see
   Exercise 2)
4. Did any automated response (Day 9's EventBridge → Lambda) fire? (It
   didn't — and not because of the finding type. Day 9's own teardown
   checklist destroys that EventBridge rule and Lambda at the end of
   Day 9; the Days 11–12 capstone re-enables only the underlying
   GuardDuty/Security Hub services, not Day 9's automation on top of
   them. Name this as its own gap: response automation that only
   exists while its teaching day's lab is applied isn't a standing
   control.)
5. What's still open after today? (the app-code SSRF fix itself — file
   it, don't let a compensating control read as a completed fix)

## Then: run the six-domain self-assessment

Open `content/CERT-MAP.md` and run its self-scored checklist now, with
this incident fresh. Record your scores in `journal.md`.
