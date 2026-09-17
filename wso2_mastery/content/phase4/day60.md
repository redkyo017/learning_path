# Day 60 — Capstone: Reflection and Next Steps

## Why This Matters

Reflection closes the learning loop. You need to know what you can now do that you couldn't 60 days ago, and where the gaps are. This is not a test; it is a self-assessment for the next phase of your learning.

## Success Criteria Check

When you started this path, the spec said you would be able to do these 7 things by Day 60. Check each one:

### ✅ 1. Explain the full OAuth2/OIDC token lifecycle through WSO2 IS

- Understand the **grant types:** client_credentials (app-to-app), authorization_code (user login with redirect), refresh_token (extend session)
- Trace the **JWT assembly:** IS generates a JWT with claims (sub, aud, exp, iat, scope, custom claims)
- Understand **introspection:** GW can ask IS "is this token still valid?" for opaque tokens
- Understand **revocation:** A client can revoke their own token; IS removes it from the store
- Point to the source: **Phase 1 Days 4–12**; specifically `labs/phase1/day04/main.go` (token issuance), `labs/phase1/day07/main.go` (introspection), `labs/phase1/day10/main.go` (key manager REST)

**Self-check:** Can you draw the sequence of a client calling `/oauth2/token` with `grant_type=client_credentials` and getting back a JWT? Can you explain what claims are in it and why?

---

### ✅ 2. Trace an API call from client → GW → TM → backend

- The call starts at the ALB (port 443)
- ALB routes to GW (port 8243)
- GW validates JWT signature (from cached JWKS from IS)
- GW validates subscription (from CP cache; optional call to `/subscriptions/validate`)
- GW validates throttle (calls TM synchronously or asynchronously)
- GW proxies to backend
- Backend responds; GW proxies response back to client
- Identify **where each failure mode manifests:** JWT validation failure → 401 at GW; subscription failure → 403 at GW; throttle exceeded → 429 at GW; backend timeout → 504 at GW

**Self-check:** Can you list all the log lines you would see for a single successful request? Can you explain what happens if each of these breaks: (a) JWT invalid, (b) subscription missing, (c) TM down, (d) backend down?

---

### ✅ 3. Explain how CP syncs API/subscription/throttle data to GW

- **On GW startup:** GW calls `GET /admin/sync` on CP → receives all APIs + subscriptions in one response
- **At runtime:** CP maintains an event bus (JMS in real WSO2; in-memory in the lab)
- **For each update:** CP fires an event (API_PUBLISHED, SUBSCRIPTION_REMOVED, POLICY_CHANGED, etc.)
- **SSE delivery:** GW holds an open SSE connection to `GET /events`; receives events in real-time
- **Eventual consistency model:** SSE delivery is nearly instant, but not guaranteed. There is always a small window where GW serves stale data.
- **Fallback:** Every 5–60 seconds, GW can call `/admin/sync` again (periodic pull) as a safety net
- **What breaks:** If CP event bus crashes, all GWs lose real-time sync. If SSE connection drops, GW continues with stale cache until it reconnects. If CP is unreachable, GW cannot start (no `/admin/sync`).

**Self-check:** Can you explain what happens if (a) CP event bus crashes, (b) an SSE connection drops, (c) a GW restarts? How do they recover?

---

### ✅ 4. Write a Go Key Manager adapter

- A Key Manager is a service that IS can query to validate keys and sign tokens
- The Go port from Phase 1 Days 10–12 implements the Key Manager REST interface
- Endpoints: `POST /keymanager/validate` (is this key authorized?), `GET /keymanager/sign` (sign this with the key)
- Real-world use case: You want to validate tokens signed by an external OIDC provider; write a Key Manager adapter that queries that provider's JWKS

**Self-check:** Can you open `labs/phase1/day10/main.go`, read it, and explain what each endpoint does?

---

### ✅ 5. Write a Go reverse proxy with JWT + subscription + throttle enforcement

- This is the entire Phase 2; the Go port of the Universal Gateway
- Receive a request with a JWT
- Validate the JWT signature
- Look up the subscription for this client
- Check the throttle limit
- Proxy the request to the backend
- Return the response

**Self-check:** Can you write a simple Go HTTP handler that does these steps? Can you explain why JWT validation must happen before subscription check?

---

### ✅ 6. Design and justify a distributed ECS Fargate deployment

