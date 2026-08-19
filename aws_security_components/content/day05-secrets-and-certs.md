# Day 5 — Secrets & certificates

## Why this matters at work

Two of the most common production incidents are the same shape: a
credential that leaked because it was easy to see, and a service that
went down (or got silently downgraded to plaintext HTTP) because a
certificate expired or was never wired up correctly in the first place.
Both are entirely preventable with the same discipline: one system of
record for secrets, referenced by ARN, never copied; and certificates
issued and renewed by a managed service instead of a spreadsheet
reminder to "renew before it expires." Today wires up both, on the same
workload you've been hardening all week.

## The engine lens

Today's door is the **resource policy** — specifically, a **secret
resource policy** attached directly to a Secrets Manager secret — plus
**service integration**, the mechanism by which ECS, ACM, and an ALB
listener each let another AWS service act on your behalf without you
handing out long-lived credentials for it.

A secret's resource policy sits in the same evaluation order you already
know: `explicit Deny → SCP/RCP → resource-based policy → identity-based
policy → permission boundary → session policy`. Concretely for a secret,
that means an explicit `Deny` in the secret's own resource policy beats
*any* identity policy anywhere in the account that tries to grant
`secretsmanager:GetSecretValue` on it — including one you forgot you
granted, or one a future teammate adds without realizing this secret is
special. That's the whole point of reaching for the resource-policy door
here instead of only tightening identity policies: it's a backstop that
holds regardless of what else changes.

## Core concepts

### Secrets Manager vs. Parameter Store SecureString — when to use which

Both store an encrypted string and both integrate with ECS's `secrets`
block. The difference is what you get beyond storage:

| | Secrets Manager | Parameter Store `SecureString` |
|---|---|---|
| Encryption at rest | Always (KMS) | Always for `SecureString` (KMS) |
| **Automatic rotation** | Built-in (`aws_secretsmanager_secret_rotation` + a rotation Lambda) | None — you'd build your own EventBridge-scheduled Lambda from scratch |
| **Resource policy** | Yes — a real resource-based policy, same evaluation-order door as everything else this week | No — Parameter Store has no per-parameter resource policy; access is identity-policy-only |
| Cross-account sharing | Resource policy makes this a first-class case | Requires identity-policy tricks on both sides, more fragile |
| Cost | ~$0.40/secret/month + API calls | Standard tier: free; Advanced tier: ~$0.05/parameter/month |
| Fits best | Credentials, API keys, anything that should rotate | App config that happens to be sensitive but doesn't need rotation (a feature flag with a sensitive default, an internal-only URL) |

**Rule of thumb:** if it's a *credential* — something with a lifecycle,
something you'd want to revoke and reissue — Secrets Manager. If it's
*sensitive configuration* that isn't itself a credential and doesn't need
rotation, Parameter Store `SecureString` is cheaper and simpler. When
you're unsure, default to Secrets Manager — the rotation and
resource-policy machinery costs you nothing extra to *have available*
even if you never turn rotation on.

### Secrets Manager rotation

Rotation is a 4-step contract your own Lambda implements (`createSecret`,
`setSecret`, `testSecret`, `finishSecret`) — Secrets Manager calls your
function, your function stages a new value under the `AWSPENDING` label,
optionally pushes it to whatever downstream system needs to know (a
database `ALTER USER`, for instance), tests that the new value actually
works, then Secrets Manager promotes it to `AWSCURRENT` and demotes the
old one to `AWSPREVIOUS`. Nothing about your application code needs to
change to support this — it always asks for whatever is `AWSCURRENT` at
call time. Today's lab ships the simplest possible version of this
Lambda: a generic (non-database) secret with nothing to push to
downstream, so `setSecret`/`testSecret` are close to no-ops — read
`labs/day05/rotation_lambda/rotate_app_secret.py` for the real shape,
including the parts that would change for a database credential.

### Secrets Manager resource policies

