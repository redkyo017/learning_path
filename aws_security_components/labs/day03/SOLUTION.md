# Day 3 lab — SOLUTION

Expected outputs for both halves of the break→harden, and the fix
rationale. Your exact AccessDenied wording will include your own
account ID, role IDs, and request ID where AWS inserts them — the
structure and status below are what to match against.

## Part 1 — THE BREAK (`enable_key_policy_hardening = false`)

### principal_a reads the object

```
$ aws s3 cp s3://<bucket>/day03/test-object.txt -
day03 test payload
```
Exit code `0`. **Expected — principal_a is the intended reader.**

### principal_b reads the object (this is the break)

```
$ aws s3 cp s3://<bucket>/day03/test-object.txt -
day03 test payload
```
Exit code `0`. **This is the finding, not a bug in the lab.**
principal_b succeeded because:

1. `labs/base`'s `aws_kms_key.app_data` has no explicit key policy of
   its own → AWS's default statement applies → that statement names
   the account root ARN with `kms:*`, which AWS documents as
   delegating the decision entirely to IAM identity policies.
2. principal_b's identity policy (`aws_iam_role_policy.principal_b`,
   identical to principal_a's) grants `kms:Decrypt` + `kms:GenerateDataKey`
   on this key's ARN, and `s3:GetObject` on the bucket's `day03/` prefix.
3. With the key policy silent-but-delegating, step 2 alone is
   sufficient. **The CMK's "encryption at rest: enabled" status never
   changed and never told you this was possible.** This is
   [`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md) #5, observed live.

## Part 2 — THE HARDEN (`enable_key_policy_hardening = true`)

### principal_a reads the object — unchanged

```
$ aws s3 cp s3://<bucket>/day03/test-object.txt -
day03 test payload
```
Exit code `0`. Unchanged, because the hardened key policy's
`AllowIntendedPrincipalUsageOnly` statement names principal_a's role
ARN explicitly.

### principal_b reads the object — now denied

```
$ aws s3 cp s3://<bucket>/day03/test-object.txt -
fatal error: An error occurred (AccessDenied) when calling the
GetObject operation: Access Denied
```

Exit code `1`. If you inspect the underlying KMS-side denial
(CloudTrail `Decrypt` event, or a direct `aws kms decrypt` call as
principal_b against the encrypted data key) the underlying reason
surfaces explicitly, typically as:

```
An error occurred (AccessDeniedException) when calling the Decrypt
operation: User: arn:aws:sts::<account-id>:assumed-role/day03-principal-b-role/day03-b-after
is not authorized to perform: kms:Decrypt on resource: <key-arn>
because no resource-based policy allows the kms:Decrypt action
```

(Exact wording varies by API/SDK version — treat the above as
typical, and record your actual text; the load-bearing fact is that AWS's
own denial message names the *resource-based policy* — for KMS, that IS
the key policy, since a KMS key has exactly one resource-based policy
document and it's called the key policy — as the missing piece, not the
identity policy.)

**That "no resource-based policy allows" clause is the entire lesson.**
principal_b's identity policy was never touched between Part 1 and
Part 2 — it still says `Allow: kms:Decrypt`. What changed is the
resource-based door: the key policy no longer names principal_b (and
no longer contains a blanket IAM-delegation statement, because the
administrators statement was deliberately scoped to management actions
only). Per the evaluation order, the resource-based policy is checked
before the identity-based policy, and same-account KMS access requires
**both** doors to open — one door closing is enough to deny the whole
request, regardless of what the other door says.

## Fix rationale (why the hardened policy is written this way)

- **Two statements, not one.** A single broad "root gets `kms:*`"
  statement (the AWS default) is exactly what created the break — it
  re-delegates *everything*, including usage actions, to IAM. Splitting
  administration (management-plane actions) from usage (`kms:Decrypt`
  /`kms:Encrypt`/`kms:GenerateDataKey`/`kms:DescribeKey`) means the
  administrators statement can stay broad (you still need to be able to
  manage the key) without silently re-opening usage to anyone with a
  matching identity policy.
- **Usage statement names a role ARN, not an account.** Naming
  `aws_iam_role.principal_a.arn` directly means only that specific role
  — not "any principal in this account with the right IAM policy" — can
  use the key for data operations. This is what makes the key policy
  the actual control, not a formality sitting behind IAM.
- **principal_b's identity policy is intentionally left unchanged.**
  The lab would be weaker if hardening also meant "and go fix
  principal_b's IAM policy" — that would make it look like the
  identity policy was the thing that mattered. Leaving it unchanged and
  denied anyway is the proof that the key policy is the root of trust.

## Teardown verification

After `terraform destroy` in this directory:
```
$ terraform state list
```
Expected: empty output. `labs/base`'s CMK (`aws_kms_key.app_data`) is
untouched and still `Enabled` — confirm with
`aws kms describe-key --key-id <cmk_key_id captured before destroy>`
if you want to double check nothing in this module scheduled it for
deletion (nothing did — this module never manages the key resource
itself, only its policy, and only while `enable_key_policy_hardening`
is `true`).
