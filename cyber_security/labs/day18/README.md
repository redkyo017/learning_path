# Day 18 Lab — Cloud Consolidation: Enumerate → Escalate via SSRF → Detect

## Authorized use only

**This lab creates real resources in YOUR OWN AWS sandbox account.** Every
command below — `setup.sh`, the enumeration calls, the SSRF request, the
stolen-credential calls, `teardown.sh` — must run only against an AWS account
you own or have explicit written authorization to test. Never point any part
of this lab at a shared, production, or employer-owned account. If you're
unsure whether your account qualifies as an authorized sandbox, stop and
confirm before running `setup.sh`.

## What this lab is

A single scenario chaining three skills from earlier in Phase 3 into one
attack path, then detecting the whole thing:

1. **Enumerate** as a deliberately low-privilege IAM user (`day18-learner`) —
   the same read-only enumeration discipline from Day 14 — to find an EC2
   target and read (without yet being able to exploit) the IAM policy
   attached to its instance role.
2. **Exploit an SSRF bug** in a small app running on that EC2 instance to
   reach `169.254.169.254` (the instance metadata service) and steal the
   instance role's temporary credentials — Day 15's technique, reused instead
   of re-taught.
3. **Escalate** using those stolen credentials: the role's own policy grants
   it `iam:CreatePolicyVersion` on itself — a real AWS privilege-escalation
   class — so the stolen creds can grant themselves more than the role
   started with.
4. **Detect** the whole chain in AWS-native telemetry — CloudTrail's free
   90-day Event History, no paid trail required — by spotting the one
   anomaly that gives credential theft away: API calls made with the
   instance role's credentials from a source IP that isn't the instance.

There is no `CTF{...}` string waiting at the end. Per the plan this lab is
built from: **cloud "flags" are proof-of-access artifacts** — a private S3
object you can only read once you hold the right credentials, and a
previously-denied API call that starts succeeding once you've escalated. Both
are staged for you by `setup.sh`; the point is reproducing *how* you reach
each one, not typing a magic string.

Full stage-by-stage instructions, objectives, and a hints ladder (nudge →
bigger nudge → answer) live in
[`content/day18-cloud-lab.md`](../../content/day18-cloud-lab.md). This README
covers only setup/verify/teardown mechanics. The complete command-by-command
walkthrough, including the detection queries, is
[`SOLUTION.md`](SOLUTION.md) — try each stage yourself first.

## Prerequisites

- Your own AWS sandbox account, and the AWS CLI v2 configured with a **named
  profile** pointing at it (never a default/shared profile — this path never
  hardcodes or assumes credentials).
- `jq` installed (used by `setup.sh` to parse the generated access key).
- Permission on that profile to create IAM users/roles/policies, EC2
  instances/security groups, and S3 buckets — a personal sandbox account's
  admin/root user has this by default.
- Days 13–17 concepts (IAM foundations, IAM privesc, IMDS/SSRF-to-cloud, cloud
  detection, cloud networking) — this lab reinforces them, it doesn't
  re-teach them from scratch.

## Cost and teardown reminder

| Resource | Free-tier status | If exhausted |
|---|---|---|
| 1x EC2 `t3.micro` | 750 hrs/month free, new accounts, first 12 months | ~$0.01/hr in most US regions |
| 1x S3 bucket, 1 tiny object | Effectively free at this scale | Negligible (fractions of a cent) |
| IAM users/roles/policies | Always free | N/A |
| CloudTrail Event History (Stage 4) | Free — no trail is created | N/A |
| GuardDuty | **Not created by this lab.** If you still have Day 16's GuardDuty trial active, using it for Stage 4 is optional and free during that trial; do not enable a fresh detector just for this lab. | 30-day trial, then hourly cost |

**Run `./teardown.sh` as soon as you finish Stage 4.** The EC2 instance is
the only resource here that costs money by the hour — nothing else accrues
cost while it's running, but there's no reason to leave any of it up longer
than one sitting.

## Setup