- Understand the topology: ALB → GW (auto 1–4) → IS (fixed 1) + CP (fixed 1) + TM (auto 1–2)
- GW is stateless; can scale horizontally. Warm up cache via `/admin/sync` on startup.
- IS and CP are stateful; single replica. For HA, add external storage (Redis for session store, RDS for registry).
- TM is semi-stateful; throttle counters can be reset per window; more resilient to restarts.
- Scaling triggers: GW at 70% CPU or 80% connections; scale out +1, scale in -1 after 10 minutes idle.
- Health checks: ALB targets GW at port 8280 (internal health endpoint); ECS monitors task CPU/memory.
- Log aggregation: All four services log to CloudWatch log groups `/ecs/{env}/wso2-{service}`; activity ID correlates logs across services.

**Self-check:** Given a traffic profile (e.g., "1000 req/s, 95th percentile latency <100ms"), can you design a scaling strategy? Can you justify why IS cannot be scaled horizontally without external state?

---

### ✅ 7. Read log4j2 output from WSO2 and map to failure class

- Failure classes (7): AUTH_FAILED, SUBSCRIPTION_NOT_FOUND, THROTTLE_EXCEEDED, BACKEND_TIMEOUT, JWT_EXPIRED, JWT_INVALID_SIGNATURE, EVENT_SYNC_LAG
- Each failure class has characteristic log messages (error codes, key phrases)
- Example: A log line with "ERROR.*900901" likely maps to AUTH_FAILED
- The Go tool from Phase 4 Day 53 (`labs/phase4/day53/main.go`) automates this classification

**Self-check:** Can you read a random ERROR log line and guess the failure class? Can you run the Day 53 tool on a log file and verify the classification?

---

## Go Lab Index (All 9 Runnable Labs)

These are the key hands-on labs. Each one is runnable and has a detailed README + solution:

| Phase | Days | Port/CLI | Lab | What it does | Key Insight |
|---|---|---|---|---|---|
| Phase 1 | 4–6 | :8080 | `labs/phase1/day04/main.go` | Token endpoint (client_credentials + auth_code grants) | OAuth2 flow; JWT assembly; claim injection |
| Phase 1 | 7–9 | :8081 | `labs/phase1/day07/main.go` | Token introspection + revocation | Opaque token validation; session store |
| Phase 1 | 10–12 | :8082 | `labs/phase1/day10/main.go` | Key Manager REST adapter (validate + sign) | Third-party key integration |
| Phase 2 | 19–21 | :8083 | `labs/phase2/day19/main.go` | JWT validator + subscription enforcer | Gateway request filtering |
| Phase 3 | 31–33 | :8084 | `labs/phase3/day33/main.go` | API registry (CRUD endpoints) | API metadata storage |
| Phase 3 | 37–39 | :8085 | `labs/phase3/day39/main.go` | Unified CP: registry + subscription store + event bus + SSE | Full control plane in one file |
| Phase 4 | 47–48 | CLI | `labs/phase4/day48/main.go` | Log correlation parser (stdin → activity ID traces) | Tracing distributed calls |
| Phase 4 | 50 | :8090 | `labs/phase4/day50/main.go` | APIHandler extension blueprint | Extending the gateway |
| Phase 4 | 51 | :8091 | `labs/phase4/day51/main.go` | OAuthGrantHandler extension blueprint | Custom OAuth2 grant implementation |

**Also useful (non-runnable, source-reading):**
- Phase 4 Day 52: Failure Mode Catalog (reference, not code)
- Phase 4 Day 53: `labs/phase4/day53/` — Go log failure classifier
- Phase 4 Day 54: `labs/phase4/day54/` — bash triage script (`debug.sh`)
- Phase 4 Day 55: ADR templates for architectural decisions
- Phase 4 Day 56: Terraform ECS autoscaling configuration

---

## What You Learned

### Concepts

- **Authentication & Authorization:** OAuth2 flows, JWT structure, token introspection, subscription policies, throttle limits
- **Architecture:** Stateless vs. stateful services, distributed caching, event-driven sync, eventual consistency
- **Observability:** Activity ID correlation, log classification, failure mode identification, incident response
- **Cloud infrastructure:** ECS Fargate, ALB, security groups, auto-scaling, CloudWatch logs
- **Implementation:** Go HTTP handlers, caching, event buses, CLI tools, testing

### Skills

- Read WSO2 source code (Java, OSGi) and understand the design patterns
- Write Go implementations of WSO2 components (IS, GW, CP, TM)
- Debug a distributed system using logs, traces, and health endpoints
- Design a production deployment on AWS (topology, scaling, monitoring)
- Write incident response runbooks and triage procedures

---

## Exercises: Reflect and Verify