A resource policy on a secret is a normal IAM-style JSON policy document,
just attached to the secret instead of to a principal:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "Allow", "Effect": "Allow", "Principal": {"AWS": "<role-arn>"},
      "Action": ["secretsmanager:GetSecretValue"], "Resource": "*" },
    { "Sid": "DenyEveryoneElse", "Effect": "Deny", "Principal": "*",
      "Action": "secretsmanager:GetSecretValue", "Resource": "*",
      "Condition": {"StringNotEquals": {"aws:PrincipalArn": "<role-arn>"}} }
  ]
}
```

The `Deny` half is the part identity policies alone can't give you: it's
not "this role isn't granted access" (the default-deny you get for free),
it's "this call is explicitly refused no matter what else says otherwise."
Today's lab uses exactly this pattern to scope a secret to precisely two
principals — the app's task execution role and the rotation Lambda's role
— nothing else, ever, without editing this policy.

### Secrets Manager access from inside a VPC (preview of Day 7)

Every Secrets Manager API call from inside a VPC either goes out through
a NAT gateway (base's design is NAT-free, see `labs/base/README.md`) or
through a **VPC interface endpoint** for `secretsmanager`. An endpoint
also gets its own resource policy — a **VPC endpoint policy** — which
layers on top of everything else: it can permit "reachable from inside
this VPC" while a secret's own resource policy simultaneously denies
everyone except two roles, and both have to say yes. This lab doesn't
provision a VPC endpoint (base's private subnets are reserved for Day 7),
but it's worth previewing now because it's the same door, twice: the
[VPC endpoint policy](GLOSSARY.md#v) is a resource policy on the
endpoint; the secret's own policy is a resource policy on the secret.
Day 7 wires the endpoint; today wires the secret's half.

### ACM: public certificate issuance and DNS validation

ACM issues a **public** certificate for free, but only after you prove
you control the domain it's for. The standard proof is **DNS
validation**: ACM hands you a CNAME record to create; once it can resolve
that record, it knows you control DNS for the domain and issues the
cert. In Terraform, that's three resources working together:
`aws_acm_certificate` (requests the cert and computes the required
validation record), `aws_route53_record` (creates that record, if your
zone is in Route53), and `aws_acm_certificate_validation` (blocks until
ACM sees the record and finishes issuance). Once issued, ACM handles
**renewal automatically** for as long as the validation record stays in
place — this is the single biggest practical win over a manually managed
certificate, which fails the way certificates always fail: quietly,
until the day it expires in production.

### Attaching a certificate to an ALB or CloudFront

An ALB HTTPS listener takes a `certificate_arn` directly — one cert,
issued in the *same region* as the ALB. CloudFront is the one exception
to "matches its own region": a CloudFront distribution's certificate
must always be issued in **us-east-1**, regardless of which region your
origin (the ALB) lives in, because CloudFront's TLS termination is a
global edge service, not tied to any single region. Base's CloudFront
distribution already terminates HTTPS for viewers using CloudFront's
*default* `*.cloudfront.net` certificate — extending that to a custom
domain (an `aliases` block + a us-east-1 cert) is one of today's
exercises, not part of the required lab, precisely to keep today's scope
to the ALB.

### The ACM domain prerequisite — the part most tutorials skip

A **public** ACM certificate cannot be issued without a domain you
control, full stop — there is no free-tier trick, no "just for a lab"
exception, no way to DNS-validate a domain you don't own. Be honest with
yourself about which of these three situations you're actually in:

1. **You own a domain, its zone is in Route53, in this account.** Take
   the real path: `domain_name` + `route53_zone_id` in today's lab, DNS
   validation, a genuinely trusted public certificate.
2. **You don't own a domain (or its zone isn't in Route53 here).** Two
   honest options, both explained so you're not stuck:
   - **Self-signed certificate, imported into ACM.** Generate a key +
     cert locally (the `tls` provider does this — no AWS call, no
     domain), then `aws_acm_certificate` supports *importing* an
     existing cert (`private_key` + `certificate_body`, no
     `validation_method` at all) instead of issuing one. You get a real
     TLS listener, a real handshake, and 100% of the plumbing this
     lesson is actually about — the only thing missing is a chain a
     browser trusts by default, so you'll need `curl -k` or a "proceed
     anyway" click. This is today's lab's default fallback.
   - **Plan-level only.** If even generating a throwaway self-signed
     cert feels like scope creep for where you are, it's legitimate to
     stop at reading and understanding the Terraform for the public-cert
     path without applying it, and note in your journal that you've
     reasoned through it, not run it. The exam tests the concept; the
     lab's job is to make sure you *could* run it when you do own a
     domain.
3. **ACM Private CA** is a real third option for organizations that want
   certificates trusted only *within* their own infrastructure (internal
   service-to-service TLS, no public domain validation needed at all —
   you are your own root of trust). It is deliberately **never
   provisioned in this lab**: the CA resource itself bills a flat
   **~$400/month whether you issue one certificate or ten thousand**,
   which alone exceeds this entire 12-day sprint's <$15 budget. Know it
   exists, know what problem it solves (internal PKI without a public
   domain), and know its cost shape — that's the exam-relevant part —
   without ever clicking "create" on one in a personal account.

## Break → Harden lab

See `labs/day05/`. **The break:** a standalone task-definition family
carries a placeholder secret hardcoded into a plaintext environment
variable. **The harden:** the next revision of that family resolves the
same secret via the ECS `secrets` block pointed at Secrets Manager (with
rotation turned on and a resource policy locking down who can ever read
it), and base's ALB gets an HTTPS listener with an ACM certificate plus
an HTTP→HTTPS redirect. **Success signal:** `aws ecs
describe-task-definition` shows no secret value anywhere in the hardened
revision, and `curl` against the ALB over HTTPS gets a response instead
of failing to negotiate TLS at all.

## Exercises

1. **Extend the ACM certificate to CloudFront.** Base's CloudFront
   distribution uses `cloudfront_default_certificate = true`. Sketch (in
   words or a diff, don't apply it against base) what changes: a *second*
   ACM certificate — issued in **us-east-1** specifically, even though
   your ALB and everything else runs in `us-east-1` already if that's
   your region, because CloudFront doesn't care what region the origin is
   in, only that its own cert lives there — plus an `aliases` block
   naming your domain, plus switching `viewer_certificate` from
   `cloudfront_default_certificate` to `acm_certificate_arn`. **Hint:**
   re-read "Attaching a certificate to an ALB or CloudFront" above for
   the us-east-1 rule. **Solution sketch:** `aws_acm_certificate.cloudfront`
   with `provider = aws.us_east_1` (a second, aliased AWS provider block
   pinned to `us-east-1`), DNS-validated the same way as the ALB one;
   `aws_cloudfront_distribution.app`'s `viewer_certificate` block would
   need `acm_certificate_arn = aws_acm_certificate_validation.cloudfront[0].certificate_arn`,
   `ssl_support_method = "sni-only"`, and a top-level `aliases =
   [var.domain_name]` — none of which this lab applies, since it would
   mean editing `labs/base/edge.tf` directly.

2. **Pick the storage backend for three new values and justify each.**
   You're asked to store: (a) a third-party payment-processor API key
   that must be rotatable, (b) a feature-flag default that happens to
   contain an internal hostname you'd rather not expose, (c) a
   database master password for an RDS instance a future day might add.
   For each, say Secrets Manager or Parameter Store `SecureString` and
   why. **Hint:** the table above turns on exactly one question per row —
   does this value have a *rotation lifecycle*? **Solution sketch:** (a)
   Secrets Manager — third-party API keys should rotate and you'll want
   the resource-policy option if you ever need to share it cross-account
   with a deploy pipeline. (b) Parameter Store `SecureString` — sensitive
   but not a credential, no rotation lifecycle, cheaper. (c) Secrets
   Manager — RDS even has a *built-in* rotation Lambda template AWS
   maintains for exactly this case (`AWS::SecretsManager::RotationSchedule`
   with `HostedRotationLambda`), so you wouldn't even write your own.

3. **Trace what happens if the resource-policy Deny is written with a
   typo.** Suppose `"aws:PrincipalArn"` in today's Deny condition is
   accidentally scoped to the **task role** ARN instead of the **task
   execution role** ARN (the two are different roles in
   `labs/base/iam.tf`). What breaks, and how would you notice? **Hint:**
   re-read which role actually calls `GetSecretValue` for the `secrets`
   block mechanism specifically — it isn't the task role for this
   pattern. **Solution sketch:** the execution role would now be
   explicitly denied (since it's not in the allow-list anymore), so the
   *next* task launch fails with a `ResourceInitializationError` pulling
   the secret — a loud, fast signal in `aws ecs describe-tasks
   --query 'tasks[0].stoppedReason'`. You'd notice within one deploy
   cycle, not silently. This is also why the harden step's
   `SOLUTION.md` explicitly calls out testing the deny path *as the role
   that's supposed to still work*, not only as a role that's supposed to
   be blocked — a policy that blocks the attacker but also accidentally
   blocks the app is not actually fixed.

4. **Rotation without a real downstream system.** Today's rotation Lambda
   has no database to `ALTER USER` against, so `setSecret` is a no-op.
   Name one *real* downstream integration where `setSecret` would need
   actual code, and sketch what that code calls. **Hint:** think about
   what "the app" in this workload could plausibly authenticate to that
   has its own credential-change API. **Solution sketch:** if this were
   the DynamoDB table's IAM-based access instead of a static key, there'd
   be nothing to rotate (IAM already handles that) — but if the app
   called a third-party SaaS API, `setSecret` would call that SaaS
   provider's own "rotate my API key" endpoint using the *current*
   (`AWSCURRENT`) key to authenticate, store the SaaS's newly issued key
   under `AWSPENDING`, and `testSecret` would make one real authenticated
   call with the pending key before `finishSecret` promotes it — the
   AWS-maintained rotation templates for RDS/Redshift/DocumentDB follow
   this exact shape against those services' native `ALTER USER` calls.

## Anti-patterns today

- [`ANTIPATTERNS.md` #10 — Secret sprawl](ANTIPATTERNS.md#10-secret-sprawl):
  today's entire break is this anti-pattern in miniature — one API key,
  copied into a task definition's plaintext environment instead of
  staying in the one place (Secrets Manager) that can rotate and audit
  it. The harden step is the corrective from that entry, applied
  literally: reference by ARN, resolve at launch, never write the value
  anywhere else.
- [`ANTIPATTERNS.md` #2 — Console-clicking instead of Terraform](ANTIPATTERNS.md#2-console-clicking-instead-of-terraform):
  it would be *faster* to click "Add HTTPS listener" in the console right
  now and pick a cert from a dropdown. It would also be non-reproducible
  and non-diffable the next time you need to stand this up, and it's
  exactly the kind of one-off manual step that turns into an orphaned,
  still-billing listener nobody remembers creating. Today's entire ACM +
  listener + redirect flow is Terraform for that reason; the console is
  only for confirming what got created (`aws elbv2 describe-listeners`,
  ideally, over an actual console click).

## Cert corner (SCS-C02)

- **Domain 5, Data Protection:** Secrets Manager vs. Parameter Store
  `SecureString`, when to use which, and how rotation actually works
  (the 4-step Lambda contract) are direct exam content under this
  domain — see `CERT-MAP.md`.
- **Domain 3, Infrastructure Security:** ACM certificate issuance
  (DNS validation), attaching a cert to an ALB listener vs. a CloudFront
  distribution (including the us-east-1-for-CloudFront rule), and what
  ACM Private CA is for vs. public ACM are core Infrastructure Security
  content.
- Both domains meet at the resource-policy door: knowing that a secret's
  resource policy is evaluated *before* identity policy (same order as
  every other resource-based policy this path has taught) is the kind of
  cross-domain synthesis SCS-C02 scenario questions reward.

## Teardown

`cd labs/day05 && terraform destroy` — **do this before** running
`labs/base`'s own daily ALB/listener teardown (today's HTTPS listener and
redirect rule depend on base's ALB and HTTP listener still existing).
Confirm: no HTTPS:443 listener remains on base's ALB, the ACM certificate
(and its Route53 DNS-validation record, if you took the public-cert path)
is gone, and the rotation Lambda + secret resource policy + rotation
config are gone. Base's own secret resource
(`aws_secretsmanager_secret.app_secret`) is **not** destroyed — it's
base's persistent data tier and stays up for the whole sprint. See the
full checklist in `labs/day05/README.md`.
