# Day 1 lab — solution and expected output

Placeholders below: `<ACCOUNT_ID>` and `<REGION>` — substitute your own
(never commit real values). `<PROJECT>` = your `project` variable from
`labs/base` (default `aws-sec-lab`), so the bucket name is
`<PROJECT>-appdata-<ACCOUNT_ID>` and the role name is
`<PROJECT>-task-role`.

## Simulator verdicts — before harden (THE BREAK)

| Trace | Action | Resource | `EvalDecision` | Matched statement |
|---|---|---|---|---|
| 1 | `s3:DeleteObject` | `.../app-data/example.txt` | `allowed` | base `BroadButWorkloadScopedAppDataAccess` |
| 2 | `s3:ListBucket` | bucket itself | `allowed` | base `BroadButWorkloadScopedAppDataAccess` |
| 3 | `s3:GetObject` | `.../other-prefix/example.txt` | `allowed` | base `BroadButWorkloadScopedAppDataAccess` |

Abbreviated real CLI output shape for Trace 1 (before harden):

```json
{
    "EvaluationResults": [
        {
            "EvalActionName": "s3:DeleteObject",
            "EvalResourceName": "arn:aws:s3:::<PROJECT>-appdata-<ACCOUNT_ID>/app-data/example.txt",
            "EvalDecision": "allowed",
            "MatchedStatements": [
                {
                    "SourcePolicyId": "<PROJECT>-task-policy",
                    "SourcePolicyType": "IAM Policy"
                }
            ]
        }
    ]
}
```

## Simulator verdicts — after harden (THE HARDEN)

| Trace | Action | Resource | `EvalDecision` | Matched statement |
|---|---|---|---|---|
| 1 | `s3:DeleteObject` | `.../app-data/example.txt` | `explicitDeny` | day01 overlay, `DenyDeleteAndListWholeBucket` |
| 2 | `s3:ListBucket` | bucket itself | `explicitDeny` | day01 overlay, `DenyDeleteAndListWholeBucket` |
| 3 | `s3:GetObject` | `.../other-prefix/example.txt` | `explicitDeny` | day01 overlay, `DenyGetPutOutsideAppPrefix` |
| contrast | `s3:GetObject` + `s3:PutObject` | `.../app-data/example.txt` | `allowed` (both) | base `BroadButWorkloadScopedAppDataAccess` |

Abbreviated real CLI output shape for Trace 1 (after harden):

```json
{
    "EvaluationResults": [
        {
            "EvalActionName": "s3:DeleteObject",
            "EvalResourceName": "arn:aws:s3:::<PROJECT>-appdata-<ACCOUNT_ID>/app-data/example.txt",
            "EvalDecision": "explicitDeny",
            "MatchedStatements": [
                {
                    "SourcePolicyId": "day01-deny-out-of-scope-s3-access",
                    "SourcePolicyType": "IAM Policy"
                }
            ]
        }
    ]
}
```

## Equivalent live-call `AccessDenied` text (for reference)

The task role can't be assumed directly for a live test (see README —
its trust policy only allows `ecs-tasks.amazonaws.com`), so these are
documented for completeness/pattern-recognition, not something you run
today. If the app (or a future lab) made these calls with the task
role's real vended credentials post-harden, the AWS CLI/SDK error text
would read:

**Trace 1 — `s3:DeleteObject`:**

```
An error occurred (AccessDenied) when calling the DeleteObject operation: User: arn:aws:sts::<ACCOUNT_ID>:assumed-role/<PROJECT>-task-role/<session-id> is not authorized to perform: s3:DeleteObject on resource: "arn:aws:s3:::<PROJECT>-appdata-<ACCOUNT_ID>/app-data/example.txt" with an explicit deny in an identity-based policy
```

**Trace 2 — `s3:ListBucket`:**

```
An error occurred (AccessDenied) when calling the ListObjectsV2 operation: User: arn:aws:sts::<ACCOUNT_ID>:assumed-role/<PROJECT>-task-role/<session-id> is not authorized to perform: s3:ListBucket on resource: "arn:aws:s3:::<PROJECT>-appdata-<ACCOUNT_ID>" with an explicit deny in an identity-based policy
```

**Trace 3 — `s3:GetObject` out of prefix:**

```
An error occurred (AccessDenied) when calling the GetObject operation: User: arn:aws:sts::<ACCOUNT_ID>:assumed-role/<PROJECT>-task-role/<session-id> is not authorized to perform: s3:GetObject on resource: "arn:aws:s3:::<PROJECT>-appdata-<ACCOUNT_ID>/other-prefix/example.txt" with an explicit deny in an identity-based policy
```

Note the phrasing: `with an explicit deny in an identity-based policy`
— distinct from the phrasing AWS uses for an **implicit** deny (no
matching `Allow` anywhere), which instead reads `because no
identity-based policy allows the <action> action`. Every denial in
this lab is the *explicit* form, because the harden technique is an
explicit-Deny overlay (see `content/day01-iam-engine.md` and `main.tf`'s
header comment) — this is a genuinely useful tell when reading a real
`AccessDenied` message: the exact wording tells you whether you're
looking for a `Deny` statement (fix: find and understand it) or a
missing `Allow` (fix: add one).

## Fix rationale

- **Why an overlay instead of editing `labs/base/iam.tf`:** every other
  day's module in this sprint layers on `labs/base` as-is; editing it
  here would ripple into every later day's assumptions about what's
  already deployed. Attaching a second identity-based policy to the
  same role, carrying only explicit `Deny` statements for the excess,
  achieves the same effective tightening without touching the shared
  base at all.
- **Why this reliably wins over the base `Allow`:** per the canonical
  evaluation order, an explicit `Deny` in *any* applicable
  identity-based policy attached to a principal overrides an `Allow`
  in any *other* identity-based policy attached to that same
  principal — multiple policies on one role are reconciled together,
  not evaluated independently. This is tier 1 of the order applying
  *within* tier 4, not a separate mechanism.
- **Why `NotResource` for the prefix restriction, not a narrower
  `Resource`:** the base `Allow` already grants across the whole
  bucket; the only way to *remove* scope from an existing `Allow`
  without editing it is an explicit `Deny` that matches everything
  outside the wanted scope. `NotResource` is the standard IAM
  mechanism for expressing "everything except this."
- **Why `DenyGetPutOutsideAppPrefix`'s `NotResource` is not additionally
  scoped to this one bucket:** the task role is never granted
  `s3:GetObject`/`s3:PutObject` on any bucket other than `app_data` in
  the base policy — there is nothing else in scope for this statement
  to unintentionally deny. Flagged explicitly in `main.tf`'s header
  comment as a simplification that would need revisiting if this role
  ever gained broader S3 grants elsewhere.
