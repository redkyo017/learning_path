# AWS System Integration Patterns — Design Spec

**Date:** 2026-08-28
**Location:** `aws_system_integrations/`
**Duration:** 5 days, ~4–5 h/day (~20–25 h total)

---

## Purpose & Goals

This path teaches **enterprise integration patterns on AWS** — not AWS service tutorials. The subject is the *pattern family*: how to think about boundaries (ingress, egress, internal, external), what crosses each boundary, and which AWS services implement which pattern. By the end the learner can name a pattern by its problem, choose between alternatives with justified trade-offs, wire a real implementation, and reason about failure modes.

**Learner profile:** AWS practitioner at A→B level — comfortable with IAM, EC2, S3, RDS; has touched SQS or SNS in isolation but has not designed event-driven or async systems end-to-end. No prior formal exposure to enterprise integration patterns (Hohpe vocabulary). Works daily with banking, payment, and microservice systems and needs patterns that map directly to those domains.

**Why unconventional:** Most AWS learning paths are service-first — you learn SQS, then SNS, then EventBridge as isolated topics. This path is pattern-first and domain-anchored. Every concept is introduced by the enterprise problem it solves (PCI scope reduction, canary deploy for a core banking upgrade, mobile BFF for a payments app), not by the AWS service. Services appear as implementation vehicles, not subjects.

---

## Success Criteria

By the end the learner can, without notes:

1. Name the 5 boundary types (API gateway, ingress, egress, internal-sync, external) and describe what each manages
2. Design a BFF, API composition, and anti-corruption layer for a given enterprise scenario
3. Choose between NLB, ALB, and API GW as an ingress vehicle and justify the decision
4. Design a VPC egress strategy (NAT vs VPC Endpoint vs PrivateLink) for a given security + cost constraint
5. Draw the service-to-service pattern (sync or async) for a given coupling and reliability requirement
6. Identify the correct async sub-pattern (point-to-point queue, pub-sub, outbox) and explain when each is wrong
7. Design an idempotent inbound webhook receiver with retry and DLQ
8. In a system design interview, whiteboard a full enterprise integration stack (ingress → internal → egress → external) with justifications and trade-off acknowledgements

---

## Constraints & Environment

| Constraint | Rule |
|---|---|
| AWS account | Personal account; cost-conscious — all labs must include a teardown checklist |
| Credentials | Never write real keys, tokens, or account IDs into any file. Placeholders + fill-in comments only. Ship `*.tfvars.example` |
| Git commits | Learner handles all VCS — no `git commit/push/add` during authoring |
| Real infra | Labs are authored and documented; the learner runs them. Never run `terraform apply` during content authoring |
| Exercises | Every exercise ships with hints + solution sketches. No bare problems |
| Labs | Every lab ships with README.md + SOLUTION.md + teardown checklist |

---

## Strategy

### The core mental model: integration is about boundaries

Every enterprise integration pattern exists to manage **what crosses a boundary and under what terms** — trust, coupling, data shape, protocol, cost. The five boundary types in this path:

- **API gateway boundary**: the contract layer between external clients and backend services (payload shape, protocol, auth policy). Distinct from ingress: ingress controls *admission*; the API gateway controls *interface*
- **Ingress boundary**: client → your system (who can enter, how, at what rate)
- **Internal boundary**: service → service inside your system (coupling, reliability contract)
- **Egress boundary**: your system → AWS managed services or internet (cost, auditability, PCI scope)
- **External boundary**: your system ↔ third-party systems (webhooks, APIs, event streams)

Once a learner sees every pattern through the lens of "which boundary does this manage, and what does it control?", the right pattern for any new situation becomes derivable rather than memorized.

### The top 1% loop (applied to every pattern)

1. **Name the pattern** and the problem it was invented to solve — not the AWS service, the pattern
2. **Draw the boundary** it manages
3. **Map to AWS** — implementation vehicles and what each trades off vs alternatives
4. **Wire it** — minimal real Terraform lab against a realistic enterprise scenario
5. **Break it** — remove a component, inject a failure
6. **Fix it** — add the resilience mechanism the pattern implies

### What the 80% waste time on

| Trap | Why it fails |
|---|---|
| Service-first learning (SQS docs → SNS docs → EventBridge docs) | Learns features, not composition. Can configure a queue but can't choose when a queue is wrong |
| Happy-path-only labs | Understands operation, not failure. Senior engineers are hired for failure reasoning |
| Treating API Gateway as "just a proxy" | Misses BFF, anti-corruption layer, API composition — the patterns that dominate enterprise design interviews |
| Ignoring egress | VPC endpoint vs NAT vs PrivateLink is the #1 gap between junior and senior AWS architects |
| Async without the outbox pattern | Ships integrations that silently lose messages under failure |

