# Day 13 — Cloud Security Model & IAM Foundations

## Objectives

By the end of today you should be able to:

- State the **shared responsibility model** precisely enough to say, for a given AWS
  service, exactly which security failures are AWS's problem and which are yours.
- Name the difference between an IAM **principal**, a **policy**, and a **role** — and
  say specifically which JSON document type a role has that a user or group doesn't.
- Read a real IAM policy JSON document and identify exactly which statement grants more
  than the task actually needs, then rewrite it to the narrowest permissions that still
  work — the core skill of **least privilege**.
- State AWS's policy evaluation order from memory (explicit deny beats any allow, which
  beats implicit deny) and predict the outcome of a given allow+deny combination without
  running anything.
- Name what a **permission boundary** and an **SCP** each cap, and how they differ from
  an identity policy (they can only shrink effective permissions, never grant any).
- Recognize why a role's **trust policy** is a distinct, separate document from its
  permission policy — and specifically who is allowed to *become* that role, which is
  the exact seam Day 14's `iam:PassRole` attack lives in.

## 1. Concept — Identity Is the New Perimeter

### The shared responsibility model

On-premises, "security" mostly meant securing a perimeter you fully controlled: the
network, the hardware, the hypervisor, the OS, the application. In AWS, that
responsibility is split with the provider, and where the line falls **depends on the
specific service**, not on "the cloud" as a single blob:

| Layer | Who owns it for EC2 (IaaS) | Who owns it for S3 (managed service) |
|---|---|---|
| Physical hosts, hypervisor, network hardware | AWS ("security **of** the cloud") | AWS |
| Guest OS patching, host firewall/security groups | **You** | N/A — no OS you manage |
| Application code, data | **You** | **You** |
| IAM policies controlling who can call the API | **You** | **You** |
| Bucket policy / Block Public Access settings | N/A | **You** |
| Encryption configuration (at rest, in transit) | **You** (you choose and configure it) | **You** (you choose and configure it) |
| Storage durability, service availability | AWS | AWS |

The pattern: AWS is always responsible for the security **of** the cloud (the physical
and virtualization layer beneath every service). You are always responsible for
security **in** the cloud — but *how much* of "in the cloud" is yours grows as you move
down the stack from a fully-managed service (S3, Lambda) toward raw infrastructure
(EC2). With EC2 you're patching a real guest OS and configuring a real host-level
firewall; with S3 there's no OS at all, so your responsibility narrows to configuration
(bucket policies, Block Public Access, encryption, and — cutting across every AWS
service without exception — the IAM policies controlling who can call which API at
all). Today's lab and Day 15 both live in that shared "your responsibility, regardless
of service" layer: IAM misconfiguration is never AWS's fault, in either case.

### IAM principals, policies, and roles

An **IAM principal** is anything that can make an authenticated request to AWS: an IAM
**user** (a persistent identity, usually a real person or a long-lived integration), an
IAM **role** (a temporary identity anything can *assume*, discussed below), or an AWS
service acting on your behalf. Every API call AWS receives is evaluated as "which
principal is this, and what does its policy allow?"

An **IAM policy** is a JSON document — the one you'll spend most of today reading and
rewriting — with a `Version` and one or more `Statement` entries, each naming an
`Effect` (`Allow` or `Deny`), an `Action` (which API calls, e.g. `s3:GetObject`,
supporting wildcards like `s3:*`), and a `Resource` (which specific ARNs it applies to,
also wildcard-able). A policy attached directly to a user or role like this is called an
**identity-based policy** — today's lab attaches exactly one to both.

An **IAM role** is not a set of credentials belonging to one fixed identity — it's a
**temporary identity anything can assume**, given permission to. That "given permission
to" is the key structural difference from a user: a role has **two separate policy
documents**, not one:

1. A **trust policy** (the role's `AssumeRolePolicyDocument`) — who is allowed to
   assume this role at all. [`labs/day13/policies/trust-policy.json`](../labs/day13/policies/trust-policy.json)
   is today's example: it trusts the `ec2.amazonaws.com` service principal, meaning any
   EC2 instance you attach this role to can assume it. This is exactly the setup pattern
   behind an **EC2 instance role** — and exactly the setup Day 14's `iam:PassRole`
   attack targets: if a low-privileged user can *pass* this role to a new EC2 instance
   they control, they inherit whatever the role's permission policy grants once that
   instance boots. Today just builds the role; Day 14 abuses it.
2. A **permission policy** — once assumed, what the role can actually do. This is the
   same JSON structure as a user's identity policy (today's over-permissive policy is
   attached to both the user *and* the role, deliberately, so you rewrite the same
   mistake in both places).

