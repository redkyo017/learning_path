# Day 23 Lab — OBO — On-Behalf-Of (RFC 8693)

## Objective

Trace a 2-hop OBO delegation chain through IS 7.3. Success signal: you can explain what `act` nesting means and why `sub` is preserved.

## Scenario

A bank's payment processing system implements a 3-hop delegation chain:

- **User**: Alice Chen (`alice_id_2024`), authorized for `payments:initiate` + `accounts:read`
- **Orchestrator Agent**: "PaymentProcessor" (`payment-processor-v1`), processes high-value payments
- **Tool Agent**: "RiskAssessment" (`risk-assessment-v1`), calls external fraud detection API
- **Backend APIs**:
  - Risk Assessment Service: `/v1/risk/score`
  - Payment Initiation Service: `/v1/payments/initiate`

Alice initiates a $50,000 transfer. The orchestrator:
1. Exchanges Alice's token for orchestrator token (OBO hop 1)
2. Calls RiskAssessment tool
3. RiskAssessment exchanges orchestrator token for its own token (OBO hop 2)
4. Calls Risk Assessment Service
5. Orchestrator then calls Payment Initiation Service

**Compliance requirement**: The audit trail must show: Alice → PaymentProcessor → RiskAssessment, with each agent's identity in the token.

## What you'll produce

1. A **Mermaid sequence diagram** showing the complete 2-hop exchange:
   - Alice authenticates to IS 7.3
   - Orchestrator makes first exchange (user → orchestrator)
   - RiskAssessment makes second exchange (orchestrator → tool)
   - Both services call their respective backends
   - Both backends introspect tokens at IS 7.3

2. An **annotated HTTP file** (`config/obo_token_exchange.http`) with:
   - First exchange request/response (user token → orchestrator token)
   - Decoded JWT showing `sub`+`act` after first hop
   - Second exchange request/response (orchestrator token → tool token)
   - Decoded JWT showing nested `sub`+`act`+`act.act` after second hop
   - Introspection call and response

3. **Token payload analysis** in SOLUTION.md explaining:
   - How `sub` is preserved at both hops
   - How `act` nests (not replaces) at each hop
   - Why scope narrowing matters
   - How revocation propagates

## Steps

### Step 1: Review the scenario

Three questions to keep in mind:
- At each hop, does the token still identify the original user (Alice)?
- How does the API know not just that Alice authorized this, but ALSO that the RiskAssessment tool made the actual call?
- What happens if Alice revokes her session mid-operation?

### Step 2: Draw the first exchange

In `diagram.md`, sketch the first exchange:
- Alice has her access token (from App-Native Auth, Day 11)
- Orchestrator calls IS 7.3's token exchange endpoint
- Request includes: `subject_token`=Alice's token, `actor_token`=Orchestrator's JWT, `scope=payments:initiate`
- IS 7.3 returns a new token

Decode the result: what claims does it have?

### Step 3: Analyze the first exchange result

The orchestrator token should have:
- `sub`: still Alice (preserved!)
- `act`: `{"sub": "payment-processor-v1"}` (added by IS 7.3)
- `scope`: `payments:initiate` only (narrowed from Alice's broader scope)
- `exp`: 900s (15 minutes — shorter than Alice's human token)

### Step 4: Draw the second exchange

Now the RiskAssessment tool:
- Takes the orchestrator token as its `subject_token`
- Sends its own JWT assertion as `actor_token`
- Requests `scope=payments:initiate` again (no further narrowing — already narrowed)
- IS 7.3 returns another new token

Decode this result: what's different in the `act` claim?

### Step 5: Analyze the second exchange result

The tool token should have:
- `sub`: **still** Alice (preserved again!)
- `act`: **nested** — `{"sub": "risk-assessment-v1", "act": {"sub": "payment-processor-v1"}}`
  - Outermost `act.sub`: the immediate caller (tool)
  - Inner `act.act.sub`: the previous hop (orchestrator)
  - Two levels deep = two agents in the chain
- `scope`: `payments:initiate` (unchanged)
- `exp`: 300s (5 minutes — even shorter for per-operation tool)

### Step 6: Verify the audit trail

Can you reconstruct the chain: Alice → orchestrator → tool?

The backend API receives the tool token and calls IS 7.3's introspection endpoint:
```http
POST /oauth2/introspect
token=<tool-token>
```

IS 7.3 responds:
```json
{
  "active": true,
  "sub": "alice_id_2024",
  "act": {
    "sub": "risk-assessment-v1",
    "act": {
      "sub": "payment-processor-v1"
    }
  },
  "scope": "payments:initiate"
}
```

The API sees the full chain in the `act` nesting!

### Step 7: Test revocation

If Alice revokes her session at T+10min:
- Alice's human token becomes inactive in IS 7.3
- Next introspection call on any derived token returns `active: false`
- All three APIs (RiskAssessment, PaymentInitiation) reject the tokens within their introspection cache TTL

## Success Criteria

- Mermaid sequence diagram shows both exchanges with decoded token payloads
- `sub` is identical at all three token states (human, orchestrator, tool)
- `act` claim correctly nests (doesn't replace) at each hop
- Scope narrowing is shown (user's broad scope → `payments:initiate`)
- You can explain why `sub` must be preserved but `act` must change

## Time estimate

50–60 minutes

## Reference

Day 23 content: `content/day23.md` — review the "Result token structure" and "Multi-hop delegation" sections
