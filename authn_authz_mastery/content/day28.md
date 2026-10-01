# Day 28 — End-to-End Delegation Chain

## Why this matters

A payment operation is flagged for fraud review. The compliance officer needs to reconstruct: "User X clicked Pay → which AI agent chain processed this → which tool made the API call → what token authorized it → was it validly delegated?" Without designing the audit chain deliberately, teams discover after an incident that no single system has the complete picture. IS 7.3 audit logs the token exchange but doesn't record the API call. AgentCore logs the API call but doesn't know which user initiated it. The payment API logs the transaction but loses the link when the token expires. A well-designed end-to-end chain uses a single correlation ID (`jti`) to thread all systems together — from the user's initial action through the agent's intermediate steps to the final API call.

## Core concepts

### 1. The complete banking AI agent chain (6 hops)

A payment operation flows through six distinct steps:

1. **User authenticates to IS 7.3** → App-Native Auth (Day 11) → receives `human_token` (1h, `sub=user`, `scope=payments:read payments:write accounts:read`)

2. **User intent sent to orchestrator** → Orchestrator calls IS 7.3 token exchange (RFC 8693, Day 23) → receives `orchestrator_token` (15min, `sub=user`, `act.sub=orchestrator_id`, `scope=payments:initiate`)

3. **Orchestrator decomposes task, calls tool agent** → Tool exchanges orchestrator token → receives `tool_token` (5min, `sub=user`, `act.sub=tool_id`, `act.act.sub=orchestrator_id`, `scope=payments:initiate`)

4. **Tool calls payment API via AgentCore** (Day 24) → Tool sends HTTP request to AgentCore proxy → AgentCore validates SigV4 signature (AWS Signature Version 4) → adds `X-AgentCore-Caller-Identity` header (contains session tags: agentId, userId, sessionId) → forwards to payment API

5. **Payment API receives token + AgentCore header** → Calls IS 7.3 `/oauth2/introspect` with the `tool_token` → IS 7.3 validates and returns: `active=true`, `sub=user`, full `act` chain, `scope`, `jti`, `iat`

6. **Payment API records: user + agent chain + trace ID** → Transaction log entry: `sub=user`, `act_chain=[tool_id, orchestrator_id]`, `jti=trace_id`, `agentcore_session_id=sessionId` (from AgentCore header)

### 2. Token lifetimes at each hop (decreasing window)

Each hop's token should expire before the parent token could become stale or be re-exchanged:

- **Human token**: 1h (user's session duration; user typically active for 30min–2h)
- **Orchestrator exchange token**: 15min (short-lived delegation; typically processes a single user request in 1–5min; if stolen, usable for 15min)
- **Tool token**: 5min (per-operation; a single tool call completes in seconds; minimal blast radius for replay)

**Why this hierarchy?** If orchestrator is compromised at T=10min and the token is stolen:
- Attacker can use it until T=25min (15min window)
- But tool tokens expire every 5min, so if the stolen orchestrator token is re-exchanged at T=11min, the tool token expires at T=16min
- Introspection-based revocation (see next section) can detect the compromise within 5min if the operator acts quickly

### 3. Revocation propagation (introspection-based, not local JWT)

**Scenario:** User revokes their session at T=60min. Three derived tokens exist:
- `tool_token` issued at T=45min, expires at T=50min (already expired — not an issue)
- `orchestrator_token` issued at T=30min, expires at T=45min (already expired — not an issue)
- But another `orchestrator_token` was issued at T=50min, expires at T=65min (still valid, but parent token is revoked)

**Propagation mechanism:**
1. User revokes session via IS 7.3 UI → IS 7.3 marks the `human_token` as revoked
2. Payment API next calls `POST /oauth2/introspect` with a token from the `orchestrator_token` chain
3. IS 7.3 traces the delegation chain: checks the `orchestrator_token` → finds its `subject_token` (parent) was the `human_token` → sees `human_token` is revoked → returns `active: false` for all derived tokens
4. Payment API rejects the next request

**Revocation latency:** = introspection call latency + IS 7.3 processing time + cache TTL (if client caches introspection result)
- Recommended: ≤5min cache TTL (banking compliance)
- In practice: introspect on every token use (cache TTL = 0) for payment operations, or cache up to 5min for non-critical operations

**Critical:** APIs in the delegation chain MUST use introspection (not local JWT validation) to honor user revocation within the token's lifetime.

### 4. Audit trail design — threading correlation IDs

Audit trail requires correlation across three systems:
- **IS 7.3 audit log**: records token exchange events
- **AgentCore CloudTrail**: records API calls (if AgentCore runs on AWS)
- **Payment API transaction log**: records the actual payment

**Without correlation:** Each system has a piece of the puzzle but can't be linked. Compliance officers must manually correlate by timestamp (error-prone, slow).

**With correlation (using `jti`):** Each token carries a unique `jti` (RFC 7519 JWT ID claim). This ID is:
- Generated by IS 7.3 when the token is issued
- Carried in the token by the API client
- Logged by the payment API in its transaction record
- Correlated with AgentCore by including the `jti` in the `X-AgentCore-Caller-Identity` header (or a custom header)

**Audit trail record at payment API:**
```json
{
  "timestamp": "2026-10-01T10:15:30Z",
  "txn_id": "PAY-001",
  "sub": "<user>",
  "act_chain": ["<tool_id>", "<orchestrator_id>"],
  "jti": "<correlation-uuid>",
  "agentcore_session_id": "<sessionId>",
  "status": "approved",
  "amount": 100.00
}
```

**Query to reconstruct the chain:**
```sql
-- Step 1: Find the payment transaction
SELECT jti, agentcore_session_id FROM payment_api_txn WHERE txn_id = "PAY-001"

-- Step 2: Find IS 7.3 token exchanges with matching jti
SELECT event_type, actor_client, issued_scope FROM is73_audit WHERE jti = <jti>

-- Step 3: Find AgentCore CloudTrail entries with matching session_id
SELECT action, resource, event_time FROM cloudtrail WHERE session_id = <agentcore_session_id>
```

### 5. Chain depth limits

RFC 8693 does not define a maximum depth for `act` nesting. Theoretically, a user → orchestrator → tool1 → tool2 → tool3 → API chain is possible, but each hop adds:
- Complexity (more systems to audit, more potential failure points)
- Latency (each exchange takes time; verify chain at API takes time)
- Security risk (each hop is an attack surface)

**Recommended:** 3 hops (user → orchestrator → tool → API)
- Deeper chains (4+) are rare in practice and add complexity without proportional security benefit

**Enforcement:** IS 7.3 actor trust policy can specify: which exchanges are permitted at each level.
```json
{
  "actor": "orchestrator",
  "subject": "group:financial-users",
  "effect": "Allow",
  "max_delegation_depth": 2
}
```

Alternative: explicit policy preventing tool-to-tool exchanges (no tool can exchange on behalf of another tool).

## WSO2 IS 7.3 / AgentCore mapping

### End-to-end HTTP trace with token requests and introspection

See `labs/day28/config/delegation_chain_trace.md` for the complete annotated trace showing:
1. **First exchange** (user → orchestrator): HTTP request, IS 7.3 response, decoded JWT
2. **Second exchange** (orchestrator → tool): HTTP request, IS 7.3 response, decoded JWT with nested `act`
3. **Payment API call**: HTTP request with token, IS 7.3 introspection call, introspection response, CloudTrail entry
4. **Revocation scenario**: User revokes, next introspection call shows `active: false` for derived tokens

All token values are `<PLACEHOLDER>` with fill-in comments. Readers study this trace to understand the full delegation flow and correlation via `jti`.

### Key decisions at each hop

**Hop 1: User → Orchestrator**
- Token lifetime: 15min (long enough for a user session, short enough to limit damage)
- Scope: narrowed to `payments:initiate` (user may have broader `payments:read payments:write`, but orchestrator only needs to initiate)
- `act.sub`: `orchestrator_id` (tells API which agent is acting)
- Correlation: IS 7.3 generates `jti=<uuid1>`

**Hop 2: Orchestrator → Tool**
- Token lifetime: 5min (tool typically operates in seconds; token expires quickly if stolen)
- Scope: same as parent (`payments:initiate`; tool inherits orchestrator's already-narrowed scope)
- `act` nesting: `{"sub": "tool_id", "act": {"sub": "orchestrator_id"}}` (full chain visible)
- Correlation: IS 7.3 generates `jti=<uuid2>` (different from hop 1)

**Hop 3: Tool → Payment API**
- Token binding: SigV4 signature (AgentCore signs via AWS SigV4)
- Session tags: AgentCore adds `X-AgentCore-Caller-Identity` with `userId`, `agentId`, `sessionId`
- Token validation: Payment API calls IS 7.3 introspect (NOT local JWT validation)
- Correlation: API logs `jti=<uuid2>` (from tool token) + `agentcore_session_id=<sessionId>` (from header)

## Anti-patterns

1. **Using local JWT validation at the payment API — revocation does not propagate within token lifetime** — a user who revokes after a fraud alert still has active agent tokens for up to 15min (orchestrator) or 5min (tool). The payment API validates the JWT signature locally and accepts it without checking IS 7.3 revocation status. Fix: use introspection on every request (or cache introspection result with TTL ≤5min) to honor user revocation.

2. **Not correlating `jti` across IS 7.3 audit, AgentCore CloudTrail, and payment API logs — each system has a piece of the chain; without shared correlation ID, reconstructing the chain requires cross-system log correlation by timestamp (imprecise, slow).** Example: compliance officer needs to audit all actions by `tool_id` on behalf of `user_001` in a 24h window. Without `jti` correlation, the officer must: (1) find all tokens in IS 7.3 audit log for that user+tool, (2) guess which ones were used by looking at timestamps in CloudTrail and payment API, (3) manually align them by time (error-prone). With `jti`: query IS 7.3 audit for user+tool, get list of `jti` values, query payment API with those `jti` values, get matching transactions. Fix: include `jti` in all three audit logs; use `jti` as primary correlation key.

3. **Passing `sessionId` from AgentCore to IS 7.3 token exchange but not to the payment API — the payment API cannot correlate its transaction record with the CloudTrail entry.** Example: `tool_id` agent makes multiple API calls in rapid succession. Each call has the same CloudTrail `session_id` (one user session). But the payment API logs transactions with no link to the AgentCore session, so if the tool is compromised and makes fraudulent calls, the auditor cannot quickly find the CloudTrail entries via the payment transaction. Fix: include `sessionId` (or a derived claim like `azp`) in the IS 7.3 exchange token, and pass it to the payment API (either in the JWT or in a custom header). Payment API logs the session ID, enabling direct correlation.

## Exercises

**Exercise 1:** A user's human token expires after 1 hour. At T=50min, the orchestrator exchanges it and gets a 15-minute exchange token. At T=60min, the user's session expires (human token is revoked by IS 7.3). At T=62min, the tool is activated and tries to exchange the orchestrator token (received at T=50) for a tool token. What happens, and why? Does the revocation affect the exchange?

**Hint:** At exchange time, is the `subject_token` (orchestrator token) still valid? What does IS 7.3 check?

**Solution sketch:** At T=62min, the tool requests token exchange. IS 7.3 checks the `subject_token` (the orchestrator token from T=50, still valid until T=65). But IS 7.3 also traces the chain: the orchestrator token's parent is the human token (issued at T=0, expired at T=60). The human token is revoked. IS 7.3 returns `invalid_request` or `invalid_grant` — the exchange is rejected because the chain is broken. The revocation propagates upstream. If the tool had already received a token (before T=60), subsequent introspection calls would return `active: false`. This is why introspection-based revocation works: every API call checks the full chain, not just the leaf token.

---

**Exercise 2:** The payment API receives a tool token and calls IS 7.3 introspection. IS 7.3 returns `active: true` with the full `act` chain. The API processes the payment and logs: `sub=<user>, act_chain=[tool_id, orchestrator_id], jti=<uuid2>`. Later, a customer disputes the charge. The compliance officer queries the payment API for transaction with `jti=<uuid2>`. What should they query next in IS 7.3 to verify the user actually delegated this payment?

**Hint:** Start with the `jti` from the payment API. What does IS 7.3 audit log have with the same `jti`?

**Solution sketch:** Query IS 7.3 audit log: `SELECT * FROM is73_audit WHERE jti = <uuid2>`. This returns the second-hop exchange (orchestrator → tool), showing: `event_type=token_exchange`, `subject_client=<orchestrator_token_jti>`, `actor_client=tool_id`, `timestamp`. Then recursively query with `jti=<orchestrator_token_jti>` to find the first-hop exchange (user → orchestrator). This gives the full chain with timestamps. If at any hop the `issued_at` timestamp is later than the user's consent date or after the user revoked, the payment is unauthorized. The `jti` correlation makes this query fast and accurate.

---

**Exercise 3:** Design an introspection cache strategy for a banking payment API. The API handles 1000 requests/sec from agents. IS 7.3 can handle 500 introspection calls/sec. Is a simple "no cache" strategy viable? If not, propose a cache TTL and explain how it affects revocation latency.

**Hint:** Revocation must propagate within 5min (banking compliance). How long can an introspection result be cached?

**Solution sketch:** "No cache" is not viable: 1000 requests/sec × 1 introspection per request = 1000 introspection calls/sec, but IS 7.3 handles only 500/sec. Requests queue up, causing timeouts and API degradation. Solution: cache introspection result for TTL=300s (5 minutes). Strategy:
- Key: `token_hash` (hash of the token value)
- Value: `{active: true, sub, act, scope, exp}`
- TTL: 300s

Effect on revocation: If user revokes at T=60min and the API cached an introspection result at T=59.5min (TTL expires at T=64.5min), the revocation is not detected for up to 4.5min. This is within the banking compliance requirement (≤5min). If compliance requires faster revocation, reduce TTL to 60s or use "introspect on every N-th call" (e.g., every 10th call, or random sampling).

## Lab

See `labs/day28/README.md` — trace a complete end-to-end delegation chain through IS 7.3, AgentCore, and a payment API, with audit trail correlation via `jti`.