### Policy evaluation: how AWS actually decides allow or deny

Every API call gets evaluated against **every** policy that applies to it — identity
policies, resource policies (like an S3 bucket policy), permission boundaries, and
(cutting across accounts) SCPs — and the result collapses to one rule, in this priority
order:

1. **Explicit deny wins, always, no matter what else allows it.** If *any* applicable
   policy has an explicit `Deny` matching the action, the call is denied — full stop, no
   allow anywhere can override it.
2. **Explicit allow, if no explicit deny matched.** If at least one applicable policy
   allows the action and nothing denied it, the call succeeds.
3. **Implicit deny is the default.** If nothing explicitly allowed the action, it's
   denied — IAM denies by default; permissions must be granted, never assumed.

The phrase to memorize precisely: **explicit deny > explicit allow > implicit deny**.
This is *not* "the most restrictive policy wins" or "policies are ANDed together" —
it's specifically that deny is a trump card and allow is only ever a default-off
switch flipped on. Drill 2 below gives you a concrete allow+deny combination to
resolve using exactly this rule.

### Permission boundaries and SCPs — permissions that only ever shrink

Two mechanisms exist specifically to **cap** what an identity policy can grant, never to
grant anything beyond it:

- A **permission boundary** is a *managed policy attached to a single user or role*
  that sets the **maximum** permissions that identity's own policies can ever grant.
  The *effective* permission for any action is the **intersection** — allowed only if
  both the identity policy AND the boundary allow it.
  [`labs/day13/policies/permission-boundary-example.json`](../labs/day13/policies/permission-boundary-example.json)
  shows one that allows S3 read/write and EC2 read but explicitly denies `iam:*` and
  `organizations:*` — so even if someone later attaches an over-permissive identity
  policy to this user by mistake, IAM permission-management actions stay blocked
  regardless.
- An **SCP** (Service Control Policy) is the same idea one level up: an **AWS
  Organizations**-level policy applied to an entire account or organizational unit,
  capping what *every* identity in that account can ever do — no identity policy in the
  account can override an SCP's deny. Today's sandbox is a single standalone account
  (no Organization), so this lab doesn't attach a live SCP — it's introduced
  conceptually here, with a documented example
  ([`labs/day13/policies/example-scp-deny-iam-users.json`](../labs/day13/policies/example-scp-deny-iam-users.json))
  denying `iam:CreateAccessKey`/`iam:CreateLoginProfile` org-wide, the kind of guardrail
  a real organization puts in place so no single account's IAM misconfiguration (like
  today's!) can create a long-lived credential nobody centrally tracks.

Both mechanisms answer the same question at different scopes: **"no matter what any
identity policy says, what's the hard ceiling?"** Neither one is a substitute for
writing a correct, narrow identity policy in the first place — they're a second layer
for when that first layer fails, which (per today's lab) it regularly does.

## 2. Attack/Assess Lab — Enumerate and Prove the Over-Permissive Grant

**Authorized use only:** every command below runs against **your own AWS sandbox
account**, addressed through a **named AWS CLI profile** (never hardcoded credentials).
If you don't already have one: `aws configure --profile cyberlab-sandbox` (or export
`AWS_PROFILE=<your-profile>` before running anything below). Never point any of this at
an account you don't own or don't have explicit written authorization to test.

### Step 0 — Confirm you're pointed at the sandbox, not anything else

```sh
export AWS_PROFILE=cyberlab-sandbox   # use your own profile name
aws sts get-caller-identity --profile "$AWS_PROFILE"
```

**What you should see:** the sandbox account's `Account`, `UserId`, and `Arn` — confirm
this is the throwaway sandbox before Step 1 creates anything real in it.

### Step 1 — Bring up the lab

```sh
cd cyber_security/labs/day13
./setup.sh
```

`setup.sh` creates `cyberlab-day13-user`, the deliberately-broad
`cyberlab-day13-overpermissive-policy`
([`policies/overpermissive-policy.json`](../labs/day13/policies/overpermissive-policy.json)),
attaches it to that user, then creates `cyberlab-day13-role`
(trust policy: [`policies/trust-policy.json`](../labs/day13/policies/trust-policy.json))
and attaches the same policy there too. Run `./setup.sh --dry-run` first if you want to
see the exact plan without making any API calls.

