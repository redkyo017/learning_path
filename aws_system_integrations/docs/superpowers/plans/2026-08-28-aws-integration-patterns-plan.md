# AWS System Integration Patterns — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete 5-day enterprise integration patterns learning path anchored to banking, payment, and microservice use cases.

**Architecture:** Pattern-first curriculum organized by boundary type (API gateway, ingress, egress, internal, external). Each day delivers one content file + one full Terraform lab with README, SOLUTION, and teardown. Enterprise scenarios (mobile banking BFF, PCI PrivateLink, canary deploy for core banking API) run as the concrete thread across all days.

**Tech Stack:** Markdown content files, Terraform (AWS provider) for labs, AWS services: API GW, ALB, NLB, CloudFront, WAF, SQS, SNS, VPC Endpoints, PrivateLink, Step Functions, Lambda, Route 53, DynamoDB.

**Spec:** `aws_system_integrations/docs/superpowers/specs/2026-08-28-aws-integration-patterns-design.md`

## Global Constraints

- No git commits, git add, or git push during authoring — learner handles all VCS
- No real credentials, account IDs, or access keys in any file — placeholders only, ship `terraform.tfvars.example`
- Every exercise ships with **Hint** + **Solution sketch** — no bare problems
- Every lab ships with README.md + SOLUTION.md + teardown.md
- Labs are authored and documented only — never run `terraform apply` during authoring
- No `git status`, `git log`, or `git diff` in any subagent dispatch

---

## File Map

```
aws_system_integrations/
├── README.md                            ← Task 1
├── STRATEGY.md                          ← Task 1
├── content/
│   ├── GLOSSARY.md                      ← Task 2
│   ├── day01.md                         ← Task 3
│   ├── day02.md                         ← Task 4
│   ├── day03.md                         ← Task 5
│   ├── day04.md                         ← Task 6
│   └── day05.md                         ← Task 7
└── labs/
    ├── day01/                           ← Task 3
    │   ├── README.md
    │   ├── SOLUTION.md
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars.example
    │   └── teardown.md
    ├── day02/ … day05/                  ← Tasks 4–7 (same structure)
```

---

### Task 1: Root scaffold — README.md + STRATEGY.md

**Files:**
- Create: `aws_system_integrations/README.md`
- Create: `aws_system_integrations/STRATEGY.md`

**Interfaces:**
- Produces: entry point for the learner; referenced by all day files

- [ ] **Step 1: Write `aws_system_integrations/README.md`**

  Required sections and content:

  ```markdown
  # AWS System Integration Patterns

  5-day pattern-first learning path. Focus: enterprise integration patterns
  (API gateway, ingress, egress, service-to-service, external) implemented on AWS.
  Use cases: banking, payment, microservices.

  ## Prerequisites
  - AWS account (personal)
  - AWS CLI configured
  - Terraform >= 1.5 installed
  - Familiarity with IAM, EC2, S3, RDS basics

  ## How to use this path
  Each day = one content file (read first) + one lab (then build).
  Follow the pattern loop: name it → draw the boundary → map to AWS → wire it → break it → fix it.

  ## Day Index
  | Day | Pattern family | Enterprise scenario |
  |---|---|---|
  | 1 | API Gateway patterns | Mobile banking BFF |
  | 2 | Ingress patterns | Core banking API canary deploy |
  | 3 | Egress + VPC boundary | PCI PrivateLink scope reduction |
  | 4 | Service-to-service | Microservice mesh (order→payment→fulfillment) |
  | 5 | External integration + synthesis | Payment provider webhook + cross-account PCI |

  ## Cost note
  Each lab includes a teardown checklist. Run teardown after every session.
  Estimated cost per lab if left running overnight: $2–$10 depending on day.
  ```

- [ ] **Step 2: Write `aws_system_integrations/STRATEGY.md`**

  Required sections and content:

  ```markdown
  # The Top 1% Strategy for AWS Integration Patterns

  ## The core mental model: integration is about boundaries

  Every enterprise integration pattern exists to manage what crosses a boundary
  and under what terms. Four boundary types in this path:

  - **Ingress boundary** — client → your system (who can enter, how, at what rate)
  - **Internal boundary** — service → service inside your system (coupling, reliability)
  - **Egress boundary** — your system → AWS services or internet (cost, PCI scope, auditability)
  - **External boundary** — your system ↔ third-party systems (webhooks, partner APIs)

  Once you see every pattern through this lens, the right pattern for any new
  situation becomes *derivable*, not memorized.

  ## The pattern loop (apply to every day)

  1. Name the pattern and the problem it was invented to solve
  2. Draw the boundary it manages
  3. Map it to AWS — which services implement it and what each trades off
  4. Wire it — minimal real Terraform lab
  5. Break it — remove a component, inject a failure
  6. Fix it — add the resilience mechanism the pattern implies

  ## What the 80% waste time on

  | Trap | Why it fails |
  |---|---|
  | Service-first learning (SQS docs → SNS docs → EventBridge docs) | Learns features, not composition |
  | Happy-path-only labs | Understands operation, not failure — senior engineers are hired for failure reasoning |
  | Treating API Gateway as "just a proxy" | Misses BFF, anti-corruption layer, API composition |
  | Ignoring egress | VPC endpoint vs NAT vs PrivateLink is the #1 gap junior→senior |
  | Async without the outbox pattern | Ships integrations that silently lose messages under failure |

  ## What the top 1% do differently

  - They learn the *pattern* before the *service*
  - They intentionally break systems in labs to understand failure modes
  - They can name the pattern AND the problem it solves AND one scenario where it's the wrong choice
  - They treat egress as a first-class design concern, not an afterthought
  - They always ask: "what happens when this component is unavailable?"
  ```

- [ ] **Step 3: Verify both files exist and contain all required sections**

  Check: README has Prerequisites, How to use, Day Index, Cost note.
  Check: STRATEGY has boundary mental model, pattern loop, 80% traps table, top 1% behaviors.

---

### Task 2: GLOSSARY.md

**Files:**
- Create: `aws_system_integrations/content/GLOSSARY.md`

**Interfaces:**
- Produces: pattern name → plain-English definition for all terms used in days 1–5

- [ ] **Step 1: Write `aws_system_integrations/content/GLOSSARY.md`**

  Include a definition for every pattern and term used across all 5 days.
  Format: `**Term** — plain-English definition (1–2 sentences). Example: <one-line enterprise example>.`

  Required entries (minimum — add any term a Day 1-5 reader would need to look up):

  - API Gateway (pattern) — not the AWS service; the architectural pattern
  - Backend-for-Frontend (BFF)
  - API Composition / Aggregation
  - Anti-Corruption Layer (ACL)
  - Reverse Proxy
  - L4 ingress / L7 ingress
  - Weighted routing
  - Header-based routing
  - mTLS
  - WAF integration (as a pattern)
  - CDN + origin offload
  - NAT Gateway (when correct vs wrong)
  - VPC Gateway Endpoint
  - VPC Interface Endpoint (PrivateLink)
  - PrivateLink as service exposure pattern
  - VPC Peering
  - Transit Gateway
  - Split-horizon DNS
  - Service discovery
  - Circuit breaker
  - Timeout + retry budget
  - Bulkhead
  - Point-to-point queue
  - Pub-sub
  - Outbox pattern
  - Fan-out to queues
  - Dead-letter queue (DLQ)
  - Inbound webhook receiver
  - Idempotency key
  - Webhook signature validation
  - Polling vs push
  - Cross-account access patterns

