# Day 9 lab — SOLUTION

Expected outputs, evidence format, and fix rationale for both
pipelines. Exact IDs/timestamps will differ per run — the shapes below
are what to expect and compare against.

## Pipeline 1 — GuardDuty → EventBridge → quarantine Lambda

### Before containment

```
$ AWS_ACCESS_KEY_ID=ASIA... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=... \
  aws s3 ls s3://aws-sec-lab-appdata-123456789012
                           PRE uploads/
2026-08-18 10:03:11        842 note.txt
```

Succeeds — the stolen credential from Day 8 is still fully live.

### Triggering the Lambda (synthetic test event)

```
$ aws lambda invoke --function-name aws-sec-lab-day09-quarantine \
    --payload file:///tmp/test-finding.json \
    --cli-binary-format raw-in-base64-out /tmp/quarantine-result.json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
$ cat /tmp/quarantine-result.json
{
  "action": "quarantined",
  "role_name": "aws-sec-lab-task-role",
  "role_arn": "arn:aws:iam::123456789012:role/aws-sec-lab-task-role",
  "finding_id": "test-finding-0001",
  "finding_type": "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS",
  "severity": 8.5,
  "boundary_attached": "arn:aws:iam::123456789012:policy/aws-sec-lab-day09-quarantine-boundary",
  "revoke_policy_attached": "Day09RevokeOldSessions",
  "contained_at": "2026-08-19T14:02:37Z"
}
```

(Note: the test payload's `accessKeyDetails.userName` is set to the
REAL task role's name, substituted from `terraform output` — that
match against `TASK_ROLE_NAME` is exactly what the Lambda's safety
guardrail checks before acting, per the design in
`lambda_src/quarantine.py`. A finding naming any other principal —
including GuardDuty's own synthetic sample findings — is logged
`"action": "refused"` and touches nothing.)

### CloudWatch Logs (the containment record)

```
$ aws logs tail /aws/lambda/aws-sec-lab-day09-quarantine --since 5m
2026-08-19T14:02:37Z {"action": "quarantined", "role_name": "aws-sec-lab-task-role", ...}
```

### Role state after containment

```
$ aws iam get-role --role-name aws-sec-lab-task-role \
    --query 'Role.[PermissionsBoundary,Tags]'
[
    {
        "PermissionsBoundaryType": "Policy",
        "PermissionsBoundaryArn": "arn:aws:iam::123456789012:policy/aws-sec-lab-day09-quarantine-boundary"
    },
    [
        {"Key": "quarantine", "Value": "true"},
        {"Key": "quarantine-finding-id", "Value": "test-finding-0001"},
        {"Key": "quarantine-finding-type", "Value": "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS"},
        {"Key": "quarantine-timestamp", "Value": "2026-08-19T14:02:37Z"}
    ]
]

$ aws iam list-role-policies --role-name aws-sec-lab-task-role
{
    "PolicyNames": ["aws-sec-lab-task-policy", "Day09RevokeOldSessions"]
}
```

### After containment — the exact same stolen credential, same command

```
$ AWS_ACCESS_KEY_ID=ASIA... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=... \
  aws s3 ls s3://aws-sec-lab-appdata-123456789012

An error occurred (AccessDenied) when calling the ListObjectsV2 operation:
User: arn:aws:sts::123456789012:assumed-role/aws-sec-lab-task-role/<session>
is not authorized to perform: s3:ListBucket on resource:
"arn:aws:s3:::aws-sec-lab-appdata-123456789012" with an explicit deny in
a permissions boundary
```

**This is the containment signal.** Same credential, same command, now
`AccessDenied` — and the error text itself names the mechanism
("explicit deny in a permissions boundary"), which is the concrete,
observable proof the automation fired and worked.

### Fix rationale

The permission boundary caps the intersection of what the role's
identity policy grants down to nothing, regardless of the credential's
age — it takes effect on the very next API call, not on next login,
because IAM evaluates the boundary live per-request. The
`Day09RevokeOldSessions` inline deny is redundant with the boundary on
this single-purpose role (both fire and both would independently
produce the same `AccessDenied`), included specifically so the
token-time technique is demonstrated end to end even though this
particular role didn't strictly need it — see content/day09 exercise 3
for the role shape where it *would* be the only appropriate tool.

## Pipeline 2 — Config rule → automatic remediation

### Before remediation

```
$ aws configservice start-config-rules-evaluation \
    --config-rule-names aws-sec-lab-day09-s3-public-read-prohibited

$ aws configservice get-compliance-details-by-config-rule \
    --config-rule-name aws-sec-lab-day09-s3-public-read-prohibited \
    --compliance-types NON_COMPLIANT
{
  "EvaluationResults": [
    {
      "EvaluationResultIdentifier": {
        "EvaluationResultQualifier": {
          "ConfigRuleName": "aws-sec-lab-day09-s3-public-read-prohibited",
          "ResourceType": "AWS::S3::Bucket",
          "ResourceId": "aws-sec-lab-day09-config-demo-123456789012"
        }
      },
      "ComplianceType": "NON_COMPLIANT"
    }
  ]
}

$ aws s3api get-public-access-block --bucket aws-sec-lab-day09-config-demo-123456789012
{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": false, "IgnorePublicAcls": false,
    "BlockPublicPolicy": false, "RestrictPublicBuckets": false
  }
}
```

### After automatic remediation (fires within minutes of the NON_COMPLIANT evaluation, no manual trigger needed)

```
$ aws s3api get-public-access-block --bucket aws-sec-lab-day09-config-demo-123456789012
{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": true, "IgnorePublicAcls": true,
    "BlockPublicPolicy": true, "RestrictPublicBuckets": true
  }
}

$ aws configservice get-compliance-details-by-config-rule \
    --config-rule-name aws-sec-lab-day09-s3-public-read-prohibited \
    --compliance-types COMPLIANT
{
  "EvaluationResults": [
    {
      "EvaluationResultIdentifier": {
        "EvaluationResultQualifier": {
          "ResourceId": "aws-sec-lab-day09-config-demo-123456789012"
        }
      },
      "ComplianceType": "COMPLIANT"
    }
  ]
}
```

If the automatic remediation hasn't fired yet when you check (Config's
remediation loop isn't instant — allow a few minutes), force it:

```bash
aws configservice start-remediation-execution \
  --config-rule-name aws-sec-lab-day09-s3-public-read-prohibited \
  --resource-keys ResourceType=AWS::S3::Bucket,ResourceId=aws-sec-lab-day09-config-demo-123456789012
```

### Fix rationale

`S3_BUCKET_PUBLIC_READ_PROHIBITED` evaluates the bucket's actual
resolved public accessibility (policy + ACL + access-block settings
together), not just one setting in isolation — which is why the demo
bucket needed both the public-access-block disabled *and* an explicit
public-read bucket policy to be genuinely flagged. The paired
`AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock` remediation
re-enables all four public-access-block settings, which is sufficient
to make the bucket policy's public grant inert (Block Public Policy +
Restrict Public Buckets override an existing public policy statement
without requiring you to also rewrite or delete that policy) — the
bucket goes from actually-public to actually-private without any
human editing a policy document by hand.

## Containment scope reminder

Both pipelines only ever touch resources their own execution role is
explicitly scoped to (`iam:PutRolePermissionsBoundary` etc. limited to
the one task role ARN; the SSM remediation role limited to the one
demo bucket ARN). Nothing in this lab can act on a resource outside
`labs/base` or this module, even given an unexpected event payload —
verify this by reading the two `aws_iam_role_policy` resources in
`main.tf` before trusting the automation with anything real.
