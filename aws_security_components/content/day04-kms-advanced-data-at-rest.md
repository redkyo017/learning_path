# Day 4 — KMS advanced + data at rest

## Why this matters at work

Cross-account data sharing — a partner reading from your analytics
bucket, a DR copy in another account, a shared CMK backing both your prod
and security-tooling accounts — is one of the most common real production
patterns, and it's also where "encrypted at rest" quietly stops meaning
"safe." A CMK's key policy is the one place that decides who can ever
decrypt, full stop, regardless of how tight every other policy in the
request looks. Get that one document slightly wrong — a `Principal` a
notch too broad, a missing `kms:ViaService` condition, a grant nobody
tracked and retired — and the encryption checkbox becomes theater. This
day is about learning to read and write that one document correctly,
because "who can decrypt this, really?" is a question worth asking about
every CMK you will ever touch, not just the ones in this lab.

## The engine lens

**Door:** resource-based policy (the KMS key policy) + condition keys
(`kms:ViaService`, and — for cross-account — the caller's account/ARN).

KMS is a genuinely special case of the evaluation order, worth naming
explicitly: for most resources, a resource-based policy is *additive* —
it can grant access an identity policy never mentions (that's how
cross-account S3 bucket policies work), but if there's no resource policy
at all, the identity policy alone is often sufficient within the same
account. **KMS key policies don't work that way.** A KMS key's policy is
mandatory and load-bearing even for same-account access: if the key
policy doesn't grant a permission (to the account root, to IAM control, or
to a specific principal), no identity policy anywhere can make up the
difference. This is why every `aws_kms_key` needs a
`"Sid": "Enable IAM User Permissions"`-style root statement — remove it,
and you can lock even account admins out of a key they own (there's no
"IAM override" for KMS the way there sort of is for some other services).

