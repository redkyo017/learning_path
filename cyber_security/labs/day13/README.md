# Lab: Day 13 — Cloud Security Model & IAM Foundations

## Authorized use only

This lab creates and modifies real IAM resources in **your own AWS account**. Run it
only against an **AWS sandbox account you own** (a throwaway/dev account, ideally with
no production resources in it at all) — never against an employer's, client's, or any
other account you don't have explicit written authorization to test. IAM misconfiguration
here is a deliberate teaching device, not something to leave lying around: run
`./teardown.sh` as soon as you're done with the lab (see below).

## Prerequisites

- An **AWS sandbox account**, distinct from any production/work account.
- The **AWS CLI** installed and configured with a **named profile** for that sandbox
  account: `aws configure --profile cyberlab-sandbox` (pick any profile name; every
  script here defaults to reading `AWS_PROFILE`, falling back to `cyberlab-sandbox` if
  unset — never edit a script to hardcode a key or secret).
- IAM permissions in that sandbox account sufficient to create/delete IAM users, roles,
  and managed policies (an account's own root/admin credentials, used only to configure
  the CLI profile above, are sufficient — this lab does not need you to already have a
  scoped-down operator identity, since setting one up correctly is literally today's
  topic).
- `jq` is not required for these scripts, but is used elsewhere in this path if you want
  to pretty-print policy JSON by hand.

## What this lab creates

Running `./setup.sh` creates, in your sandbox account:

| Resource | Name | Purpose |
|---|---|---|
| IAM user | `cyberlab-day13-user` | The identity whose over-broad permissions you'll assess |
| IAM managed policy | `cyberlab-day13-overpermissive-policy` | Deliberately grants `s3:*` on `Resource: "*"` (see [`policies/overpermissive-policy.json`](policies/overpermissive-policy.json)) |
| IAM role | `cyberlab-day13-role` | Trusted by `ec2.amazonaws.com`; foreshadows Day 14's `iam:PassRole` attack |

During the Defense Lab (content file Section 3) you may also create:

- A new default version of the policy above (via `create-policy-version`), holding the
  least-privilege rewrite ([`policies/least-privilege-policy.json`](policies/least-privilege-policy.json)).
- A second managed policy, `cyberlab-day13-boundary`, used as a permissions boundary
  ([`policies/permission-boundary-example.json`](policies/permission-boundary-example.json)).

`teardown.sh` removes all of the above, including any extra policy versions you created.

## Estimated cost

**$0.** IAM users, roles, and policies carry **no charge** on AWS — creating, attaching,
simulating, and deleting them is free regardless of account age or free-tier status.
This lab creates no EC2 instances, no S3 buckets, and makes no data-plane calls to any
billable service; the only API calls made are IAM/STS control-plane calls (also free).
If you extend the lab yourself (e.g. actually launching an EC2 instance to test the
role, or creating a real S3 bucket matching the `cyberlab-day13-*` prefix), those
resources fall under their own normal (free-tier-eligible, small) pricing — not part of
this lab as written.

## Setup

```sh
cd cyber_security/labs/day13
export AWS_PROFILE=cyberlab-sandbox   # your own profile name
aws sts get-caller-identity --profile "$AWS_PROFILE"   # confirm you're pointed at the sandbox
./setup.sh --dry-run                  # review the plan first — no API calls made
./setup.sh                            # create the lab resources
```

## Walkthrough

Work through [`content/day13-cloud-iam.md`](../../content/day13-cloud-iam.md) Sections
2 and 3 in order: enumerate and prove the over-permissive grant with
`simulate-principal-policy` (Section 2), then rewrite to least privilege and layer on a
permission boundary (Section 3). Full expected command output is in
[`SOLUTION.md`](SOLUTION.md) — attempt each step yourself first.

## Teardown — do this before you forget

```sh
cd cyber_security/labs/day13
./teardown.sh --dry-run   # review the plan first
./teardown.sh
```

**Reminder:** this lab intentionally leaves an over-permissive IAM policy attached to a
real user and role in your account for as long as it's up. Don't leave it running
between sessions — run `./teardown.sh` at the end of each sitting, and verify it worked:

```sh
aws iam get-user --user-name cyberlab-day13-user --profile "$AWS_PROFILE"
# expected after teardown: An error occurred (NoSuchEntity) ...
```
