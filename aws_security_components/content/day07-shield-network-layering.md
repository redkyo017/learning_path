# Day 7 — Edge protection II + network layering

## Why this matters at work

Every real incident review eventually asks the same question: "this
resource was supposed to be internal-only — how did the request reach
it at all?" The answer is almost always that someone assumed one
control (a VPC, a private subnet, a security group) was doing a job
that a *different* control actually has to do, and nobody ever tested
the deny path to find out. Today you stop treating "it's in a VPC" as
a security boundary by itself, and instead build the actual boundary:
a VPC endpoint policy plus a resource-policy condition that only trusts
requests arriving through that specific endpoint — the same pattern
AWS calls a **data perimeter**, and the pattern behind most
"why did our S3 bucket leak even though it wasn't public" incidents.

## The engine lens

Today's door is **the explicit-deny door, wearing a network condition
key.** The evaluation order is still `explicit Deny → SCP/RCP →
resource-based policy → identity-based policy → permission boundary →
session policy` — nothing new there. What's new is *what the Deny
tests*: instead of a principal ARN or an action name, the condition
checks `aws:SourceVpce` (which VPC endpoint the request physically came
through) or `aws:SourceIp` (which IP it came from). An explicit Deny in
a resource policy beats any identity-based Allow, no matter how
permissive that identity's IAM policy is — which is exactly why this is
the tool for "this resource must be VPC-only, full stop," rather than
trying to express that constraint solely through identity policies.

The base workload's task role already has an `Allow` for
`secretsmanager:GetSecretValue` on the app secret (see `iam.tf`,
`ReadOwnSecret`). That identity-level Allow is not going anywhere today
— you are not touching it. Today's control is layered *on top of it*,
at the resource-policy level, so it doesn't matter how broad or narrow
the identity policy is: the network condition decides whether the
request is even allowed to be evaluated as an Allow in the first place.

## Core concepts

### Shield Standard vs. Shield Advanced

**Shield Standard** is free and always on for every AWS account, no
opt-in required. It protects CloudFront, Route 53, and any
Elastic-IP/ALB-fronted resource against common, automated
network/transport-layer (L3/L4) DDoS patterns — SYN floods, UDP
reflection, that kind of volumetric noise. Base's ALB and CloudFront
distribution are covered by Shield Standard right now, at zero cost,
with nothing for you to configure.

