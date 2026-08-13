# Day 16 Lab — Cloud Detection & Response

## Authorized use only

Every script and command in this lab targets **your own AWS sandbox account**, via a
named CLI profile you already control. `setup.sh` refuses to run without an explicit
`--profile` argument. Never point any part of this lab at a shared, production, or
employer-owned AWS account. This lab creates real AWS resources (S3, CloudTrail,
GuardDuty, IAM, SNS, EventBridge) in that account — nothing here runs against a Docker
target, unlike every earlier day.

## !!! GuardDuty cost / free-trial warning !!!

**Read this before running `setup.sh`.** GuardDuty is **not** part of AWS's
always-free tier. AWS gives new GuardDuty detectors a **30-day free trial** per
account/region; after that window (or if this sandbox account has already used its
trial previously), GuardDuty **bills continuously** based on the volume of CloudTrail
events, VPC Flow Logs, and DNS logs it analyzes — typically a few dollars a month for a
small, low-traffic sandbox account, but it is real, ongoing, non-zero cost for as long
as the detector stays **enabled**, independent of whether you're actively using this
lab that day. `setup.sh` prints this same warning and requires you to type `yes` before
it creates the detector. **`teardown.sh` deletes the detector and stops this cost — but
only if you actually run it.** Set a calendar reminder if you're not tearing down
immediately.

Everything else this lab creates (CloudTrail's first single-region trail, the S3
bucket at this data volume, the disposable IAM user/policy, the SNS topic, the
EventBridge rules) is free or effectively free at lab scale — GuardDuty is the one line
item that isn't.

## What this lab is

Unlike Days 0–12's Docker labs, Day 16 has no `docker-compose.yml` — it stands up real,
minimal AWS telemetry and detection infrastructure in your own sandbox account:

- A private S3 bucket + a single-region CloudTrail trail logging management events.
- A GuardDuty detector (see the cost warning above).
- A disposable IAM user + policy (`day16-lab-user` / `day16-lab-policy`) whose only
  purpose is to be the principal you use to replay Day 14's `CreatePolicyVersion`
  escalation as one real, observable CloudTrail event.
- Three GuardDuty **sample findings** — a built-in, no-attack-required AWS mechanism
  for generating fully-formed, real-looking findings, tagged `sample: true` — covering
  both variants of Day 15's IMDS-credential-exfiltration finding plus the privilege-
  escalation finding type.
- An SNS topic with an email subscription, and two EventBridge rules routing GuardDuty
  findings and the specific `CreatePolicyVersion`/`SetDefaultPolicyVersion` CloudTrail
  events to that topic.

**This lab is self-contained**, whether or not Day 14/15's own labs still exist in your
account — it stages its own minimal reproduction of each attack's signature so the
detection queries below work against a freshly bootstrapped sandbox on their own. Full
walkthrough and concept detail: [`content/day16-cloud-detection.md`](../../content/day16-cloud-detection.md).

## Prerequisites

- An AWS sandbox account you're authorized to create/delete resources in.
- The AWS CLI installed and a named profile already configured:
  `aws configure --profile my-sandbox-profile`.
- An email address you can check, for the SNS alert subscription (AWS sends a
  confirmation email you must click before the topic will actually deliver).
- `jq` is not required by these scripts; only the AWS CLI and a POSIX shell.

## Estimated cost

- **CloudTrail:** the first trail's management events are free; S3 storage for a lab's
  worth of logs is a few cents at most.
- **Athena** (if you follow the SOLUTION.md query path): ~$5/TB scanned — a lab's
  worth of logs is a tiny fraction of a cent.
- **IAM, SNS, EventBridge:** free at this scale (SNS's free tier covers far more
  notifications than this lab sends).
- **GuardDuty: NOT free after the 30-day trial** — see the boxed warning above. This is
  the one cost that persists after you stop actively working on this lab, until
  `teardown.sh` deletes the detector.

## Setup

```sh
cd cyber_security/labs/day16
chmod +x setup.sh teardown.sh
./setup.sh --profile my-sandbox-profile --region us-east-1 --email you@example.com
```

Read the printed GuardDuty warning, type `yes`, and confirm the SNS subscription email
that arrives shortly after. Resource IDs are written to `.day16-state.env` in this
directory — **don't delete that file**; `teardown.sh` reads it to know what to remove.

## Walkthrough

Follow [`content/day16-cloud-detection.md`](../../content/day16-cloud-detection.md)
Section 2 in order:

1. **Step 1** — run `setup.sh` as above (enables the telemetry).
2. **Step 2** — replay the Day 14 escalation for real, against the disposable
   `day16-lab-user`'s policy (`setup.sh`'s own output prints the exact command with
   your policy's real ARN filled in).
3. **Step 3** — `setup.sh` already generated the GuardDuty sample findings for you; this
   step is just confirming they're there (Step 4 below).
4. **Step 4** — find the `CreatePolicyVersion` event via `aws cloudtrail lookup-events`
   (fast path) and via Athena SQL (the query Drill 1 asks you to write yourself —
   solution below); find the GuardDuty findings via `aws guardduty list-findings` +
   `get-findings`.
5. **Step 5** — verify the EventBridge → SNS wiring by re-running the
   `create-policy-version` call once more and confirming an alert email arrives.

## Verify

```sh
DETECTOR_ID=$(grep DETECTOR_ID .day16-state.env | cut -d= -f2)
aws --profile my-sandbox-profile guardduty list-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"type":{"Eq":["PrivilegeEscalation:IAMUser/AdministrativePermissions"]}}}' \
  --query 'FindingIds' --output text
```

**Expected:** at least one finding ID printed (the sample finding `setup.sh` created).
Combined with a `CreatePolicyVersion` event returned by `aws cloudtrail lookup-events
--lookup-attributes AttributeKey=EventName,AttributeValue=CreatePolicyVersion`, this
confirms both the replayed attack and its detection are visible in your account's
telemetry. Full expected output for every step, the Athena query, and the GuardDuty
finding-type mapping table: [`SOLUTION.md`](SOLUTION.md).

## Teardown

**Do this before you close out today — GuardDuty keeps billing until you do.**

```sh
cd cyber_security/labs/day16
./teardown.sh --profile my-sandbox-profile
```

Confirm the deletion prompt (or pass `--yes`). This deletes, in order: the EventBridge
rules, the SNS topic, the GuardDuty detector (stops GuardDuty billing), the CloudTrail
trail, the S3 bucket (emptied first), and the disposable IAM user + policy (including
any extra policy versions the replay created). `teardown.sh` prints four verification
commands at the end — run them and confirm each returns "empty" / `NoSuchEntity` /
`NoSuchBucket` before considering today's cleanup done.
