# Capstone attack — expected artifacts (SOLUTION)

Companion to `attack-runbook.md` and `attack.sh`. This records what each
stage *should* produce in your own account, so you can self-check what
you actually captured against what should be there. Real finding IDs,
ARNs, and timestamps are yours to fill in from your own run — nothing
here is a real identifier from any AWS account.

## Stage-by-stage expected output

### Stage 1 — Leaked access key (narrated)

- `aws sts get-caller-identity` returns your deployer identity's
  `Account`, `UserId`, `Arn`. No detection artifact expected — this is
  initial access, indistinguishable (on its own) from normal operator
  activity. That's realistic: leaked-key use rarely looks anomalous
  until it's paired with something it shouldn't be doing.

### Stage 2 — Recon

- `describe-load-balancers` / `list-services` succeed with `HTTP 200`-
  equivalent CLI success (exit code 0), returning your base workload's
  ALB and ECS service metadata.
- **CloudTrail:** look up events named `DescribeLoadBalancers`,
  `ListServices` (event source `elasticloadbalancing.amazonaws.com`,
  `ecs.amazonaws.com`) in the incident window, `userIdentity.arn`
  matching your Stage-1 caller identity, `errorCode` absent (successful
  calls). Nothing anomalous by itself — this is why recon alone rarely
  trips GuardDuty; it looks like normal operator read access.

### Stage 3 — SSRF exploit

- The `curl` to `/fetch?url=...` returns `HTTP 200` with a JSON body
  containing `AccessKeyId`, `SecretAccessKey`, `Token`, `Expiration`,
  and (typically) a `RoleArn` matching your base workload's task role.
- **No CloudTrail event for this stage.** The HTTP request to your own
  ALB/app is not an AWS API call CloudTrail observes — this is a
  deliberate teaching point: the SSRF itself is invisible to CloudTrail;
  only what happens *with* the credentials it returns becomes visible.

### Stage 4 — Credential theft confirmed

- `aws sts get-caller-identity`, run with the exported stolen
  credentials, returns an `Arn` in the shape
  `arn:aws:sts::<account-id>:assumed-role/<task-role-name>/<session-id>`
  — this is the pivot: everything from here on carries this ARN, not
  your Stage-1 deployer ARN.
- No detection artifact expected purely from this call in isolation —
  a single `GetCallerIdentity` from the task role's own credentials, on
  its own, is unremarkable. The anomaly signal comes from *where* the
  next calls originate from (outside AWS), not from this call itself.

### Stage 5 — Data exfil

- `aws s3 ls` / `aws s3 sync` / `aws dynamodb scan`, run with the stolen
  credentials from your workstation, succeed and pull down the base
  workload's actual objects/items.
- **CloudTrail:** `GetObject`/`ListObjectsV2` (event source
  `s3.amazonaws.com`) and `Scan` (event source `dynamodb.amazonaws.com`)
  events, `userIdentity` of type `AssumedRole` with the task role's
  session ARN from Stage 4, and — the key forensic tell —
  `sourceIPAddress` matching your workstation's public IP, **not** an
  AWS-internal or VPC-associated address. That mismatch (task-role
  credentials, non-AWS source IP) is the signature of stolen-and-
  relocated credentials.
- **GuardDuty:** expect a finding in the
  `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration` family
  (exact type name may vary — GuardDuty has extended this detector
  family to cover container/task credentials, and AWS's naming evolves;
  record whatever type your account actually shows). Fields to capture:
  `Type`, `Severity`, `CreatedAt`, the `Resource` block naming the task
  role, and the finding `Id`.
- **Security Hub:** a corresponding finding, ARN of the form
  `arn:aws:securityhub:<region>:<account-id>:finding/<uuid>`, `CreatedAt`
  a few seconds to a couple of minutes after the GuardDuty finding's
  `CreatedAt` (Security Hub ingests GuardDuty findings rather than
  generating this one natively). Capture `SeverityLabel` and the
  `Types` array.

### Stage 6 — Crypto-mining-flavored call (dry-run stand-in)

- `aws ec2 run-instances --dry-run` returns a client error whose message
  contains `DryRunOperation` (something like `An error occurred
  (DryRunOperation) when calling the RunInstances operation: Request
  would have succeeded, but DryRun flag is set.`). **This is the
  success signal for this stage** — no instance is launched, no cost is
  incurred.
- **CloudTrail:** a `RunInstances` event (event source
  `ec2.amazonaws.com`), same assumed-role ARN and same external
  `sourceIPAddress` as Stage 5, `errorCode: "Client.DryRunOperation"`.
  Even though nothing launched, the *attempt* is fully logged — this is
  the point: CloudTrail captures intent, not just successful outcomes.
- **GuardDuty:** a dry-run call may or may not be enough on its own to
  trip a distinct crypto-mining finding type (e.g.
  `CryptoCurrency:EC2/BitcoinTool.B!DNS` is triggered by actual mining
  network traffic, which this safe stand-in deliberately does not
  generate). Don't force a match here — record honestly whether a
  second finding appeared or whether this stage only shows up in
  CloudTrail. That gap is itself a useful lesson: intent captured in
  logs and impact captured by a threat detector are not the same
  guarantee.

### Forensic cross-check — Config

- `aws configservice get-resource-config-history` on the S3 bucket and
  on the task role's inline policy, scoped to the incident window,
  should show **no configuration changes** — the bucket policy and the
  task role's grant are exactly what they were before the incident
  started.
- This is a meaningful negative result, not a null one: it rules out
  "someone widened a policy" as the cause and confirms this incident is
  pure credential theft plus abuse of an existing (if over-broad) grant
  — which is exactly what Day 12's eradication step needs to know before
  deciding what to fix.

## Completed timeline template

Fill this in from your own run (`attack-SOLUTION.md` intentionally ships
without real values — these are yours to capture):

| Stage | Timestamp | Artifact type | Artifact ID / reference |
|---|---|---|---|
| 2 (recon) | | CloudTrail eventID | |
| 4 (theft confirmed) | | CloudTrail eventID | |
| 5 (exfil) | | CloudTrail eventID(s) | |
| 5 (exfil) | | GuardDuty finding ID | |
| 5 (exfil) | | Security Hub finding ARN | |
| 6 (dry-run) | | CloudTrail eventID | |
| — (cross-check) | window start–end | Config history — no changes found | |

## What this is not

This SOLUTION file records **expected artifacts for the attack**, not
the fix. Nothing here revokes the stolen credentials, tightens the task
role, or closes the SSRF hole — that's Day 12's `defend-runbook.md`
(driven from [`labs/day12/`](../day12/README.md)), which reads the
timeline you build from this file as its starting evidence.
