# Day 15 Lab — SSRF-to-Cloud: Steal Instance Role Creds, Read a Public Bucket

## Authorized use only

This lab creates real resources in **your own AWS sandbox account** — an EC2
instance running a deliberately SSRF-vulnerable app, an over-permissive instance
role, and two S3 buckets (one intentionally public). Only ever run these commands
against resources `setup.sh` creates, tagged `purpose=cyberlab-day15`, in an AWS
account you own or have explicit written authorization to test in. Never point any
of today's techniques — SSRF to `169.254.169.254`, anonymous S3 enumeration — at an
instance, bucket, or account that isn't yours.

## Cost warning

One `t3.micro` EC2 instance (free-tier eligible for the first 12 months of a new AWS
account; a few cents/hour on-demand otherwise) and two mostly-empty S3 buckets
(negligible — well under a cent for the lifetime of this lab). Nothing here enables
GuardDuty, NAT gateways, Elastic IPs, or any other line item with meaningful cost.
**Run `./teardown.sh` when you're done** — leaving the instance running past this
session is the only way this lab costs you anything real.

## What this lab is

- **The vulnerable app** (`url_preview.py`, embedded in `setup.sh`'s user-data —
  see the setup script for its full source): a ~40-line stdlib-only Python HTTP
  server exposing `GET /fetch?url=<url>`, which fetches whatever URL it's given,
  server-side, with no allowlist and no block on link-local addresses. It only ever
  issues a plain `GET` with no custom headers — architecturally identical to Day 9's
  SSRF lab target, and exactly why IMDSv2 (Defense 1) is able to stop it completely
  without any change to this app's own code.
- **The instance role**: attached to the EC2 instance, deliberately over-permissive
  in the attack baseline (`AmazonS3ReadOnlyAccess`, a broad managed policy covering
  every bucket in the account) — Defense 3 tightens this to a scoped inline policy
  covering only the lab's own private bucket.
- **The private bucket**: Block Public Access **on**, no public policy — reachable
  only with valid AWS credentials (stolen or legitimate).
- **The public bucket**: Block Public Access **off**, a bucket policy granting
  `s3:GetObject` to `Principal: "*"` — reachable with zero credentials at all, by
  design, until Defense 2 fixes it.
- **IMDSv1 allowed** (`HttpTokens=optional`) on the instance, on purpose, in the
  attack baseline — Defense 1 enforces IMDSv2 (`HttpTokens=required`) against the
  same running instance.

Full walkthrough with objectives and concept background:
[`content/day15-metadata-s3.md`](../../content/day15-metadata-s3.md).

## Setup

Prerequisite: a working AWS CLI, and a named profile you've already configured
(`aws configure --profile cyberlab-sandbox`) with credentials that can create IAM
roles/instance profiles, EC2 instances/security groups, and S3 buckets in a sandbox
account. **No credentials are ever hardcoded** in `setup.sh` or `teardown.sh` — both
scripts require `$AWS_PROFILE` to already be set.

```sh
cd cyber_security/labs/day15
export AWS_PROFILE=cyberlab-sandbox
export ALLOWED_CIDR="$(curl -s https://checkip.amazonaws.com)/32"   # your own IP only
./setup.sh
```

`setup.sh` refuses to run if `$AWS_PROFILE` or `$ALLOWED_CIDR` isn't set — it will
not default the security group to `0.0.0.0/0`. On success it prints the instance's
public IP, both bucket names, and the instance role name, and writes them to
`.day15-state.env` for `teardown.sh` to read later.

**Note:** this script authors real AWS CLI commands but was authored and validated
with `bash -n setup.sh` only, never executed against a live account while building
this lab (see repository-level constraint on AWS days). Run it for the first time
in your own sandbox, and read every step above before you do.

## Walkthrough

Work through [`content/day15-metadata-s3.md`](../../content/day15-metadata-s3.md)
Section 2 in order, using the public IP, bucket names, and role name `setup.sh`
printed:

1. Step 1 — recon the app at `http://<EC2_PUBLIC_IP>:8080/`.
2. Step 2 — SSRF to IMDS to enumerate the instance role's name.
3. Step 3 — SSRF to IMDS to steal that role's live temporary credentials.
4. Step 4 — use the stolen credentials (`aws sts get-caller-identity`, `aws s3
   ls`, read the private bucket's object).
5. Step 5 — separately, read the public bucket's object with `--no-sign-request`
   and no credentials at all.
6. Read Section 3 (Defense) and apply Defenses 1–3 by hand against these same
   resources, re-running the corresponding attack step after each one, before
   checking `SOLUTION.md`.

## Verify

```sh
curl -sf "http://<EC2_PUBLIC_IP>:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/" \
  | grep -q "instance-role" && echo ATTACK_OK
```

Expected: `ATTACK_OK`. Full expected command sequence and response shapes:
[`SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day15
export AWS_PROFILE=cyberlab-sandbox
./teardown.sh
```

This terminates the EC2 instance, deletes the security group, detaches/deletes the
IAM role and instance profile (including the Defense 3 inline policy if you added
it), and empties + deletes both S3 buckets. It reads `.day15-state.env` for resource
IDs, falling back to a tag-based lookup (`purpose=cyberlab-day15`) if that file is
missing. **Reminder: run this when you're done** — an EC2 instance left running is
the only ongoing cost this lab has. Verify commands are printed at the end of
`teardown.sh`'s own output; they're also listed in `SOLUTION.md`.