- [ ] **Step 2: Verify all entries follow the format and include an enterprise example**

---

### Task 3: Day 1 — API Gateway Patterns

**Files:**
- Create: `aws_system_integrations/content/day01.md`
- Create: `aws_system_integrations/labs/day01/README.md`
- Create: `aws_system_integrations/labs/day01/SOLUTION.md`
- Create: `aws_system_integrations/labs/day01/main.tf`
- Create: `aws_system_integrations/labs/day01/variables.tf`
- Create: `aws_system_integrations/labs/day01/terraform.tfvars.example`
- Create: `aws_system_integrations/labs/day01/teardown.md`

**Interfaces:**
- Produces: first content day + working Terraform BFF lab skeleton

- [ ] **Step 1: Write `aws_system_integrations/content/day01.md`**

  Use the day skeleton from the spec. Required content:

  **Why this matters:** Mobile banking apps must talk to multiple backend services
  (payment, account, notification) without each client knowing the full service topology.
  Without a BFF, every client change requires coordination across multiple teams.

  **The boundary this manages:** Ingress boundary — specifically the layer between
  external clients and backend services.

  **Pattern sections to include (one section each, using the pattern structure from spec):**
  1. Reverse proxy — problem: protocol termination + single entry point; AWS: ALB, nginx, CloudFront
  2. API Gateway (generalized) — problem: cross-cutting concerns (auth, rate limiting, transformation) at one boundary; AWS: API GW REST vs HTTP vs WebSocket decision tree; when HTTP API is correct vs REST API
  3. Backend-for-Frontend (BFF) — problem: mobile vs web have different payload shapes; mobile banking needs account summary + recent transactions + payment status in one call; AWS: API GW + Lambda aggregator or API GW + VTL mapping
  4. API Composition / Aggregation — problem: client makes N calls → fan-in; AWS: Lambda orchestrator pattern, Step Functions for complex fan-in
  5. Anti-Corruption Layer (ACL) — problem: downstream service speaks different protocol or schema (legacy core banking SOAP → REST); AWS: API GW + Lambda transformer

  **Decision tree:** REST API GW vs HTTP API GW vs ALB as lightweight gateway — table with criteria (latency, cost, features needed)

  **Exercises (3 minimum, each with Hint + Solution sketch):**
  1. A mobile banking app needs to call the account service (returns balance) and the transaction service (returns last 10 transactions) in a single API call. Which pattern? Draw the flow. — **Hint:** Think about what the mobile client needs vs what each service returns. — **Solution sketch:** BFF pattern: API GW → Lambda aggregator → parallel calls to account-svc + transaction-svc → merged response. Lambda handles the fan-out and merge.
  2. Your core banking system exposes a SOAP/XML API. Your new mobile gateway must expose REST/JSON. Which pattern? What are the failure modes? — **Hint:** The client and the backend speak different languages — what sits between them? — **Solution sketch:** ACL pattern: API GW + Lambda transformer. Failure modes: schema mismatch silently returns null fields; SOAP fault not mapped to HTTP 4xx/5xx; latency spike from XML parsing.
  3. You have an API GW in front of 5 microservices. A single slow microservice is causing all requests to time out. What pattern is missing, and how do you add it? — **Hint:** The problem is coupling via shared wait time. — **Solution sketch:** Bulkhead + timeout per upstream. API GW integration timeout (max 29s) per route. Lambda aggregator adds per-service deadline. Circuit breaker for repeated failures.

  **Anti-patterns / Common mistakes:**
  - Using REST API GW when HTTP API GW suffices — 70% cost saving ignored because REST is the default
  - BFF that becomes a "god aggregator" — BFF should be thin; business logic belongs in services
  - ACL that caches stale transformed responses — transformation layer must propagate cache-control from upstream

  **Lab:** See `labs/day01/`. Goal: wire a BFF with API GW + Lambda aggregating two mock services; add JWT authorizer + usage plan. Success signal: single API call returns merged response; a request without JWT returns 401; exceeding rate limit returns 429.

- [ ] **Step 2: Write `aws_system_integrations/labs/day01/README.md`**

  Required sections:
  - **Scenario:** Mobile banking app needs a single `/summary` endpoint that aggregates account balance (from mock account service) and last 5 transactions (from mock transaction service) with JWT auth and rate limiting.
  - **Architecture diagram** (ASCII): Client → API GW (JWT authorizer + usage plan) → Lambda BFF → [Account Lambda mock, Transaction Lambda mock]
  - **Prerequisites:** AWS CLI configured, Terraform >= 1.5, AWS account, `jq` installed
  - **What you'll build:** API GW HTTP API + Lambda authorizer + Lambda BFF aggregator + 2 mock backend Lambdas + usage plan
  - **Goal:** One `curl` call to `/summary` returns merged JSON; call without JWT returns 401; exceed rate limit returns 429
  - **Success signal:** `curl -H "Authorization: Bearer <token>" https://<api-id>.execute-api.<region>.amazonaws.com/summary` returns `{"balance": ..., "transactions": [...]}`
  - **Break it exercise:** Remove the Lambda BFF timeout on one mock backend. Call `/summary` while the backend is slow. Observe the API GW integration timeout behavior. What does the client see?

- [ ] **Step 3: Write `aws_system_integrations/labs/day01/main.tf`**

  Create Terraform that provisions:
  ```hcl
  # Mock account service Lambda (returns hardcoded balance JSON)
  resource "aws_lambda_function" "account_mock" { ... }

  # Mock transaction service Lambda (returns hardcoded transactions JSON)
  resource "aws_lambda_function" "transaction_mock" { ... }

  # BFF aggregator Lambda (calls both mocks in parallel, merges response)
  resource "aws_lambda_function" "bff_aggregator" { ... }

  # Lambda authorizer (validates Bearer token — accepts any non-empty token for lab)
  resource "aws_lambda_function" "jwt_authorizer" { ... }

  # HTTP API Gateway
  resource "aws_apigatewayv2_api" "banking_bff" { ... }

  # Authorizer attached to API
  resource "aws_apigatewayv2_authorizer" "jwt" { ... }

  # Route: GET /summary → BFF Lambda
  resource "aws_apigatewayv2_route" "summary" { ... }

  # Usage plan + API key (rate limiting)
  resource "aws_apigatewayv2_stage" "default" { ... }

  # IAM roles for Lambdas
  resource "aws_iam_role" "lambda_exec" { ... }
  ```
  Use `var.aws_region` and `var.environment` — no hardcoded values.
  Lambda inline source code (simple Python handler) embedded as `filename` with `archive_file` data source or as `source_code_hash` + base64 inline for mock simplicity.
  All resource names prefixed with `var.environment`.

