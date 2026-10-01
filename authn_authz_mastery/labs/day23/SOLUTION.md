# Day 23 Lab — Solution

## Complete 2-Hop Token Exchange Trace

### State 1: Human Token (User Authenticates)

```json
{
  "iss": "https://is.bank.local:9443/oauth2/token",
  "sub": "alice_id_2024",
  "aud": "https://api.bank.local/v1",
  "azp": "bank-mobile-app",
  "scope": "payments:initiate accounts:read",
  "auth_time": 1726841700,
  "exp": 1726845300,
  "iat": 1726841700,
  "jti": "uuid-h1"
}
```

**Analysis:**
- `sub`: Alice's subject identifier (preserved throughout the chain)
- `scope`: Alice's full authorized scope (both payment and account read access)
- `exp`: 3600s (1 hour) — human session duration
- Issued by: IS 7.3 via App-Native Auth (Day 11)

---

### State 2: Orchestrator Token (After First Exchange)

**Exchange Request:**
```
POST /oauth2/token
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
subject_token=<human_token>
actor_token=<payment-processor-v1-jwt>
scope=payments:initiate
```

**IS 7.3 Validation:**
1. ✓ human_token is valid and not revoked
2. ✓ actor_token is a signed JWT for payment-processor-v1
3. ✓ payment-processor-v1 is authorized to exchange for users in this organization
4. ✓ requested scope (payments:initiate) ⊆ human_token scope (payments:initiate, accounts:read)
5. ✓ All checks passed

**Resulting Token:**

```json
{
  "iss": "https://is.bank.local:9443/oauth2/token",
  "sub": "alice_id_2024",
  "aud": "https://api.bank.local/v1",
  "azp": "payment-processor-v1",
  "act": {
    "sub": "payment-processor-v1"
  },
  "scope": "payments:initiate",
  "auth_time": 1726841700,
  "exp": 1726842600,
  "iat": 1726841800,
  "jti": "uuid-o1"
}
```

**Key Changes:**
- `sub=alice_id_2024`: **PRESERVED** (same as human_token)
- `act={"sub": "payment-processor-v1"}`: **ADDED** (identifies the orchestrator)
- `scope=payments:initiate`: **NARROWED** (removed accounts:read)
- `exp=1726842600`: **SHORTENED** (now +900s = 15 minutes)
- `azp=payment-processor-v1`: Authorized party is the orchestrator

**Why these changes?**
- Preserving `sub` ensures the audit trail points back to Alice
- Adding `act` records which agent is acting
- Narrowing scope limits the orchestrator to only what it needs
- Shorter `exp` forces periodic re-evaluation; if orchestrator is compromised, damage window is limited

---

### State 3: Tool Token (After Second Exchange)

**Exchange Request:**
```
POST /oauth2/token
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
subject_token=<orchestrator_token>
actor_token=<risk-assessment-v1-jwt>
scope=payments:initiate
```

**IS 7.3 Validation:**
1. ✓ orchestrator_token is valid (and parent human_token is not revoked)
2. ✓ risk-assessment-v1 is authorized to exchange
3. ✓ requested scope (payments:initiate) ⊆ orchestrator_token scope (payments:initiate)
4. ✓ All checks passed

**Resulting Token:**

```json
{
  "iss": "https://is.bank.local:9443/oauth2/token",
  "sub": "alice_id_2024",
  "aud": "https://api.bank.local/v1",
  "azp": "risk-assessment-v1",
  "act": {
    "sub": "risk-assessment-v1",
    "act": {
      "sub": "payment-processor-v1"
    }
  },
  "scope": "payments:initiate",
  "auth_time": 1726841700,
  "exp": 1726842400,
  "iat": 1726841800,
  "jti": "uuid-r1"
}
```

**Key Changes:**
- `sub=alice_id_2024`: **PRESERVED AGAIN** (three hops, same user)
- `act`: **NESTED** (not replaced):
  - Outermost `act.sub`: `risk-assessment-v1` (immediate caller)
  - Inner `act.act.sub`: `payment-processor-v1` (previous hop)
- `scope=payments:initiate`: **UNCHANGED** (already at minimum)
- `exp=1726842400`: **SHORTENED FURTHER** (now +300s = 5 minutes for per-operation tool)
- `azp=risk-assessment-v1`: Immediate recipient is the tool

**Why `act` nests instead of replacing?**

| Token | Act Structure | What It Means |
|-------|---------------|--------------|
| orchestrator_token | `act.sub=payment-processor-v1` | "The payment orchestrator agent is acting" |
| tool_token | `act.sub=risk-assessment-v1, act.act.sub=payment-processor-v1` | "The risk tool is acting, who was acting for which user? The payment orchestrator." |

The nested structure preserves the full delegation path: Alice → Payment Processor → Risk Assessment Tool.

If the API only reads the outermost `act.sub`, it sees the immediate caller (tool). If it traverses the chain, it sees the full path.

---

## Token Introspection Response

When a backend API calls `POST /oauth2/introspect` with the tool token:

