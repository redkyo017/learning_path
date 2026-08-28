# Day 2 — Ingress Patterns

## Why this matters

A core banking team is releasing `/api/payments` v2. The wrong approach is an all-or-nothing deploy: push v2, hope, and roll back if anything goes wrong. That approach means minutes of customer impact, no ability to validate at low traffic, and no escape valve short of a full rollback.

Ingress patterns solve this at the routing layer — before the request ever touches a service. Weighted routing gives you a canary: 5% of real traffic hits v2 while 95% stays on the proven v1. Header-based routing lets your QA team pin to v2 without affecting production traffic. WAF at the ingress layer means security policy (fraud signals, rate limits, geo-blocks) is enforced once, not reimplemented in every service.

Getting the ingress layer wrong is expensive: you cannot add WAF or mTLS to an NLB after the fact, header-based routing requires L7 awareness that NLB simply does not have, and a poorly structured canary with no weighted rollback mechanism means every deploy is still high-risk.

## The boundary this manages

The **ingress boundary**: the traffic admission and routing layer that sits between the public internet (or internal network) and your services. Everything that happens at this boundary is decided before any service receives a byte of the request body.

```
Internet / VPC / Partner network
         │
  ┌──────▼───────┐
  │  Ingress tier │  ← This is what Day 2 covers
  │  (NLB / ALB / │
  │   API GW / CF) │
  └──────┬───────┘
         │ shaped, routed, authenticated, inspected
  ┌──────▼───────┐
  │   Services    │
  └──────────────┘
```

Decisions made here: which layer (L4 vs L7), how traffic is split, which headers determine routing, which certificates are validated, which WAF rules apply.

---

## Core patterns

### 1. L4 vs L7 ingress decision

**Problem:** Choosing the wrong OSI layer for your ingress causes capability gaps (adding WAF to NLB is impossible) or unnecessary cost and complexity (ALB where you only need TLS passthrough). This decision is hard to reverse.

**How it works:**
- **L4 (NLB — Network Load Balancer):** operates at TCP/UDP. Routes by IP + port. No HTTP awareness. Supports TLS passthrough (the backend terminates TLS; NLB never sees the plaintext). Ultra-low latency (single-digit milliseconds). Preserves client IP via Proxy Protocol.
- **L7 (ALB — Application Load Balancer):** operates at HTTP/HTTPS. Terminates TLS, reads headers, path, host. Content-based routing (host/path/header/query string rules). Supports HTTP/2 and WebSockets. Required for WAF attachment, mTLS offload, and header-based routing.

**AWS implementation:**
- NLB: `aws_lb` with `load_balancer_type = "network"`. TLS listener with `certificate_arn`. No `aws_wafv2_web_acl_association` possible.
- ALB: `aws_lb` with `load_balancer_type = "application"`. HTTP/HTTPS listeners with rule blocks. `aws_wafv2_web_acl_association` attached to ALB ARN.

**When it's wrong:**
- Choosing NLB when your services need WAF, header-based routing, or mTLS offload — you will have to replace the entire ingress tier later.
- Choosing ALB for a service that requires TLS passthrough (e.g., backend must see the raw client certificate, not forwarded headers) — ALB terminates TLS and cannot pass the raw handshake through.
- Choosing ALB for sub-millisecond latency requirements in a financial matching engine — NLB's passthrough is meaningfully faster at this scale.

---

### 2. Weighted routing (canary deploy)

**Problem:** Deploying a new API version all-or-nothing means any defect immediately affects 100% of traffic. Rolling back requires a full redeploy, costing minutes of customer impact.

**How it works:** ALB weighted target groups split incoming traffic between two target groups using integer weights. The ALB normalises the weights to percentages. A `forward` action can list multiple target groups, each with a weight. Changing the weights is an API call — no redeployment needed.

**AWS implementation:**
1. Create two target groups: `v1-tg` (existing version) and `v2-tg` (new version).
2. ALB listener default action: `forward` with `target_group { arn = v1-tg, weight = 90 }` and `target_group { arn = v2-tg, weight = 10 }`.
3. Canary promotion: update weights to 50/50, then 0/100. At 0/100 you can safely decommission v1.

**Canary vs blue-green distinction:**
- **Canary:** gradual weight shift (10% → 50% → 100%). Real production traffic at each step. Requires v1 and v2 to be compatible with the same data schema during the transition period.
- **Blue-green:** run full v2 in parallel, validate with synthetic traffic, then shift 0% → 100% in one step. More compute cost, faster rollback (flip back to 0/100).