- [ ] **Step 4: Write `aws_system_integrations/labs/day01/variables.tf`**

  ```hcl
  variable "aws_region" {
    description = "AWS region to deploy into"
    type        = string
    default     = "ap-southeast-1"
  }

  variable "environment" {
    description = "Environment prefix for all resource names"
    type        = string
    default     = "lab-day01"
  }
  ```

- [ ] **Step 5: Write `aws_system_integrations/labs/day01/terraform.tfvars.example`**

  ```hcl
  aws_region  = "ap-southeast-1"   # Change to your preferred region
  environment = "lab-day01"        # Prefix for all created resources
  # No credentials here — use AWS CLI profile or environment variables:
  # export AWS_PROFILE=your-profile
  # export AWS_ACCESS_KEY_ID=...     (never commit real keys)
  # export AWS_SECRET_ACCESS_KEY=... (never commit real keys)
  ```

- [ ] **Step 6: Write `aws_system_integrations/labs/day01/SOLUTION.md`**

  Required sections:
  - **Architecture explanation:** Why HTTP API GW (not REST) — cost, latency, sufficient features for this lab
  - **BFF Lambda logic walkthrough:** How the aggregator calls both mocks concurrently (Python `asyncio` or `ThreadPoolExecutor`), merges responses, returns combined JSON
  - **JWT authorizer explanation:** Why a Lambda authorizer vs Cognito for this lab; how the policy document is constructed
  - **Usage plan explanation:** Throttle (rate + burst) vs quota — what each controls
  - **Break it answer:** When BFF Lambda timeout < API GW integration timeout, client receives API GW's generic 504. When BFF Lambda timeout > API GW integration timeout (29s max), API GW 504 fires first. Client always sees 504, never the partial response — teach learner to add per-upstream timeouts inside the BFF.
  - **Common mistakes in this lab:** Lambda execution role missing `lambda:InvokeFunction` on peer Lambdas; authorizer cache TTL set to 0 causing re-auth on every request (cost + latency); forgetting to attach stage to deployment

- [ ] **Step 7: Write `aws_system_integrations/labs/day01/teardown.md`**

  ```markdown
  # Day 1 Lab Teardown

  Run after every lab session to avoid ongoing charges.

  ## Automated teardown
  From `labs/day01/`:
  ```bash
  terraform destroy -auto-approve
  ```

  ## Manual verification checklist (run after destroy)
  - [ ] API GW HTTP API deleted: AWS Console → API Gateway → verify no `lab-day01-*` APIs
  - [ ] Lambda functions deleted: AWS Console → Lambda → verify no `lab-day01-*` functions
  - [ ] IAM roles deleted: AWS Console → IAM → Roles → verify no `lab-day01-*` roles
  - [ ] CloudWatch log groups deleted (not auto-deleted by Terraform):
        `aws logs delete-log-group --log-group-name /aws/lambda/lab-day01-bff-aggregator`
        (repeat for each Lambda log group)

  ## Estimated cost if left running
  - Lambda: ~$0.00 (free tier covers lab volume)
  - API GW HTTP API: ~$0.00 (free tier covers lab volume)
  - Note: This lab has no always-on resources — cost only accrues per request.
  ```

- [ ] **Step 8: Verify all 7 files exist; confirm day01.md has all required sections, all exercises have Hint + Solution sketch, lab README has Break it exercise, SOLUTION.md has Break it answer**

---

### Task 4: Day 2 — Ingress Patterns

**Files:**
- Create: `aws_system_integrations/content/day02.md`
- Create: `aws_system_integrations/labs/day02/README.md`
- Create: `aws_system_integrations/labs/day02/SOLUTION.md`
- Create: `aws_system_integrations/labs/day02/main.tf`
- Create: `aws_system_integrations/labs/day02/variables.tf`
- Create: `aws_system_integrations/labs/day02/terraform.tfvars.example`
- Create: `aws_system_integrations/labs/day02/teardown.md`

**Interfaces:**
- Consumes: boundary mental model established in day01.md
- Produces: Day 2 content + ALB weighted/header-based routing lab

- [ ] **Step 1: Write `aws_system_integrations/content/day02.md`**

  **Why this matters:** A core banking team needs to roll out a new API version without
  a big-bang cutover. Ingress patterns control how traffic is admitted, shaped, and
  routed before it touches any service — getting this wrong means all-or-nothing deploys,
  no ability to A/B test, and no security policy at the edge.

  **The boundary this manages:** Ingress boundary — specifically the traffic admission
  and routing layer before services receive requests.

  **Pattern sections:**
  1. L4 vs L7 ingress decision — problem: choosing the wrong layer causes capability gaps or unnecessary cost; L4 = NLB (TCP/UDP/TLS passthrough, ultra-low latency, no HTTP awareness); L7 = ALB (content-based routing, host/path/header rules, HTTP/2, WebSocket); decision tree: need TLS passthrough or non-HTTP? → NLB. Need routing rules, auth offload, WAF? → ALB.
  2. Weighted routing — problem: deploy a new version without all-or-nothing risk; how: ALB weighted target groups (e.g., 90% v1, 10% v2); AWS: ALB + two target groups + weighted rule; canary deploy pattern; blue-green pattern (100% shift after validation)
  3. Header-based routing — problem: serve different API versions or tenants from one ingress; how: ALB listener rule on `x-api-version` or `x-tenant-id` header; AWS: ALB listener rules with `http-header` condition
  4. mTLS at ingress — problem: authenticate the caller at the network layer, not just app layer; how: ALB mutual TLS (ALB mTLS feature, or NLB TLS passthrough to app); use case: B2B banking partner connecting to your API
  5. WAF integration as a pattern — problem: enforce security policy (OWASP, geo-block, rate limit by IP) before the request reaches any compute; how: WAF WebACL attached to ALB or API GW; pattern: separate WAF rules by concern (managed rules + custom rules + rate-based rules)
  6. CDN + origin offload — problem: static/cacheable responses should never reach origin; how: CloudFront → ALB → origin; cache policy per behavior; origin shield; use case: banking static assets, public-facing product pages

  **Decision tree table:** NLB vs ALB vs API GW as ingress — rows: protocol, routing rules, WAF support, mTLS, cost, latency

  **Exercises (3 minimum):**
  1. Your team wants to roll out a new `/payments/v2` API to 5% of traffic while keeping 95% on v1. Which ingress pattern? Which AWS service? Draw the target group configuration. — **Hint:** You need traffic split at the routing layer, not the application layer. — **Solution sketch:** ALB weighted routing: two target groups (v1-tg, v2-tg), one listener rule with weighted forward action (95/5). Shift weights in ALB without redeployment. Promote v2 by moving to 100/0.
  2. A banking partner must connect to your internal settlement API. They present a client certificate. Where do you terminate mTLS and why? — **Hint:** Think about where you want the certificate validated relative to your services. — **Solution sketch:** ALB mTLS (AWS ACM integration): ALB validates client cert against trust store (ACM Private CA), forwards `x-amzn-mtls-clientcert-*` headers to backend. Avoids exposing cert validation logic to every service.
  3. Your WAF is blocking 5% of legitimate mobile app requests. How do you diagnose which rule is responsible without disabling WAF? — **Hint:** WAF has a count mode separate from block mode. — **Solution sketch:** Set suspicious rule to Count mode in WAF WebACL. Watch CloudWatch `AllowedRequests` vs `CountedRequests` metrics. Identify which rule IDs fire on legitimate traffic. Tune IP reputation lists or rate limits. Re-enable block.

  **Anti-patterns / Common mistakes:**
  - Routing by URL path prefix only — breaks when services are restructured; prefer host-based + path-based combination
  - WAF in block mode on day one — always start in count mode, tune for 1–2 weeks before switching to block
  - NLB for a new service that later needs WAF/mTLS — impossible to add later without replacing the ingress tier; assess upfront

  **Lab:** See `labs/day02/`. Goal: ALB with weighted + header-based routing for a versioned banking API; canary deploy simulation. Success signal: header `x-api-version: v2` routes to v2 target; 10%/90% weight distributes traffic across versions.

