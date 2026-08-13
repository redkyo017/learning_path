# Day 17 Lab — Cloud Network Security

## Authorized sandbox only

Everything in this lab runs in **your own AWS sandbox account**, via a **named AWS
CLI profile** you configure yourself (`aws configure --profile <name>`). Never
hardcode an access key/secret anywhere in these scripts or your shell history — set
`AWS_PROFILE` as an environment variable instead. `setup.sh` provisions a genuinely
internet-reachable EC2 instance with a deliberately over-permissive security group
(SSH and a full TCP port range open to `0.0.0.0/0`) — do not point the `nmap` scans
below, or any other tooling, at any account, instance, or IP you don't own or don't
have explicit written authorization to test. Tear the stack down promptly with
`./teardown.sh` — see the cost note below.

## What this builds on

This lab assumes you already know how to build a VPC — subnets, route tables,
Internet Gateways, NAT — from prior AWS networking work. It does not re-teach that
construction. It puts a **security lens** on the same constructs: which combinations
create exposure, how to find that exposure from outside with `nmap`, and how to fix
and instrument it (security group least privilege, NACL layering, VPC Flow Logs). If
any of those base networking terms are unfamiliar as mechanisms, close that gap with
general AWS networking material first.

## Cost note

- One `t3.micro` EC2 instance — typically free-tier eligible for 750 hrs/month in
  eligible accounts, **but this is not guaranteed for every account** (check your own
  account's free-tier status before running this for an extended period).
- VPC, subnet, Internet Gateway, route table, security group — all free on their own.
- If you complete Defense Lab Step 3 (VPC Flow Logs), the CloudWatch Logs group and
  IAM role are also free at this lab's tiny data volume; CloudWatch Logs storage/
  ingestion costs scale with volume if left running for a long time.
- Nothing in this lab enables GuardDuty, CloudTrail (org-level), Config, or any other
  metered detective control.

**Run `./teardown.sh` as soon as you're done with today's lab.** Don't leave the
instance (or, if you completed Defense Lab Step 3, the Flow Log/log group/IAM role)
running longer than needed.

## Setup

```sh
cd cyber_security/labs/day17
export AWS_PROFILE=<your-sandbox-profile>
./setup.sh
```

This creates, in order: a VPC, a public subnet (route table → Internet Gateway), a
security group with one intended rule (`80/tcp` from `0.0.0.0/0`) and two **planted
risky rules** (`22/tcp` and `0-65535/tcp`, both from `0.0.0.0/0`), and a `t3.micro`
EC2 instance running a small Apache web server. `setup.sh` prints the instance's
`SG_ID`, `SUBNET_ID`, `VPC_ID`, `INSTANCE_ID`, and public IP at the end — keep that
output, the Attack/Assess and Defense Lab steps below all reference those values.

No SSH key pair is created — this lab never needs an interactive session on the
instance; the point is the SG rule that *would* allow SSH, not actually logging in.

## Walkthrough

Full step-by-step commands, expected output, and reasoning live in
[`content/day17-cloud-network.md`](../../content/day17-cloud-network.md):

- **Section 2 (Attack/Assess Lab):** read the SG's rules with `aws ec2
  describe-security-groups`, identify the two planted risky rules, then confirm both
  are actually reachable with an external `nmap -Pn` scan against the instance's
  public IP.
- **Section 3 (Defense Lab):** tighten the SG to least privilege and re-run the exact
  same scan to prove the fix; add a NACL rule as a second, independent layer; turn on
  VPC Flow Logs and query them for both the pre-fix `ACCEPT` and post-fix `REJECT`
  records of the same scan traffic; read the architectural note on private
  subnets + NAT for anything that doesn't need direct internet reachability at all.

[`SOLUTION.md`](SOLUTION.md) has the exact risky-rule findings, the SG-vs-NACL
reasoning, and what the Flow Log records for this scan look like, if you want to
check your own assessment before or after working through the content file.

## Teardown

```sh
cd cyber_security/labs/day17
export AWS_PROFILE=<your-sandbox-profile>
./teardown.sh
```

Discovers and removes every resource tagged `Project=cyberlab-day17` (instance,
security group, route table, Internet Gateway, subnet, VPC), plus a best-effort
cleanup of the optional Defense Lab Flow Logs extras (the flow log resource, the
`/cyberlab/day17/vpc-flow-logs` CloudWatch Logs group, and the `day17-flow-logs-role`
IAM role) if you created them — those steps no-op safely if you skipped Defense Lab
Step 3. Ends by re-querying for any remaining tagged VPC and printing `TEARDOWN_OK`
if none remain, or a warning with the resource ID(s) still present if teardown was
incomplete.

**Reminder:** re-run `./teardown.sh` and confirm `TEARDOWN_OK` before moving on —
don't leave this lab's exposed instance running.