**When it's wrong:**
- Using weighted routing when v1 and v2 write incompatible formats to a shared database — some requests will fail regardless of routing weight.
- Using it as a permanent multi-version strategy — the ALB rule becomes the long-term versioning mechanism, which should be header-based routing (see below).

---

### 3. Header-based routing

**Problem:** Multiple API versions or tenants need to coexist behind a single DNS name. URL-path versioning (`/v1/`, `/v2/`) works but forces clients to change base URLs on every version upgrade. Subdomain-per-tenant requires wildcard certificates and DNS management overhead.

**How it works:** ALB listener rules evaluate HTTP header conditions before the default action. A rule with `http_header` condition matching `x-api-version: v2` can forward to v2-tg regardless of the weighted default. Priority ordering matters: lower priority number = evaluated first.

**AWS implementation:**
```hcl
resource "aws_lb_listener_rule" "header_v2" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1   # evaluated before weighted default

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.v2.arn
  }

  condition {
    http_header {
      http_header_name = "x-api-version"
      values           = ["v2"]
    }
  }
}
```

The default action (weighted) is the fallback when no rule matches. This means: internal QA team sends `x-api-version: v2`, always hits v2. Production mobile clients send no such header, get the weighted canary split.

**Other header conditions:** `x-tenant-id` for multi-tenant routing; `x-feature-flag` for A/B test routing; `host` condition for subdomain-based routing.

**When it's wrong:**
- Trusting client-controlled headers for security-sensitive routing without stripping or validating them upstream — a malicious client can inject `x-api-version: v2` to bypass canary controls.
- Using header routing as the only versioning strategy without a sunset plan — old header values accumulate indefinitely, bloating listener rule sets.

---

### 4. mTLS at ingress

**Problem:** Authenticating callers only at the application layer (JWT, API key) leaves a gap: the network connection itself is unauthenticated. A banking partner connecting to your settlement API should be identifiable at the TLS layer, before any application code runs.

**How it works:** Mutual TLS (mTLS) requires the client to present a certificate during the TLS handshake. The server validates that certificate against a trust store (a CA or set of CAs). If validation fails, the connection is rejected at the network layer — no HTTP request is ever forwarded to the backend.

**AWS implementation:**
- **ALB mTLS (preferred for most use cases):** ALB validates the client certificate against an **ELB trust store** (`aws_lb_trust_store`) — a CA certificate bundle you upload to S3 and register with the listener. The bundle can contain your own CAs (exported from ACM Private CA) or an external partner's CA certificates. On successful validation, ALB forwards the cert details as HTTP headers (`x-amzn-mtls-clientcert`, `x-amzn-mtls-clientcert-serial-number`, etc.) to the backend. Backend trusts these headers and uses them for identity — no cert validation logic in the service.
- **NLB TLS passthrough (when backend must validate):** NLB passes the raw TLS bytes to the backend, which terminates TLS and validates the client cert itself. Required when the backend needs to extract and validate cert extensions (OIDs, SANs) that ALB does not expose as headers.

**When it's wrong:**
- Using NLB passthrough when multiple backend instances each need their own cert validation logic — certificate authority configuration drifts across instances.
- Using ALB mTLS when the backend must inspect certificate extensions (custom OIDs, SANs) that ALB does not surface as headers — use NLB TLS passthrough so the backend sees the raw handshake.
- Confusing the trust store with ACM Private CA: ACM PCA *issues* certificates for your own PKI; the ALB trust store *validates* client certs against any CA bundle you upload, including a partner's external CA. You cannot import a partner's CA into ACM PCA.

---

### 5. WAF integration as a pattern

**Problem:** Security policy (OWASP Top 10 mitigations, geo-blocking, IP reputation, rate limiting) should be enforced once at the edge, not reimplemented across dozens of services.

**How it works:** AWS WAF WebACL attached to ALB or API Gateway evaluates every request against an ordered rule set before it is forwarded to any target. Rules run in priority order; the first matching rule's action applies (Allow, Block, Count, CAPTCHA). Managed rule groups (AWS-managed or Marketplace) provide curated rule sets you do not have to write yourself.

**Rule organisation pattern (separate by concern):**
1. **Managed rules first:** `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesSQLiRuleSet` — broad baseline coverage.
2. **IP reputation second:** `AWSManagedRulesAmazonIpReputationList` — blocks known bad IPs.
3. **Rate-based rules third:** count requests per IP over a 5-minute window; block if over threshold.
4. **Custom rules last:** business-specific rules (geo-block, header validation for fraud signals).

