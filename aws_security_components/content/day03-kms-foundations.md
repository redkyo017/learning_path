# Day 3 — KMS foundations

## Why this matters at work

"Encryption at rest: enabled" is the single most misleading green
checkmark in AWS. It tells you data is scrambled on disk; it tells you
nothing about who can unscramble it. Every real incident involving a
KMS-encrypted resource comes down to the same question a checkbox
can't answer: *who can actually decrypt this, right now, today?*
Answering that requires reading a key policy the way you'd read a
firewall rule — as the actual control, not as paperwork sitting behind
a UI toggle.

## The engine lens

A KMS **key policy** ([`GLOSSARY.md`](GLOSSARY.md#k)) is a resource-based policy — same door, same slot
in the evaluation order as an S3 bucket policy or an SQS queue policy:

```
explicit Deny → SCP/RCP → resource-based policy → identity-based policy
                                    → permission boundary → session policy
```

KMS has one quirk that makes this door special: **a KMS key with no
key policy statement grants access to nobody, not even the account
root.** Every other resource in this path defaults toward "the account
owns it, IAM decides" without you writing anything down; KMS forces you
to write it down. That's why the key policy is called the **root of
trust** for a [CMK](GLOSSARY.md#c) — it is the one place every other permission for that
key (grants, identity policies) is checked against, and if the key
policy is silent, nothing downstream matters.

In practice almost every CMK ships with one specific statement — the
one AWS itself writes by default when you create a key without
specifying `policy` in Terraform:

```json
{
  "Sid": "Enable IAM User Permissions",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::<account-id>:root" },
  "Action": "kms:*",
  "Resource": "*"
}
```

This is not "only the root user can use this key." AWS documents this
specific pattern as **delegation to IAM**: naming the account's root
ARN with `kms:*` tells KMS "let this account's own IAM identity
policies decide who does what." It's the reason `labs/base`'s
`aws_kms_key.app_data` — which never sets a `policy` argument — already
works: the task role's inline policy grants
`kms:Decrypt`/`kms:GenerateDataKey` on that key's ARN (see the
`DecryptAppDataKey` statement in `labs/base/iam.tf`), and because the
key policy delegates to IAM, that identity-policy grant is all it takes.
**That delegation statement is also the exact hole today's lab exploits
and then closes** — see Break → Harden below.

## Core concepts

### AWS-managed vs. customer-managed keys

Full definition: [`GLOSSARY.md`](GLOSSARY.md#c).

| | AWS-managed key (`aws/service`) | Customer-managed key (CMK) |
|---|---|---|
| Who creates it | The integrating service, automatically | You, explicitly |
| Key policy | Fixed, AWS-controlled — you can view, never edit | Yours to write |
| Rotation | Automatic, ~1 year, not configurable | Optional automatic (1-year default, now configurable to any period from 90–2560 days) or manual |
| Deletion | You cannot delete it | You can schedule deletion (7–30 day window) |
| "Who can decrypt?" | Whatever that service's fixed policy says | Whatever *you* wrote — your responsibility |

Reach for a CMK the moment the answer to "who can decrypt this" needs
to be something more specific than "whatever this AWS service decided."
`labs/base`'s `aws_kms_key.app_data` is a CMK for exactly this reason:
it backs both the S3 bucket and the DynamoDB table, and this path wants
you controlling — and testing — that policy directly.

### Key policy vs. grant

Full definition: [`GLOSSARY.md`](GLOSSARY.md#k).

- **Key policy** — the resource policy on the key itself. The root of
  trust: nothing about that key is authorized without it, directly or
  by delegation. You edit it deliberately, usually rarely.
- **Grant** ([`GLOSSARY.md`](GLOSSARY.md#k)) — a narrower, often temporary and programmatically-created
  delegation of specific key operations to a specific principal.
  Grants exist so a service (or an automated process) can get exactly
  the KMS permissions it needs *without anyone editing the key policy
  document* — the canonical example is an AWS service that creates a
  grant for itself at the moment it needs to use your key on your
  behalf, then revokes it when done.
- The one nuance worth holding onto: a grant is normally sufficient
  **on its own** — the grantee does not also need a matching
  identity-based policy statement, unlike the "identity policy must
  also allow it" requirement that applies when permission comes from
  the key policy's IAM-delegation statement. A grant is a complete,
  self-contained authorization, scoped to exactly the operations and
  principal it names.

Read the key policy first, always. Grants are additive permissions
layered on top of what the key policy already allows — never a
side-door around it.

### Envelope encryption, walked through

KMS's direct `Encrypt`/`Decrypt` API caps the payload at 4 KiB — it was
never meant to encrypt a file, an object, or a database row directly.
**Envelope encryption** ([`GLOSSARY.md`](GLOSSARY.md#e)) is the pattern every SDK, every S3 SSE-KMS
integration, and every EBS volume uses instead:

```
1. GenerateDataKey  →  KMS returns TWO things:
                          - a PLAINTEXT data key   (use once, then discard)
                          - the SAME key, ENCRYPTED under your CMK
2. Encrypt locally   →  use the plaintext data key to encrypt your
                          actual data (AES-GCM, etc.) — no KMS call per
                          byte, no 4 KiB limit, fast
3. Store             →  the ciphertext data  +  the ENCRYPTED data key
                          side by side. Discard the plaintext data key
                          immediately — never write it to disk.
4. Later, to decrypt →  Decrypt(encrypted data key)  →  KMS returns the
                          plaintext data key  →  decrypt your data
                          locally with it.
```

KMS never touches your bulk data — only the small [data key](GLOSSARY.md#d), twice
(once to mint it, once to unwrap it). This is also *why* the CMK is the
root of trust even though KMS never sees the payload: whoever can
decrypt that encrypted data key can decrypt everything it protects.
Today's lab runs this exact sequence by hand with the CLI (`generate-
data-key` → `openssl` → `decrypt`), and it's also precisely what
happens invisibly every time the base S3 bucket's SSE-KMS default
encrypts an object — S3 is doing steps 1–4 on your behalf, per object.

### Rotation

- **Automatic rotation** (`enable_key_rotation = true` — already set on
  `aws_kms_key.app_data` in `labs/base/data.tf`): once a year, KMS
  generates new backing key material for the *same* key ID/ARN/alias.
  Old ciphertext keeps working forever — KMS retains every prior
  backing version internally and picks the right one automatically at
  decrypt time. You do nothing; nothing needs re-encrypting.
- **Manual rotation** (swapping an alias to point at a brand-new key):
  the *old* key still has to stick around to decrypt data encrypted
  under it, and anything you want migrated to the new key has to be
  explicitly re-encrypted. Only reach for this when you need a genuinely
  new key (e.g., a new administrative boundary), not as a routine
  hygiene task — automatic rotation already covers routine hygiene.
- AWS now also supports a **configurable rotation period** (90–2560
  days) for automatic rotation, instead of only the fixed ~1-year
  default — useful when a compliance requirement names a specific
  rotation cadence.

### `kms:ViaService` (preview — Day 4 goes deep)

`kms:ViaService` ([`GLOSSARY.md`](GLOSSARY.md#k)) is a condition key that scopes a KMS permission to requests arriving *via*
a named AWS service (e.g. `s3.us-east-1.amazonaws.com`), rather than a
direct `kms:Decrypt` call from the CLI/SDK. It's how a key policy can
say "S3 may use this key to serve SSE-KMS objects on callers' behalf"
without that same statement also authorizing "anyone with this
permission may call KMS directly and hold the decrypted data key
outside of S3's use case." File it away today; Day 4's cross-account
lab is where you'll write one.

### The central question: who can actually decrypt this?

Every time you touch a CMK, run this trace — it's the same evaluation
order as every other door, with KMS's one quirk (silence = nobody)
folded in:

1. **Explicit Deny**, anywhere (key policy, SCP, identity policy) —
   wins immediately, full stop.
2. **SCP/RCP** — could the organization-level guardrail even reach this
   far? (Usually not scoped to KMS in a single-account lab, but never
   assume.)
3. **Key policy (resource-based)** — does it name this principal
   directly, *or* does it contain the IAM-delegation statement? If the
   key policy is silent on both counts, stop here: **denied**, no matter
   what the identity policy says.
4. **Identity policy** — if the key policy delegates to IAM, does this
   principal's identity policy grant the action on this key's ARN? If
   the key policy instead named the principal directly (no IAM
   delegation), the identity-policy check for that specific permission
   is moot — the key policy already carried it.
5. **Permission boundary / session policy** — do either of these,
   if present, cap the identity-policy grant below what's needed?

Walk `labs/base`'s real setup through this trace right now, before you
touch the lab: `aws_kms_key.app_data`'s policy is silent-but-delegating
(step 3 passes via IAM delegation), and `aws_iam_role.task`'s
`DecryptAppDataKey` statement grants `kms:Decrypt` + `kms:GenerateDataKey`
on that key's ARN (step 4 passes) — so the ECS task role can decrypt.
Nothing else in the base workload can, because nothing else has that
identity-policy statement. That's the whole model; today's lab now
breaks and reinstates the resource-policy half of it deliberately.

## Break → Harden lab

See [`labs/day03/`](../labs/day03/). **The break:** a second test
principal gets the *same* KMS + S3 identity-policy grant as the
intended one (a realistic copy-paste mistake) — and because the key
policy is left at its silent, IAM-delegating default, the unintended
principal can decrypt just fine. **The harden:** the key policy is
replaced with an explicit key-administrators statement (management
actions only) plus a usage statement naming *only* the intended
principal for `kms:Decrypt`/`kms:GenerateDataKey`/`kms:Encrypt` — after
which the unintended principal's identical identity-policy grant is no
longer enough, because the resource-based door no longer delegates.
**Success signal:** the same `aws kms decrypt` / `aws s3 cp` call from
the unintended principal returns `AccessDenied` after the harden,
having returned data before it.

## Exercises

1. **Trace who can decrypt.** A key policy has exactly two statements:
   (a) account root granted `kms:*` on `Resource: "*"`, and (b) a
   statement naming `role/reporting-svc` for `kms:Decrypt`, with a
   condition `"StringEquals": {"kms:ViaService": "s3.us-east-1.amazonaws.com"}`.
   The identity policy for `role/reporting-svc` grants `kms:Decrypt` on
   this key's ARN with no conditions. Does `role/reporting-svc` succeed
   calling `kms:Decrypt` directly from the CLI (not via S3)? Does it
   succeed reading an SSE-KMS object from S3?
   **Hint:** statement (a) delegates to IAM for everyone; statement (b)
   is an *additional* narrower allow, not a restriction on (a) — but the
   `kms:ViaService` condition only applies to statement (b)'s grant of
   the request context, and a direct CLI call's context is not "via S3."
   **Solution sketch:** the direct CLI call still succeeds — statement
   (a)'s IAM delegation plus the role's own unconditioned identity-policy
   `Allow` covers it regardless of statement (b). The S3-read also
   succeeds (via delegation, or via (b) — either path opens it). The
   `kms:ViaService` condition here narrows *nothing* in practice because
   the broad delegation statement (a) is still present; this is exactly
   the trap this day's lab demonstrates — a scoped statement means
   nothing while a blanket delegation statement is also in the policy.
2. **Grants vs. identity policy.** A Lambda function's execution role
   has no KMS statements in its identity policy at all. A grant exists
   on the CMK naming that exact role ARN for `kms:Decrypt` and
   `kms:GenerateDataKey`. Can the function decrypt?
   **Hint:** re-read "Key policy vs. grant" above — grants are
   self-contained.
   **Solution sketch:** yes. The grant alone is a complete authorization
   for the operations and principal it names; no identity-based policy
   statement is required to accompany it. This is precisely why AWS
   services use grants internally instead of asking you to edit your
   key policy every time they need momentary access.
3. **Rotation and old ciphertext.** Automatic rotation has been enabled
   on a CMK for two years (two rotation events have occurred). An object
   encrypted under this CMK the day it was created, before rotation ever
   ran, is fetched today. Does it decrypt?
   **Hint:** what does "same key ID, new backing material" actually
   mean for *old* ciphertext?
   **Solution sketch:** yes, transparently — KMS retains every prior
   backing key version tied to the same key ID and selects the correct
   version automatically at decrypt time. Automatic rotation never
   requires re-encrypting existing data; that's the entire point of
   rotating the backing material instead of swapping the key ID.
4. **Why envelope encryption, not direct `Encrypt`.** A teammate
   proposes calling `kms:Encrypt` directly on every 2 MB file the app
   uploads, to "keep it simple." What breaks, and what's the fix?
   **Hint:** check the payload limit on the direct `Encrypt`/`Decrypt`
   API.
   **Solution sketch:** the direct API caps at 4 KiB of plaintext — a
   2 MB file fails outright. The fix is the envelope pattern: call
   `GenerateDataKey` once, encrypt the 2 MB locally with the returned
   plaintext data key (no size cap, no per-byte KMS round trip), and
   store only the small encrypted data key alongside the ciphertext.

## Anti-patterns today

- [`ANTIPATTERNS.md` #5](ANTIPATTERNS.md) — trusting default encryption
  without asking "who can decrypt?" is the entire spine of today's
  lesson: `labs/base`'s CMK has "encryption at rest: enabled" from Day
  0, and that fact alone told you nothing about the break this lab just
  proved was sitting there the whole time.
- Related, not yet numbered: copy-pasting an IAM policy from one
  principal to a "similar" new one without re-deriving what it actually
  grants — the exact mistake that creates today's break.

## Cert corner (SCS-C02)

- **Domain 5 — Data Protection.** Key policy vs. grant, envelope
  encryption, and rotation are core Data Protection domain content —
  see [`CERT-MAP.md`](CERT-MAP.md) row 5 (Days 3, 4, 5, 12).
- Expect exam scenarios phrased exactly as "who can decrypt this
  object" given a key policy excerpt plus an identity policy excerpt —
  Exercise 1 above is that question format.
- Know the AWS-managed-vs-CMK trade-off table cold: it's a fast,
  frequently-tested distinction with no calculation required.

## Teardown

`cd labs/day03 && terraform destroy` removes only this day's two test
IAM roles. **No new CMK was created today** — the lab reuses
`labs/base`'s `aws_kms_key.app_data` and only manages that key's
*policy document* (via a standalone `aws_kms_key_policy` resource), so
there is no 7-day pending-deletion window to think about here, and
`labs/base/aws_kms_key.app_data` itself is never destroyed or scheduled
for deletion. See the lab README's teardown checklist for the one
gotcha specific to this day: destroying `aws_kms_key_policy` does not
revert the key to its original AWS-default policy, since a CMK must
always have *some* policy — the checklist gives the exact `aws kms
put-key-policy` command to restore the default if you want it back
before Day 4 picks the key policy up again.
