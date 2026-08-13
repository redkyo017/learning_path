# Day 14 Lab — IAM Abuse & Privilege Escalation in Your Own AWS Sandbox

## Authorized use only

This lab creates real IAM resources in **your own AWS sandbox account** — an account
you own or have explicit written authorization to test. Never point `setup.sh`,
`teardown.sh`, or any of the CLI calls in `content/day14-iam-privesc.md` at a
production account, an employer's account without written authorization, or any
account you don't control. The escalation this lab demonstrates is real and works
against any account with the same misconfiguration — treat the resulting credentials
with the same care you'd give real admin credentials, because by the end of the
Attack Lab, they are exactly that.

## What this lab is

Unlike Days 0–12 (Docker containers on the shared `cyberlab` network), this is an AWS
lab: `setup.sh` and `teardown.sh` create and remove real IAM resources via the AWS
CLI, authenticated with a **named profile** — never a hardcoded credential.

`setup.sh` creates:

- **`day14-lowpriv`** — an IAM user with programmatic (access-key) credentials only,
  no console login.
- **`day14-lowpriv-policy`** — a managed policy attached to that user, granting a
  narrow, realistic-looking set of read-only IAM/STS calls, **plus the planted
  misconfiguration**: `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion`
  scoped by `Resource` to the policy's own ARN. See
  [`setup.sh`](setup.sh) for the exact JSON.

That single self-referential scoping is the entire vulnerability: the identity this
policy is attached to can rewrite and re-activate the policy itself.

## Cost

**$0.** IAM users, groups, policies, and access keys are entirely free — there is no
free-tier limit to watch here, and nothing in this lab provisions a billable resource
(no EC2, no S3 storage beyond what you might add yourself). The only reason to still
run `teardown.sh` promptly is security hygiene, not cost: an unused low-privilege
access key sitting in your sandbox account — especially one that, after the Attack
Lab, is actually admin-equivalent — is a standing risk on its own, independent of
billing.

**Reminder: run `./teardown.sh` when you're done with this lab**, even though nothing
here costs money.

## Prerequisites

- AWS CLI v2 installed and configured with a **named profile** that has
  administrator-level access in your sandbox account (used only for `setup.sh` /
  `teardown.sh` — never for the Attack Lab steps themselves, which use the low-priv
  profile you create below):

  ```sh
  aws configure --profile cyberlab-sandbox
  ```

- Optionally export `AWS_PROFILE=cyberlab-sandbox` so you don't need `--profile` on
  every command; both scripts default to `cyberlab-sandbox` if `AWS_PROFILE` is unset,
  and accept any profile name via `AWS_PROFILE=<name>`.
- For the Defense Lab's pmapper section: `pip install principalmapper` (or see
  [NCC Group's pmapper repo](https://github.com/nccgroup/PMapper) for install options).
  Not required to complete the Attack Lab or Defense 1/2.

## Setup

```sh
cd cyber_security/labs/day14
AWS_PROFILE=cyberlab-sandbox ./setup.sh
```

This prints the created user name, policy ARN, and the path to a local, gitignored
JSON file containing the low-priv user's access key
(`output/day14-lowpriv-access-key.json` — never commit this file; the lab's
`.gitignore` already excludes `**/output/`).

Configure a second, low-privilege profile from that file:

```sh
KEY_FILE=output/day14-lowpriv-access-key.json
aws configure set aws_access_key_id     "$(jq -r .AccessKey.AccessKeyId "$KEY_FILE")"     --profile day14-lowpriv
aws configure set aws_secret_access_key "$(jq -r .AccessKey.SecretAccessKey "$KEY_FILE")" --profile day14-lowpriv
```

## Attack walkthrough

Full step-by-step commands and expected output: `content/day14-iam-privesc.md` Section
2, and the fully captured before/after in [`SOLUTION.md`](SOLUTION.md). In short:

1. Enumerate as `day14-lowpriv`: `sts:get-caller-identity`,
   `iam:list-attached-user-policies`, `iam:get-policy` + `get-policy-version`.
2. Spot that the attached policy grants `iam:CreatePolicyVersion` /
   `iam:SetDefaultPolicyVersion` scoped to its own ARN.
3. Push a new default version granting `Action: *, Resource: *`.
4. Confirm escalation: a previously-denied call (e.g. `iam:list-users`) now succeeds.

## Defense walkthrough

Full detail: `content/day14-iam-privesc.md` Section 3. In short:

1. **The single deny statement** that closes the path (denying
   `iam:CreatePolicyVersion` / `iam:SetDefaultPolicyVersion`, e.g. via a permissions
   boundary on `day14-lowpriv`) — the exact JSON and why explicit deny always wins is
   in [`SOLUTION.md`](SOLUTION.md).
2. **IAM Access Analyzer** (unused-access analyzer) — what it would and would not have
   flagged about this exact misconfiguration.
3. **pmapper** — the graph command that reports this escalation as a named
   privilege-escalation edge.

## Teardown

```sh
cd cyber_security/labs/day14
AWS_PROFILE=cyberlab-sandbox ./teardown.sh
```

Deletes, in dependency order: the user's access key(s), the policy attachment, all
non-default policy versions, the policy itself, the user, and the local credentials
file. Verify manually afterward:

```sh
aws iam get-user --user-name day14-lowpriv --profile cyberlab-sandbox
```

Expected: an error naming `NoSuchEntity` — confirming full cleanup.

**Reminder:** run teardown even though this lab costs nothing — an orphaned
(now-admin-equivalent) access key is the actual risk, not the AWS bill.