**WAF fraud signal injection pattern:** WAF can add custom labels to requests that match specific patterns (e.g., requests from TOR exit nodes, requests with known fraud headers). These labels are forwarded to the backend as request context, allowing fraud scoring without blocking.

**When it's wrong:**
- Starting with WAF in Block mode on day one — legitimate traffic almost always triggers managed rules due to edge cases in your specific API. Start in Count mode, analyse CloudWatch `CountedRequests` metrics, tune, then switch to Block.
- Attaching WAF to every ALB in your account individually — use AWS Firewall Manager to enforce WAF policies centrally across ALBs.

---

### 6. CDN + origin offload

**Problem:** Static and cacheable API responses (product catalogues, exchange rate tables, public-facing balance summaries) should never reach your origin. Every cacheable response served from CloudFront instead of ALB + EC2 reduces cost, reduces latency by 80–90%, and reduces load on backend services.

**How it works:** CloudFront sits in front of ALB. Each CloudFront behaviour maps a URL path pattern to a cache policy and an origin. The origin for dynamic APIs is the ALB; the origin for static assets can be S3. Origin Shield adds a dedicated caching tier between CloudFront edge and your ALB, collapsing cache-miss requests.

**AWS implementation:**
```
Client → CloudFront distribution
           → Behaviour /api/*     → No cache (TTL=0) → ALB origin
           → Behaviour /static/*  → Cache (TTL=86400) → S3 origin
           → Behaviour /rates     → Cache (TTL=60) → ALB origin
```

Cache policy on `/rates`: TTL 60s. After CloudFront has one copy, subsequent requests served from edge — 1000 requests/second to `/rates` generates only ~1 origin request per 60 seconds.

**When it's wrong:**
- Caching responses that include user-specific data (account balances, transaction history) — you will serve one user's data to another. Always include `Cache-Control: no-store` or use per-user cache keys, which effectively disables caching.
- CloudFront in front of an internal ALB (not internet-facing) without PrivateLink — CloudFront edge nodes need a path to your origin, which usually means the ALB must be internet-accessible.

---

## Decision tree

Use this table to choose the right ingress tier. Start with the protocol row; each constraint narrows the choice.

| Criterion | NLB | ALB | API Gateway |
|---|---|---|---|
| Protocol | TCP, UDP, TLS (L4) | HTTP, HTTPS, WebSocket (L7) | HTTP, WebSocket (L7) |
| Routing rules | IP + port only | Host, path, header, query string | Path + method; stage variables |
| WAF support | No | Yes (WebACL attachment) | Yes (WebACL attachment) |
| mTLS | TLS passthrough only | Yes (ALB mTLS trust store) | Yes (mutual TLS on custom domain) |
| Latency | ~1ms (single-digit) | ~5–10ms (TLS termination + L7 parse) | ~10–20ms (managed service overhead) |
| Cost | Per NLCU; no per-request fee | Per LCU; no per-request fee | Per request + per connection |
| Best for | Non-HTTP, ultra-low latency, TLS passthrough | Microservices, canary, header routing | Serverless backends, API management features |

**Decision path:**
1. Non-HTTP protocol or must preserve raw TLS stream → **NLB**
2. Need WAF, header routing, mTLS offload, or HTTP/2 → **ALB**
3. Need usage plans, API keys, request transformation, or serverless backend → **API Gateway**
4. Need global CDN caching in front of any of the above → **CloudFront → (NLB / ALB / API GW)**

---

## Exercises

### Exercise 1 — Canary deploy routing

Your team wants to roll out `/payments/v2` to 5% of traffic while keeping 95% on v1. Describe which ingress pattern you would use, which AWS service, and draw the target group configuration as a list of weighted entries.

**Hint:** You need traffic split at the routing layer, not the application layer. The split should be adjustable without redeploying either service.

**Solution sketch:** ALB weighted routing. Create two target groups: `v1-tg` (pointing to v1 instances) and `v2-tg` (pointing to v2 instances). ALB listener default action: `forward` with weights `v1-tg: 95, v2-tg: 5`. To promote v2, update weights to `50/50`, then `0/100` — each change is a single `aws elbv2 modify-listener` call, no service restart. When v2 is at 100%, deregister v1 instances from `v1-tg` and delete the target group.

---

### Exercise 2 — mTLS placement decision

A banking partner must connect to your internal settlement API. They present a client certificate issued by their own private CA. Where do you terminate mTLS — at the ALB, at the application, or somewhere else? Justify your choice.

**Hint:** Think about where you want the certificate validated relative to your services, and what the backend receives after validation.