- [ ] **Step 2: Write `aws_system_integrations/labs/day02/README.md`**

  Scenario: Core banking team releasing `/api/payments` v2. Need canary deploy (10% v2) and header-based version pinning for internal QA team (always v2 via `x-api-version: v2`).
  Architecture diagram (ASCII): Client → ALB → [Listener Rule 1: header x-api-version=v2 → v2-tg (100%), Listener Rule 2: weighted → v1-tg (90%), v2-tg (10%)]
  Break it exercise: Remove all instances from v2 target group (set desired=0 on ASG or deregister targets). With 10% weighted to v2, what does ALB do? Does it return 502, redistribute to v1, or fail silently?

- [ ] **Step 3: Write `aws_system_integrations/labs/day02/main.tf`**

  Provisions: VPC (or use default VPC), two EC2 instances (or ECS tasks) acting as v1 and v2 mock servers, ALB, two target groups (v1-tg, v2-tg), listener on port 80, two listener rules: (1) header condition `x-api-version = v2` → forward 100% to v2-tg; (2) default weighted forward 90/10 v1/v2. Security groups. Use `var.aws_region` and `var.environment`. No hardcoded AMI IDs — use `data "aws_ami"` for Amazon Linux 2.

- [ ] **Step 4: Write `aws_system_integrations/labs/day02/variables.tf`**

  Variables: `aws_region` (default `ap-southeast-1`), `environment` (default `lab-day02`), `v2_weight` (default `10`, type number, description "Percentage of traffic to route to v2 target group").

- [ ] **Step 5: Write `aws_system_integrations/labs/day02/terraform.tfvars.example`**

  Same pattern as day01: region, environment, v2_weight, credentials comment.

- [ ] **Step 6: Write `aws_system_integrations/labs/day02/SOLUTION.md`**

  Sections: ALB listener rule priority explanation (lower number = higher priority — why header rule must have lower priority number than weighted default), weighted target group mechanics (503 vs redistribution when target is unhealthy — ALB does NOT redistribute healthy traffic from a healthy group; it returns 502/503 if ALL targets in a weighted group are unhealthy), how to simulate canary promotion (change `v2_weight` variable to 50, then 100, then decommission v1-tg), Break it answer.

- [ ] **Step 7: Write `aws_system_integrations/labs/day02/teardown.md`**

  Checklist: `terraform destroy`, verify ALB deleted, EC2 instances terminated, target groups deleted, security groups deleted (may require manual if dependency graph leaves orphans — include the `aws ec2 delete-security-group` command). Estimated cost if left running: ALB ~$0.008/hour (~$0.19/day).

- [ ] **Step 8: Verify all 7 files exist; confirm all exercises have Hint + Solution sketch, Break it exercise in README, Break it answer in SOLUTION**

---

### Task 5: Day 3 — Egress + VPC Boundary Patterns

**Files:**
- Create: `aws_system_integrations/content/day03.md`
- Create: `aws_system_integrations/labs/day03/README.md`
- Create: `aws_system_integrations/labs/day03/SOLUTION.md`
- Create: `aws_system_integrations/labs/day03/main.tf`
- Create: `aws_system_integrations/labs/day03/variables.tf`
- Create: `aws_system_integrations/labs/day03/terraform.tfvars.example`
- Create: `aws_system_integrations/labs/day03/teardown.md`

**Interfaces:**
- Consumes: VPC / networking concepts introduced in day02.md (ALB, VPC, subnets)
- Produces: Day 3 content + VPC endpoint + PrivateLink lab

