# Day 28 Lab — End-to-End Delegation Chain

## Objective

Trace a complete end-to-end delegation chain through IS 7.3, AgentCore, and a payment API. Understand how `jti` (unique token ID) correlates audit events across systems. Success signal: you can reconstruct the full chain of authority from a single payment transaction by querying three systems using the `jti` correlation ID.

## Scenario

A payment transaction (PAY-001, $1000 transfer) needs to be audited for compliance:

1. User `alice_001` initiated a payment via mobile app (Friday 10:00 AM)
2. Payment orchestrator exchanged the user token and got a delegated token
3. Risk scorer tool exchanged the orchestrator token and got a second-level delegated token
4. Risk scorer called the payment API with the tool token
5. Payment API introspected the token and verified the delegation chain
6. Payment API processed the transaction

**Audit question:** "What is the complete chain of authority for PAY-001? Which user, which agents, which tokens, which API calls?"

## What you'll produce

1. **Trace diagram** showing all 6 steps with HTTP requests, token payloads, and introspection responses
   - Step 1: User authentication → human_token
   - Step 2: First-hop exchange → orchestrator_token (with `jti=uuid-2`)
   - Step 3: Second-hop exchange → risk_scorer_token (with `jti=uuid-3`)
   - Step 4–5: Tool calls payment API → introspection
   - Step 6: Payment API records transaction with correlation IDs

2. **Decoded token payloads** at each hop:
   - Human token: claims (`sub`, `scope`, `exp`, `jti`)
   - Orchestrator token: claims (`sub`, `act`, `scope`, `exp`, `jti`)
   - Tool token: claims (`sub`, `act` nested, `scope`, `exp`, `jti`)

3. **Introspection response** from IS 7.3:
   - What IS 7.3 returns when payment API introspects the tool token
   - Proves the full `act` chain is visible to the API

4. **Audit trail reconstruction**:
   - Payment API transaction log entry with `jti` and `agentcore_session_id`
   - SQL queries to correlate: payment API log → IS 7.3 audit → CloudTrail

5. **Revocation scenario**:
   - User revokes at T=60min
   - At T=62min, tool tries to use orchestrator token
   - What happens and why

## Steps

### Step 1: Review the scenario

The compliance officer needs to prove PAY-001 is valid: user authorized it, agents executed it properly, revocation would have caught it if user changed their mind.

### Step 2: Study the delegation chain trace

Open `config/delegation_chain_trace.md`. This file annotates the complete flow with `<PLACEHOLDER>` token values and explains each step.

### Step 3: Analyze token payloads

For each token state, extract the claims:

- **Human token** (issued by IS 7.3 at authentication):
  - `sub = "alice_001"` (original user)
  - `scope = "payments:read payments:write accounts:read"` (broad, user's full scope)
  - `exp = now+3600` (1 hour; user session duration)
  - `jti = "550e8400-e29b-41d4-a716-446655440000"` (issued by IS 7.3)

- **Orchestrator token** (issued by IS 7.3 at first exchange):
  - `sub = "alice_001"` (preserved)
  - `act = {"sub": "payment_orchestrator"}` (agent identity added)
  - `scope = "agent:payments:initiate"` (narrowed from user's scope)
  - `exp = now+900` (15 min; short-lived exchange token)
  - `jti = "550e8400-e29b-41d4-a716-446655440001"` (new, unique ID)

- **Tool token** (issued by IS 7.3 at second exchange):
  - `sub = "alice_001"` (preserved)
  - `act = {"sub": "risk_scorer", "act": {"sub": "payment_orchestrator"}}` (nested chain)
  - `scope = "agent:payments:initiate"` (same as parent)
  - `exp = now+300` (5 min; minimal blast radius)
  - `jti = "550e8400-e29b-41d4-a716-446655440002"` (new, unique ID)

### Step 4: Understand the introspection response

When payment API calls `POST /oauth2/introspect` with the tool token:

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
  "scope": "agent:payments:initiate",
  "aud": "payment-api",
  "exp": 1696105229,
  "iat": 1696104929,
  "jti": "550e8400-e29b-41d4-a716-446655440002"
}
```

**What this proves:**
- `active: true` — token is valid (subject_token chain is not revoked)
- `sub: alice_001` — user is verified
- `act` chain — full delegation chain is recorded (tool ← orchestrator ← user)
- `jti` — unique correlation ID for linking to audit logs

### Step 5: Design the audit trail query

**Payment API logs transaction with:**
```json
{
  "timestamp": "2026-10-01T10:15:30Z",
  "txn_id": "PAY-001",
  "user": "alice_001",
  "act_chain": ["risk_scorer", "payment_orchestrator"],
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "agentcore_session_id": "<PLACEHOLDER: session-uuid>",
  "status": "approved",
  "amount": 1000.00
}
```

**Query IS 7.3 audit for token with that `jti`:**
```sql
SELECT * FROM is73_audit
WHERE jti = "550e8400-e29b-41d4-a716-446655440002"
  AND event_type = "token_exchange"
```

**Query AgentCore CloudTrail for matching session:**
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --query 'Events[?contains(CloudTrailEvent, `<session-id>`)]'
```

### Step 6: Analyze the revocation scenario

At T=60min, user revokes. At T=62min, orchestrator token is still valid but its parent (human_token) is revoked. What happens when tool tries to exchange orchestrator token at T=62min?

IS 7.3 receives the exchange request:
1. Checks orchestrator_token validity: `exp` > T=62min? Yes, token is not expired
2. But IS 7.3 also checks the chain: orchestrator_token.subject_token = human_token
3. Checks human_token revocation status: Is it revoked? Yes (user revoked at T=60min)
4. Result: IS 7.3 returns `error=invalid_request` (chain is broken)

## Success Criteria

- Token payloads at each hop are complete (all 5 claims visible)
- `sub` is preserved across all hops
- `act` grows (not replaces) at each exchange
- `jti` values are unique at each token issuance
- You can explain how `jti` correlates payment API log ↔ IS 7.3 audit ↔ AgentCore CloudTrail
- You can explain the revocation chain: user revokes → parent token revoked → derived token exchange fails
- Introspection response shows full `act` nesting

## Time estimate

50–70 minutes

## Key concepts (reference Day 28 content)

- **End-to-end delegation chain** — 6 steps from user auth to API processing
- **Token lifetime hierarchy** — human > orchestrator > tool (decreasing lifetime, minimizing blast radius)
- **Revocation propagation** — introspection-based; user revokes → next introspection returns `active: false`
- **Correlation via `jti`** — unique token ID threads audit events across IS 7.3, AgentCore, payment API
- **Introspection cache TTL** — balances performance (cache hits) with compliance (revocation latency ≤5min)