### Density decision

Days 1–3 are the heavy core: API gateway patterns, ingress, egress. These are the least-covered and most-examined topics in enterprise AWS architecture. Days 4–5 cover internal service-to-service and external integration at sufficient depth to complete the pattern vocabulary, without turning into a SQS/SNS drill.

---

## Curriculum

### Day 1 — API Gateway Patterns (~4–5 h)
**Enterprise scenario:** Mobile banking BFF — one app routing to payment service, account service, and notification service

**Pattern family:** The layer between external clients and backend services

| Pattern | Problem it solves |
|---|---|
| Reverse proxy | Protocol termination, TLS offload, single entry point |
| API Gateway (generalized) | Auth, rate limiting, request transformation at the boundary |
| Backend-for-Frontend (BFF) | Client-specific aggregation without polluting service contracts |
| API Composition / Aggregation | Fan-in from multiple services into one response |
| Anti-Corruption Layer (ACL) | Protocol translation, schema mapping between incompatible systems |

**AWS implementation vehicles:** API GW (REST vs HTTP vs WebSocket — decision tree), ALB as lightweight API GW, CloudFront as L7 edge gateway

**Lab:** Wire a BFF in front of two services using API GW; add JWT authorizer + usage plan (rate limiting); break the upstream payment service, observe the client impact; add a fallback response pattern

---

### Day 2 — Ingress Patterns (~4–5 h)
**Enterprise scenario:** Core banking API upgrade — canary deploy for a new version, header-based routing for API versioning, WAF for fraud signal injection

**Pattern family:** How traffic enters and gets routed — L4 vs L7, and why the distinction matters

| Pattern | Problem it solves |
|---|---|
| L4 ingress (NLB) | High-throughput, low-latency, protocol-agnostic (TCP/UDP/TLS passthrough) |
| L7 ingress (ALB) | Content-based routing, host/path/header rules, sticky sessions |
| Weighted routing | Canary deploys, blue-green, A/B traffic splits |
| Header-based routing | API versioning, tenant routing, feature flags at the edge |
| mTLS at ingress | Mutual authentication for service-to-service and B2B entry |
| WAF integration | Security policy as a pattern, not a product — fraud signals, geo-blocking, OWASP rules |
| CDN + origin offload | Push static/cacheable content to edge, shield origin |

**AWS implementation vehicles:** ALB (routing rules deep dive), NLB, API GW, CloudFront, Route 53 routing policies, WAF v2

**Lab:** ALB with weighted + header-based routing rules for a versioned banking API; simulate canary deploy with 10%/90% weight; inject a WAF rule to block a fraud pattern; break the target group, observe health check + routing behavior

---

### Day 3 — Egress + VPC Boundary Patterns (~4–5 h)
**Enterprise scenario:** PCI DSS scope reduction — payment processor calling card vault service without internet traversal; split-horizon DNS for private service resolution

**Pattern family:** How your system reaches outward — cost, auditability, security scope

| Pattern | Problem it solves |
|---|---|
| NAT Gateway | Outbound internet access for private subnets — when it's correct and when it's a PCI/cost mistake |
| VPC Gateway Endpoint | Free, private path to S3 and DynamoDB — always prefer over NAT for these |
| VPC Interface Endpoint (PrivateLink) | Private path to AWS managed services (SQS, SNS, API GW, etc.) without internet exposure |
| PrivateLink as a service exposure pattern | Expose your own service to another VPC/account without VPC peering or internet |
| VPC Peering | Low-latency, non-transitive VPC-to-VPC — when it's correct |
| Transit Gateway | Hub-and-spoke for many VPCs — when peering mesh becomes unmanageable |
| Split-horizon DNS | Same hostname resolves differently inside vs outside VPC — private service discovery pattern |

**AWS implementation vehicles:** NAT GW, VPC Endpoints (Interface + Gateway), PrivateLink, VPC Peering, Transit GW, Route 53 Resolver, Private Hosted Zones

**Lab:** Start with a service using NAT GW for S3 + SQS access; convert both to VPC endpoints; add PrivateLink for a cross-account card vault service; configure split-horizon DNS; measure and document cost + attack surface delta

---

### Day 4 — Service-to-Service Patterns (~4–5 h)
**Enterprise scenario:** Microservice mesh — order service → payment service → fulfillment service; circuit breaker on payment; async audit event queue

**Pattern family:** Internal communication — synchronous first, async compressed

**Synchronous patterns:**