### Exercise 1: From Memory, List the 4 WSO2 Components and Their Port Numbers

**Scenario:** You're in a job interview. The interviewer asks: "Tell me the WSO2 API gateway architecture." You have 2 minutes and no notes.

**Task:** Without looking at today's notes or previous days, write down the 4 main components and their port numbers.

**Hint:** Think about what each component does: token validation, API management, gateway, throttling.

**Solution Sketch:**

- **IS (Identity Server):** 9443 (HTTPS), 9763 (HTTP) — Token issuance, introspection, revocation, JWKS
- **CP (Control Plane):** 9443 (HTTPS) — API registry, subscription management, event bus
- **GW (Universal Gateway):** 8243 (HTTPS), 8280 (HTTP) — JWT validation, subscription enforcement, proxy
- **TM (Traffic Manager):** 9443 (HTTPS), 9611 (binary), 9711 (SSL) — Throttle checking, event reporting

**Why these matter:** If you can't remember this in a conversation, the architecture is not yet in your long-term memory. Practice until you can recite it without thinking.

---

### Exercise 2: From Memory, Name the 7 Failure Classes

**Scenario:** During an incident, your teammate says "The logs show ERROR 900901." You should immediately know what that is.

**Task:** List all 7 failure classes (from Day 52) and their HTTP codes.

**Hint:** Think about what can go wrong: authentication, authorization, throttling, backend, tokens.

**Solution Sketch:**

1. **AUTH_FAILED** (900901) — JWT invalid, expired, or missing
2. **SUBSCRIPTION_NOT_FOUND** (900908) — Client not subscribed to this API
3. **THROTTLE_EXCEEDED** (900800) — Over the rate limit
4. **BACKEND_TIMEOUT** (504) — Backend not responding
5. **JWT_EXPIRED** (401) — Token TTL exceeded
6. **JWT_INVALID_SIGNATURE** (401) — Signature doesn't match public key
7. **EVENT_SYNC_LAG** (403 stale) — Subscription was deleted but event not delivered yet

---

### Exercise 3: A New Engineer Joins; How Do You Onboard Them?