```json
{
  "active": true,
  "scope": "payments:initiate",
  "sub": "alice_id_2024",
  "aud": "https://api.bank.local/v1",
  "azp": "risk-assessment-v1",
  "act": {
    "sub": "risk-assessment-v1",
    "act": {
      "sub": "payment-processor-v1"
    }
  },
  "auth_time": 1726841700,
  "exp": 1726842400,
  "iat": 1726841800,
  "jti": "uuid-r1"
}
```

**API Authorization Logic:**

```
1. Is token active? YES → proceed
2. Who is the user? alice_id_2024 → look up Alice's account permissions
3. Who is the immediate caller? risk-assessment-v1 → apply per-agent rate limits/policies
4. What is the full delegation chain? [risk-assessment-v1, payment-processor-v1] → log for audit
5. Scope? payments:initiate → check if this operation is allowed
```

---

## Revocation Propagation Deep Dive

### Scenario: Alice Revokes at T+30sec (After Tool Token Issued)

```
Timeline:
T+0sec:   Alice authenticates → human_token (exp: T+3600)
T+2sec:   Orchestrator exchanges → orchestrator_token (exp: T+902)
T+4sec:   Tool exchanges → tool_token (exp: T+304)
T+10sec:  Risk API introspects tool_token
          IS 7.3: "Is human_token revoked?" NO → tool_token active:true ✓

T+30sec:  Alice revokes session via IS 7.3 console
          IS 7.3: Marks human_token (uuid-h1) as revoked

T+31sec:  Payment API introspects orchestrator_token
          IS 7.3 logic:
            1. Is orchestrator_token (uuid-o1) directly revoked? NO
            2. Trace exchange chain:
               - uuid-o1 came from uuid-h1
               - Is uuid-h1 revoked? YES
            3. Return: active:false ✓

T+50sec:  Risk API introspects tool_token again
          IS 7.3 logic:
            1. Is tool_token (uuid-r1) directly revoked? NO
            2. Trace exchange chain:
               - uuid-r1 came from uuid-o1
               - uuid-o1 came from uuid-h1
               - Is uuid-h1 revoked? YES
            3. Return: active:false ✓
```

**Revocation Propagation Timing:**
- Immediate: User revokes (IS 7.3 marks human_token revoked)
- Within 5–10 seconds: APIs with introspection cache TTL=0 detect revocation on next introspection
- Within 5 minutes: APIs with cache TTL=5min detect revocation by cache expiration + next introspection
- **Worst case**: If an API validates JWTs locally (not using introspection), revocation is NOT detected until the token's own `exp` time

**Banking Compliance**: APIs MUST use introspection (not local JWT validation) for tokens in delegation chains. This ensures user revocation propagates within the cache TTL.

---

## Why Scope Narrowing at Each Hop

### Example Design

```
Alice's full scope: payments:write, payments:read, accounts:read, transfers:write

First exchange (orchestrator):
  Orchestrator only needs: payments:write, payments:read
  Narrowed scope: payments:write, payments:read
  (Removed: accounts:read, transfers:write)

Second exchange (risk assessment tool):
  Risk tool only needs: payments:read
  Narrowed scope: payments:read
  (Removed: payments:write — tool can only read, not initiate)
```

**Benefit**: If the risk assessment tool is compromised, attacker can only read payment info, not initiate new payments. Scope narrowing limits blast radius.

**IS 7.3 Enforcement**: Cannot request scope wider than subject_token scope.

```
❌ INVALID:
  subject_token.scope = "payments:read"
  requested_scope = "payments:write"
  Result: IS 7.3 returns invalid_scope

✓ VALID:
  subject_token.scope = "payments:read"
  requested_scope = "payments:read"
  Result: Token issued with payments:read
```

---

## Audit Trail Reconstruction

**Question**: "Prove that Alice authorized the $50k transfer. Show the full agent chain."

**Method**: Correlate logs using token `jti` values.

### Step 1: Payment API Log

```json
{
  "timestamp": "2024-10-01T14:22:33Z",
  "transaction_id": "TXN-20241001-50k",
  "amount": 50000,
  "user": "alice_id_2024",
  "agent": "payment-processor-v1",
  "token_jti": "uuid-o1",
  "risk_decision": "APPROVED"
}
```

**Finding**: Transaction used orchestrator_token with jti=uuid-o1

### Step 2: Risk API Log

```json
{
  "timestamp": "2024-10-01T14:22:25Z",
  "operation": "risk_assessment",
  "token_jti": "uuid-r1",
  "result": "APPROVED"
}
```

**Finding**: Risk assessment used tool_token with jti=uuid-r1

### Step 3: IS 7.3 Audit Log

Search for token issuance events:

