# Capstone attack runbook — Day 11

> **⚠️ AUTHORIZED TESTING ONLY.** Every step below targets **your own AWS
> account and your own Terraform-deployed `labs/base` workload, and
> nothing else.** Do not run any part of this against an account, a
> workload, or a piece of infrastructure you do not own and are not
> explicitly authorized to test. This is the canonical statement from
> [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement)
> — that file is the source of truth if this copy and that one ever
> drift.

This is the attack half of the Day 11–12 IR capstone. `attack.sh` is the
runnable version of the steps below. `attack-SOLUTION.md` records the
expected artifact for every step, so you can self-check what you
captured against what should be there. **Day 12 owns the defend half**
(`defend-runbook.md` in this same directory, driven from
[`labs/day12/`](../day12/README.md)) — this file and its `attack*`
siblings never touch containment/eradication.

## Objective

Run the shared capstone incident — leaked key → recon → SSRF →
task-role credential theft → data exfil → a crypto-mining-flavored API
call — end to end against your own workload, and capture every artifact
each detection control produces along the way. You are building the
evidence file Day 12 will use to contain, eradicate, and recover.

## Prerequisites

- `labs/base` is applied and healthy — `terraform output` from
  `labs/base` should return real values for `alb_dns_name` (or
  `cloudfront_distribution_id`), `app_bucket_name`, `task_role_arn`, and
  the DynamoDB table name embedded in `db_endpoint`.
- The Day 8 detection module is (re-)applied so **GuardDuty and Security
  Hub are running**. Day 9's teardown disabled them at the end of the
  free-trial checkpoint; re-run `terraform apply` in `labs/day08/` (or
  wherever your Day 8 module lives) before starting today — see Day 11's
  content file, "The free-trial window, re-opened," for the cost/trial
  math. **Macie and Detective stay off** — this incident's artifact list
  is CloudTrail + GuardDuty + Security Hub + Config only.
- AWS CLI v2 configured with the credentials you used to deploy
  Terraform. This lab intentionally does **not** provision a second,
  separately-leaked IAM identity to play "the attacker" — see the note
  below on why, and what that trades away.
- `curl`, `jq`, and `python3` on your machine — `attack.sh` shells out to
  `python3` to URL-encode the SSRF target before curling it.
- A scratch directory to hold captured artifacts (JSON exports, curl
  output, CLI output) — `attack.sh` writes to `./capstone-evidence/` by
  default.

## A note on "leaked access key" and on the credential-endpoint GUID

Two deliberate simplifications, stated up front so you know what's
realistic and what's compressed for a one-day lab:

