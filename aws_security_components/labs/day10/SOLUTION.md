# `labs/day10` — SOLUTION

Expected outputs, the SCP-precedence proof, and the fix rationale.

## 1. SCP-precedence proof (written trace — the simulator does NOT model SCPs)

**Why a written trace and not just the simulator:** AWS's IAM Policy
Simulator evaluates identity-based policies, resource-based policies, and
permission boundaries — but it does **not** evaluate Organizations SCPs/RCPs.
That's exactly why the brief for this day asks for "the policy simulator
OR a written trace": the simulator covers steps 3–5 of the order; SCP is
step 2, and a single-account learner also has no real Organization to test
it against. The trace below is the actual proof for the SCP layer.

### Scenario

- **SCP** (`data.aws_iam_policy_document.deny_cloudtrail_tamper` in
  `main.tf`), attached at the org root or an OU covering every workload
  account:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "DenyCloudTrailTamper",
      "Effect": "Deny",
      "Action": ["cloudtrail:StopLogging", "cloudtrail:DeleteTrail", "cloudtrail:UpdateTrail"],
      "Resource": "*"
    }]
  }
  ```
- **Identity policy**, attached to some IAM role in a member account under
  that OU — deliberately permissive, e.g. an "admin" role with:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{ "Effect": "Allow", "Action": "cloudtrail:*", "Resource": "*" }]
  }
  ```
- **Request:** that role calls `cloudtrail:StopLogging` on the account's
  trail.

### Trace (canonical order: explicit Deny → SCP/RCP → resource policy →
identity policy → permission boundary → session policy)

| Step | Layer | Result | Evaluation continues? |
|---|---|---|---|
| 1 | Explicit deny (on the caller's own identity/resource policies) | None present | Yes |
| 2 | **SCP/RCP** | `Deny` matches `cloudtrail:StopLogging` — **explicit Deny found** | **No — STOP** |
| 3 | Resource-based policy | *never evaluated* | — |
| 4 | Identity-based policy | *never evaluated* — the `Allow` on `cloudtrail:*` is real, but irrelevant | — |
| 5 | Permission boundary | *never evaluated* | — |
| 6 | Session policy | *never evaluated* | — |

**Final decision: `Deny`.** Expected error text on the actual API call
(recorded for real if you flip `enable_org_resources = true` against a
real Organizations management account and attempt the call from a member
account under that OU):

```
An error occurred (AccessDeniedException) when calling the StopLogging operation:
User: arn:aws:sts::<member-account-id>:assumed-role/<admin-role>/<session>
is not authorized to perform: cloudtrail:StopLogging with an explicit deny
in a service control policy
```

Note the error text itself names the SCP as the reason, and specifically
as an **explicit deny** — because this SCP is deny-list-shaped (a real
`Deny` statement targeting this action), not allow-list-shaped. AWS's own
`AccessDeniedException` message distinguishes this "explicit deny in a
service control policy" wording from the "because no service control
policy allows..." wording an *allow-list* SCP would produce if this
action simply weren't on its allow list — either phrasing is a second,
independent confirmation that the SCP layer is the one that fired, not
the identity layer, but the exact wording tells you which SCP shape you're
looking at.

## 2. ABAC + permission-boundary intersection (simulator-verifiable)

After `terraform apply` and `null_resource.apply_abac_tags` running
(tags applied to the base app bucket: `Project=aws-sec-lab`,
`Environment=sandbox`, `DataClassification=internal`):

**Simulate `s3:GetObject` for `abac_demo_role` against the tagged base
bucket**, passing the resource's tags as simulator context
(`--resource-handling-option` / resource tag context entries with key
`aws:ResourceTag/Project` = `aws-sec-lab`, matching the role's own
`Project` tag):

```
$ aws iam simulate-principal-policy \
    --policy-source-arn "$(terraform output -raw abac_demo_role_arn)" \
    --action-names s3:GetObject \
    --resource-arns "$(terraform output -json tagged_base_resources | jq -r .bucket_name)" \
    --context-entries ContextKeyName=aws:ResourceTag/Project,ContextKeyValues=aws-sec-lab,ContextKeyType=string

EvalActionName: s3:GetObject
EvalResourceName: arn:aws:s3:::<base-bucket-name>
EvalDecision: allowed
```

**Same simulation, against a different bucket ARN NOT carrying
`Project=aws-sec-lab`** (omit the matching context entry, or supply a
different value):

```
EvalActionName: s3:GetObject
EvalResourceName: arn:aws:s3:::some-other-untagged-bucket
EvalDecision: implicitDeny
```

**Why `implicitDeny` and not an explicit `Deny`:** the permission
boundary is an allow-list ceiling, not a deny statement — when the
`Condition` doesn't match, the boundary simply doesn't grant anything for
that resource, and a permission boundary that grants nothing for a given
request results in an implicit deny for that request, same as any
identity policy with no matching `Allow`. The identity policy's own
`Resource: "*"` would have allowed this on its own; the boundary is what
narrows it.

Live `AccessDenied` text you'd see calling `s3:GetObject` for real against
the untagged bucket, as the assumed `abac_demo_role`:

```
An error occurred (AccessDenied) when calling the GetObject operation:
User: arn:aws:sts::<account-id>:assumed-role/aws-sec-lab-day10-abac-demo/<session>
is not authorized to perform: s3:GetObject on resource:
"arn:aws:s3:::some-other-untagged-bucket/<key>" because no permissions
boundary allows the s3:GetObject action
```

## 3. Fix rationale

- The SCP proof matters because it's the only layer in the whole sprint
  that a member-account identity policy, however permissive, cannot
  override — it's the correct place to put a control you never want any
  account admin to be able to talk their way around (CloudTrail tamper,
  leaving the org, disabling the SCP-attachment mechanism itself).
- The ABAC proof matters because it shows the boundary doing real,
  resource-specific narrowing — not just "a boundary exists," but "the
  same identity policy, unmodified, produces a different effective
  permission depending on which resource's tags it's checked against."
  That's the scaling property: add a hundred more Project-tagged
  resources and this exact boundary + identity policy pair needs zero
  edits to cover them.
- The merge-safe S3 tagging step (`scripts/tag-base-resources.sh`) matters
  because `labs/base`'s bucket already carried tags
  (`Project`/`ManagedBy`/`Layer` from `common_tags`) before Day 10 ever
  ran — a naive `put-bucket-tagging` call would have silently replaced
  them, breaking any future automation keyed on `ManagedBy=terraform`.

## Expected `terraform plan`/`apply` behavior on this module

- With `enable_org_resources = false` (default): plan shows the SCP
  `data` source evaluated (readable in `output.scp_policy_json`), but
  **zero** `aws_organizations_policy*` resources planned (count = 0).
  Apply creates only the demo role, its inline policy, the boundary
  policy, and the `null_resource` tagging step.
- With `enable_org_resources = true` from a non-management account or
  outside an Organization entirely: `apply` will fail on the
  `aws_organizations_policy` resource with an AWS API error (not a
  Terraform-side error) — expected, and the reason this defaults to
  `false`.
