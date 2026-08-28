# Day 1 — API Gateway Patterns

## Why this matters

Mobile banking apps must talk to multiple backend services (payment, account, notification) without each client knowing the full service topology. A mobile client that calls the account service, then the transaction service, then the notification service in sequence is fragile: it couples the client to service addresses, protocols, and response shapes; any backend refactor forces a mobile app update.

Without a BFF, every client change requires coordination across multiple teams. An API Gateway layer — and specifically a Backend-for-Frontend on top of it — absorbs that complexity at one boundary so backend services can evolve independently.

This day covers the five ingress patterns you will use in every enterprise AWS integration: reverse proxy, API Gateway, BFF, API Composition/Aggregation, and Anti-Corruption Layer (ACL). By the end you should be able to pick the right pattern in under two minutes given a scenario.

---

## The boundary this manages

**API gateway boundary** — the contract layer between external clients (mobile apps, SPAs, third-party partners) and backend services. This is the first security control point, the place where protocol normalisation happens, and the place where client-specific aggregation lives. Distinct from the ingress boundary (which controls *admission* — who enters, at what rate, L4 vs L7 routing): the API gateway boundary controls *interface* — what shape the request takes and what cross-cutting policies apply before services see it.

Everything inside this boundary (service-to-service calls, event buses, databases) is a different domain. Day 1 concerns only what touches external clients.

---

## Core patterns

### Reverse Proxy

**Problem:** Clients need a single entry point so that backend service locations are not exposed, TLS is terminated at one place, and static content can be cached.

**How it works:** The reverse proxy sits in front of backend services. It accepts a client request, rewrites or forwards it to a backend, receives the backend response, and returns it to the client. No aggregation, no transformation — pure forwarding with optional header manipulation and TLS offload.

**AWS implementation:**
- **Application Load Balancer (ALB):** Path-based and host-based routing to EC2, ECS, or Lambda targets. Handles TLS termination. Correct choice when backends are long-lived services (not serverless) and traffic is HTTP/1.1 or HTTP/2.
- **CloudFront + ALB/origin:** Adds CDN edge caching, geo-routing, and DDoS protection (Shield Standard) in front of an ALB origin. Use when static asset delivery matters or when you need global PoPs.
- **nginx on EC2/ECS:** Still common for legacy workloads; gives full configuration flexibility but you own the patching and scaling.

**When it's wrong:**
- When you need per-request auth decisions, rate limiting, or transformation — a reverse proxy has no concept of these; you are bolting logic onto a forwarding tool.
- When aggregating multiple backends — a reverse proxy returns one upstream response, not a merge of N.

---

### API Gateway (Generalized)

**Problem:** Cross-cutting concerns — authentication, rate limiting, request/response transformation, logging, CORS — must be applied consistently to every API call without duplicating logic in each backend service.

**How it works:** An API Gateway is a managed ingress layer that intercepts every request, applies a configurable pipeline (auth → validate → transform → route → log), and forwards to the correct backend. Cross-cutting concerns live in the pipeline, not in services.

**AWS implementation — REST API vs HTTP API vs WebSocket:**

| Criterion | HTTP API (v2) | REST API (v1) | When to use |
|---|---|---|---|
| **Cost** | ~$1/million requests | ~$3.50/million requests | HTTP API saves ~70% for most workloads |
| **Latency** | Lower (~6ms overhead) | Higher (~10ms overhead) | HTTP API for latency-sensitive paths |
| **Lambda authorizer** | Yes (simple/request) | Yes (token/request) | Both support; REST has more config options |
| **Usage plans / API keys** | Not supported | Supported | REST API when you must enforce per-client quotas |
| **Request validation** | Body + params via JSON Schema | Full model validation | REST API for strict contract enforcement |
| **VTL mapping templates** | Not supported | Supported | REST API for response transformation without Lambda |
| **WebSocket** | Not included | Not included | Separate WebSocket API product |
| **mTLS** | Supported | Supported | Either |
| **Resource policies** | Limited | Full | REST API for IP allowlisting/denylisting |

