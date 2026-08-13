# Day 16 Lab — Solution

Full worked answers: the CloudTrail/Athena query catching `CreatePolicyVersion` abuse,
the GuardDuty finding-type mapping table, and an auto-response design. Read
[`content/day16-cloud-detection.md`](../../content/day16-cloud-detection.md) first and
attempt the drills yourself before reading this.

## 1. The CloudTrail/Athena query catching `CreatePolicyVersion` abuse

### Fast path — CLI, no Athena table setup required, last 90 days

```sh
aws --profile my-sandbox-profile cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreatePolicyVersion \
  --max-results 10
```

**Expected output shape** (abbreviated — the real response is the full CloudTrail event
JSON per entry):

```json
{
  "Events": [
    {
      "EventId": "…",
      "EventName": "CreatePolicyVersion",
      "EventTime": "2026-08-12T…",
      "Username": "day16-lab-user",
      "CloudTrailEvent": "{...\"requestParameters\":{\"policyArn\":\"arn:aws:iam::<acct>:policy/day16-lab-policy\",\"policyDocument\":\"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Effect\\\":\\\"Allow\\\",\\\"Action\\\":\\\"*\\\",\\\"Resource\\\":\\\"*\\\"}]}\",\"setAsDefault\":true}...}"
    }
  ]
}
```

The escalating signal is inside `CloudTrailEvent.requestParameters.policyDocument`
(a JSON string, itself needing one more decode): `"Action":"*","Resource":"*"` is the
tell — a routine, narrow policy update would show a specific action/resource list
instead.

### Athena path (once your trail's S3 logs are queryable — see AWS's "Create a table
for CloudTrail logs in Athena" doc for the `CREATE EXTERNAL TABLE` DDL against your
trail's own bucket/prefix)

```sql
SELECT
  eventtime,
  useridentity.arn AS caller,
  json_extract_scalar(requestparameters, '$.policyArn') AS policy_arn,
  json_extract_scalar(requestparameters, '$.policyDocument') AS new_policy_document
FROM cloudtrail_logs
WHERE eventname = 'CreatePolicyVersion'
ORDER BY eventtime DESC;
```

**Why this shape, specifically:** filtering on `eventname = 'CreatePolicyVersion'`
alone catches *every* call to that API, escalating or not — pulling
`new_policy_document` into its own column (rather than leaving the analyst to dig
through the full raw JSON blob each time) is what actually makes "which of these calls
granted broad new permissions" a fast visual scan instead of a manual decode per row.
A stricter version filters further with `WHERE
json_extract_scalar(requestparameters, '$.policyDocument') LIKE '%\"Action\":\"*\"%'` to
surface only the escalating subset directly — useful once you have enough history that
scrolling every `CreatePolicyVersion` call by hand stops being practical.

## 2. GuardDuty finding-type mapping table

| Attack (Day) | Exact GuardDuty finding type | Where the *use* of stolen creds/access happened |
|---|---|---|
| Day 14 — `CreatePolicyVersion` self-escalation | `PrivilegeEscalation:IAMUser/AdministrativePermissions` | N/A — this finding fires on the escalating *API call itself*, from a principal that didn't already have admin permissions |
| Day 15 — SSRF → IMDS → creds, used from the attacker's own machine/network | `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS` | Outside AWS's network entirely (an attacker's laptop, home network, non-AWS VPS) |
| Day 15 variant — stolen creds used from a *different* EC2 instance or AWS account | `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS` | Inside AWS's network, but not the instance the credentials actually belong to |

**The distinction that matters (Drill 2's exact scenario):** both `InstanceCredential
Exfiltration` findings share the same root cause — IMDS-exposed temporary credentials
used from somewhere other than the instance they belong to — but the finding *type*
that fires depends on where the credentials were **used**, not where they were
**stolen from**. A cross-account, cross-instance use inside AWS is `.InsideAWS`, even
though the theft itself (SSRF against IMDS) is identical to the classic `.OutsideAWS`
case.

Retrieve full finding detail (including the `sample: true` flag on `setup.sh`'s
synthetic findings) with:

```sh
DETECTOR_ID=$(grep DETECTOR_ID .day16-state.env | cut -d= -f2)
FINDING_IDS=$(aws --profile my-sandbox-profile guardduty list-findings \
  --detector-id "$DETECTOR_ID" --query 'FindingIds' --output text)
aws --profile my-sandbox-profile guardduty get-findings \
  --detector-id "$DETECTOR_ID" --finding-ids $FINDING_IDS
```

## 3. Auto-response design

**Trigger:** EventBridge rule matching
`{"source":["aws.guardduty"],"detail-type":["GuardDuty Finding"],"detail":{"type":["PrivilegeEscalation:IAMUser/AdministrativePermissions"]}}`,
targeting a Lambda function (not deployed by this lab — design only, stated as such in
the content file's Section 3).

**Response, in order:**

1. **Contain (smallest, most reversible action first):** parse the finding's
   `detail.resource` to get the affected policy ARN and the escalating version ID, and
   call `iam:DeletePolicyVersion` on that *specific version only* — the pre-escalation
   default version is left untouched. This is a design choice, not an accident: rolling
   back one version is trivially reversible if the finding is a false positive;
   disabling the whole principal is not.
2. **Preserve evidence before anything more aggressive:** write the full finding JSON
   plus the deleted policy version's document to a dedicated, access-restricted S3
   bucket (a chain-of-custody step, matching Day 19's evidence-handling concept) *before*
   taking any further action.
3. **Notify:** publish to the same SNS topic this lab's `setup.sh` already created, now
   with a message indicating auto-remediation already occurred, so the human on the
   other end investigates the *root cause* (why did this principal have
   `CreatePolicyVersion` in the first place) rather than re-doing the rollback manually.
4. **Deliberately not automated in this design:** deactivating the principal's access
   keys or attaching an explicit deny is left as a human's next step, not the Lambda's —
   a larger, harder-to-instantly-reverse action that a single automated finding (which,
   rarely, could be a false positive) shouldn't trigger on its own.

**What would make this production-grade, named but not built here:** idempotency
(handling the same finding delivered twice by EventBridge's at-least-once delivery),
a dead-letter queue for failed remediation attempts, and Security Hub integration so
the remediation status is visible alongside the original finding rather than only in
CloudTrail/Lambda's own logs.