**Shield Advanced** is the paid tier: roughly **$3,000/month per
organization** (12-month commitment) plus data-transfer fees, on top of
Standard. It adds near-real-time DDoS visibility and attack
diagnostics, 24/7 access to the DDoS Response Team (DRT), and cost
protection against scaling charges incurred *during* an attack. That
price point puts it entirely out of scope for this sprint's <$15
budget — the content here is exam/architecture knowledge, not a lab you
enable. The exam-relevant point: Advanced is a business/operational
decision (what's the cost of downtime vs. $3k/mo), not a "is my app
technically vulnerable" decision — Standard already covers the common
volumetric case for free.

### CloudFront security: OAC, signed URLs, geo restriction

- **[OAC (Origin Access Control)](GLOSSARY.md#o)** — when CloudFront
  fronts an S3 bucket *directly* as an origin, OAC is how you make sure
  the bucket is reachable **only** via that specific CloudFront
  distribution's signed requests, never directly over the public S3
  endpoint. Base's CloudFront distribution fronts the ALB, not an S3
  bucket, so OAC isn't literally wired into this workload — but it's
  the direct S3-origin analog of what you're about to do to Secrets
  Manager today with a VPC endpoint policy: "only this specific
  signed/identified path in, nothing else." It supersedes the older OAI
  and is required if the origin bucket uses SSE-KMS.
- **Signed URLs / signed cookies** — a CloudFront distribution can
  require every request to carry a signature (generated server-side
  with a CloudFront key pair) that encodes an expiry and, optionally,
  an IP restriction. Anyone without a valid, unexpired signature gets a
  403, even if they have the exact object URL. Use signed *URLs* for
  individual files (e.g. a report download link emailed to one user);
  use signed *cookies* when a user needs access to many objects across
  a session (e.g. a whole video-course path) without re-signing every
  link.
- **Geo restriction** — an allow-list or deny-list of countries,
  enforced at the CloudFront edge before the request ever reaches your
  origin. It's a blunt instrument (whole countries, not users) but it's
  free, edge-enforced, and closes off entire classes of unwanted
  traffic before your ALB or WAF even sees a request. Base's
  distribution currently sets `restriction_type = "none"` (see
  `edge.tf`) — intentionally, since this workload has no
  jurisdiction requirement; a real deployment with, say, an export-
  control constraint would set an allow-list here.

### The "which layer does what" map

The single most common Infrastructure Security exam trap (and real
misconfiguration) is expecting one of these four controls to do a job
that belongs to a different one:

| Control | Layer | State | Scope | Sees | Typical job |
|---|---|---|---|---|---|
| **Security group** | Network (L3/L4) | Stateful | Per-ENI | Source/dest IP, port, protocol | "Which other resource can open a connection to this one" |
| **NACL** | Network (L3/L4) | Stateless | Per-subnet | Source/dest IP, port, protocol | Coarse subnet-wide backstop; must allow both directions explicitly |
| **WAF Web ACL** | Application (L7) | N/A (per-request) | ALB / CloudFront / API Gateway | Full HTTP request — headers, body, URI, rate | Blocking bad *requests* (SQLi, XSS, bad bots, rate abuse) regardless of source IP |
| **VPC endpoint policy + resource-policy condition** | Identity/network hybrid | N/A (per-request) | Traffic to one specific AWS API, through one specific endpoint | Which endpoint/VPC the API call arrived through | Proving an API call to S3/Secrets Manager/etc. came from inside a specific VPC, not just "some IAM principal allowed it" |

Read the table as: SG and NACL answer "can a *connection* reach this
network location at all," WAF answers "is this specific *HTTP
request* malicious," and a VPC endpoint policy answers "did this *API
call* travel through the path I designated as trusted." None of the
four substitutes for another — a Web ACL blocking SQL injection does
nothing to stop someone with valid AWS credentials calling
`GetSecretValue` from their laptop, and a tight security group on an
ECS task does nothing to stop that same laptop calling the AWS API
directly over the public internet, because the security group governs
*network* connections to the ENI, not API calls to a managed service
that has no ENI of its own to protect.

### VPC endpoint policies, `aws:SourceVpce`, and `aws:SourceIp`

A [VPC endpoint policy](GLOSSARY.md#v) is a resource policy attached to
the endpoint itself: it can narrow (never widen) which actions and
which resources are reachable *through that endpoint*, independent of
whatever the target resource's own policy allows. It answers "what may
travel through this door," symmetrically with the resource's own
policy answering "who may enter."

The other half of the pattern — the half that actually makes a
resource VPC-only — is a condition on the **resource's own policy**
(an S3 bucket policy, a Secrets Manager resource policy, a KMS key
policy) using:

- **`aws:SourceVpce`** — the specific VPC endpoint ID the request
  arrived through. Use this when the resource is reached via a VPC
  endpoint (S3 gateway endpoint, or any interface endpoint) and you
  want to say "must come through *this exact* endpoint," which by
  construction also means "must come from inside this VPC."
- **`aws:SourceIp`** — the caller's source IP address. Use this when
  there's no VPC endpoint in the picture at all (e.g. restricting to a
  known corporate CIDR reaching the API over the public internet, or a
  Direct Connect/VPN-advertised private range) or as a *second*,
  belt-and-suspenders condition alongside `aws:SourceVpce`. For traffic
  that already goes through an interface endpoint, `aws:SourceVpce` is
  the more precise and more commonly correct key — `aws:SourceIp` on an
  ENI's private address is fragile (addresses can be reused/reassigned)
  and doesn't identify a specific trusted path the way an endpoint ID
  does.

The canonical hardening statement (used in today's lab) is a resource
policy with an explicit `Deny` on the relevant actions, conditioned on
`StringNotEquals { "aws:SourceVpce": "<endpoint-id>" }` — i.e. "deny
this action for every request that does *not* present this exact
endpoint ID." Because it's an explicit Deny, it wins regardless of
what any identity policy allows.

## Break → Harden lab

See `labs/day07/`. **The break:** the base Secrets Manager secret
(`secret_arn` output) has an identity-level Allow already granted to
the task role, and no resource policy at all — so any caller with
`secretsmanager:GetSecretValue` permission can read it from anywhere on
the internet, not just from inside the VPC where the app actually
needs it. **The harden:** stand up a Secrets Manager interface VPC
endpoint in the base's private subnets, attach an endpoint policy
scoped to this one secret, and attach a secret resource policy that
`Deny`s `GetSecretValue`/`DescribeSecret` unless `aws:SourceVpce`
matches that endpoint — then layer a purpose-built security group and
NACL on the endpoint's private subnets for least exposure. **Success
signal:** the identical CLI call, run from outside the VPC, returns
`AccessDeniedException`; run from inside the VPC (through the new
endpoint), it succeeds — recorded side-by-side in `labs/day07/SOLUTION.md`
along with a VPC Reachability Analyzer check proving no other path in.

## Exercises

1. **SG vs. NACL: which blocks this, and why?** The Secrets Manager
   endpoint's security group (created in today's lab) accidentally
   allows inbound 443 from `0.0.0.0/0` instead of the VPC CIDR. The
   private subnet's NACL correctly allows inbound 443 only from the
   base VPC CIDR (`10.42.0.0/16`), with matching ephemeral-port
   (1024–65535) egress for the stateless return leg. Is the endpoint
   now reachable from the public internet?
   **Hint:** the endpoint's ENI has no public IP and sits in a private
   subnet whose route table has no route to an Internet Gateway (see
   `network.tf`'s private route table). Ask whether a packet from the
   public internet can physically arrive at that ENI at all before
   asking whether the SG would let it in.
   **Solution sketch:** No — not from the *internet*, because there is
   no route getting a packet there in the first place; the overly
   broad SG is a real bug but the private subnet's missing default
   route is what's actually protecting you here (defense that shouldn't
   be relied on alone — see below). It *does* matter for **lateral
   reach inside the VPC**: `0.0.0.0/0` on the SG means *any* ENI
   anywhere in this VPC (any other day-lab's resources sharing this
   VPC, a future NAT instance, anything) can reach the endpoint on 443,
   not just the ECS task. The correctly-scoped NACL (VPC CIDR only)
   doesn't fully compensate, because a NACL is subnet-wide — it can't
   distinguish "the ECS task's ENI" from "some other ENI in the same
   VPC CIDR." The fix is the SG, not the NACL: scope the SG's ingress
   to the VPC CIDR (or better, to the task security group specifically,
   the same `referenced_security_group_id` pattern base's `ecs.tf` uses
   for `task_from_alb`).

2. **Extend the pattern to S3, at zero extra cost.** Base already
   creates a free S3 gateway endpoint (`aws_vpc_endpoint.s3` in
   `network.tf`) attached to both route tables — but the `app_data`
   bucket has no policy restricting access to it. Write (don't apply)
   an `aws_s3_bucket_policy` for `app_data` that denies all `s3:*`
   actions unless `aws:SourceVpce` equals that gateway endpoint's ID.
   **Hint:** you don't know the endpoint's ID at write-time since it's
   base-owned — look it up with a `data "aws_vpc_endpoint"` block
   filtered by `service_name = "com.amazonaws.${var.region}.s3"` and
   `vpc_id`, rather than hardcoding an ID or editing `labs/base`.
   **Solution sketch:**
   ```hcl
   data "aws_vpc_endpoint" "s3" {
     vpc_id       = data.terraform_remote_state.base.outputs.vpc_id
     service_name = "com.amazonaws.${var.region}.s3"
   }

   resource "aws_s3_bucket_policy" "app_data_vpc_only" {
     bucket = data.terraform_remote_state.base.outputs.app_bucket_name
     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Sid       = "DenyIfNotViaS3Endpoint"
         Effect    = "Deny"
         Principal = "*"
         Action    = "s3:*"
         Resource = [
           data.terraform_remote_state.base.outputs.app_bucket_arn,
           "${data.terraform_remote_state.base.outputs.app_bucket_arn}/*"
         ]
         Condition = {
           StringNotEquals = { "aws:SourceVpce" = data.aws_vpc_endpoint.s3.id }
         }
       }]
     })
   }
   ```

3. **`aws:SourceIp` vs. `aws:SourceVpce` — when is each the right
   tool?** Your company has an on-prem data center connected to the VPC
   over Direct Connect, with no VPC endpoint for the service in
   question, and a separate requirement that a specific SaaS partner
   (reaching the API over the public internet with valid IAM
   credentials) may only call from their published egress IP range.
   Which condition key fits which requirement, and why would
   `aws:SourceVpce` be the wrong choice for the on-prem case?
   **Hint:** `aws:SourceVpce` only has a value when the request
   actually transited a VPC endpoint — Direct Connect traffic that
   never touches an interface/gateway endpoint has no endpoint ID to
   match against.
   **Solution sketch:** the on-prem/Direct-Connect case has no VPC
   endpoint in its path at all (unless you specifically route it
   through one), so `aws:SourceVpce` would simply never match —
   `aws:SourceIp` against the advertised on-prem CIDR is correct there.
   The SaaS partner case is also `aws:SourceIp` (their published egress
   range), not `aws:SourceVpce`, since they're calling over the public
   internet with no VPC endpoint involved either. `aws:SourceVpce`
   is specifically for "this call transited one of *my* VPC's
   endpoints" — it has no meaning for traffic that never does.

4. **Design a distribution policy.** Quarterly investor reports must be
   downloadable only by APAC-region readers, only for 48 hours after
   publication, and must not be discoverable by direct S3 URL.
   **Hint:** you need three independent controls stacked, not one
   clever one.
   **Solution sketch:** S3 bucket as a private CloudFront origin behind
   **OAC** (closes "direct S3 URL" entirely); CloudFront **geo
   restriction** allow-listing the APAC country codes (closes
   non-APAC at the edge, free); **signed URLs** with a 48-hour expiry
   embedded in the signature for the actual report links (closes
   "still valid after the window," independent of geo). Each control
   closes a different gap in the requirement — none of the three alone
   satisfies it.

## Anti-patterns today

- [`ANTIPATTERNS.md` #3](ANTIPATTERNS.md) — "never actually testing a
  deny." Today's entire lab exists because the base secret's *allow*
  path was already tested (the app works), but nobody had tested
  whether it was reachable from somewhere it shouldn't be. That gap —
  not a broken allow — is what today's harden closes.
- **Confusing WAF/SG/NACL/Shield responsibilities.** Concretely: a team
  spends real budget attaching a WAF Web ACL (~$5/mo base + ~$1/mo per
  rule + ~$0.60 per million requests) to "stop unauthorized access" to
  an internal API that was never supposed to be reachable outside the
  VPC in the first place — the actual gap is a missing VPC-endpoint
  resource-policy condition (free beyond the endpoint's own ~$0.01/hr
  per AZ), which WAF cannot express at all, because WAF inspects HTTP
  requests, not which network path an AWS API call took. Equally
  common in the other direction: locking down security groups
  aggressively and calling the app "protected from bots," when a
  security group has no concept of an HTTP request's contents — that's
  a Web ACL's job. Match the control to the question it can actually
  answer (see the layer map above) before spending money or engineering
  time on it.

## Cert corner (SCS-C02)

- **Domain 3, Infrastructure Security (~20%):** this is the domain's
  core content — perimeter DDoS posture (Shield Standard vs. Advanced),
  edge controls (WAF, CloudFront OAC/signed URLs/geo restriction), and
  network-layer segmentation (SG vs. NACL, VPC endpoints).
- Expect scenario questions that describe a symptom ("requests from
  outside the VPC are still reaching an internal resource") and ask you
  to pick the *one* control among SG/NACL/WAF/endpoint-policy that
  actually closes that specific gap — the layer map in this file is
  built to answer exactly that question type.
- `aws:SourceVpce` / `aws:SourceIp` condition-key questions are a
  recurring SCS-C02 pattern for both Domain 3 and Domain 5 (Data
  Protection) — know which one has a value in which network path
  (VPC-endpoint transit vs. plain IP-based).

## Teardown

`cd labs/day07 && terraform destroy` — this destroys only the day-07
layer (the Secrets Manager interface endpoint, its security group, the
custom NACL, and the secret resource policy). It does **not** touch
`labs/base`'s persistent resources (the secret itself, its value, the
S3 bucket, the KMS key). The interface endpoint bills hourly
(~$0.01/hr per AZ, two AZs here) — tear it down the same day per the
checklist in `labs/day07/README.md`; do not leave it running overnight.
