# Solution — Day 13: Cloud Security Model & IAM Foundations

Full worked walkthrough: assessing the over-permissive grant, rewriting it, and the
policy-evaluation reasoning behind both. Read [`content/day13-cloud-iam.md`](../../content/day13-cloud-iam.md)
first and attempt the lab yourself — this document assumes you've already run
`./setup.sh`.

## 1. Assessing the over-permissive policy

### Reading it (Section 2, Step 2)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OverlyBroadS3FullAccess",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    },
    {
      "Sid": "ScopedEC2ReadOnly",
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
```

Reading alone tells you `OverlyBroadS3FullAccess` is suspicious (any `*` wildcard on
both `Action` and `Resource` is a signal worth investigating), but it doesn't tell you
*how bad* — for that you need Step 3's simulator call.

### Proving it (Section 2, Step 3)

```sh
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::<ACCOUNT_ID>:user/cyberlab-day13-user" \
  --action-names s3:DeleteBucket s3:PutBucketPolicy \
  --resource-arns "arn:aws:s3:::some-completely-unrelated-bucket" \
  --profile "$AWS_PROFILE" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table
```

Representative output:

```
-------------------------------------------
|          SimulatePrincipalPolicy         |
+---------------------+---------------------+
|  s3:DeleteBucket     |  allowed            |
|  s3:PutBucketPolicy  |  allowed            |
+---------------------+---------------------+
```

Both come back `allowed` — against a bucket named nothing like anything this user
should ever touch. That's the concrete proof: `s3:*`/`Resource: "*"` isn't a
theoretical overreach, it's a live, exploitable path to destroying or hijacking any
bucket in the account, from an identity whose actual job (per the lab's framing) never
needed more than reading and writing objects in its own lab bucket.

## 2. Rewriting to least privilege

Before (attached by `setup.sh`, [`policies/overpermissive-policy.json`](policies/overpermissive-policy.json)):

```json
{
  "Sid": "OverlyBroadS3FullAccess",
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}
```

After ([`policies/least-privilege-policy.json`](policies/least-privilege-policy.json)):

```json
{
  "Sid": "ScopedS3ReadWriteOwnBucketsOnly",
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
  "Resource": [
    "arn:aws:s3:::cyberlab-day13-*",
    "arn:aws:s3:::cyberlab-day13-*/*"
  ]
}
```

Applied as a new default policy version:

```sh
aws iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document file://policies/least-privilege-policy.json \
  --set-as-default \
  --profile "$AWS_PROFILE"
```

Re-running the exact Step 3 simulator call afterward:

```
-------------------------------------------
|          SimulatePrincipalPolicy         |
+---------------------+---------------------+
|  s3:DeleteBucket     |  implicitDeny       |
|  s3:PutBucketPolicy  |  implicitDeny       |
+---------------------+---------------------+
```

Now `implicitDeny` for both — nothing in the rewritten policy grants either action at
all anymore, and there's no other applicable policy to allow them. This is the exact
same mechanism as Drill 2's `dev-scratch` result (Section 4 of the content file): no
matching allow anywhere means the default (implicit deny) is what governs.

**What didn't change and why:** `ScopedEC2ReadOnly` (`ec2:DescribeInstances` on
`Resource: "*"`) was left as-is in both versions. It was already correctly scoped to
one specific, non-destructive, read-only action — least privilege means matching the
task's actual need, not mechanically minimizing every wildcard on sight, and many
EC2 `Describe*` actions genuinely don't support resource-level restriction at all (this
one included), so `Resource: "*"` here isn't a mistake to "fix."

## 3. Policy evaluation order, worked against this lab's own resources

Applying Section 1's rule (**explicit deny > explicit allow > implicit deny**) to a
concrete extension of this lab: suppose, after the least-privilege rewrite above, you
additionally attached the permission boundary
([`policies/permission-boundary-example.json`](policies/permission-boundary-example.json))
via `put-user-permissions-boundary`, and *also*, hypothetically, someone re-attached the
original over-permissive policy back onto the user alongside the rewritten one (a
realistic mistake — old policies rarely get detached when a new one is added).

Now the user has: identity policy #1 (rewritten, scoped), identity policy #2
(over-permissive `s3:*`/`*`, re-attached by mistake), and a permission boundary (allows
only `s3:GetObject`/`PutObject`/`ListBucket`/`ec2:DescribeInstances`, denies
`iam:*`/`organizations:*`/`account:*`).

- `s3:DeleteBucket` — identity policy #2 allows it, but the permission boundary doesn't
  list it among its allowed actions. Effective result: **denied**. The boundary's
  intersection-only semantics (Drill 4) mean the mistaken re-attachment of the broad
  policy is neutralized — this is exactly the "second layer" Defense 2 in the content
  file argues for: a correct boundary makes a *future accidental over-broad grant* safe,
  not just today's already-known one.
- `iam:CreateUser` — even though neither identity policy grants this at all (implicit
  deny would apply on its own), the boundary's explicit `Deny` on `iam:*` also matches.
  Effective result: **denied**, and denied for the stronger reason (explicit deny, not
  just absence of any allow) — the distinction matters if a third policy is ever added
  later that *does* try to allow it: an explicit deny in the boundary would still win,
  where a mere absence-of-allow would not survive a later allow being added elsewhere.

## 4. Foreshadowing Day 14 — `iam:PassRole`

`cyberlab-day13-role`'s trust policy ([`policies/trust-policy.json`](policies/trust-policy.json))
trusts `ec2.amazonaws.com` unconditionally — any EC2 instance can assume this role, no
further condition. That trust relationship, by itself, is not a vulnerability: creating
a role trusted by EC2 is exactly how legitimate EC2 instance roles are supposed to work.

The vulnerability Day 14 demonstrates is a **separate, additional** permission on the
*calling* identity: if a user (not the role — the user *launching* an instance) holds
both `iam:PassRole` (permission to attach an IAM role to a resource they're creating)
and `ec2:RunInstances`, they can launch a brand-new EC2 instance and attach
`cyberlab-day13-role` to it directly — inheriting every permission that role's policy
grants, running as that instance, with no further exploitation needed. Today's lab
built the role and its trust policy specifically so Day 14 has a concrete, already-
existing over-permissioned role to escalate into; today's user was never granted
`iam:PassRole`, so this lab's user cannot perform that escalation as configured — Day 14
adds exactly that one missing permission and shows the result.

## 5. Teardown verification

```sh
cd cyber_security/labs/day13
./teardown.sh
aws iam get-user --user-name cyberlab-day13-user --profile "$AWS_PROFILE"
aws iam get-role --role-name cyberlab-day13-role --profile "$AWS_PROFILE"
```

Expected for both: `An error occurred (NoSuchEntity) when calling the GetUser/GetRole
operation` — confirming every resource `setup.sh` created (and any extra policy version
created during the Defense Lab) is actually gone, not just detached.