- [ ] **Step 1: Write `aws_system_integrations/content/day03.md`**

  **Why this matters:** A payment processor calling a card vault service over the public
  internet is a PCI DSS scope explosion — every network device between them is now in scope.
  Egress patterns let you keep data on the AWS backbone, reduce PCI scope, cut NAT costs,
  and maintain auditability of exactly what leaves your environment.

  **The boundary this manages:** Egress boundary — what leaves your VPC, to where, under
  what security and cost terms.

  **Pattern sections:**
  1. NAT Gateway — problem: private subnet instances need internet access (OS patches, external APIs); how: route 0.0.0.0/0 through NAT GW in public subnet; cost: $0.045/hour + $0.045/GB processed; when it's a mistake: using NAT for S3 or SQS traffic (Gateway Endpoints are free and faster); PCI implication: any service using NAT is potentially in internet-routable path
  2. VPC Gateway Endpoint — problem: free, private path to S3 and DynamoDB without NAT; how: route table entry for S3/DynamoDB prefix lists → gateway endpoint; cost: free; always prefer over NAT for these two services; limitation: only S3 and DynamoDB
  3. VPC Interface Endpoint (PrivateLink) — problem: private path to AWS managed services (SQS, SNS, API GW, ECR, Secrets Manager, etc.) without internet exposure; how: ENI in your subnet with a private IP, DNS resolves to private IP; cost: $0.01/hour per AZ + $0.01/GB; when to use: PCI-scoped workloads, air-gapped environments, compliance mandates
  4. PrivateLink as a service exposure pattern — problem: expose your own service (in VPC A) to a consumer (in VPC B or different account) without VPC peering or internet; how: NLB in provider VPC → VPC Endpoint Service → Interface Endpoint in consumer VPC; use case: card vault service exposed to payment processor in separate PCI account
  5. VPC Peering — problem: low-latency, private VPC-to-VPC connectivity for services that communicate frequently; how: peering connection, non-transitive routing; limitation: doesn't scale beyond ~10 VPCs (becomes a mesh); when it's wrong: if you need transitive routing or > ~10 VPCs → Transit GW
  6. Transit Gateway — problem: hub-and-spoke for many VPCs (org-wide connectivity, centralized inspection); how: each VPC attaches to TGW, route tables control which VPCs can reach each other; cost: $0.05/hour per attachment + $0.02/GB; when overkill: < 5 VPCs with simple topology
  7. Split-horizon DNS — problem: same hostname (e.g., `vault.internal.bank.com`) should resolve to private IP inside VPC and optionally be unreachable outside; how: Route 53 Private Hosted Zone associated with VPC; DNS resolver returns private IP inside VPC, public DNS has no record (or different record); use case: card vault service — only reachable from within the payment VPC

  **Decision tree:** NAT GW vs Gateway Endpoint vs Interface Endpoint vs PrivateLink — by destination type (S3, DynamoDB, other AWS service, own service, internet)

  **Exercises (3 minimum):**
  1. Your Lambda function in a private subnet calls S3 and SQS. Currently it uses NAT Gateway. What change reduces cost and improves security? — **Hint:** Ask: does each destination need internet, or is there a private path? — **Solution sketch:** Replace NAT for S3 with Gateway Endpoint (free, no data processing charge). Replace NAT for SQS with Interface Endpoint ($0.01/hr per AZ, but saves $0.045/GB NAT processing). Keep NAT only if Lambda needs internet for anything else. Add bucket policy condition `aws:SourceVpce` to restrict S3 access to endpoint only.
  2. Your card vault service runs in Account A (PCI scope). Your payment processor runs in Account B. The vault must be reachable from Account B without VPC peering and without internet. Design the connectivity. — **Hint:** You need to expose a service across account boundaries privately. — **Solution sketch:** Account A: NLB in front of card vault + VPC Endpoint Service (PrivateLink). Account B: VPC Interface Endpoint pointing to Account A's Endpoint Service. Account A approves the endpoint request. DNS in Account B resolves vault hostname to Interface Endpoint private IP. No VPC CIDR overlap concerns, no transitive routing needed.
  3. You have 12 VPCs across 3 AWS regions. Teams complain that adding new VPC-to-VPC connectivity requires updating N peering connections. What pattern removes this scaling pain? — **Hint:** Think about whether you need point-to-point or hub-and-spoke. — **Solution sketch:** Transit Gateway (one TGW per region, TGW peering cross-region). Each VPC has one TGW attachment. Route tables on TGW control which VPCs can reach each other. Adding a new VPC = one attachment + one route table entry, not N peering connections.

  **Anti-patterns / Common mistakes:**
  - Using NAT GW for S3 and SQS traffic — common in default architectures; Gateway and Interface Endpoints are free or low-cost and keep traffic off the internet
  - PrivateLink without endpoint policies — anyone with access to the endpoint can reach the service; always add an endpoint policy scoping access to specific principals and actions
  - VPC Peering for > 10 VPCs — the mesh becomes unmanageable and non-transitive routing causes traffic blindspots; this is when Transit GW earns its cost

  **Lab:** See `labs/day03/`. Goal: convert a service from NAT GW egress to VPC Gateway Endpoint (S3) + Interface Endpoint (SQS); add PrivateLink for cross-account card vault pattern (simulated). Success signal: Lambda in private subnet reaches S3 and SQS with no NAT GW; VPC Flow Logs show no traffic to NAT GW for S3/SQS.

- [ ] **Step 2: Write `aws_system_integrations/labs/day03/README.md`**

  Scenario: Payment processor Lambda in private subnet currently uses NAT GW to reach S3 (transaction logs) and SQS (audit queue). Goal: eliminate NAT dependency for AWS service calls; then add PrivateLink endpoint for a simulated card vault service in the same account (cross-account simulation with two VPCs).
  Architecture diagram (ASCII): two VPCs — Provider VPC (card vault mock service, NLB, Endpoint Service) and Consumer VPC (Lambda, Interface Endpoints for S3/SQS/vault).
  Break it exercise: Delete the SQS Interface Endpoint. With no NAT GW and no endpoint, what happens when Lambda tries to publish to SQS? Does it time out, get a connection refused, or receive a specific AWS error?

- [ ] **Step 3: Write `aws_system_integrations/labs/day03/main.tf`**

  Provisions: Consumer VPC (private subnet, no NAT GW), S3 Gateway Endpoint (route table association), SQS Interface Endpoint (private DNS enabled), Lambda in private subnet that writes to S3 + sends to SQS, Provider VPC (NLB + mock EC2 card vault service), VPC Endpoint Service (NLB-backed), Interface Endpoint in consumer VPC for vault service. IAM roles. Security groups for Lambda and endpoints. VPC Flow Logs to CloudWatch (for the Break it observation).

- [ ] **Step 4: Write `aws_system_integrations/labs/day03/variables.tf`**

  Variables: `aws_region`, `environment`, `consumer_vpc_cidr` (default `10.0.0.0/16`), `provider_vpc_cidr` (default `10.1.0.0/16`).

- [ ] **Step 5: Write `aws_system_integrations/labs/day03/terraform.tfvars.example`**

  Same pattern: region, environment, CIDR values, credentials comment.

- [ ] **Step 6: Write `aws_system_integrations/labs/day03/SOLUTION.md`**

  Sections: Gateway Endpoint vs Interface Endpoint mechanics (routing table vs ENI + DNS), private DNS override explanation (Interface Endpoint with `private_dns_enabled=true` overrides the default AWS service DNS — Lambda now resolves `sqs.ap-southeast-1.amazonaws.com` to the private ENI IP automatically), PrivateLink cross-account flow (approval workflow, DNS in consumer, endpoint policies), Break it answer (Lambda receives `Connection timeout` or `Could not connect to the endpoint URL` — not a 403, because the DNS resolution fails before the TCP connection; shows why VPC Endpoints are not optional in isolated subnets), cost comparison table (NAT GW vs Interface Endpoints for 100GB/month traffic).

- [ ] **Step 7: Write `aws_system_integrations/labs/day03/teardown.md`**

  Checklist: `terraform destroy`, verify VPC Endpoints deleted (Interface Endpoints accrue hourly cost), verify NAT GW deleted if one was created, verify VPC Flow Log CloudWatch group deleted. Estimated cost if left running: Interface Endpoints ~$0.02/hour total, VPC Flow Logs ~$0.50/GB ingested.

- [ ] **Step 8: Verify all 7 files exist; confirm all exercises have Hint + Solution sketch, Break it in README, Break it answer in SOLUTION**

---

### Task 6: Day 4 — Service-to-Service Patterns

**Files:**
- Create: `aws_system_integrations/content/day04.md`
- Create: `aws_system_integrations/labs/day04/README.md`
- Create: `aws_system_integrations/labs/day04/SOLUTION.md`
- Create: `aws_system_integrations/labs/day04/main.tf`
- Create: `aws_system_integrations/labs/day04/variables.tf`
- Create: `aws_system_integrations/labs/day04/terraform.tfvars.example`
- Create: `aws_system_integrations/labs/day04/teardown.md`

