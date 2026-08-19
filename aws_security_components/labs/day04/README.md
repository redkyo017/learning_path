# Day 4 lab — KMS advanced + data at rest

> **Authorized testing only.** This lab's "exfiltration attempt" targets
> only a role and a test object created inside YOUR OWN account by this
> lab, layered on YOUR OWN `labs/base` workload. See
> [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md) "Authorized-testing
> statement" — it applies here exactly as it does to every other day.

## What this lab is actually testing

Every other day in this path starts from a broken state and hardens it.
This one starts LOCKED, on purpose — because the whole point of Day 4 is
proving that a specific `kms:ViaService` condition is what's holding the
door shut, by literally removing it and watching the door swing open, then
putting it back. That's a one-line diff you can point to, which is the
most convincing way to actually believe a condition key does anything.

**Objective:** prove that a stolen-credential-shaped principal (the
`exfil_sim` role — see main.tf for why we simulate rather than literally
steal the live task role's creds here) can decrypt data through the
legitimate path (via S3) but NOT via a direct `kms:Decrypt` call, when the
base CMK's key policy scopes decrypt with `kms:ViaService`. Then break that
scoping, watch the direct call succeed, and re-lock it.

## Prereqs

- `labs/base` applied and up (`terraform output` works from `../base`).
- Terraform >= 1.6, AWS provider >= 5.20 (see main.tf comment — this lab
  uses `aws_kms_key_policy`, which needs a newer provider than base's own
  `>= 5.0` floor; bump the constraint if your resolved version predates it).
- AWS CLI v2, `jq`, and credentials for a principal in the SAME account as
  `labs/base` with permission to `sts:AssumeRole`, `kms:Encrypt`,
  `kms:PutKeyPolicy` (via this Terraform run), and `s3:GetObject`.
- **Terraform is not run by this document's author.** You run
  `terraform init/plan/apply/destroy` and every AWS CLI command yourself.
  This README and main.tf were validated by manual HCL review, not by a
  real `terraform apply` — see the day's report for what that review
  covered.

## Bring it up

```bash
cd labs/day04
cp terraform.tfvars.example terraform.tfvars
# edit: region + project MUST match labs/base's values
terraform init
terraform plan
terraform apply    # break_key_policy = false (locked) by default
```

## Step 1 — prove the block: THE BREAK setup (should stop, and does)

```bash
# Produce a ciphertext blob directly against the CMK, using YOUR OWN
# (admin) credentials — this simulates data an attacker exfiltrated by
# some other means (a backup, replicated data, a memory dump) and is now
# trying to decrypt with stolen task-role-shaped credentials.
CMK_ALIAS=$(terraform output -raw cmk_alias)
aws kms encrypt --cli-binary-format raw-in-base64-out \
  --key-id "$CMK_ALIAS" --plaintext "day04-exfil-secret" \
  --query CiphertextBlob --output text | base64 --decode > /tmp/day04-ciphertext.bin

# Assume the exfil_sim role (stand-in for the stolen credential)
SIM_ROLE_ARN=$(terraform output -raw exfil_sim_role_arn)
CREDS=$(aws sts assume-role --role-arn "$SIM_ROLE_ARN" --role-session-name day04-exfil-test)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .Credentials.SessionToken)

# Attempt a DIRECT decrypt (not via S3/DynamoDB) — this is the exfil
# attempt that the locked key policy SHOULD stop.
aws kms decrypt --cli-binary-format raw-in-base64-out \
  --ciphertext-blob fileb:///tmp/day04-ciphertext.bin --key-id "$CMK_ALIAS"
```

**Expected right now (locked policy):** `AccessDenied` — see SOLUTION.md
for the exact expected error text.

Now prove the legitimate path still works, under the SAME locked policy:

```bash
aws s3api get-object --bucket "$(terraform output -raw test_object_bucket)" \
  --key "$(terraform output -raw test_object_key)" /tmp/day04-via-s3.txt
cat /tmp/day04-via-s3.txt
```

**Expected:** `200`, plaintext content in the file. S3's `GetObject` calls
`kms:Decrypt` on your behalf `kms:ViaService = s3.<region>.amazonaws.com`,
which the locked policy explicitly allows.

Unset the sim credentials before continuing (`unset AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`), back to your own admin identity.

## Step 2 — THE BREAK: deliberately mis-configure the key policy

```bash
# terraform.tfvars: break_key_policy = true
terraform apply
```

Re-assume `exfil_sim` (repeat the `sts assume-role` + export block above)
and re-run the SAME direct decrypt command from Step 1.

**Expected now:** it SUCCEEDS — `Plaintext` comes back
base64-encoded in the response. This is the exfil succeeding. See
SOLUTION.md "Which statement opened it" for exactly what changed.

## Step 3 — THE HARDEN: re-lock it

```bash
# terraform.tfvars: break_key_policy = false
terraform apply
```

Re-assume `exfil_sim` again, re-run the direct decrypt.

**Expected:** `AccessDenied` again — same error as Step 1. Re-run the
`s3api get-object` command too, to confirm the harden didn't break the
legitimate path: it should still return `200`.

## Teardown (day-04 layer only — base stays up)

```bash
cd labs/day04
terraform destroy
```

Confirm:

- [ ] `terraform state list` for this directory is empty (or errors
      because the state is gone — either is fine).
- [ ] The base CMK (check via `aws kms get-key-policy --key-id <alias>
      --policy-name default`) is back on AWS's default policy (root-only
      statement) — this is expected: destroying `aws_kms_key_policy`
      reverts the key to that default, which is the same state base itself
      leaves it in.
- [ ] The `exfil_sim` IAM role and its inline policy are gone
      (`aws iam get-role --role-name aws-sec-lab-day04-exfil-sim-role`
      should error).
- [ ] The test object is gone from the base bucket.
- [ ] `labs/base`'s own resources (CMK, bucket, table, secret, VPC, etc.)
      are all untouched — this destroy never targets base.

Base's own daily/end-of-sprint teardown (ALB, ECS service, CloudFront —
the hourly-billing pieces) is separate; see `labs/base/README.md`. Nothing
in this lab is hourly-billing, so there's no urgency beyond "don't leave
the `exfil_sim` role sitting around after you're done with the day."
