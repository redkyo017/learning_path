# Day 3 lab — KMS foundations: who can actually decrypt this?

Companion to [`content/day03-kms-foundations.md`](../../content/day03-kms-foundations.md).

## Authorized-testing note

This lab creates and tests IAM roles and KMS/S3 access **only inside
your own AWS account, against your own `labs/base` workload.** See
[`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement).

## Objective

Prove that "encryption at rest: enabled" tells you nothing about *who
can decrypt* — then fix it. Two IAM roles, `principal_a` (intended) and
`principal_b` (unintended, but carrying an **identical** identity-policy
grant by mistake), both start out able to decrypt objects encrypted
under `labs/base`'s existing CMK. You then replace the CMK's key policy
so only `principal_a` can — **without touching `principal_b`'s identity
policy at all** — proving the key policy, not the identity policy, is
what actually decided the outcome.

## Prereqs

- `labs/base` already applied (`terraform apply` in `labs/base/`,
  successfully — its state file at `../base/terraform.tfstate` is what
  this module reads via `data.terraform_remote_state`).
- Your own AWS CLI credentials configured, with enough IAM permission to
  create roles/policies and to `sts:AssumeRole`, `kms:*`, and `s3:*` on
  this workload (typical for whatever principal you're using to run
  this whole sprint).
- `cp terraform.tfvars.example terraform.tfvars` and fill in
  `learner_principal_arn` (get it with `aws sts get-caller-identity`).
  **Set it to the exact identity you will run `terraform apply` and
  `aws kms`/`aws sts` commands as** — after Part 2's harden, the key
  policy only trusts this exact ARN (plus `principal_a`) to manage or
  use the key; a mismatch here can lock you out of the key yourself.
- **Terraform is not run by the authoring agent for this repo** — every
  command below is written for *you*, the learner, to run yourself.
  Validate the `.tf` files by reading them before you apply; this
  lab's HCL was authored and manually reviewed, not machine-applied,
  before being handed to you.

## Part 1 — THE BREAK: two identical grants, one key policy

### 1. Apply with the default (hardening off)

```bash
cd labs/day03
terraform init
terraform apply   # enable_key_policy_hardening = false (the default)
```

Note the outputs: `principal_a_role_arn`, `principal_b_role_arn`,
`cmk_arn`, `app_bucket_name`.

### 2. Put a test object, encrypted under the base CMK

Using your own (already-privileged) CLI identity:

```bash
BUCKET=$(terraform output -raw app_bucket_name)
CMK_ARN=$(terraform output -raw cmk_arn)

echo "day03 test payload" > /tmp/day03-test.txt

aws s3 cp /tmp/day03-test.txt "s3://${BUCKET}/day03/test-object.txt" \
  --sse aws:kms --sse-kms-key-id "${CMK_ARN}"
```

### 3. Assume principal_a and read it back — expect success

```bash
A_ARN=$(terraform output -raw principal_a_role_arn)
CREDS_A=$(aws sts assume-role --role-arn "${A_ARN}" \
  --role-session-name day03-a --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS_A" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_A" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS_A" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws s3 cp "s3://${BUCKET}/day03/test-object.txt" -
# Expected: prints "day03 test payload" — principal_a can decrypt.

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

### 4. Assume principal_b and read it back — expect success TOO (this is the break)

```bash
B_ARN=$(terraform output -raw principal_b_role_arn)
CREDS_B=$(aws sts assume-role --role-arn "${B_ARN}" \
  --role-session-name day03-b --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS_B" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_B" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS_B" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws s3 cp "s3://${BUCKET}/day03/test-object.txt" -
# Expected (THE BREAK): ALSO prints "day03 test payload". principal_b was
# never supposed to be able to decrypt this — it can, because base's CMK
# key policy delegates fully to IAM, and principal_b's identity policy
# (a copy-paste of principal_a's) grants kms:Decrypt too.

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

**Success signal for the break:** both principal_a and principal_b
successfully read and decrypt the object. Record this — SOLUTION.md
has the exact expected output.

## Part 2 — THE HARDEN: replace the key policy, change nothing else

### 5. Flip the variable and re-apply

Edit `terraform.tfvars`: `enable_key_policy_hardening = true`, then:

```bash
terraform apply
```

This replaces `aws_kms_key.app_data`'s policy (via `aws_kms_key_policy`,
which manages a key's policy independently of the resource that created
it — used here specifically because `labs/base` owns the key and this
module must not edit `labs/base`) with an explicit administrators-only +
principal-A-only-for-usage policy. **`principal_b`'s identity policy is
untouched** — still grants `kms:Decrypt`.

### 6. Re-run principal_a's read — still succeeds

```bash
CREDS_A=$(aws sts assume-role --role-arn "$(terraform output -raw principal_a_role_arn)" \
  --role-session-name day03-a-after --output json)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS_A" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_A" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS_A" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws s3 cp "s3://${BUCKET}/day03/test-object.txt" -
# Expected: still prints "day03 test payload".
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

### 7. Re-run principal_b's read — now denied (THE HARDEN, proven)

```bash
CREDS_B=$(aws sts assume-role --role-arn "$(terraform output -raw principal_b_role_arn)" \
  --role-session-name day03-b-after --output json)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS_B" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS_B" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS_B" | python3 -c 'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws s3 cp "s3://${BUCKET}/day03/test-object.txt" -
# Expected (THE HARDEN): AccessDenied — see SOLUTION.md for the exact text.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

**Success signal for the harden:** principal_a unchanged (still
succeeds); principal_b now `AccessDenied`, with zero change to
principal_b's own identity policy — the key policy alone made the
difference.

## Part 3 — CLI envelope-encryption demo

Run this as your normal privileged CLI identity (not A or B) — this
part is about the *mechanism*, independent of the A/B break-harden
story above.

```bash
CMK_ARN=$(terraform output -raw cmk_arn)

# 1. Ask KMS for a data key: get back plaintext + the SAME key, encrypted.
aws kms generate-data-key --key-id "${CMK_ARN}" --key-spec AES_256 \
  --output json > /tmp/day03-datakey.json

python3 - <<'PY'
import base64, json
d = json.load(open("/tmp/day03-datakey.json"))
open("/tmp/day03-plaintext-key.bin", "wb").write(base64.b64decode(d["Plaintext"]))
open("/tmp/day03-encrypted-key.bin", "wb").write(base64.b64decode(d["CiphertextBlob"]))
PY

# 2. Encrypt your actual data LOCALLY with the plaintext data key — no
#    per-byte KMS call, no 4 KiB limit.
echo "a much bigger payload than KMS's 4KiB direct-Encrypt limit would allow" \
  > /tmp/day03-plaintext-data.txt

openssl enc -aes-256-cbc -pbkdf2 -salt \
  -in /tmp/day03-plaintext-data.txt -out /tmp/day03-ciphertext-data.bin \
  -pass file:/tmp/day03-plaintext-key.bin

# 3. DISCARD the plaintext data key — never persist it.
rm -f /tmp/day03-plaintext-key.bin

# 4. "Store": ciphertext data + encrypted data key travel together.
ls -la /tmp/day03-ciphertext-data.bin /tmp/day03-encrypted-key.bin

# 5. Later: decrypt the encrypted data key via KMS, then decrypt the data.
aws kms decrypt --ciphertext-blob fileb:///tmp/day03-encrypted-key.bin \
  --output json > /tmp/day03-decrypted-key.json

python3 - <<'PY'
import base64, json
d = json.load(open("/tmp/day03-decrypted-key.json"))
open("/tmp/day03-recovered-key.bin", "wb").write(base64.b64decode(d["Plaintext"]))
PY

openssl enc -d -aes-256-cbc -pbkdf2 \
  -in /tmp/day03-ciphertext-data.bin -out /tmp/day03-recovered-data.txt \
  -pass file:/tmp/day03-recovered-key.bin

cat /tmp/day03-recovered-data.txt
# Expected: prints the original payload back out.

rm -f /tmp/day03-recovered-key.bin /tmp/day03-datakey.json /tmp/day03-decrypted-key.json
```

This is exactly what S3's SSE-KMS default did on your behalf in Part 1
— KMS never touched the bulk payload, only the small data key, twice.

## Exercises

See [`content/day03-kms-foundations.md`](../../content/day03-kms-foundations.md#exercises)
— 4 exercises with hints and solution sketches, including the
"trace who can decrypt" scenario.

## Teardown checklist

1. **Test S3 object** (not Terraform-managed): delete it with your
   privileged CLI identity —
   `aws s3 rm "s3://$(terraform output -raw app_bucket_name)/day03/test-object.txt"`.
2. **This module's resources:**
   ```bash
   terraform destroy
   ```
   This removes `principal_a`, `principal_b`, and (if
   `enable_key_policy_hardening = true`) drops the
   `aws_kms_key_policy` resource from Terraform's management.
3. **The one gotcha:** destroying `aws_kms_key_policy` does **not**
   revert the CMK to its original AWS-default policy — a KMS key must
   always have *some* policy document, so the provider leaves the
   last-applied one in place rather than deleting it. If you want the
   key back at the exact AWS-default ("Enable IAM User Permissions")
   policy before Day 4 picks the key policy up again, run this
   yourself (no file in this repo needs your account ID — it's
   resolved live by the shell):
   ```bash
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   KEY_ID=$(terraform output -raw cmk_key_id)
   cat > /tmp/day03-default-key-policy.json <<EOF
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Sid": "Enable IAM User Permissions",
       "Effect": "Allow",
       "Principal": {"AWS": "arn:aws:iam::${ACCOUNT_ID}:root"},
       "Action": "kms:*",
       "Resource": "*"
     }]
   }
   EOF
   aws kms put-key-policy --key-id "${KEY_ID}" --policy-name default \
     --policy file:///tmp/day03-default-key-policy.json
   rm -f /tmp/day03-default-key-policy.json
   ```
   Leaving the hardened policy in place instead is also fine (arguably
   an improvement) — Day 4 replaces the key policy again regardless.
4. **No new CMK was created this lab** — `labs/base`'s
   `aws_kms_key.app_data` is never destroyed or scheduled for deletion
   by this module. Confirm it's still there:
   `aws kms describe-key --key-id "$(terraform output -raw cmk_key_id 2>/dev/null || echo <paste-from-before-destroy>)"`
   (run this check *before* step 2 if you want `terraform output` to
   still work).
5. Confirm zero billable resources left from this day's module:
   `terraform state list` should be empty after `terraform destroy`.