**Interfaces:**
- Consumes: VPC, ALB, and SQS patterns from days 1–3
- Produces: Day 4 content + internal ALB + SQS + DLQ lab

- [ ] **Step 1: Write `aws_system_integrations/content/day04.md`**

  **Why this matters:** An order service calling a payment service calling a fulfillment
  service is a synchronous chain. If payment is slow, order times out. If fulfillment is
  down, the payment still ran. Service-to-service patterns break these failure propagation
  chains without losing data.

  **The boundary this manages:** Internal boundary — how services inside your system
  communicate with each other, and what coupling and reliability contract they hold.

  **Synchronous pattern sections:**
  1. Service discovery — problem: hardcoded IPs break when instances scale or restart; how: DNS-based discovery (Cloud Map, ECS service discovery), client-side vs server-side; AWS: Cloud Map (`servicediscovery`), ECS Service Connect (built-in), ALB DNS name as stable endpoint
  2. Internal load balancing strategies — problem: distribute load across instances without client awareness; how: round-robin (default), least-outstanding-requests (LOR — better for variable response times), weighted (for staged rollouts); AWS: ALB target group algorithms
  3. Circuit breaker — problem: a slow or failing downstream causes callers to exhaust their thread pool waiting; how: track failure rate per downstream; trip (open) when threshold exceeded; half-open probe after timeout; AWS: no native circuit breaker — implement in Lambda/ECS application code or use App Mesh + Envoy retry/outlier detection
  4. Timeout + retry budget — problem: unbounded wait time cascades upstream; how: per-call deadline + total budget (not per-attempt); retryable (connection error, 503) vs non-retryable (400, 402); exponential backoff with jitter; AWS: ALB idle timeout, Lambda timeout, SDK retry config
  5. Bulkhead — problem: one slow downstream exhausts shared connection pool, starving other downstreams; how: separate thread pools or Lambda concurrency reservations per downstream; AWS: Lambda reserved concurrency per function

  **Asynchronous pattern sections (compressed):**
  6. Point-to-point queue (SQS) — problem: decouple producer from consumer; one message, one consumer; exactly-once processing with deduplication ID (FIFO) or idempotency in consumer; AWS: SQS Standard vs FIFO — decision: ordering required? → FIFO. Throughput critical? → Standard.
  7. Pub-sub (SNS / EventBridge) — problem: one event, multiple independent consumers; SNS: push to N subscriptions simultaneously; EventBridge: content-based routing (filter by event detail fields), cross-account, schema registry; when EventBridge over SNS: need content routing, cross-account fan-out, schema enforcement
  8. Outbox pattern — problem: you write to DB and publish to queue in the same operation; if queue publish fails after DB write, the message is lost; how: write event to `outbox` table in same DB transaction, separate relay process reads outbox and publishes to queue, deletes row on success; AWS: Lambda on DynamoDB Streams reading outbox table
  9. Fan-out to queues — problem: need both distribution (pub-sub) and per-consumer buffering (queue); how: SNS topic → multiple SQS subscriptions; each consumer has its own queue + DLQ; AWS: SNS subscription filter policy per SQS queue
  10. Dead-letter queue — problem: unprocessable messages block the queue or get silently dropped; how: SQS `maxReceiveCount` → DLQ on failure; monitor DLQ depth (CloudWatch alarm); AWS: `redrive_policy` on source SQS queue

  **Decision tree:** sync vs async choice — by coupling requirement, latency requirement, failure isolation need

  **Exercises (3 minimum):**
  1. Your order service calls payment service synchronously. Payment service is responding in 8–15 seconds under load (normally 200ms). Orders are timing out. What patterns apply, and which do you implement first? — **Hint:** There are two separate problems: timeout propagation and slow downstream. — **Solution sketch:** (1) Timeout budget — order service sets a 2s deadline on the payment call; returns 503 fast instead of waiting 15s. (2) Circuit breaker — after N consecutive timeouts, stop calling payment; return fallback response (e.g., "payment queued, processing"). (3) Async decoupling — move payment call to SQS; order service returns 202 Accepted immediately; payment service processes at its own rate.
  2. An audit event must be delivered to three consumers: the audit log service, the fraud detection service, and the compliance reporting service. Each must receive every event independently. Which pattern? What happens if fraud detection is down for 2 hours? — **Hint:** Three independent consumers, each needs its own failure isolation. — **Solution sketch:** SNS topic → three SQS subscriptions (fan-out to queues). Each consumer reads from its own SQS queue. Fraud detection being down for 2 hours: its SQS queue accumulates messages (up to SQS retention period, default 4 days). When fraud detection recovers, it drains the queue. Other consumers are unaffected.
  3. Your payment service writes a DB record and sends a "payment-completed" SQS message. In testing you find that 0.1% of the time the DB write succeeds but the SQS publish fails. What pattern fixes this, and what does the implementation look like on DynamoDB? — **Hint:** The problem is two side effects that need to be atomic but are not. — **Solution sketch:** Outbox pattern. Add `payment_outbox` DynamoDB table. In the same Lambda invocation: (1) write payment record + write outbox record (DynamoDB TransactWriteItems — atomic). (2) Separate relay Lambda triggered by DynamoDB Streams on `payment_outbox` → publishes to SQS → deletes outbox record. If SQS publish fails, outbox record remains and relay retries. DB write + outbox write succeed or fail together.

  **Anti-patterns / Common mistakes:**
  - Retry without jitter — synchronized retries amplify load on a recovering service (thundering herd); always add `random.uniform(0, 1) * base_delay`
  - SQS FIFO for high-throughput workloads — FIFO max 3,000 TPS with batching; Standard SQS is effectively unlimited; don't default to FIFO
  - Publishing to SNS/SQS outside a DB transaction and calling it "reliable" — without the outbox pattern, network partition between DB write and queue publish silently loses events

  **Lab:** See `labs/day04/`. Goal: internal ALB for order→payment sync call; circuit breaker simulation via target group health check manipulation; SQS queue for async audit events with DLQ. Success signal: unhealthy payment targets return 502 within 1 health check interval; DLQ receives messages after `maxReceiveCount` failures.

- [ ] **Step 2: Write `aws_system_integrations/labs/day04/README.md`**

  Scenario: Order service Lambda calls payment service (internal ALB) synchronously. Also publishes audit events to SQS. Lab simulates: (1) payment service going unhealthy, (2) circuit breaker behavior via ALB health checks, (3) SQS consumer failing → DLQ fill.
  Architecture diagram: Order Lambda → Internal ALB → Payment Lambda mock; Order Lambda → SQS (audit-queue) → Consumer Lambda mock; SQS → DLQ (audit-dlq) on maxReceiveCount=3.
  Break it exercise: Set Consumer Lambda to always throw an exception. Send 10 messages to SQS. After 3 receive attempts each, verify all 10 land in DLQ. Then fix the Consumer Lambda and drain the DLQ.

