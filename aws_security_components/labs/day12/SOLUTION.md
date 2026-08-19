# Day 12 lab — SOLUTION

Expected outputs for each phase. Placeholders (`<...>`) stand in for
values that are unique to your own account/apply — never real
account IDs, ARNs, or key material belong in this file.

## CONTAIN

| Action | Expected output |
|---|---|
| `aws iam update-access-key --status Inactive` on the leaked key | Exit 0, no output. Follow-up `aws sts get-caller-identity` with that key → `An error occurred (InvalidClientTokenId) when calling the GetCallerIdentity operation: The security token included in the request is invalid` |
| `aws iam delete-access-key` | Exit 0, no output. Follow-up call with that key → `An error occurred (InvalidAccessKeyId) when calling the GetCallerIdentity operation: The AWS Access Key Id ... does not exist in our records.` |
| `aws iam put-role-policy` (break-glass `Deny *`) | Exit 0, no output. `/whoami` on the app → HTTP 5xx (connection reset or 500 depending on how the app's boto3 call fails once its own role is denied `sts:GetCallerIdentity` too — this is expected collateral of a full `Deny *`, not a bug) |
| (optional) `aws ecs update-service --desired-count 0` | `"desiredCount": 0` in the JSON response; task count drops to 0 within ~1-2 minutes |

## ERADICATE

`terraform plan` (manual review, since Terraform is not installed in
this authoring environment) should show, added, in this shape:

```
+ aws_iam_role_policy.eradicate_tighten
    name   = "aws-sec-lab-task-day12-eradicate-deny"
    role   = "aws-sec-lab-task-role"
    policy = jsonencode(5 statements: DenyS3DeleteAnywhereInBucket,
             DenyS3ReadWriteOutsideAllowedPrefix,
             DenyDynamoDBBulkScan,
             DenyEc2ComputePivot,
             DenyDirectKmsUseNotViaTrustedService)

+ aws_wafv2_web_acl.capstone_defend
    scope = "REGIONAL"
    default_action = allow
    rule: block-metadata-ssrf-in-url-param (priority 1, action=block,
          OR of 4 byte_match_statement CONTAINS checks against the
          query_string, URL_DECODE transform)

+ aws_wafv2_web_acl_association.alb
    resource_arn = <base alb_arn>

+ aws_iam_user.leaked                 (only if create_leaked_user_fixture=true)
+ aws_iam_user_policy.leaked_recon_only
+ aws_iam_access_key.leaked
```

`terraform apply` → 3 resources added always (`eradicate_tighten`,
`capstone_defend`, `web_acl_association.alb`), plus 3 more
(`aws_iam_user.leaked`, `aws_iam_user_policy.leaked_recon_only`,
`aws_iam_access_key.leaked`) if `create_leaked_user_fixture = true` —
3–6 total, 0 changed, 0 destroyed.

`aws iam delete-role-policy --policy-name emergency-quarantine` (removing
the break-glass policy) → exit 0, no output. App's `/whoami` recovers to
200 within seconds (no break-glass Deny left; the new permanent Deny
doesn't block `sts:GetCallerIdentity` or the app's own scoped access).

## RECOVER

| Check | Expected |
|---|---|
| `curl .../whoami` | HTTP 200, JSON body with `account`, `arn` (the task role's ARN), `app_bucket`, `app_table` |
| `curl ".../fetch?url=https://example.com"` | HTTP 200, body = example.com's HTML |
| App's own S3 read/write on `app-data/*` | HTTP 200 (unaffected — inside `app_object_prefix`) |
| ECS service task count | back to 1 (or whatever `desired_count` was before containment) |

## Success signal — attack now blocked

**Credentials setup first.** The stolen creds are STS temporary
credentials (an `AccessKeyId`/`SecretAccessKey` pair alone will fail
with an invalid-token error, independent of any policy, because a
session token is also required). There's no AWS CLI profile named
`stolen-creds` defined anywhere — don't reference one. Reuse Day 11's
own `attack.sh` pattern instead: export all three env vars in the
shell you run these commands from —

```
$ export AWS_ACCESS_KEY_ID="<stolen AccessKeyId>"
$ export AWS_SECRET_ACCESS_KEY="<stolen SecretAccessKey>"
$ export AWS_SESSION_TOKEN="<stolen SessionToken>"
```

```
$ curl -s -o /dev/null -w "%{http_code}\n" \
  "http://<alb_dns_name>/fetch?url=http://169.254.170.2/v2/credentials/<GUID>"
403

$ aws s3api delete-object --bucket <app_bucket_name> --key app-data/anything
An error occurred (AccessDenied) when calling the DeleteObject operation: User: arn:aws:sts::<acct>:assumed-role/aws-sec-lab-task-role/<session> is not authorized to perform: s3:DeleteObject on resource: "arn:aws:s3:::aws-sec-lab-appdata-<acct>/app-data/anything" with an explicit deny in an identity-based policy

$ aws dynamodb scan --table-name aws-sec-lab-appdata
An error occurred (AccessDenied) when calling the Scan operation: User: arn:aws:sts::<acct>:assumed-role/aws-sec-lab-task-role/<session> is not authorized to perform: dynamodb:Scan on resource: "arn:aws:dynamodb:<region>:<acct>:table/aws-sec-lab-appdata" with an explicit deny in an identity-based policy

$ aws s3api get-object --bucket <app_bucket_name> --key some/other-prefix/file /tmp/out
An error occurred (AccessDenied) when calling the GetObject operation: User: ... is not authorized to perform: s3:GetObject on resource: "...some/other-prefix/file" with an explicit deny in an identity-based policy

$ aws kms decrypt --ciphertext-blob fileb://exfiltrated.bin
An error occurred (AccessDenied) when calling the Decrypt operation: ... with an explicit deny in an identity-based policy

$ aws ec2 run-instances --dry-run --instance-type m5.24xlarge --image-id ami-00000000000000000
An error occurred (UnauthorizedOperation) when calling the RunInstances operation: You are not authorized to perform this operation...
```

**The EC2 line is intentionally NOT `AccessDenied`.** EC2's dry-run
convention is its own: `DryRunOperation` means the call would have
succeeded (permission check passed), `UnauthorizedOperation` means the
permission check failed — that's the correct, expected signal here,
not a different/lesser proof than the generic `AccessDenied` every
other service (S3/DynamoDB/KMS/IAM) returns for a deny. Don't expect
`AccessDenied` on this one line; `UnauthorizedOperation` is what
`DenyEc2ComputePivot` produces.

The `"with an explicit deny in an identity-based policy"` phrase in
the non-EC2 messages is the tell that the *new* Deny is doing the work
(not, for instance, a bucket policy or SCP) — exactly the door this
lab targeted. Unset the exported credentials
(`unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`)
once you're done verifying.

## Fix rationale (why each Deny statement, tied to the incident)

- `DenyS3DeleteAnywhereInBucket` — the app never calls `DeleteObject`;
  this closed the action the attacker used to (attempt) destructive
  exfil cover-up, with zero legitimate-traffic impact.
- `DenyS3ReadWriteOutsideAllowedPrefix` — the app only ever touches
  `app-data/*`; this shrinks the blast radius of any *future* stolen
  credential from "the whole bucket" to "one prefix," independent of
  whether the SSRF hole is ever found again.
- `DenyDynamoDBBulkScan` — the app does item-level `GetItem`/`PutItem`,
  never a table-wide `Scan`; this was the exact action the attacker
  used for bulk exfil from the DB tier.
- `DenyEc2ComputePivot` — the task role has no legitimate reason to
  call any EC2 action. Day 11's pre-fix `--dry-run` check on this
  pivot may have returned `DryRunOperation` (permission check passed)
  or `UnauthorizedOperation` (already denied) depending on exactly
  what your account's task role carried when you ran it — check your
  own `attack-SOLUTION.md`. Either pre-fix result, the post-fix re-run
  above should now return `UnauthorizedOperation` — this Deny closes
  the pivot permanently and provably rather than leaning on an
  absence-of-grant.
- `DenyDirectKmsUseNotViaTrustedService` — ties to
  [Antipattern #5](../../content/ANTIPATTERNS.md#5-trusting-default-encryption-without-asking-who-can-decrypt): `Decrypt`
  is legitimately needed via S3/DynamoDB/Secrets Manager doing
  server-side work on the app's behalf, but a stolen credential
  calling `kms:Decrypt` *directly* (to decrypt exfiltrated ciphertext
  offline) is not a legitimate call pattern — `kms:ViaService`
  distinguishes the two.
- WAF rule — closes the request-layer entry point itself (the SSRF),
  independent of the IAM fix; the two together are defense in depth,
  not redundant (see Exercise 2 in the content file for why network
  controls can't do this job here).

## CERT-MAP self-assessment — expected artifact, not a score

There's no "correct" score to record here — the point of the checklist
in `CERT-MAP.md` is an honest self-assessment. What belongs in
`journal.md` is: your six scores, and for any domain below 3, which
day's lab you're re-running before deciding whether to schedule the
exam.
