# Day 28 Lab — Solution

## End-to-End Delegation Chain Analysis

### Token Payloads at Each Hop

#### Human Token (Step 1: User Authentication)

```json
{
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "sub": "alice_001",
  "aud": "mobilebank",
  "scope": "payments:read payments:write accounts:read",
  "exp": 1696108129,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440000",
  "token_type": "Bearer",
  "alg": "RS256"
}
```

**Claims breakdown:**
- `sub = "alice_001"` — user identity (will be preserved through all hops)
- `scope = "payments:read payments:write accounts:read"` — broad user scope (can be narrowed by agents)
- `exp = now+3600` — 1-hour session (typical user session duration)
- `jti = "550e8400-e29b-41d4-a716-446655440000"` — unique token ID for tracing
- No `act` claim (user token, not delegated)

---

#### Orchestrator Token (Step 2: First-hop Exchange)

```json
{
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "sub": "alice_001",
  "act": {
    "sub": "payment_orchestrator"
  },
  "aud": "payment-api",
  "scope": "agent:payments:initiate",
  "exp": 1696104729,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440001",
  "token_type": "Bearer",
  "alg": "RS256"
}
```

**Claims breakdown:**
- `sub = "alice_001"` — **preserved** from human token
- `act = {"sub": "payment_orchestrator"}` — **added** by IS 7.3 to identify the acting agent
- `scope = "agent:payments:initiate"` — **narrowed** from user's full scope (specific to agent use case)
- `exp = now+900` — 15 minutes (shorter than user token; expires before orchestrator could re-exchange a compromised parent)
- `jti = "550e8400-e29b-41d4-a716-446655440001"` — new unique ID (different from parent)
- **Key insight:** `sub` unchanged, `act` added — verifiable delegation recorded

---

#### Risk Scorer Token (Step 3: Second-hop Exchange)

```json
{
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "sub": "alice_001",
  "act": {
    "sub": "risk_scorer",
    "act": {
      "sub": "payment_orchestrator"
    }
  },
  "aud": "payment-api",
  "scope": "agent:payments:initiate",
  "exp": 1696104829,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "token_type": "Bearer",
  "alg": "RS256"
}
```

**Claims breakdown:**
- `sub = "alice_001"` — **still preserved** through two hops
- `act` is **nested:** immediate caller (risk_scorer) wraps the parent chain (payment_orchestrator)
  - `act.sub = "risk_scorer"` — the tool that is calling
  - `act.act.sub = "payment_orchestrator"` — the parent agent that delegated to risk_scorer
  - **Full chain is verifiable:** user authorized orchestrator; orchestrator authorized risk_scorer