### Step 2 — Read the policy you were just handed

```sh
POLICY_ARN=$(aws iam list-attached-user-policies \
  --user-name cyberlab-day13-user --profile "$AWS_PROFILE" \
  --query 'AttachedPolicies[0].PolicyArn' --output text)
VERSION_ID=$(aws iam get-policy --policy-arn "$POLICY_ARN" \
  --profile "$AWS_PROFILE" --query 'Policy.DefaultVersionId' --output text)
aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$VERSION_ID" \
  --profile "$AWS_PROFILE" --query 'PolicyVersion.Document'
```

**What you should see:** the same two statements as
[`overpermissive-policy.json`](../labs/day13/policies/overpermissive-policy.json) —
`OverlyBroadS3FullAccess` granting `s3:*` on `Resource: "*"`, and `ScopedEC2ReadOnly`
granting only `ec2:DescribeInstances`. One of these is the problem; naming *precisely
which one, and why* is the actual skill (Drill 1 below asks you to do this cold on a
different example).

### Step 3 — Prove the overreach with the IAM policy simulator, not just by reading JSON

Reading a policy tells you what it *says*; the simulator tells you what AWS will
*actually* decide for a specific call — the same distinction as Day 4's "reading a JWT
needs no secret, but verifying/forging one does": reading is free, but *proving* the
effective decision requires actually evaluating it.

```sh
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text):user/cyberlab-day13-user" \
  --action-names s3:DeleteBucket s3:PutBucketPolicy \
  --resource-arns "arn:aws:s3:::some-completely-unrelated-bucket" \
  --profile "$AWS_PROFILE" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table
```

**What you should see:** both `s3:DeleteBucket` and `s3:PutBucketPolicy` evaluate to
`allowed` — against a bucket this user has no legitimate business touching, and for two
of the most destructive S3 actions that exist (deleting a bucket outright; rewriting its
access policy to grant a third party access). This is the over-permissive
`s3:*`/`Resource: "*"` statement made concrete: it's not a hypothetical "too broad on
paper" — the simulator proves AWS will actually honor a destructive call against
literally any bucket in the account, including ones this identity has never interacted
with.

### Verify

```sh
./setup.sh --dry-run
```

Expected: prints the exact resource-creation plan (user/policy/role names and the ARNs
that will result) with no live API calls — confirms the script's logic is sound before
or after a real run. The full walkthrough of Steps 1–3's actual command output for a
representative sandbox account is captured in
[`labs/day13/SOLUTION.md`](../labs/day13/SOLUTION.md).

## 3. Defense Lab — Rewrite to Least Privilege, Add a Boundary

### Defense 1 — Rewrite the policy to least privilege

**Least privilege** means granting exactly the permissions a task needs, no more —
never a wildcard "in case something needs it later." Compare the original statement
against the rewrite in
[`labs/day13/policies/least-privilege-policy.json`](../labs/day13/policies/least-privilege-policy.json):

```diff
- "Action": "s3:*",
- "Resource": "*"
+ "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
+ "Resource": ["arn:aws:s3:::cyberlab-day13-*", "arn:aws:s3:::cyberlab-day13-*/*"]
```

Three things changed, each for a specific reason:

1. **`s3:*` → three named actions.** The task (read/write objects in a lab bucket) never
   needed `s3:DeleteBucket`, `s3:PutBucketPolicy`, or any of the dozens of other actions
   `s3:*` silently included.
2. **`Resource: "*"` → a scoped ARN prefix.** The rewrite can only ever touch buckets
   named `cyberlab-day13-*` — Step 3's simulator call against an unrelated bucket would
   now evaluate to `implicitDeny`, not `allowed`.
3. **`ec2:DescribeInstances` was left unchanged.** It was already correctly scoped —
   least privilege isn't "make everything narrower," it's "make everything exactly as
   narrow as the task requires," and this statement already was. Note also that many
   AWS `Describe*`/`List*` read-only actions genuinely don't support resource-level ARN
   restriction at all — `Resource: "*"` on a read-only Describe action is often not a
   mistake, unlike `Resource: "*"` on `s3:*`, which grants destructive actions AWS
   *does* support scoping.

Apply it as a new policy version (IAM keeps up to 5 versions per managed policy; you set
which one is active):