1. **The "leaked key."** A real leaked-key incident starts with a
   *separate*, usually far more restricted, IAM identity than whatever
   you use to run Terraform. Provisioning a second real IAM user with
   its own access key here would mean extra infrastructure this lab
   would then have to track and tear down — its own instance of
   secret sprawl (`ANTIPATTERNS.md` #10) in the name of demonstrating
   secret sprawl. So this lab narrates every "attacker" step as if run
   with a leaked key, but you actually run it with your existing
   deployer credentials. The mechanics that matter for today's teaching
   point — what the SSRF pivot does, and what trail it leaves — are
   identical either way.
2. **The credential-endpoint path.** As covered in the Day 11 content
   file, ECS deliberately makes the task credentials endpoint's path
   segment (the value of `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`, e.g.
   `/v2/credentials/<GUID>`) unguessable, specifically so a blind
   SSRF bug can't reach it without a second, independent leak of that
   value. This lab does not chain a second bug to discover it — that's
   a separate research exercise. `attack.sh` asks you to supply it as
   `$CREDS_RELATIVE_URI`, treated as already known to the attacker (a
   reasonable stand-in for "leaked in a log line" or "already visible
   from the recon access most real leaked keys carry"). If you want the
   sharper version of this lab: temporarily add a debug line to
   `labs/base/app/app.py`'s `/whoami` route that also returns
   `os.environ.get("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI")`, capture
   the value once, then remove it and redeploy — now you've chained two
   real bugs, the way production incidents usually work. Optional, not
   required.

## The incident, stage by stage

Every stage names the control it should trip and where to look
afterward. `attack-SOLUTION.md` has the fully worked expected output;
this table is the map.

| # | Stage | What you run | Detection control expected to fire |
|---|---|---|---|
| 1 | Leaked key (narrated) | `aws sts get-caller-identity` | none — this is initial access, not yet an anomaly |
| 2 | Recon | `describe-load-balancers` / `describe-services` / `get-distribution` against your own base workload | CloudTrail (read-only management events, your caller identity) |
| 3 | SSRF exploit | `curl` the app's `/fetch?url=` endpoint, pointed at the ECS credential endpoint | CloudTrail (`Invoke`-style ALB/app access isn't a CloudTrail event — nothing fires here yet; the *use* of what it returns is what trips control) |
| 4 | Credential theft confirmed | parse the JSON the SSRF call returned; export it as `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN` | GuardDuty (credential-exfiltration-flavored finding, once stage 5/6 use it from outside AWS) |
| 5 | Data exfil | `aws s3 sync` from `app_bucket_name`; `aws dynamodb scan` on the base table, using the **stolen** credentials | CloudTrail (data-plane events under the task role's assumed-role ARN, from your workstation's IP, not from inside the VPC); GuardDuty; Security Hub (ingests the GuardDuty finding) |
| 6 | Crypto-mining-flavored call | `aws ec2 run-instances --dry-run` with an oversized instance type, using the **stolen** credentials | CloudTrail (`errorCode: DryRunOperation`, same assumed-role ARN, same external IP) |
| — | Forensic cross-check | `aws configservice get-resource-config-history` on the bucket and the task role's policy | Config — confirms whether anything was *reconfigured* during the window (expected: no) |

The GuardDuty finding type most likely to fire here is in the
`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration` family —
**record whatever exact type and ID your account actually emits** in
`attack-SOLUTION.md`'s blank fields; finding-type names are AWS's to
define and can evolve, so treat the family name as a pointer, not a
guarantee, and always confirm against what you actually see.

## Running it

```bash
cd labs/capstone
# review attack.sh top-to-bottom before running anything against your account
# — it needs several placeholders filled in first (see its header comment)
bash attack.sh
```

`attack.sh` pauses between stages and prints a reminder of what to
capture before continuing — don't skip the pauses, the artifacts are
the point of today, not the exploit itself.

## Capture checklist (also printed by `attack.sh`)

For each stage above, save the actual output you get, not this
document's description of it, into `./capstone-evidence/`:

- [ ] Stage 2 recon: the CLI output naming your ALB DNS name / CloudFront
      domain / ECS service.
- [ ] Stage 3–4: the raw JSON the SSRF request returned (redact nothing
      — it's your own temporary credentials, they expire in hours).
- [ ] Stage 5: `aws s3 ls` and `aws dynamodb scan` output using the
      stolen credentials; the exfiltrated object(s) themselves if you
      want the full loop closed.
- [ ] Stage 6: the `DryRunOperation` error text.
- [ ] `aws cloudtrail lookup-events` output covering the whole window,
      filtered to the task role's assumed-role session.
- [ ] `aws guardduty list-findings` + `get-findings` output — the full
      finding JSON, not just the ID.
- [ ] `aws securityhub get-findings` output for the corresponding
      finding.
- [ ] `aws configservice get-resource-config-history` output for the S3
      bucket and the task role's inline policy, covering the window.
- [ ] A one-paragraph timeline you write yourself, in your own words,
      ordering all of the above by timestamp — this is the artifact Day
      12 actually needs.

## Teardown

Nothing lab-specific to tear down — this lab creates no new
infrastructure, only API calls against what's already there. **Leave
GuardDuty and Security Hub running** — they stay up into Day 12, which
performs the sweep. Delete `./capstone-evidence/` only after Day 12 is
done with it (Day 12's defend runbook reads from it).
