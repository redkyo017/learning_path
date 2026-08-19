# Day 8 lab — Solution notes

**No AWS calls were made while authoring this lab** — the author's
environment has no credentials, does not run `terraform apply`, and does
not call AWS. Every value below marked "example format" is a
structurally accurate illustration of what that step's real output looks
like (field names, ID length/character set, JSON shape), not a literal
ID from a real run. Fill in the `← record yours here` blanks with your
own output as you go.

## Step 1 — apply

Expected `terraform apply` resource count: ~11-13 (S3 bucket + 3-4 S3
sub-resources for the trail-log bucket, the bucket policy, the trail
itself, the GuardDuty detector, the Security Hub account + standard
subscription, the Macie account + classification job, the Detective
graph). No `aws_lb*`, `aws_ecs*`, or `aws_cloudfront*` resources appear —
this module creates none.

## Step 3 — stolen credentials (expected shape)

```json
{
  "Code": "Success",
  "AccessKeyId": "ASIAEXAMPLE0000STOLEN",
  "SecretAccessKey": "<40-char base64-ish secret>",
  "Token": "<long base64 session token>",
  "Expiration": "2026-08-19T20:45:00Z"
}
```

← record your real `AccessKeyId` prefix and expiration here:
`________________________`

If instead you get `{"error": "..."}` with a 502, the SSRF request
itself failed — re-check `$RELATIVE_URI` from Step 2 (it must include
the leading `/v2/credentials/` segment) and that the ALB DNS name is
reachable (`curl http://$ALB_DNS/` should return `ok`).

## Step 4 — weaponized call, `get-caller-identity` (expected shape)

```json
{
  "UserId": "AROAEXAMPLE:i-am-a-session",
  "Account": "111122223333",
  "Arn": "arn:aws:sts::111122223333:assumed-role/aws-sec-lab-task-role/i-am-a-session"
}
```

Confirms the credentials your laptop is now holding are the task role's,
not your own admin identity — the `Arn` should end in
`aws-sec-lab-task-role/<session>`, matching `labs/base`'s
`task_role_arn` output.

## Step 5 — CloudTrail end-to-end trail (expected shape)

`lookup-events` for `GetObject` should return an entry like:

```json
{
  "EventId": "<uuid>",
  "EventName": "GetObject",
  "EventTime": "2026-08-19T14:32:07Z",
  "Username": "aws-sec-lab-task-role",
  "CloudTrailEvent": "{\"eventVersion\":\"1.09\",\"userIdentity\":{\"type\":\"AssumedRole\",\"arn\":\"arn:aws:sts::111122223333:assumed-role/aws-sec-lab-task-role/i-am-a-session\",\"accessKeyId\":\"ASIAEXAMPLE0000STOLEN\"},\"sourceIPAddress\":\"<your public IP>\",\"userAgent\":\"aws-cli/2.x...\",\"requestParameters\":{\"bucketName\":\"<app_bucket_name>\",\"key\":\"...\"},\"eventName\":\"GetObject\",\"eventSource\":\"s3.amazonaws.com\"}"
}
```

The load-bearing fields to confirm by hand: `userIdentity.arn` = the task
role, `sourceIPAddress` = your own public IP (not an internal AWS
range), `userAgent` = `aws-cli/...` (not the Flask app's `requests`
library). That three-way mismatch is the entire "end-to-end trail of the
SSRF read" this lab's success signal requires.

← record your real `EventId` and `sourceIPAddress` here:
`________________________`

The `ExecuteCommand` management event from Step 2's recon should appear
a few minutes earlier in the same lookup window, with `eventSource`
`ecs.amazonaws.com` and your own admin identity as `userIdentity` (not
the task role) — that's the recon step, distinct from the SSRF exploit
itself.

## Step 6 — GuardDuty sample findings (expected shape)

```
$ aws guardduty create-sample-findings --detector-id <id> \
    --finding-types "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS" "CryptoCurrency:EC2/BitcoinTool.B!DNS"
{}
```

(empty JSON object is the correct success response for this call)

```
$ aws guardduty list-findings --detector-id <id>
{
  "FindingIds": [
    "<32-hex-char-id-1>",
    "<32-hex-char-id-2>"
  ]
}
```

`get-findings` on each should show `"service": {"additionalInfo": ...,
"sample": true}` marking these explicitly as AWS's documented sample
findings — real finding records, real IDs, real severities, honestly
labeled as sample data (not a fabricated finding, and not something this
lab's author invented).

| # | Finding type | Expected severity | Your finding ID (fill in) |
|---|---|---|---|
| 1 | `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS` | High (~8.x) | `________________________` |
| 2 | `CryptoCurrency:EC2/BitcoinTool.B!DNS` | High (~8.x) | `________________________` |
| 3 (bonus, if it landed naturally from Steps 3-4 before teardown) | `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS` (real, non-sample) | High | `________________________` |

This table, filled in with your real run's IDs, **is** this lab's "≥2
findings visible with IDs" success signal.

## Step 7 — Security Hub + Macie (expected shape)

`securityhub get-findings` should return ASFF-formatted records whose
`ProductArn` includes `.../guardduty` for the two findings from Step 6,
plus a larger set of `.../aws-foundational-security-best-practices`
records — those are the standard's own control checks, not something
this lab triggered.

`macie2 describe-classification-job` should transition
`jobStatus`: `RUNNING` → `COMPLETE` within a few minutes for a bucket
this small. `macie2 list-findings` may return zero findings if the
`app_data` bucket has no actual PII-shaped content in it — that's an
expected, valid outcome (Macie's job is "did I check," not "did I find
something"; an empty result after a completed job is a real, useful
answer, not a failure).

## Fix rationale (why this lab is a "break" with no harden yet)

Every artifact this lab produces — the stolen credentials, the
CloudTrail trail, the GuardDuty findings — documents that the task
role's permissions (still the Day-1-broad-within-bucket grant, unless
you're running this lab after Day 1 already tightened it) and the app's
SSRF hole (still present — nothing in this lab patches `app.py`) both
remain fully exploitable. That's intentional: Day 8's job is proving
detection *works*, not fixing the underlying holes. Day 9 is where the
GuardDuty finding from Step 6 becomes the trigger for an EventBridge rule
that invokes a Lambda to quarantine `aws-sec-lab-task-role`'s permissions
automatically — the harden half of this exact break.