**Decision:** Use HTTP API unless you specifically need usage plans, request model validation, VTL mapping, or advanced resource policies. The 70% cost difference is real.

**When it's wrong:**
- When you need persistent connections (WebSockets, streaming) — use the WebSocket API or a dedicated service.
- When you need sub-millisecond latency for intra-service calls — put that behind an ALB or service mesh, not a public API GW.

---

### Backend-for-Frontend (BFF)

**Problem:** Mobile and web clients have different payload needs. A mobile banking app needs account summary + recent transactions + payment status in a single call to conserve battery and radio time. A web app might want the same data in separate calls with richer metadata. Forcing both clients to use the same "generic" API means mobile fetches too much or makes too many round trips.

**How it works:** A BFF is a thin aggregation layer created specifically for one client type. It knows the shape the client needs, fans out to multiple backend services, and merges the results before returning a single response. It contains no business logic — that belongs in the services. It is the translator between client-specific needs and service-specific contracts.

**AWS implementation:**
- **API GW + Lambda aggregator:** Lambda calls multiple backend services (or other Lambdas) in parallel, merges responses, and returns a single JSON payload. This is the standard pattern. Use `asyncio` (Python) or `Promise.all` (Node.js) for the fan-out; never call services sequentially.
- **API GW + VTL mapping template:** For simple response reshaping when no fan-out is needed. VTL is a templating language built into API GW REST API integration responses. It can rename fields, filter arrays, and restructure objects — but cannot make outbound calls.
- **AppSync (GraphQL BFF):** When the "shape" problem is severe — multiple clients each wanting different subsets of the same data graph. GraphQL resolvers replace Lambda aggregators.

**When it's wrong:**
- When the "BFF" starts accumulating business logic — validation rules, pricing calculations, eligibility checks. At that point it is a service, not a frontend adapter.
- When you create a single BFF for all client types — that defeats the purpose; it becomes a generic API again.
- When the aggregated backends all live behind the same service and the fan-out is just N SQL queries — push the aggregation into the service, not the BFF.

---

### API Composition / Aggregation

**Problem:** A client call requires data from N independent services, and you want the call to complete in the time of the slowest necessary service (not the sum of all services). This is the fan-out / fan-in problem.

**How it works:** An orchestrator component fires N upstream calls concurrently, collects all responses within a deadline, and composes the final response. Optional: partial responses — if one upstream fails, return what is available and mark the missing section with an error envelope.

**AWS implementation:**
- **Lambda orchestrator:** For 2–5 upstreams with simple merge logic. Use `concurrent.futures.ThreadPoolExecutor` (Python) or `Promise.all` (Node.js). Each upstream has its own timeout and error handler. Merge happens in memory.
- **Step Functions Express Workflow:** For complex fan-in where error handling, retries, partial results, and state between steps matter. Express Workflows (not Standard) are appropriate for synchronous composition because they support sync execution and have sub-second billing granularity. Use when you have >5 upstreams, conditional aggregation, or compensation logic.

**When it's wrong:**
- When the composition logic becomes a stateful multi-step process with waits — use Step Functions, not a Lambda.
- When the data being composed is large (>6MB Lambda payload limit) — stream it or split the aggregation.
- When all upstreams are in the same database — do it in a SQL JOIN, not a distributed fan-out.

---

### Anti-Corruption Layer (ACL)

**Problem:** A downstream service speaks a different protocol or schema than the upstream expects. Classic case in banking: a legacy core banking system exposes SOAP/XML; the new mobile gateway needs REST/JSON. The ACL prevents the legacy contract from leaking into the new system.

**How it works:** The ACL sits between two bounded contexts. It translates protocol (SOAP → REST), transforms schema (XML → JSON, field renames, unit conversions), maps error codes (SOAP fault → HTTP 4xx/5xx), and isolates the new system from the legacy contract.