**Solution sketch:** ALB mTLS with an ELB trust store. Upload the partner's CA certificate bundle to S3 and create an `aws_lb_trust_store` referencing it, then enable mTLS verify mode on the HTTPS listener with that trust store. ALB validates the client cert against the partner's CA during the TLS handshake. On success, ALB forwards cert details via `x-amzn-mtls-clientcert-*` headers. The settlement service reads the partner identity from the header — no cert parsing code in the service. This is preferred over application-layer validation because: (1) the connection is rejected before HTTP is parsed if the cert is invalid, (2) no cert validation logic per service, (3) the CA trust store is managed in one place at the listener. (Note: ACM Private CA is not involved here — it issues certs for your own PKI; the trust store validates against any CA bundle, including a partner's external CA.)

---

### Exercise 3 — WAF diagnosis without downtime

Your WAF is blocking 5% of legitimate mobile app requests. How do you identify which WAF rule is responsible without disabling WAF entirely or causing further disruption to legitimate traffic?

**Hint:** WAF has a mode that records which rules match without actually blocking. Count mode metrics are separate from Block mode counters in CloudWatch.

**Solution sketch:** In the AWS WAF console (or via Terraform), change the suspected rule's action from `block` to `count`. This means matched requests are logged and counted in CloudWatch (`CountedRequests` metric, broken down by rule) but not blocked. Watch the `CountedRequests` metric on the suspicious rule while traffic continues normally. When you see legitimate mobile requests appearing in the count (you can correlate with CloudWatch Logs Insights on your WAF log group filtering by `terminatingRuleId`), you have identified the offending rule. Common causes: IP reputation rule blocking a mobile carrier NAT IP, `AWSManagedRulesCommonRuleSet` blocking a non-standard Content-Type your mobile app sends. Tune the rule (add an IP exception or rule exclusion), verify counts drop, then switch back to `block`.

---

## Anti-patterns / Common mistakes

- **Routing by URL path prefix only:** `/v1/payments` vs `/v2/payments` works until the service is restructured. A path prefix change forces every client to update their URLs. Combine host-based routing (stable DNS name) with a version header (`x-api-version`) so you can restructure paths without client changes.

- **WAF in Block mode on day one:** Every production API has edge cases — unusual Content-Type headers, mobile clients with non-standard user agents, partner IPs in reputation lists. Starting in Block mode guarantees false positives. Start all rules in Count mode, run for one to two weeks, analyse `CountedRequests` in CloudWatch, add exceptions, then switch to Block. Skipping this step is the most common cause of WAF-induced production incidents.

- **NLB for a service that later needs WAF or mTLS:** NLB operates at L4; WAF requires L7 attachment. If you start with NLB and later need WAF, you must tear out the entire ingress tier and replace it with ALB — a high-risk, high-effort migration. The 5ms extra latency of ALB is almost never a valid reason to start with NLB for an HTTP API.

---

## Lab

See `labs/day02/`. The lab provisions an ALB with two target groups (`v1-tg`, `v2-tg`) and two listener rules:

1. **Header rule (priority 1):** `x-api-version: v2` → 100% to `v2-tg`
2. **Weighted default:** 90% to `v1-tg`, 10% to `v2-tg`

Success signal:
- `curl http://<alb-dns>/api/payments` — approximately 9 in 10 responses say `"version": "v1"`
- `curl -H "x-api-version: v2" http://<alb-dns>/api/payments` — always returns `"version": "v2"`
- A request with `x-fraud-signal: high-risk` increments the WAF `FraudSignalHeader` count metric in CloudWatch (the lab's WAF rules start in Count mode — see the WAF exercise in the lab README)

The `v2_weight` variable controls the canary percentage. Promote v2 by setting `v2_weight = 50`, then `v2_weight = 100`.

---

## Teardown

After completing the lab:

```bash
cd aws_system_integrations/labs/day02
terraform destroy
```

Verify in the AWS console:
- ALB deleted (EC2 → Load Balancers)
- Target groups deleted (EC2 → Target Groups)
- EC2 instances terminated (EC2 → Instances)
- Security groups deleted — ALB and EC2 SGs may remain if dependencies are not resolved by `terraform destroy`

If security groups remain:

```bash
# Get the security group IDs from the Terraform state or AWS console, then:
aws ec2 delete-security-group --group-id sg-XXXXXXXXXXXXXXXXX --region ap-southeast-1
```

Estimated cost if left running: ALB ~$0.0225/hour base plus LCU usage (~$0.54/day), two t3.micro instances ~$0.0104/hour each (~$0.50/day combined). Full lab cost if forgotten overnight: approximately $1.05.