```sh
cd cyber_security/labs/day18
./setup.sh --profile <your-aws-profile> \
  --allowed-cidr "$(curl -s https://checkip.amazonaws.com)/32" \
  --region us-east-1
```

`--allowed-cidr` scopes the SSRF target's security group to only your own IP
— `setup.sh` refuses `0.0.0.0/0` outright. This is deliberate: Day 17 covers
exactly why an internet-facing SSRF target would be its own separate bug, and
this lab practices that lesson instead of contradicting it.

`setup.sh` is idempotent-guarded, not idempotent — if a previous run's state
file (`.day18-state.env`) already exists, it refuses to run again until you
either run `./teardown.sh` or confirm by hand that everything is already gone
and delete the state file yourself.

**What it prints at the end** (also saved in `.day18-state.env`, read
automatically by `teardown.sh`):

- The target instance's public IP (Stage 2's SSRF target).
- The `day18-app-role` and `day18-app-policy` ARNs (what Stage 1's
  enumeration should independently discover — use these only to check your
  own answer, not as a shortcut).
- Where Flag 1 lives in S3.
- Where `day18-learner`'s freshly-generated access key was saved:
  `aws-credentials-day18.txt` (matches this repo's `aws-credentials*`
  `.gitignore` pattern — never commit it). No key material is ever hardcoded
  in `setup.sh` itself; the key is generated live by `aws iam
  create-access-key` at setup time.

Load the learner credentials into your shell (values come from the file
`setup.sh` just wrote — nothing here is a real value):

```sh
export AWS_ACCESS_KEY_ID=$(grep AWS_ACCESS_KEY_ID aws-credentials-day18.txt | cut -d= -f2)
export AWS_SECRET_ACCESS_KEY=$(grep AWS_SECRET_ACCESS_KEY aws-credentials-day18.txt | cut -d= -f2)
aws sts get-caller-identity   # should show day18-learner, not your own profile
```

## Verify the lab is up

```sh
aws --profile <your-aws-profile> --region us-east-1 \
  ec2 describe-instances --instance-ids "$(grep INSTANCE_ID .day18-state.env | cut -d= -f2)" \
  --query 'Reservations[0].Instances[0].State.Name' --output text
```

Expected: `running`. If it prints anything else, wait a few seconds and
re-run — `setup.sh` already waits for `running` before it prints its summary,
so this should only be a race if you ran it immediately after.

## Walkthrough

Work `content/day18-cloud-lab.md`'s four stages in order, using this lab's
generated identifiers (from `setup.sh`'s output / `.day18-state.env`) instead
of the placeholders shown there. Try each stage's hints ladder before
reaching for `SOLUTION.md`. Each stage's proof-of-access artifact is named
explicitly in the content file so you know when you've actually finished it,
not just attempted it.

## Teardown

```sh
cd cyber_security/labs/day18
./teardown.sh --profile <your-aws-profile> --region us-east-1
```

(If you already have `.day18-state.env` from `setup.sh`, `--profile`/
`--region` are optional — `teardown.sh` reads them back out of that file.)

`teardown.sh`:

1. Terminates the EC2 instance and deletes the security group.
2. Detaches and deletes the instance profile, role, and app policy (including
   any extra policy version Stage 3's escalation created — IAM won't delete a
   policy with more than one version still attached).
3. Deletes `day18-learner`'s access key, detaches its policy, deletes the
   user and policy.
4. Empties and deletes the S3 bucket.
5. Runs and prints **documented clean-account checks** for exactly the five
   categories this plan requires: IAM users, EC2, S3, CloudTrail trails, and
   GuardDuty — see `SOLUTION.md` for what each check's expected (clean)
   output looks like. The trail/GuardDuty checks are informational only:
   this lab never creates either, so it never deletes them either — if either
   shows anything, it predates Day 18 (most likely left over from Day 16) and
   is out of scope for this teardown to touch.
6. Removes the local `.day18-state.env` and `aws-credentials-day18.txt` files.

Re-running `./setup.sh` after a clean teardown works exactly the same as the
first time.