**Scenario:** A new engineer starts Monday. They need to understand the event sync architecture (how CP keeps GW's cache in sync with reality). You have 10 minutes to point them to a resource.

**Task:** Which single file or document do you point them to? Why?

**Hint:** Is it a day's markdown notes? A Go source file? A diagram? What is the most readable and self-contained?

**Solution Sketch:**

**Answer:** `labs/phase3/day39/main.go`

**Why:**
- It's a single file (~300 lines)
- All four components are in one place: API registry, subscription store, event bus, SSE
- It includes both the event publisher (CP) and the consumer (SSE client simulator)
- The code is readable and has comments
- They can run it and watch events flow in real-time: `go run labs/phase3/day39/main.go`
- It's more concrete than a markdown description

**Second choice:** Day 37 markdown (Event-Driven Sync: Concepts) + Day 39 diagram in README

---

## Anti-Patterns (Final 3)

### 1. ❌ Treating the Go ports as production replacements

- The Go implementations you built are **learning tools**
- They lack: TLS certificate management, persistence (journaling), clustering (replicas), OSGi lifecycle, bundle hot-reload, web console
- In production, you run the real WSO2 (Java + OSGi + H2 database + lot of ops tooling)
- The Go ports teach you the architecture and decision-making, not the production implementation

### 2. ❌ Stopping at "it works in Docker Compose"

- Your Docker Compose file has 4 containers on `localhost`
- They share a network; all can reach each other on ports 8243, 9443, etc.
- **In ECS Fargate, the topology is completely different:**
  - Services run in separate tasks (separate IP addresses)
  - Service discovery via CloudMap (DNS names like `wso2-gw.service.consul`)
  - No shared volumes; no `localhost`
  - Security groups enforce network isolation
  - Monitoring and logging go to CloudWatch, not local files
- Test your setup on AWS: use the Day 56 Terraform to deploy and watch it scale

### 3. ❌ Not writing a "why" comment for each day

- After each day, add a comment to the top of that day's lab or notes explaining **why** you built this
- Example: "Day 39: Understanding event sync is critical because cache lag is the root cause of most race conditions in distributed gateways"
- These comments become your reference architecture document
- When you onboard a new engineer in 2 years, you have instant context

---

## Next Steps (Immediate)

### 1. Run the Phase 3 Docker Compose smoke test end-to-end

```bash
cd wso2_mastery/labs/phase3/day43
docker-compose up --detach
sleep 10

# Test the full flow
TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -d 'grant_type=client_credentials&client_id=demo&client_secret=secret' \
  | jq -r .access_token)

curl -s -H "Authorization: Bearer $TOKEN" \
  http://localhost:8243/petstore/v1/pets | jq .
```

This verifies that all 4 services can actually run together.

### 2. Deploy the Day 56 Terraform in your AWS dev account

```bash
cd wso2_mastery/labs/phase4/day56
terraform init
terraform plan
terraform apply  # (only if you have AWS credentials)
```

This is your first real ECS Fargate deployment. Watch autoscaling fire when you load-test it.

### 3. Run the Day 48 log parser against real CloudWatch logs

```bash
# Download logs from your GW in AWS
aws logs get-log-events \
  --log-group-name /ecs/dev/wso2-gw \
  --log-stream-name <stream-name> \
  --query 'events[].message' --output text > /tmp/gw.log

# Parse them
go run wso2_mastery/labs/phase4/day48/main.go < /tmp/gw.log
```

This teaches you how to debug real incidents.

### 4. Add Redis-backed session store to IS

The lab implementation of IS uses an in-memory map for the token store. In production, you need:
- Shared session store across multiple IS replicas
- Persistence (tokens survive IS restart)
- Clustering support

**Spec (ADR-001):**
- Replace the in-memory `map[string]*Token` with a Redis connection
- `GET wso2:token:{token_id}` to retrieve; `SET ... EX {ttl}` to store
- Backward-compatible API; no changes to the HTTP endpoints

This is a good capstone exercise: apply what you learned to extend the system.

### 5. Write your first real WSO2 incident post-mortem

Use the Day 59 runbook as a template. When something breaks in production, capture:
- **Timeline:** 14:05 alert fires, 14:07 GW health check fails, 14:12 is restarted, 14:15 recovered
- **Root cause:** IS keystore rotation was in progress; GW cache was stale
- **What we did:** Restarted GW to force `/admin/sync`
- **What we should have done:** Pre-warm GW JWKS cache before keystore rotation
- **Action items:** (1) Document keystore rotation SOP, (2) Add JWKS pre-load test to CI/CD

---

## Long-Term Learning Path (Beyond Day 60)

If you want to go deeper, consider these areas:

1. **Advanced Authorization:** OAuth2 Proof Key for Public Clients (PKCE), mTLS, device flow
2. **Rate Limiting Algorithms:** Token bucket, sliding window, distributed rate limiting
3. **Service Mesh:** Deploy Istio alongside WSO2 for observability and traffic management
4. **Multi-Region:** Replicate your setup across AWS regions; handle cross-region latency
5. **Real WSO2 Administration:** Set up the web console, configure plugins, deploy custom mediators
6. **Analytics & Monetization:** Use the WSO2 Analytics engine to understand API usage; implement usage-based billing
7. **Zero-Trust Security:** Move the gate inside the network; require client certificates, service-to-service mTLS
8. **Performance Tuning:** Benchmark each service; profile hotspots; optimize JVM settings

---

## Final Reflection

**What you started with:** A blank page and a question: "How does an API gateway work?"

**What you've built:** A complete distributed system that validates tokens, enforces policies, throttles traffic, and logs everything.

**What you understand now:** The why behind every decision — why CP is separate from GW, why event sync is eventually consistent, why the runbook matters, why observability is not optional.

**The next phase:** From learning the architecture to operating it. From "I built it" to "I shipped it and kept it running under load."

---

## Success Criteria: Full Checklist

Before you close this day, verify:

- [ ] I can explain the 4-layer architecture (Client/ALB → GW → IS/CP/TM → Backend)
- [ ] I can trace a request from client to backend and back, naming the decision point at each layer
- [ ] I can list the 7 failure classes and recognize them in log output
- [ ] I can read `labs/phase3/day39/main.go` and explain how event sync works
- [ ] I can write a triage checklist for a production incident
- [ ] I can design an ECS Fargate topology for WSO2 and justify the scaling strategy
- [ ] I can point a new engineer to the resources they need to onboard

If all are true, you have successfully completed the 60-day WSO2 mastery path.

---

## Gratitude & Attribution

This path was designed to teach you the why behind WSO2 APIM, not just the what. By rebuilding the core services in Go, you learned the architecture at the deepest level. The real WSO2 team has solved problems at scale that these labs only hint at. Use this knowledge with humility and curiosity.

**What to do now:** Close this file. Take a 5-minute break. Then run the Phase 3 smoke test. Watching all four services talk to each other in real-time is the best way to celebrate 60 days of work.

See you on the other side. ✨