```sh
aws iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document file://policies/least-privilege-policy.json \
  --set-as-default \
  --profile "$AWS_PROFILE"
```

Re-run Step 3's simulator call after this change — full before/after output in
[`SOLUTION.md`](../labs/day13/SOLUTION.md).

### Defense 2 — Add a permission boundary as a second layer

Even a correctly-written identity policy is one future bad edit away from becoming
over-permissive again. A **permission boundary**
([`policies/permission-boundary-example.json`](../labs/day13/policies/permission-boundary-example.json))
attached to the user caps the *maximum* that any future identity-policy edit could ever
grant — explicitly denying `iam:*`/`organizations:*`/`account:*` regardless of what gets
attached later:

```sh
BOUNDARY_ARN=$(aws iam create-policy \
  --policy-name cyberlab-day13-boundary \
  --policy-document file://policies/permission-boundary-example.json \
  --profile "$AWS_PROFILE" --query 'Policy.Arn' --output text)
aws iam put-user-permissions-boundary \
  --user-name cyberlab-day13-user \
  --permissions-boundary "$BOUNDARY_ARN" \
  --profile "$AWS_PROFILE"
```

### Defense 3 — SCP awareness (named, not live-tested here)

This sandbox is a standalone account with no AWS Organization, so an SCP can't actually
be attached and re-verified in this lab — an honest scope note, matching this path's
pattern elsewhere of naming a control precisely rather than glossing over what wasn't
actually demonstrated live. The concept and a documented example policy
([`policies/example-scp-deny-iam-users.json`](../labs/day13/policies/example-scp-deny-iam-users.json))
are in Section 1 above; if you have access to an AWS Organization, attaching it to an OU
and re-running Step 3's simulator call (`simulate-principal-policy` accepts an
`--organizations-policy` parameter for exactly this) is the natural extension.

### Defense 4 — `iam:PassRole` awareness (foreshadowing Day 14)

Notice what today's role's trust policy
([`policies/trust-policy.json`](../labs/day13/policies/trust-policy.json)) actually
says: **any** EC2 instance can assume `cyberlab-day13-role`, *if* something with
`iam:PassRole` + `ec2:RunInstances` permission attaches it when launching that instance.
Today doesn't grant the user that combination on purpose — Day 14 does, and shows
exactly how a low-privileged user with those two permissions together can launch an
instance, attach this over-permissioned role to it, and inherit everything the role's
policy grants without ever touching an IAM console. Keep this trust policy in mind; it's
the exact seam Day 14 opens.

Always tear down when you're done:

```sh
cd cyber_security/labs/day13
./teardown.sh
```

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Identify the over-broad statement and tighten it