- `scope = "agent:payments:initiate"` — same narrowed scope (inherited from orchestrator's already-narrowed token)
- `exp = now+300` — 5 minutes (minimal lifetime; tool operations complete in seconds)
- `jti = "550e8400-e29b-41d4-a716-446655440002"` — new unique ID (different from both parents)
- **Key insight:** `sub` preserved over 2 hops, `act` chain grows without replacement

---

### Token Lifetime Justification

| Token | Lifetime | Issuance | Expiry | Why This Duration |
|-------|----------|----------|--------|-------------------|
| human_token | 3600s (1h) | T+0 | T+3600 | User session typical duration (user active for 30min–2h); human can manually revoke anytime |
| orchestrator_token | 900s (15min) | T+50 | T+950 | Orchestrator typically processes a user request in 1–5min; if stolen, usable for only 15min |
| risk_scorer_token | 300s (5min) | T+55 | T+355 | Tool operations complete in seconds; 5min is max blast radius for a compromised tool |

**Why decreasing:** Each hop's token should expire before the parent token could become stale. If human_token expires at T+3600 and orchestrator_token lives for 900s, the orchestrator cannot exchange a new risk_scorer token after the parent orchestrator_token expires.

---

### Introspection Response

**When payment API calls `POST /oauth2/introspect` with risk_scorer_token:**

```json
{
  "active": true,
  "sub": "alice_001",
  "act": {
    "sub": "risk_scorer",
    "act": {
      "sub": "payment_orchestrator"
    }
  },
  "aud": "payment-api",
  "scope": "agent:payments:initiate",
  "exp": 1696104829,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "client_id": "risk_scorer",
  "token_type": "Bearer",
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "aud": "payment-api"
}
```

**What this response proves:**

1. **`active: true`** — Token is valid and not revoked
   - If user had revoked their session, IS 7.3 would return `active: false`
   - Full chain validation is performed (not just leaf token)

2. **`sub: alice_001`** — Original user is authenticated
   - Payment API can now prove: "This action was authorized by alice_001"

3. **`act` chain** — Full delegation path is recorded
   - API can read: "alice_001 → payment_orchestrator → risk_scorer"
   - Identifies every principal in the chain

4. **`scope: agent:payments:initiate`** — Scope is narrowed and verified
   - API can check: "This token is only allowed to initiate payments; not read, not transfer, not admin"

5. **`jti: 550e8400-e29b-41d4-a716-446655440002`** — Unique correlation ID
   - Payment API logs this `jti` in its transaction record
   - IS 7.3 audit log has the same `jti`
   - Enables audit trail reconstruction

---

### Payment API Transaction Log

```json
{
  "timestamp": "2026-10-01T10:15:30Z",
  "txn_id": "PAY-001",
  "user_sub": "alice_001",
  "agent_chain": ["risk_scorer", "payment_orchestrator"],
  "token_jti": "550e8400-e29b-41d4-a716-446655440002",
  "agentcore_session_id": "550e8400-e29b-41d4-a716-446655440003",
  "introspection_cache_hit": false,
  "introspection_latency_ms": 45,
  "amount": 1000.00,
  "currency": "USD",
  "status": "approved",
  "risk_score": "low"
}
```

**Audit trail elements:**
- `token_jti` — links to IS 7.3 token exchange audit entries
- `agentcore_session_id` — links to AgentCore CloudTrail entries
- `agent_chain` — human-readable chain (risk_scorer called by orchestrator)
- `user_sub` — proves user alice_001 initiated this action

---

### Audit Trail Reconstruction (Correlation via `jti`)

**Starting from payment transaction PAY-001:**

**Step 1: Find IS 7.3 token exchange for the `jti`**

```sql
SELECT timestamp, event_type, subject_client, actor_client, issued_scope, policy_result
FROM is73_audit
WHERE jti = "550e8400-e29b-41d4-a716-446655440002"
```

**Result:**
```
timestamp: 2026-10-01 10:15:15
event_type: token_exchange
subject_client: alice_001
actor_client: risk_scorer
issued_scope: agent:payments:initiate
policy_result: ALLOW
```

→ Risk scorer exchanged a token for alice_001. (Second-hop exchange)

**Step 2: Find parent exchange (by querying for first-hop `jti`)**

IS 7.3 audit logs which token was used as `subject_token`. In this case, orchestrator_token had `jti = "550e8400-e29b-41d4-a716-446655440001"`.

```sql
SELECT timestamp, event_type, subject_client, actor_client, issued_scope
FROM is73_audit
WHERE jti = "550e8400-e29b-41d4-a716-446655440001"
```

**Result:**
```
timestamp: 2026-10-01 10:15:10
event_type: token_exchange
subject_client: alice_001
actor_client: payment_orchestrator
issued_scope: agent:payments:initiate
policy_result: ALLOW
```

→ Orchestrator exchanged a token for alice_001. (First-hop exchange)

**Step 3: Find AgentCore CloudTrail using `agentcore_session_id`**

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=SessionId,AttributeValue="550e8400-e29b-41d4-a716-446655440003" \
  --max-results 10
```

**Result:**
```
eventTime: 2026-10-01 10:15:25
eventName: AssumeRole
sourceIPAddress: <PLACEHOLDER: agent-ip>
requestParameters.roleArn: arn:aws:iam::<PLACEHOLDER: account>:role/RiskScorerRole
additionalEventData.sessionTags.userId: alice_001
additionalEventData.sessionTags.agentId: risk_scorer
```

→ Risk scorer assumed a role with session tags (userId=alice_001, agentId=risk_scorer).

**Complete reconstruction:**
```
2026-10-01 10:15:10 — alice_001 authorized payment_orchestrator to act (token exchange, jti=uuid-1)
2026-10-01 10:15:15 — payment_orchestrator authorized risk_scorer to act (token exchange, jti=uuid-2)
2026-10-01 10:15:25 — risk_scorer assumed role RiskScorerRole (CloudTrail, sessionId=uuid-3)
2026-10-01 10:15:30 — risk_scorer called /v1/payments/initiate (Payment API, amount=$1000, approved)
```

**All linked by correlation IDs.** Without `jti`, teams would have to correlate manually by timestamp (error-prone, slow).

---

### Revocation Scenario

**User revokes at T+60min:**

```http
POST /oauth2/revoke
Content-Type: application/x-www-form-urlencoded

token=<PLACEHOLDER: human-token-jwt>
```

**IS 7.3 marks human_token as revoked.**

**At T+62min, tool tries to exchange orchestrator_token:**

IS 7.3 receives:
```
subject_token = orchestrator_token (jti=uuid-1, still valid, exp > T+62)
actor_token = risk_scorer_jwt
grant_type = token-exchange
```

**IS 7.3 validation:**
1. Is orchestrator_token valid? `exp > T+62`? Yes, expires at T+65
2. Check chain: orchestrator_token.subject_token = human_token (jti=uuid-0)
3. Is human_token revoked? **YES** (revoked at T+60)
4. **Result:** Exchange fails with `error=invalid_request`, `error_description=subject_token_revoked`

**OR if tool already has a risk_scorer_token and calls payment API at T+62:**

Payment API calls introspect(risk_scorer_token):

```http
POST /oauth2/introspect
token=<PLACEHOLDER: risk-scorer-token>
```

**IS 7.3 introspection check:**
1. Is risk_scorer_token.exp > T+62? Yes, expires at T+65
2. Check chain: risk_scorer_token.sub = alice_001
3. Is alice_001's parent token (human_token) revoked? **YES**
4. **Response:**
```json
{
  "active": false,
  "error": "invalid_token",
  "error_description": "Subject token chain revoked"
}
```

**Payment API returns 401 Unauthorized; transaction is rejected.**

---

### Introspection Cache Strategy

**Bank requirement:** Revocation must propagate within 5 minutes.

**Cache TTL decision: 300 seconds (5 minutes)**

| Time | Scenario | Result |
|------|----------|--------|
| T+0 | User revokes session | IS 7.3 marks human_token as revoked |
| T+1 | Payment API introspects risk_scorer_token | IS 7.3 returns `active: false` immediately (no cache, or cache expired) |
| T+60 | Payment API introspects again | If cache hit (result from T+1 still cached): `active: false` (serves cached result) |
| T+300 (T+5min) | Cache expires | Next introspection is fresh query; still `active: false` |
| T+400 | Later | Still `active: false` (revocation persists indefinitely) |

**If cache TTL were 1 hour:**
- User revokes at T+0
- Payment API introspects at T+1, gets `active: false`, caches for 3600s
- But if another payment API (different instance, no shared cache) introspects at T+30, it gets fresh query, also `active: false`
- Issue: two APIs with different cache states could accept/reject the same user for 1 hour → compliance violation

**5-minute cache is the right balance:**
- Performance: Reduces load on IS 7.3 (introspect once per token, then serve from cache for 5min)
- Compliance: Revocation propagates within 5min (banking requirement)

---

### Scope Narrowing Verification

**User token scope:** `payments:read payments:write accounts:read accounts:write` (broad)

**Orchestrator requests:** `scope=agent:payments:initiate` (narrower)

**IS 7.3 validation:**
- Does `scope=agent:payments:initiate` fit within user's scope?
- Mapping: `agent:payments:initiate` ⊆ `payments:write` ✓
- Exchange succeeds, orchestrator_token has narrowed scope

**Tool inherits:** `scope=agent:payments:initiate` (same as orchestrator)

**Result:**
- User can do: payments:read, payments:write, accounts:read, accounts:write
- Orchestrator can do: agent:payments:initiate (narrower; can't read accounts)
- Tool can do: agent:payments:initiate (same as orchestrator; can't escalate)

**Scope narrowing prevents blast radius expansion:** User's authority is not escalated through agent chain; each agent gets the minimum scope needed.

---

## Key Lessons

1. **`sub` preservation** — original user identity flows through entire chain; no impersonation
2. **`act` growth** — agent identities accumulate (don't replace); full chain is verifiable
3. **Token lifetime hierarchy** — each hop's token expires before parent could cause damage
4. **Revocation chain check** — IS 7.3 validates full chain on introspection, not just leaf token
5. **`jti` correlation** — enables audit trail reconstruction across three systems (IS 7.3, AgentCore, API)
6. **Scope narrowing** — prevents agents from escalating authority beyond user's original consent
7. **Introspection cache** — balances performance with compliance (5min ≤ revocation latency ≤ 5min)

This architecture makes agent actions auditable, revocable, and traceable — critical for regulatory compliance in banking.