| Pattern | Problem it solves |
|---|---|
| Service discovery | How a caller finds an instance without hardcoded IPs |
| Load balancing strategies | Round-robin vs least-connections vs weighted target — when each |
| Circuit breaker | Stop cascading failures when a downstream service degrades |
| Timeout + retry budget | Prevent indefinite waiting; distinguish retryable from non-retryable errors |
| Bulkhead | Isolate failure domains so one slow service doesn't exhaust shared resources |

**AWS sync vehicles:** ALB internal, Cloud Map (service discovery), ECS Service Connect, App Mesh

**Asynchronous patterns (compressed — pattern recognition, not SQS/SNS drill):**

| Pattern | Problem it solves |
|---|---|
| Point-to-point queue (SQS) | Decouple producer from consumer; one consumer per message |
| Pub-sub (SNS / EventBridge) | One event → multiple independent consumers |
| Outbox pattern | Guarantee async message delivery atomically with the DB write |
| Fan-out to queues | Combine pub-sub + point-to-point: SNS topic → multiple SQS queues |
| Dead-letter queue | Capture unprocessable messages without losing them |

**Lab:** Internal ALB for order→payment sync call; add circuit breaker simulation (toggle target group health); add SQS queue for async audit events; kill the consumer, watch DLQ fill; restore consumer, drain DLQ

---

### Day 5 — External Integration + Synthesis (~4–5 h)
**Enterprise scenario:** External payment provider webhook (Stripe-style) + cross-account PCI isolation design

**Pattern family:** Your system ↔ third-party systems + tying the full stack together

| Pattern | Problem it solves |
|---|---|
| Inbound webhook receiver | Accept push events from external providers reliably |
| Idempotency key | Process the same event exactly once even under retry |
| Webhook signature validation | Authenticate the sender before processing |
| Outbound webhook / event push | Notify external consumers of your events |
| Polling vs push decision | When to pull vs accept push — latency, cost, complexity trade-offs |
| Cross-account access patterns | Resource-based policy vs PrivateLink vs RAM — decision tree |

**Lab:** Build an inbound webhook receiver (API GW → Lambda → SQS) with HMAC signature validation + idempotency key (DynamoDB); simulate duplicate delivery, confirm exactly-once; then whiteboard (no build) a cross-account PCI isolation architecture using the patterns from Days 1–4

**Synthesis exercise:** Given a real enterprise scenario (e.g., a payments platform accepting external provider webhooks, exposing a BFF to a mobile app, and running microservices in a PCI-scoped VPC), whiteboard the complete integration stack — ingress → internal → egress → external — with pattern names, AWS vehicles, and explicit trade-off justifications for each boundary decision.

---

## Directory Layout

```
aws_system_integrations/
├── README.md                            # quickstart, day index, prerequisites
├── STRATEGY.md                          # top-1% approach, boundary mental model, what to skip
├── content/
│   ├── GLOSSARY.md                      # pattern names, plain-English definitions
│   ├── day01.md                         # API Gateway patterns + mobile banking BFF
│   ├── day02.md                         # Ingress patterns + core banking API canary
│   ├── day03.md                         # Egress + VPC boundary + PCI PrivateLink
│   ├── day04.md                         # Service-to-service + microservice mesh
│   └── day05.md                         # External integration + synthesis
├── labs/
│   ├── day01/
│   │   ├── README.md                    # scenario, goal, success signal, prerequisites
│   │   ├── SOLUTION.md                  # annotated solution walkthrough
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars.example
│   │   └── teardown.md
│   ├── day02/ … day05/                  # same structure
└── docs/superpowers/
    ├── specs/
    │   └── 2026-08-28-aws-integration-patterns-design.md   ← this file
    └── plans/
        └── 2026-08-28-aws-integration-patterns-plan.md
```

---

## Content Day Skeleton

```markdown
# Day N — <Pattern Family Title>

## Why this matters
<1 paragraph: the enterprise pain this pattern family solves. Concrete. Reference banking/payment/microservice context.>

## The boundary this manages
<1–2 sentences: which of the 5 boundary types, and what it controls.>

## Core patterns

### Pattern Name
**Problem:** <what breaks without this pattern>
**How it works:** <mechanism in 2–4 sentences>
**AWS implementation:** <primary vehicle + decision notes vs alternatives>
**When it's wrong:** <the anti-pattern condition>

[repeat for each pattern in the day]

## Decision tree
<A short "when to use what" comparison across the day's patterns.>

## Exercises
1. <scenario-grounded task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. ...

## Anti-patterns / Common mistakes
- <2–3 bullets, each with: what the mistake is + what it costs in production>

## Lab
See `labs/dayNN/`. **Goal:** <one sentence>. **Success signal:** <observable output>.

## Teardown
See `labs/dayNN/teardown.md`.
```