```json
[
  {
    "event": "token_exchange",
    "timestamp": "2024-10-01T14:22:20Z",
    "issued_jti": "uuid-r1",
    "subject_jti": "uuid-o1",
    "actor_client_id": "risk-assessment-v1",
    "scope": "payments:read",
    "status": "success"
  },
  {
    "event": "token_exchange",
    "timestamp": "2024-10-01T14:22:15Z",
    "issued_jti": "uuid-o1",
    "subject_jti": "uuid-h1",
    "actor_client_id": "payment-processor-v1",
    "scope": "payments:write",
    "status": "success"
  },
  {
    "event": "oidc_login",
    "timestamp": "2024-10-01T14:15:00Z",
    "issued_jti": "uuid-h1",
    "subject": "alice_id_2024",
    "status": "success"
  }
]
```

### Audit Trail Report

```
TRANSACTION AUDIT: TXN-20241001-50k

1. AUTHENTICATION (uuid-h1)
   ✓ User: alice_id_2024
   ✓ Method: OIDC Login (App-Native Auth)
   ✓ Timestamp: 2024-10-01T14:15:00Z
   ✓ Scope: payments:write, payments:read, accounts:read

2. FIRST DELEGATION (uuid-h1 → uuid-o1)
   ✓ Subject: alice_id_2024 (preserved)
   ✓ Actor: payment-processor-v1 (orchestrator)
   ✓ Scope: payments:write (narrowed — removed accounts:read)
   ✓ Timestamp: 2024-10-01T14:22:15Z
   ✓ Reason: Orchestrator exchanged for delegation

3. SECOND DELEGATION (uuid-o1 → uuid-r1)
   ✓ Subject: alice_id_2024 (preserved again)
   ✓ Actor: risk-assessment-v1 (tool)
   ✓ Scope: payments:read (narrowed further — removed payments:write)
   ✓ Timestamp: 2024-10-01T14:22:20Z
   ✓ Reason: Tool exchanged for risk assessment

4. RISK ASSESSMENT (using uuid-r1)
   ✓ API: Risk Assessment Service
   ✓ Timestamp: 2024-10-01T14:22:25Z
   ✓ Decision: APPROVED (score: 0.15, low risk)

5. PAYMENT INITIATION (using uuid-o1)
   ✓ API: Payment Initiation Service
   ✓ Timestamp: 2024-10-01T14:22:33Z
   ✓ Amount: $50,000
   ✓ Status: INITIATED (TXN-20241001-50k)

COMPLIANCE CONCLUSION:
✓ Alice (alice_id_2024) authenticated to the system
✓ Alice authorized the $50k transfer via app login
✓ Payment Orchestrator (payment-processor-v1) decomposed the task
✓ Risk Assessment Tool (risk-assessment-v1) evaluated compliance
✓ Scope narrowed appropriately at each hop
✓ Full delegation chain recorded in `act` claims
✓ Every step traceable via `jti` correlation
✓ AUDIT TRAIL COMPLETE ✓
```

---

## Common Mistakes and Fixes

### Mistake 1: Omitting `actor_token`

**What happens:**
```
Request:
  grant_type=token-exchange
  subject_token=<user-token>
  scope=payments:initiate
  (actor_token is missing)

IS 7.3 Response:
  Might accept but issues token with NO `act` claim
  Result: Audit log cannot identify which agent made the call
```

**Fix:** Always include both `actor_token` and `actor_token_type` in the exchange request.

### Mistake 2: Requesting scope wider than subject_token

**What happens:**
```
subject_token.scope = "payments:read"
Request:
  requested_scope = "payments:write"

IS 7.3 Response:
  400 invalid_scope
  "Requested scope exceeds subject token scope"
```

**Fix:** Ensure `requested_scope` ⊆ `subject_token.scope`.

### Mistake 3: Using local JWT validation instead of introspection

**What happens:**
```
Backend API validates JWT locally (checks signature + exp)
User revokes their session at IS 7.3
API still accepts derived tokens because they're not expired
Revocation is NOT detected until token expires naturally
```

**Fix:** Use `POST /oauth2/introspect` at IS 7.3. This checks the exchange chain and detects revoked parent tokens.

### Mistake 4: Not configuring actor trust policy

**What happens:**
```
No actor trust policy in IS 7.3
Any client can exchange any user's token
A low-privilege agent could exchange a high-privilege user's token
Broken for banking compliance
```

**Fix:** Configure per-application actor trust policy in IS 7.3 Console:
- Specify which agent client_ids are allowed to exchange
- Restrict by user role (e.g., only orchestrators authorized for user_role=customer)

---

## Self-Check: 2-Hop Delegation Checklist

After completing the lab, verify:

- [ ] I can explain why `sub` must be preserved at every hop
- [ ] I can draw the `act` nesting structure for a 2-hop chain
- [ ] I can explain why each token's `exp` is shorter than the parent's
- [ ] I can design a scope narrowing strategy for my application
- [ ] I can reconstruct an audit trail using `jti` correlation
- [ ] I understand why introspection is required for revocation propagation
- [ ] I can identify which agent is the immediate caller from the outermost `act.sub`
- [ ] I can trace the full delegation chain by traversing nested `act` claims

All checked? You've mastered RFC 8693 OBO delegation chains.