**AWS implementation:**
- **API GW + Lambda transformer:** Lambda receives the REST/JSON request, constructs a SOAP XML envelope, calls the legacy service via HTTPS, parses the SOAP response, and returns REST/JSON. This is the most common pattern because it handles arbitrary transformations and can map errors precisely.
- **API GW VTL mapping:** Can do simple XML-to-JSON transformation inline (no Lambda), but VTL is limited to what API GW's template engine supports. Does not handle custom error mapping or multi-step transformation.
- **AWS App Mesh / EventBridge with Schema Registry:** For ACL in event-driven pipelines where schema evolution across producers and consumers must be managed centrally.

**When it's wrong:**
- When the ACL caches transformed responses without propagating `Cache-Control` from the upstream — stale transformed data silently serves clients.
- When the ACL absorbs business logic ("if account_type == PREMIUM, add field X") — that belongs in the domain service.
- When the "legacy" system is actually a well-designed REST API with a slightly different naming convention — a simple field-rename in a BFF is cheaper than a full ACL.

---

## Decision tree

**Step 1: What does the client need?**

```
One upstream, no transformation needed
  → Reverse Proxy (ALB / CloudFront)

One upstream, transformation / auth / rate-limit needed
  → API Gateway (choose REST vs HTTP below)

Multiple upstreams, client-specific shape
  → BFF (API GW + Lambda aggregator)

Multiple upstreams, generic aggregation
  → API Composition (Lambda orchestrator or Step Functions)

Legacy protocol translation
  → ACL (API GW + Lambda transformer)
```

**Step 2: REST API GW vs HTTP API GW vs ALB**

```
Need usage plans / per-client quotas?          → REST API GW
Need VTL mapping templates?                    → REST API GW
Need request model validation (JSON Schema)?   → REST API GW
Need WebSockets?                               → WebSocket API GW (separate product)
Need lowest cost + sufficient features?        → HTTP API GW
Traffic to long-lived EC2/ECS (not Lambda)?    → ALB
Need edge caching / global PoPs?               → CloudFront + ALB/Lambda
```

---

## Exercises

### Exercise 1 — BFF design

A mobile banking app needs to call the account service (returns balance) and the transaction service (returns last 10 transactions) in a single API call. Which pattern applies? Draw the request/response flow.

**Hint:** Think about what the mobile client needs (one merged response) versus what each backend service returns (separate payloads). Neither service should change to accommodate the mobile client.

**Solution sketch:**
BFF pattern. Flow:

```
Mobile Client
    │  GET /summary  (Bearer token)
    ▼
API Gateway (HTTP API)
    │  JWT authorizer validates token
    ▼
BFF Lambda (aggregator)
    ├──▶ account-service Lambda   →  { "balance": 12450.00 }
    └──▶ transaction-service Lambda → { "transactions": [...] }
    ▼  (fan-out: both calls in parallel via ThreadPoolExecutor)
    ▼  (fan-in: merge both responses)
    ◀── { "balance": 12450.00, "transactions": [...] }
    ▼
API Gateway
    ◀── Mobile Client receives merged JSON
```

The BFF Lambda handles fan-out concurrently (not sequentially). Each call has its own timeout. The mobile client makes exactly one HTTP call.

---

### Exercise 2 — ACL failure modes

Your core banking system exposes a SOAP/XML API. Your new mobile gateway must expose REST/JSON. Which pattern applies? What are the top failure modes?

**Hint:** The client and the backend speak different languages — protocol, data format, and error conventions all differ. What sits between two systems that speak different languages?

**Solution sketch:**
ACL pattern: API GW (HTTP API) + Lambda transformer.

Failure modes to document in a production ACL:

1. **Schema mismatch silently returns null fields:** The SOAP response adds a new optional field the Lambda transformer does not map; the JSON response omits it silently. Clients expecting the field receive `null` with no error. Fix: strict mapping with unknown-field alerts.
2. **SOAP fault not mapped to HTTP 4xx/5xx:** The SOAP service returns `<faultcode>Client</faultcode>` but the Lambda returns HTTP 200 with the fault XML serialised as JSON. Fix: explicit fault-to-status-code mapping table in the transformer.
3. **Latency spike from XML parsing:** Large SOAP envelopes (account statements with 500 transactions) cause Lambda cold-start + XML parse time to spike. Fix: paginate at the SOAP call level; do not fetch full history in one call.
4. **Encoding mismatch:** Legacy SOAP uses ISO-8859-1; Lambda default encoding is UTF-8. Special characters in account holder names corrupt silently. Fix: explicit charset decode/encode in the transformer.

---

### Exercise 3 — Timeout coupling

You have an API Gateway in front of 5 microservices. A single slow microservice is causing all requests to time out, even requests that do not need that microservice. What pattern is missing, and how do you add it?

**Hint:** The problem is coupling via a shared wait time. One slow service should affect only requests that need it, not requests that do not.

**Solution sketch:**
Two missing patterns working together:

1. **Bulkhead:** Isolate resources per upstream so one slow service cannot exhaust the shared thread pool. In a Lambda BFF: use separate `ThreadPoolExecutor` pools per service, or fire each as a separate Lambda invocation so one slow backend does not block others.
2. **Per-upstream timeout:** Each backend call has its own deadline independent of the API GW integration timeout. API GW HTTP API integration timeout max is 29 seconds. The BFF Lambda must enforce a shorter per-service timeout (e.g., 3s for account, 5s for transactions). If a service times out, return a partial response with an error envelope for that section rather than failing the entire request.
3. **Circuit breaker (optional but production-grade):** After N consecutive timeouts from one service, the BFF stops calling it and returns the cached last-good value or a graceful degradation. Lambda has no built-in circuit breaker; use a simple in-memory state variable (resets on cold start) or DynamoDB-backed state for multi-instance breakers.

---

## Anti-patterns / Common mistakes

**1. Using REST API GW when HTTP API GW suffices**
The default tutorials use REST API GW. For most workloads (Lambda backends, JWT auth, CORS, simple routes) HTTP API GW is 70% cheaper and has lower latency. The cost difference compounds at scale. Audit every API GW before deploying: do you actually need usage plans, VTL templates, or request model validation? If not, switch to HTTP API.

**2. BFF that becomes a "god aggregator"**
A BFF that starts with "call two services and merge" can grow to "call six services, apply eligibility rules, calculate fees, and format for mobile". Once business logic enters the BFF it becomes a service — deploy it, test it, and own it as one. The warning sign: BFF code imports business constants or applies pricing logic.

**3. ACL that caches stale transformed responses**
Transformation layers are tempting caching points (expensive XML parse → cache the JSON result). The bug: the upstream `Cache-Control: no-store` or `max-age=0` header is ignored because the ACL does not proxy it. Accounts with balance changes show stale data for minutes. Fix: always proxy `Cache-Control`, `ETag`, and `Vary` headers from upstream through the ACL to the client.

---

## Lab

See `labs/day01/`. You will wire a BFF using API Gateway HTTP API + Lambda aggregating two mock services, with a JWT Lambda authorizer and a usage plan (rate limiting via stage-level throttle).

**Success signal:**
- A single `curl` call to `/summary` with a valid Bearer token returns `{"balance": ..., "transactions": [...]}`
- The same call without a Bearer token returns HTTP 401
- Rapid repeated calls beyond the throttle rate return HTTP 429

Full instructions, architecture diagram, and the "Break it" exercise are in `labs/day01/README.md`.

---

## Teardown

After every lab session, destroy all created resources to avoid ongoing charges.

```bash
cd labs/day01/
terraform destroy -auto-approve
```

See `labs/day01/teardown.md` for the full manual verification checklist.
