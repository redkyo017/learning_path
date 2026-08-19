# Day 4 lab — SOLUTION

## Which statement opened it

The ENTIRE diff between the locked policy and the broken policy is one
`Condition` block, on one statement, in `main.tf` (plus a cosmetic `sid`
rename on that same statement — see the note below the diff):

```diff
   statement {
-    sid    = "AllowDecryptViaServiceOnly"
+    sid    = "AllowDecryptAnySource"
     effect = "Allow"
     principals {
       type        = "AWS"
       identifiers = [aws_iam_role.exfil_sim.arn]
     }
     actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
     resources = ["*"]
-
-    condition {
-      test     = "StringEquals"
-      variable = "kms:ViaService"
-      values = [
-        "s3.<region>.amazonaws.com",
-        "dynamodb.<region>.amazonaws.com",
-      ]
-    }
   }
```

Everything else — the principal, the actions, the `EnableIAMUserPermissions`
statement, the IAM identity policy on `exfil_sim` — is identical in both
states. (The diff above also shows the statement's `sid` being renamed
from `AllowDecryptViaServiceOnly` to `AllowDecryptAnySource` — that's a
human-readable label with no authorization effect of its own; it doesn't
change what the statement grants, it's just the diff being honest about
what changed alongside the `Condition` block.) The `kms:ViaService`
condition was the *only* thing standing
between "decrypt only through S3/DynamoDB" and "decrypt from anywhere,
including a bare `aws kms decrypt` call with a credential that has never
touched S3 or DynamoDB." That is exactly the gap
[`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md) #5 describes: the
identity-side statement (`MirrorTaskRoleKMSGrant`, mirroring the real task
role's `DecryptAppDataKey` statement in `labs/base/iam.tf`) was
unconditioned in BOTH states — it was never going to stop this on its own.
The resource-side (key policy) condition was the only control actually
doing the scoping.

## Expected outputs

### Step 1 — locked policy, direct decrypt (should be blocked, is blocked)

```
$ aws kms decrypt --cli-binary-format raw-in-base64-out \
    --ciphertext-blob fileb:///tmp/day04-ciphertext.bin --key-id "$CMK_ALIAS"

An error occurred (AccessDeniedException) when calling the Decrypt
operation: User: arn:aws:iam::<ACCOUNT_ID>:assumed-role/aws-sec-lab-day04-exfil-sim-role/day04-exfil-test
is not authorized to perform: kms:Decrypt on resource: arn:aws:kms:<REGION>:<ACCOUNT_ID>:key/<KEY_ID>
because no resource-based policy allows the kms:Decrypt action
```

(Typical wording — record your actual text; it can vary slightly by
API/SDK version.) That trailing clause — "because no **resource-based
policy** allows" (not "because an identity policy denies") — is KMS
specifically telling you the deny came from the key-policy side, not the
identity side. For a KMS key, the resource-based policy IS the key
policy (a CMK has exactly one such document), so that phrasing is the
tell every time this class of AccessDenied fires: check the key policy
first, not the caller's IAM policy, because the caller's IAM policy in
this scenario already allows it.

### Step 1 — locked policy, via-S3 GetObject (should still work, does)

```
$ aws s3api get-object --bucket <bucket> --key day04/exfil-test.txt /tmp/day04-via-s3.txt
{
    "AcceptRanges": "bytes",
    "ServerSideEncryption": "aws:kms",
    "SSEKMSKeyId": "arn:aws:kms:<REGION>:<ACCOUNT_ID>:key/<KEY_ID>",
    ...
}
$ cat /tmp/day04-via-s3.txt
day04 lab test object — not sensitive, safe to encrypt/decrypt/delete during this lab.
```

### Step 2 — broken policy, direct decrypt (exfil succeeds)

```
$ aws kms decrypt --cli-binary-format raw-in-base64-out \
    --ciphertext-blob fileb:///tmp/day04-ciphertext.bin --key-id "$CMK_ALIAS"
day04-exfil-secret
```

(With `--cli-binary-format raw-in-base64-out`, the CLI hands back decoded
plaintext directly to stdout via `--query Plaintext --output text` if you
add that; without it you get a base64 `Plaintext` field in the JSON
response — either way, the call returns 200 with real key material
decrypted, which is the success signal. No AccessDenied.)

**Important nuance:** the via-S3 `GetObject` test from Step 1 ALSO still
succeeds under the broken policy — the broken policy is a strict superset
of the locked one (it removed a restriction, it didn't remove the grant).
The interesting contrast isn't "S3 works / S3 stops working"; it's "direct
decrypt is denied / direct decrypt is allowed." Don't mistake "the S3 path
still works" for "nothing changed" — something did change, just not on
that path.

### Step 3 — re-locked, direct decrypt (blocked again)

Identical `AccessDeniedException` text to Step 1. Re-run the `GetObject`
test too: identical 200 to Step 1's — confirms the harden restored the
exact original behavior on both paths, not just the deny.

## Fix rationale

`kms:ViaService` doesn't ask "can this principal ever decrypt with this
key" — the unconditioned identity statement already answered "yes" to
that, and always will, because that statement mirrors a real production
grant (the task role's) that Day 4 doesn't get to redesign (that's Day 1's
job, on the S3 side of that same role). What `kms:ViaService` adds is a
narrower, orthogonal question on the RESOURCE side: "is this specific
request arriving through the one code path we actually intend this
principal to use the key from?" A direct `aws kms decrypt` call, run from
a CLI or a script using stolen credentials, never arrives "via" S3 or
DynamoDB — it's a bare KMS API call. Scoping the key-policy grant to only
honor requests tagged with `kms:ViaService = s3.<region>.amazonaws.com` (or
`dynamodb.<region>.amazonaws.com`) closes exactly that gap without
touching the identity policy at all, and without breaking the one thing
the principal is actually supposed to do (read/write through S3 and
DynamoDB, which both trigger with that ViaService tag already set by the
service itself, not the caller — it can't be spoofed by a caller crafting
their own request).

The broader lesson this SOLUTION exists to nail down: encryption-at-rest
being "on" was never in question here (`aws_kms_key.app_data` in
`labs/base/data.tf` was encrypted the whole time, in every step). The
question that mattered was "who can decrypt, and through what path" —
[`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md) #5, in the flesh.