- [ ] **Step 3: Write `aws_system_integrations/labs/day04/main.tf`**

  Provisions: VPC, internal ALB (scheme=internal), payment Lambda mock (returns 200 or 500 based on env var toggle), target group (Lambda target type), SQS standard queue (audit-queue, `maxReceiveCount=3`), SQS DLQ (audit-dlq), consumer Lambda (SQS event source mapping), IAM roles. Use `var.environment`.

- [ ] **Step 4: Write `aws_system_integrations/labs/day04/variables.tf`**

  Variables: `aws_region`, `environment`, `payment_error_rate` (default `0`, type number, description "Set to 100 to simulate payment service always failing — used for circuit breaker simulation").

- [ ] **Step 5: Write `aws_system_integrations/labs/day04/terraform.tfvars.example`**

  Same pattern + `payment_error_rate = 0`.

- [ ] **Step 6: Write `aws_system_integrations/labs/day04/SOLUTION.md`**

  Sections: Internal ALB mechanics (scheme=internal means no public IP; only reachable within VPC), Lambda as ALB target (target group type=lambda, permission grant required), SQS DLQ redrive mechanics (message becomes invisible during processing; after visibility timeout, receive count increments; at maxReceiveCount, moves to DLQ — not on exception, on receive count), Break it answer (after 3 receive attempts × 10 messages = 30 Lambda invocations, DLQ depth = 10; use `aws sqs receive-message --queue-url <dlq-url>` to inspect), circuit breaker note (ALB health checks are not a circuit breaker — they route away from *unhealthy* targets, not from *slow* ones; true circuit breaker requires app-level implementation or App Mesh).

- [ ] **Step 7: Write `aws_system_integrations/labs/day04/teardown.md`**

  Checklist: `terraform destroy`, verify internal ALB deleted, SQS queues deleted (including DLQ), Lambda functions deleted, CloudWatch log groups deleted. Estimated cost: Lambda ($0.00 at lab volume), SQS ($0.00 at lab volume), internal ALB (~$0.008/hour).

- [ ] **Step 8: Verify all 7 files exist; confirm all exercises have Hint + Solution sketch**

---

### Task 7: Day 5 — External Integration + Synthesis

**Files:**
- Create: `aws_system_integrations/content/day05.md`
- Create: `aws_system_integrations/labs/day05/README.md`
- Create: `aws_system_integrations/labs/day05/SOLUTION.md`
- Create: `aws_system_integrations/labs/day05/main.tf`
- Create: `aws_system_integrations/labs/day05/variables.tf`
- Create: `aws_system_integrations/labs/day05/terraform.tfvars.example`
- Create: `aws_system_integrations/labs/day05/teardown.md`

**Interfaces:**
- Consumes: all patterns from days 1–4
- Produces: Day 5 content + webhook receiver lab + synthesis design exercise