Given this policy attached to a billing-report Lambda's execution role, identify the
one statement that grants more than the task (reading objects from one reports bucket
and writing CloudWatch Logs) needs, and rewrite it to least privilege.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadReportsBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::billing-reports-prod/*"
    },
    {
      "Sid": "LambdaLogging",
      "Effect": "Allow",
      "Action": "logs:*",
      "Resource": "*"
    }
  ]
}
```

**Hint:** the first statement is already scoped correctly (one action, one bucket
prefix) — the problem is entirely in the second statement. Ask what a Lambda actually
needs from CloudWatch Logs versus what `logs:*` on `Resource: "*"` additionally grants
(hint: `logs:DeleteLogGroup`, and against *any* log group in the account, not just this
function's own).

**Solution sketch:** `LambdaLogging` is over-broad on both axes. A Lambda execution
role only ever needs to create its own log group/stream and write log events — never
delete log groups, read other functions' logs, or touch `Resource: "*"`. Tightened:

```json
{
  "Sid": "LambdaLogging",
  "Effect": "Allow",
  "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
  "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/billing-report-fn:*"
}
```

Three narrowed actions (no `Delete*`, no read of other groups) and a resource scoped to
exactly this function's own log group ARN pattern.

### Drill 2 — Predict the outcome of an allow+deny combination

A user has **two** policies attached:

- Policy A: `Allow s3:* on Resource: "*"`
- Policy B: `Deny s3:DeleteObject on Resource: "arn:aws:s3:::prod-*"`

The user calls `s3:DeleteObject` on `arn:aws:s3:::prod-backups/file.txt`. Allowed or
denied? What about `s3:DeleteObject` on `arn:aws:s3:::dev-scratch/file.txt`?

**Hint:** apply Section 1's exact evaluation order — check for an explicit deny that
matches *before* concluding anything from the allow.

**Solution sketch:** **Denied** for `prod-backups` — Policy B's explicit deny matches
(action and resource both match its `Deny` statement), and per **explicit deny >
explicit allow**, that overrides Policy A's blanket allow completely; it does not
matter that Policy A also technically covers this call. **Allowed** for `dev-scratch` —
Policy B's deny doesn't match this resource at all (its `Resource` pattern is
`prod-*` only), so nothing explicitly denies the call, and Policy A's allow takes
effect. This is the exact mechanism a real least-privilege guardrail uses: you don't
need to rewrite every broad allow elsewhere — one correctly-scoped explicit deny is
enough to carve out a protected exception.

### Drill 3 — Shared responsibility for S3 vs. EC2

Name one security failure that's **AWS's responsibility** and one that's **yours**, for
each of S3 and EC2 — four answers total, each with a one-sentence "because."

**Hint:** think about what you never touch (physical hardware, hypervisor) versus what
you configure yourself (bucket policy, security groups, guest OS) — Section 1's table
gives you the layer boundary directly.

**Solution sketch:**

- **S3 — AWS's responsibility:** the durability/availability of the storage layer
  itself and the physical security of the data centers holding it — you never provision
  or patch anything at that layer.
- **S3 — your responsibility:** whether the bucket is publicly readable (Block Public
  Access setting, bucket policy) — AWS gives you every tool to lock it down; a public
  leak from a misconfigured bucket policy is entirely a customer-side failure.
- **EC2 — AWS's responsibility:** the hypervisor's isolation between your instance and
  every other tenant's instance on the same physical host — a hypervisor escape would be
  AWS's failure, not yours.
- **EC2 — your responsibility:** patching the guest OS running on that instance — an
  unpatched, internet-facing EC2 instance compromised via a known OS vulnerability is a
  customer-side failure; AWS never patches your guest OS for you.

### Drill 4 — Predict the effective permission with a permission boundary in place

A user's **identity policy** allows `s3:*` on `Resource: "*"`. Their **permission
boundary** (Section 1's
[`permission-boundary-example.json`](../labs/day13/policies/permission-boundary-example.json))
allows only `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`, and `ec2:DescribeInstances`.
Can this user call `s3:DeleteBucket`? Can they call `s3:GetObject`?

**Hint:** a permission boundary isn't evaluated as "another vote" alongside the identity
policy — it's an upper bound the identity policy's grant must fit *inside*. The
effective permission is the intersection of the two, not the union.

**Solution sketch:** `s3:DeleteBucket` is **denied** — even though the identity policy's
`s3:*` technically covers it, the boundary doesn't list `s3:DeleteBucket` among its
allowed actions, so the intersection excludes it; the boundary caps what the identity
policy can grant, however broad that identity policy is. `s3:GetObject` is **allowed** —
both the identity policy (`s3:*` covers it) and the boundary (explicitly lists it) allow
it, so the intersection includes it. The lesson: a boundary makes an over-broad identity
policy *safe on the specific actions it excludes*, without requiring you to have
rewritten that identity policy correctly in the first place — a second, independent
layer, exactly as Defense 2 above applied it.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked (assessed):** name the specific over-broad statement you found in
  Step 2/3 (`s3:*` on `Resource: "*"`), and the exact simulator call that proved it was
  actually exploitable (`s3:DeleteBucket`/`s3:PutBucketPolicy` against an unrelated
  bucket), versus which part of today (SCPs) you only reasoned through conceptually,
  not against your live sandbox.
- **How:** which of the IAM concepts — principal vs. policy vs. role, trust policy vs.
  permission policy, or explicit-deny-wins evaluation order — took more than one pass to
  actually click, and what example (from today's drills or your own) made it click?
- **What defended it:** which of Defense 1–2 did you actually run against your sandbox
  (create-policy-version, put-user-permissions-boundary), and what did the simulator
  call return differently before vs. after?
- **What confused me:** anything about *why* a permission boundary can only shrink
  permissions and never grant any, or about the exact difference between a role's trust
  policy and its permission policy, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (principal, policy, role, trust
  policy, least privilege, permission boundary, SCP, explicit deny) to re-explain from
  memory before Day 14, without looking back at this file — Day 14 assumes you can
  already state the trust-policy/permission-policy distinction cold.