That root statement is also *why* the illusion of "IAM alone controls
this" holds up in normal use: granting the account root `kms:*` doesn't
mean "only the root user" — it means "any identity policy, anywhere in
this account, that grants a KMS action on this key is now sufficient,"
because the root statement delegates control down to IAM. That's the
mechanism behind [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #5's warning: once
that root statement exists (and it almost always does, because Terraform
sets it by default when you don't specify a `policy`), it's easy to
forget the key policy is even in play, because IAM identity policies
*appear* to be running the whole show. They aren't — they're running the
show *because* the key policy delegated it to them, and the key policy can
take that delegation back, narrow it, or add conditions on top, any time.

## Core concepts

### Recap: CMK vs. AWS-managed key, key policy vs. grant

Quick orientation if you're coming to this cold — full definitions live in
[`GLOSSARY.md`](GLOSSARY.md#c) and [`GLOSSARY.md`](GLOSSARY.md#k):

- A **CMK** ([`GLOSSARY.md`](GLOSSARY.md#c)) is a key you fully control the
  policy on. `labs/base/data.tf`'s `aws_kms_key.app_data` is the one CMK
  this whole path shares.
- The **key policy vs. grant** distinction
  ([`GLOSSARY.md`](GLOSSARY.md#k)): the key policy is the root document;
  grants are narrower, often temporary delegations layered *within* what
  the key policy already allows — never a way around it.
- **Envelope encryption** ([`GLOSSARY.md`](GLOSSARY.md#e)) is the pattern
  underneath both S3's SSE-KMS and DynamoDB's SSE: a data key is
  generated, used locally to encrypt the bulk data, and only its
  KMS-encrypted form is stored — KMS never touches the bulk data directly.

Today builds three new pieces on top of that foundation: cross-account
access, grants with grant tokens, and condition-key scoping of decrypt.

### Cross-account KMS: three things that must line up

Sharing a CMK across accounts is a genuinely common ask ("Account B needs
to read the S3 objects Account A encrypted with Account A's key") and it
fails in a specific, memorizable way when people get it half-right. THREE
things, on two different accounts, all have to say yes:

```
Account A (key owner)                    Account B (borrower)
┌─────────────────────────┐              ┌──────────────────────────┐
│ 1. KEY POLICY on the CMK │              │ 2. IDENTITY POLICY on    │
│    must name Account B's │   ┌────────▶ │    the specific role/user│
│    account or role ARN   │   │          │    must ALSO grant       │
│    as a Principal, with  │   │          │    kms:Decrypt (etc.) on │
│    the actions it needs  │   │          │    that key's ARN        │
└─────────────────────────┘   │          └──────────────────────────┘
              │                │                        │
              └────────────────┴────────────────────────┘
                               │
                  3. CALLER IDENTITY must be exactly
                     the principal named in both places —
                     the right role ARN, right account,
                     no typos, right partition
```

Miss any one of the three and the request fails, but each failure mode
looks different, which is exactly why this trips people up:

- **Key policy silent on Account B, identity policy grants it anyway** →
  `AccessDenied`, and it's confusing because Account B's own admin will
  swear their policy is "clearly" permissive enough. It is — on their side.
  The key's side never agreed.
- **Key policy names Account B, but nobody in Account B has an identity
  policy granting the action** → also `AccessDenied`, same symptom,
  opposite cause. `kms:ViaService`/condition scoping never even gets
  evaluated because the request doesn't have the base grant on either
  side to begin with.
- **Both policies are fine, but the caller assumed the wrong role, or a
  typo'd ARN, or the wrong account** → `AccessDenied` for a reason neither
  policy document is "wrong" about — the caller identity just isn't the
  one either document named. This is the case people burn the most time
  on, because they re-read both policies ten times and they're both
  correct.

The corrective habit: when a cross-account KMS request fails, check the
three independently, in this order — (1) does the key policy name this
exact account/principal for this exact action, (2) does an identity policy
in the caller's own account grant it too, (3) run
`aws sts get-caller-identity` as the actual caller and diff that ARN
against what both policies say, character for character.

### Grants and grant tokens

A **grant** ([`GLOSSARY.md`](GLOSSARY.md#k)) is how you delegate specific,
often-temporary key permissions to a principal *without* editing the key
policy every time — critical when the "who needs access" list changes
often or is created programmatically. The canonical real-world example:
**sharing an encrypted EBS snapshot cross-account.** You (the snapshot
owner) can't edit the *target* account's key — they don't have one yet for
this data — so instead you create a grant on YOUR CMK naming the target
account as grantee, covering `kms:CreateGrant`, `kms:Decrypt`,
`kms:DescribeKey`, and `kms:ReEncryptFrom`/`kms:ReEncryptTo`. When the
target account creates a volume from your shared snapshot, AWS
transparently re-encrypts the volume's data key under *their* CMK, using
that grant — and once that re-encryption happens, you can retire the
grant. No key policy edit, no coordination beyond "here's the grant."

**Grant tokens** exist because of grants' one operational wrinkle:
`CreateGrant` is subject to *eventual consistency* — a grant may not be
visible to a `Decrypt` call made microseconds later, even though the
`CreateGrant` API call itself already returned success. If your workflow
calls `CreateGrant` and then immediately tries to use the permission it
just granted, pass the `GrantToken` that `CreateGrant` returned back into
the follow-up `Decrypt`/`Encrypt` call — that token proves the grant
exists even before it's fully propagated, sidestepping the race. Miss this
and you get a flaky, hard-to-reproduce `AccessDenied` that "fixes itself"
if you retry a second later — a classic eventual-consistency symptom, not
a policy bug.

### Wiring KMS into S3, DynamoDB, EBS, and RDS at rest

The mechanics differ slightly by service, but the underlying question —
*who, through what path, can decrypt* — never changes.

**S3 (concrete — this workload).** `labs/base/data.tf`'s
`aws_s3_bucket_server_side_encryption_configuration.app_data` sets
SSE-KMS with `bucket_key_enabled = true` as the bucket default. Two
distinct KMS calls happen per object lifecycle: `kms:GenerateDataKey` on
`PutObject` (S3 asks KMS for a fresh data key, encrypts the object locally,
stores only the encrypted data key alongside the object — envelope
encryption again), and `kms:Decrypt` on `GetObject` (S3 asks KMS to
unwrap that stored data key, then decrypts locally and returns plaintext
to the caller transparently). `bucket_key_enabled` is a cost/latency
optimization — it caches a bucket-level data key for a short window
instead of calling KMS per object — it does not change who can decrypt;
that's still 100% a key-policy + identity-policy question.

**DynamoDB (concrete — this workload's DB tier).**
`aws_dynamodb_table.app_data`'s `server_side_encryption` block works the
same way conceptually: DynamoDB calls `kms:GenerateDataKey` and
`kms:Decrypt` against the same CMK, transparently, per the service's own
internal request path — which is exactly what lets you scope a key-policy
statement to `kms:ViaService = dynamodb.<region>.amazonaws.com` the same
way you would for S3.

**EBS (conceptual — not in this workload).** An encrypted EBS volume's
data key is generated once at volume creation and wrapped by the CMK you
chose at that time; every subsequent read/write to the volume triggers
transparent decrypt/encrypt calls against that same CMK for the life of
the volume. The share-a-snapshot-cross-account pattern above is EBS's
signature KMS interaction, and it's a grants problem specifically because
volume/snapshot ownership crosses accounts far more often than S3 object
ownership does.

**RDS (conceptual — this workload uses DynamoDB as its documented DB-tier
stand-in; see `labs/base/data.tf`'s design-decision comment for why).**
The CMK for storage encryption is chosen **once, at instance creation, and
can never be changed in place.** If you provisioned an RDS instance with
the wrong CMK — or need to move it to a different account/region's CMK —
your only path is: snapshot the instance, copy the snapshot specifying the
new CMK (this re-encrypts during the copy), then restore a new instance
from that re-encrypted copy. There is no `ModifyDBInstance` flag for this.
Automated backups and read replicas inherit the source instance's CMK
choice by default and need the same snapshot-copy-restore treatment to
move to a different key, which is exactly why this decision deserves more
up-front thought than most Terraform defaults get.

### `kms:ViaService` and condition-key scoping of decrypt

`kms:ViaService` ([`GLOSSARY.md`](GLOSSARY.md#k)) restricts a key-policy
(or identity-policy) statement so it only matches when the request arrived
*through* a named AWS service's own request path — `s3.<region>.amazonaws.com`,
`dynamodb.<region>.amazonaws.com`, `rds.<region>.amazonaws.com`, and so on.
It answers a narrower and more useful question than "can this principal
ever decrypt with this key": it asks "is this specific request the kind of
request we actually intend, or is it a bare, direct KMS API call that
happens to be using a credential that also has some other, legitimate
reason to touch this key?" A principal whose only real job is "let S3
encrypt/decrypt objects on my behalf" should almost never also be able to
call `kms:Decrypt` directly from a script — `kms:ViaService` is the
condition that turns "should never" into "structurally can't."

Two adjacent condition keys worth knowing exist, even though this day's
lab focuses on `ViaService`: `kms:CallerAccount` (scope a statement to
callers from one specific account — useful in a key policy meant to serve
several trusted accounts with different permissions each) and
`kms:EncryptionContext:<key>` (scope a statement so it only matches
requests carrying a specific encryption-context key/value pair — a way to
bind a grant or an allow statement to *which* logical dataset is being
decrypted, not just which principal is asking). Both follow the identical
mental model as `ViaService`: the identity side answers "who," the
condition key on the resource side answers "under exactly what
circumstances," and both have to say yes.

One more habit worth adopting here, unrelated to policy syntax but just as
important: when you call `Decrypt`, **always pass an explicit `KeyId`**,
even though the API doesn't require it (KMS can derive the key from the
ciphertext's own metadata). If you don't, you're implicitly trusting
whatever key the ciphertext claims to be encrypted under — which matters
if an attacker can substitute ciphertext encrypted under a *different*,
more permissive key you also have some access to. Passing `KeyId`
explicitly turns that into a hard check instead of an assumption.

## Break → Harden lab

See `labs/day04/`. Unlike most days, this lab starts LOCKED on purpose:
**the break:** deliberately strip the `kms:ViaService` condition from one
key-policy statement, watch a direct `kms:Decrypt` call (using
credentials shaped exactly like the real, already-over-broad task role's)
succeed where it shouldn't. **The harden:** put the condition back.
**Success signal:** `AccessDenied` under the locked policy, decrypt
succeeds under the broken one, `AccessDenied` again once re-locked — with
the legitimate via-S3 read proven unaffected in every state. Full expected
outputs and the exact one-statement diff that opened the hole are in
`labs/day04/SOLUTION.md`.

## Exercises

1. **Cross-account, make it work then make it least-privilege.** Sketch
   (in HCL or plain JSON — no real second account needed, use a clearly
   marked placeholder like `ACCOUNT_B_PLACEHOLDER`) what it takes for a
   role in a second AWS account to decrypt objects encrypted with this
   workload's CMK. First pass: get it working at all. Second pass: tighten
   it to least privilege.
   **Hint:** you need statements in *two* places (see "three things that
   must line up" above) — don't forget the caller-identity check is a
   third, separate thing to verify, not a policy edit.
   **Solution sketch:** Pass 1 (works, too broad) — key policy statement:
   `Principal: {"AWS": "arn:aws:iam::ACCOUNT_B_PLACEHOLDER:root"}`,
   `Action: "kms:Decrypt"`, `Resource: "*"`; Account B side: an identity
   policy on the target role granting `kms:Decrypt` on the CMK's ARN,
   `Resource: "*"` for now. This works but lets ANY principal in Account B
   with a matching identity policy use the key. Pass 2 (least privilege):
   narrow the key-policy `Principal` from the account root to the *specific
   role ARN* that needs access
   (`arn:aws:iam::ACCOUNT_B_PLACEHOLDER:role/specific-consumer-role`), add
   a `kms:ViaService` condition scoped to whichever service Account B
   actually reads through, and narrow Account B's identity policy
   `Resource` from `"*"` to the exact CMK ARN. Verify by testing the deny
   path too (anti-pattern #3): a *different* role in Account B should now
   get `AccessDenied`.

2. **EBS cross-account snapshot share.** Write the `CreateGrant` call
   (CLI or HCL `aws_kms_grant`) needed before Account B can create a
   volume from a snapshot you've shared with them, encrypted under your
   CMK.
   **Hint:** the target account needs to *re-encrypt*, not just decrypt —
   what permission does re-encryption require that plain reading doesn't?
   **Solution sketch:** grant `kms:CreateGrant`, `kms:Decrypt`,
   `kms:DescribeKey`, `kms:GenerateDataKeyWithoutPlaintext`,
   `kms:ReEncryptFrom`, and `kms:ReEncryptTo` to Account B's account/role
   as grantee principal — `GenerateDataKeyWithoutPlaintext` is the piece
   that's easy to forget: it's what lets Account B's new volume get a
   freshly wrapped data key under your CMK during the copy, not just
   decrypt the existing one. When Account B creates a volume from the
   shared snapshot, AWS uses this grant to decrypt with your CMK and
   re-encrypt the new volume's data key under Account B's own CMK in one
   step. Retire the grant (`RetireGrant`) once you've confirmed the
   volume was created — it's a one-time bridge, not a standing grant.

3. **Wrong CMK on an RDS instance.** You provisioned an RDS instance with
   the wrong CMK a month ago. It's now got production data on it. What are
   your actual options, and what's the operational cost of each?
   **Hint:** re-read the RDS paragraph above — there is no in-place fix.
   **Solution sketch:** snapshot the instance → copy the snapshot,
   specifying the correct target CMK on the copy (this re-encrypts) →
   restore a new instance from the re-encrypted copy → cut over
   application connection strings → decommission the old instance. Cost:
   downtime or a blue/green cutover window, storage cost of the
   intermediate snapshot/copy, and the operational risk of a full
   restore-and-cutover instead of a config change — which is exactly why
   choosing the right CMK before first launch (not after) is worth the
   extra five minutes of design review.

4. **Grant token race.** Your application calls `CreateGrant`, then
   immediately calls `Decrypt` using the permission that grant was
   supposed to provide, and gets an intermittent `AccessDenied` that
   disappears on retry. What's happening, and what's the fix?
   **Hint:** re-read "Grant tokens" above — this is not a policy bug.
   **Solution sketch:** grants are eventually consistent; the `Decrypt`
   call can race ahead of the grant's propagation. Fix: capture the
   `GrantToken` returned by `CreateGrant` and pass it as a parameter on the
   immediately-following `Decrypt`/`Encrypt` call — that token proves the
   grant exists to KMS even before it's globally visible, removing the
   race instead of papering over it with a retry loop.

## Anti-patterns today

- **[`ANTIPATTERNS.md`](ANTIPATTERNS.md) #5** is this day, in full:
  "encryption at rest: enabled" was never the question that mattered in
  the break→harden lab above — `aws_kms_key.app_data` was encrypted at
  every single step, including the step where the exfil succeeded. "Who
  can decrypt, through what path" was the only question that changed.
- **Over-broad key policies specifically** are the resource-policy-side
  twin of [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #6's identity-side warning
  about wildcards: a key-policy statement with `Principal: "*"` or a
  `Resource: "*"`-plus-unconditioned-`kms:Decrypt` grant to a whole account
  root (rather than a specific role) looks fine in a policy read-through —
  nothing about it "looks dangerous" — until you ask exactly the question
  #5 poses. Today's lab statement, before the fix, was precisely this
  shape: correct actions, correct principal, just missing the one
  condition that scoped *how* it could be invoked.
- **Treating the key policy as "just KMS's syntax"** is
  [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #1 wearing a KMS costume — it's the
  same resource-based-policy door Day 1 already taught, evaluated in the
  same evaluation order, just with `kms:ViaService` as this door's
  distinctive condition-key flavor.

## Cert corner (SCS-C02)

- **Domain 5, Data Protection** (see [`CERT-MAP.md`](CERT-MAP.md)) —
  today's primary domain, continuing directly from Day 3's KMS
  foundations.
- Know the cross-account "three things must line up" model cold — it's
  the single most testable KMS cross-account scenario shape, and it's the
  same shape whether the exam frames it as S3, EBS, or a direct KMS
  question.
- Know `kms:ViaService`'s specific job (scoping *how* a request arrived,
  not *who* sent it) and the fact that RDS's CMK choice is immutable
  post-creation — both are common "which statement/approach is correct"
  question shapes.

## Teardown

`cd labs/day04 && terraform destroy` — destroys only this day's
`exfil_sim` role/policy and test S3 object, and reverts the base CMK's key
policy to AWS's default (root-only) policy — the same state `labs/base`
itself leaves it in, since base never sets an explicit `policy` on the
key. The base CMK, S3 bucket, DynamoDB table, and Secrets Manager secret
are never touched by this destroy. Full checklist in
`labs/day04/README.md` "Teardown."