- [ ] **Step 1: Write `aws_system_integrations/content/day05.md`**

  **Why this matters:** Payment providers (Stripe, Adyen, local payment rails) push events
  to your system via webhooks. A duplicate webhook means a double-processed payment.
  A dropped webhook means a missed settlement. External integration patterns are the last
  frontier before your system can be called production-grade.

  **The boundary this manages:** External boundary — how your system communicates with
  third-party systems outside your control.

  **Pattern sections:**
  1. Inbound webhook receiver — problem: external providers push events at unpredictable rates; you must accept, validate, and process reliably; how: API GW (public endpoint) → Lambda (validate + enqueue) → SQS (buffer) → consumer; why enqueue immediately: Lambda has 15-min max; SQS decouples acceptance from processing; validation must happen before enqueue to avoid queue poisoning
  2. Idempotency key — problem: external providers retry webhooks on timeout; same event processed twice = double charge; how: extract unique event ID from payload; check DynamoDB `idempotency_store` before processing; write "processing" status atomically; only process if not seen before; write "completed" after; AWS: DynamoDB conditional write (`attribute_not_exists(event_id)`)
  3. Webhook signature validation — problem: anyone can POST to your webhook endpoint; how: provider signs payload with HMAC-SHA256 using a shared secret; your receiver recomputes HMAC and compares; reject if mismatch; AWS: Lambda custom authorizer or in-handler validation; secret stored in Secrets Manager (not env var)
  4. Outbound webhook / event push — problem: your system must notify external consumers when events occur; how: SNS → Lambda → HTTP POST to consumer endpoint with retry; delivery guarantees: at-least-once; consumers must be idempotent; include signature in outbound request; AWS: EventBridge API destinations (managed outbound HTTP with retry), or Lambda + SQS for custom retry logic
  5. Polling vs push decision tree — problem: when to pull vs accept push; push: lower latency, provider controls delivery, suits high-frequency events; polling: simpler consumer, you control rate, suits infrequent or batch events; decision: latency < 1 min + event frequency > 1/min → push; otherwise polling acceptable
  6. Cross-account access patterns decision tree — Resource-based policy (same org, low complexity), PrivateLink (private connectivity requirement, different account), RAM (share resources like Transit GW or Subnet, same org), Assume Role (cross-account API calls, federated access)

  **Synthesis section:**
  Include a complete worked example: a payments platform accepting external provider webhooks, exposing a BFF to a mobile app, and running microservices in a PCI-scoped VPC. Walk through the full pattern stack for this scenario:
  - Ingress: CloudFront → ALB (Day 2 patterns) for the BFF
  - API Gateway pattern: BFF (Day 1) aggregating account + payment services
  - Internal: Internal ALB + service discovery, SQS for async audit (Day 4)
  - Egress: SQS Interface Endpoint, S3 Gateway Endpoint (Day 3)
  - External: Inbound webhook receiver for provider events (Day 5)
  - Cross-cutting: DLQ on every async queue, idempotency on webhook + payment processing, split-horizon DNS for internal services

  **Exercises (3 minimum):**
  1. Stripe sends your webhook endpoint a `payment_intent.succeeded` event. Your Lambda processes it and charges the customer. Stripe times out waiting for your 200 response and retries. You charge the customer twice. Walk through the complete idempotency fix. — **Hint:** You need to detect the duplicate before you act, not after. — **Solution sketch:** Extract `stripe_event_id` from payload. DynamoDB `PutItem` with condition `attribute_not_exists(event_id)`. If condition fails (item exists) → return 200 immediately (idempotent acknowledge) without processing. If condition succeeds → write `{event_id, status: "processing", ttl: now+24h}` → process → update status to "completed". TTL prevents DynamoDB growing unboundedly.
  2. You need to expose an internal payment service to a partner bank in a separate AWS account. The partner refuses to route traffic over the internet. What connectivity pattern do you use, and what are the steps? — **Hint:** Review Day 3 egress patterns — one of them was specifically designed for cross-account private connectivity. — **Solution sketch:** PrivateLink: (1) In your account: NLB in front of payment service + VPC Endpoint Service. (2) Share Endpoint Service name with partner. (3) Partner creates Interface Endpoint in their VPC pointing to your Endpoint Service. (4) You approve the endpoint connection request. (5) Partner's DNS resolves your service to the Interface Endpoint private IP. No internet, no VPC peering, no CIDR overlap concerns.
  3. Design (don't build) the complete integration architecture for: a mobile banking app with 500k users, a payment service that must be PCI-scoped, a core banking legacy SOAP system, and an external payment provider that sends webhooks. Use pattern names from days 1–5 for each decision. — **Hint:** Work boundary by boundary: ingress first, then internal, then egress, then external. — **Solution sketch:** Ingress: CloudFront → ALB (L7 ingress, WAF, header-based routing for API versioning). API GW pattern: BFF (HTTP API GW + Lambda aggregator) for mobile app, ACL pattern for SOAP→REST translation to core banking. Internal: Internal ALB for service-to-service; SQS fan-out to queues for payment events (audit + fraud + compliance); circuit breaker + timeout budget on core banking calls (slow SOAP). Egress: Interface Endpoints for SQS/Secrets Manager; Gateway Endpoint for S3; PrivateLink to expose payment service to PCI account. External: Inbound webhook receiver (API GW → Lambda validator → SQS → consumer) with HMAC validation + DynamoDB idempotency store.

  **Anti-patterns / Common mistakes:**
  - Storing webhook signing secret in Lambda environment variable — rotatable secrets belong in Secrets Manager; env vars are visible in Lambda console and logs
  - Processing webhook payload synchronously in the receiver Lambda — if processing is slow, provider times out and retries; always acknowledge (200) immediately, enqueue, process async
  - No TTL on idempotency store — DynamoDB table grows unboundedly; always set TTL to `event_timestamp + 24h` or `now + 24h`

  **Lab:** See `labs/day05/`. Goal: inbound webhook receiver with HMAC validation + DynamoDB idempotency key; simulate duplicate delivery, confirm exactly-once processing. Success signal: sending the same event ID twice results in exactly one DynamoDB "completed" record and one SQS consumer invocation.

- [ ] **Step 2: Write `aws_system_integrations/labs/day05/README.md`**

  Scenario: Simulate a Stripe-style payment webhook receiver. External provider POSTs to API GW endpoint with HMAC-SHA256 signature. Lambda validates signature (secret from Secrets Manager), checks idempotency (DynamoDB), enqueues to SQS (if new), consumer Lambda processes.
  Architecture diagram: Provider (curl) → API GW (POST /webhook) → Validator Lambda (HMAC check + idempotency check) → SQS (webhook-queue) → Consumer Lambda; DynamoDB (idempotency-store); Secrets Manager (webhook-secret).
  Break it exercise: Send the same event ID three times in rapid succession (simulate retry). Verify that DynamoDB has exactly one record with status "completed" and that Consumer Lambda was invoked exactly once (check CloudWatch Logs invocation count).

- [ ] **Step 3: Write `aws_system_integrations/labs/day05/main.tf`**

  Provisions: API GW HTTP API (POST /webhook route), Validator Lambda (Python — inline code for HMAC validation + DynamoDB conditional write + SQS send), DynamoDB table `webhook_idempotency` (partition key: `event_id`, TTL attribute: `expires_at`), SQS queue (webhook-queue), Consumer Lambda (SQS event source mapping — logs event to CloudWatch), Secrets Manager secret (`webhook-signing-secret`, value: placeholder "REPLACE_BEFORE_RUNNING"), IAM roles (Validator: SecretsManager:GetSecretValue + DynamoDB:PutItem + SQS:SendMessage; Consumer: SQS:ReceiveMessage + SQS:DeleteMessage). Use `var.environment`.

- [ ] **Step 4: Write `aws_system_integrations/labs/day05/variables.tf`**

  Variables: `aws_region`, `environment`.

- [ ] **Step 5: Write `aws_system_integrations/labs/day05/terraform.tfvars.example`**

  Same pattern + note: "After `terraform apply`, update the Secrets Manager secret value via AWS Console or CLI before testing. Never commit the real signing secret."

- [ ] **Step 6: Write `aws_system_integrations/labs/day05/SOLUTION.md`**

  Sections: HMAC-SHA256 validation walkthrough (Python `hmac.compare_digest` — why `==` is wrong: timing attack), DynamoDB conditional write mechanics (`attribute_not_exists(event_id)` raises `ConditionalCheckFailedException` on duplicate — catch this, return 200 without processing), TTL calculation (`int(time.time()) + 86400`), SQS exactly-once delivery note (SQS is at-least-once; idempotency in the validator ensures the consumer sees each logical event once even if SQS delivers twice), Break it answer (3 requests: first succeeds DynamoDB write + SQS send + Consumer invocation; second and third hit `ConditionalCheckFailedException`, return 200, no SQS send → Consumer invoked exactly once). Synthesis design model answer walkthrough (the Day 5 exercise 3 full solution with pattern names annotated on an ASCII architecture diagram).

- [ ] **Step 7: Write `aws_system_integrations/labs/day05/teardown.md`**

  Checklist: `terraform destroy`, verify API GW deleted, Lambda functions deleted, DynamoDB table deleted, SQS queue deleted, Secrets Manager secret deleted (`aws secretsmanager delete-secret --secret-id <name> --force-delete-without-recovery`), CloudWatch log groups deleted. Estimated cost if left running: API GW ($0.00 at lab volume), DynamoDB ($0.00 on-demand at lab volume), SQS ($0.00 at lab volume), Secrets Manager ~$0.40/month per secret.

- [ ] **Step 8: Verify all 7 files exist; confirm all exercises have Hint + Solution sketch, Break it in README, Break it answer in SOLUTION, synthesis exercise is complete with worked answer**

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| API Gateway patterns (BFF, ACL, composition) | Task 3 (day01.md) |
| Ingress: L4/L7, weighted, header-based, mTLS, WAF, CDN | Task 4 (day02.md) |
| Egress: NAT, Gateway Endpoint, Interface Endpoint, PrivateLink, Peering, TGW, split-horizon DNS | Task 5 (day03.md) |
| Service-to-service sync + compressed async | Task 6 (day04.md) |
| External integration + synthesis | Task 7 (day05.md) |
| GLOSSARY.md with all pattern terms | Task 2 |
| README.md + STRATEGY.md | Task 1 |
| All labs: README + SOLUTION + teardown | Tasks 3–7 |
| All exercises: hints + solution sketches | Tasks 3–7 |
| No credentials in any file | Enforced in all Terraform tasks (variables + tfvars.example) |
| Enterprise scenarios: banking, payment, microservices | All days 1–5 |

No gaps found.

**Placeholder scan:** No TBDs, TODOs, or "implement later" entries. All exercises have explicit Hint + Solution sketch. All Break it exercises have explicit answers in SOLUTION.md. All Terraform files specify exact resource types and variable references.

**Type consistency:** No cross-task type or name dependencies — each task produces standalone files. No naming conflicts across tasks.
