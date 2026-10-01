# Day 23 Lab — 2-Hop OBO Delegation Chain

## Complete RFC 8693 Token Exchange Flow

```mermaid
sequenceDiagram
  actor User as Alice Chen<br/>(alice_id_2024)
  participant IS73 as IS 7.3<br/>(OAuth2 AS)
  participant Orch as PaymentProcessor<br/>(payment-processor-v1)
  participant Risk as RiskAssessment<br/>(risk-assessment-v1)
  participant RiskSvc as Risk API<br/>/v1/risk/score
  participant PaySvc as Payment API<br/>/v1/payments/initiate

  User->>IS73: 1. App-Native Auth Login
  IS73->>User: 2. human_token (JWT)<br/>sub=alice_id_2024<br/>scope=payments:initiate,accounts:read<br/>exp=now+3600<br/>jti=uuid-h1

  Note over Orch: Alice initiates payment via UI<br/>Orchestrator receives: amount=$50k, destination_account

  Orch->>IS73: 3. POST /oauth2/token (First Exchange)<br/>grant_type=token-exchange<br/>subject_token=human_token<br/>subject_token_type=access_token<br/>actor_token=<orch-jwt><br/>actor_token_type=jwt<br/>scope=payments:initiate

  Note over IS73: Validate:<br/>1. human_token is valid<br/>2. orch-jwt signed correctly<br/>3. payment-processor-v1 authorized<br/>4. scope requested ⊆ human_token.scope ✓

  IS73->>Orch: 4. orchestrator_token (JWT)<br/>sub=alice_id_2024<br/>act={sub: payment-processor-v1}<br/>scope=payments:initiate<br/>exp=now+900<br/>jti=uuid-o1

  Note over Orch: ✓ Received token showing:<br/>sub=alice (user preserved)<br/>act=me (orchestrator identified)<br/>scope=payments:initiate only (narrowed)

  Orch->>Risk: 5. "Assess risk for $50k transfer"<br/>Pass orchestrator_token

  Risk->>IS73: 6. POST /oauth2/token (Second Exchange)<br/>grant_type=token-exchange<br/>subject_token=orchestrator_token<br/>subject_token_type=access_token<br/>actor_token=<risk-jwt><br/>actor_token_type=jwt<br/>scope=payments:initiate

  Note over IS73: Validate:<br/>1. orchestrator_token is valid + not revoked<br/>2. risk-jwt signed correctly<br/>3. risk-assessment-v1 authorized<br/>4. scope requested ⊆ orchestrator_token.scope ✓

  IS73->>Risk: 7. risk_token (JWT)<br/>sub=alice_id_2024<br/>act={sub: risk-assessment-v1,<br/>    act: {sub: payment-processor-v1}}<br/>scope=payments:initiate<br/>exp=now+300<br/>jti=uuid-r1

  Note over Risk: ✓ Received token showing:<br/>sub=alice (user preserved)<br/>act NESTS:<br/>  - immediate caller: risk-assessment-v1<br/>  - previous hop: payment-processor-v1<br/>scope=payments:initiate (unchanged)

  Risk->>RiskSvc: 8. GET /v1/risk/score<br/>Authorization: Bearer risk_token

  RiskSvc->>IS73: 9. POST /oauth2/introspect<br/>token=risk_token

  IS73->>RiskSvc: 10. Introspection Response<br/>active=true<br/>sub=alice_id_2024<br/>act={sub: risk-assessment-v1,<br/>    act: {sub: payment-processor-v1}}<br/>scope=payments:initiate

  Note over RiskSvc: ✓ Validates:<br/>Token is active<br/>User is alice_id_2024<br/>Full chain: alice → payment-processor → risk-assessment<br/>Scope: payments:initiate only

  RiskSvc->>Risk: 11. 200 OK<br/>{risk_score: 0.15, decision: APPROVED}

  Risk->>Orch: 12. Risk assessment result

  Orch->>PaySvc: 13. POST /v1/payments/initiate<br/>Authorization: Bearer orchestrator_token<br/>{amount: $50k, dest: ...}

  PaySvc->>IS73: 14. POST /oauth2/introspect<br/>token=orchestrator_token

  IS73->>PaySvc: 15. Introspection Response<br/>active=true<br/>sub=alice_id_2024<br/>act={sub: payment-processor-v1}<br/>scope=payments:initiate

  PaySvc->>PaySvc: 16. Verify authorization:<br/>- User: alice_id_2024 (known customer)<br/>- Agent: payment-processor-v1<br/>- Scope: payments:initiate ✓<br/>- Risk approved: yes ✓

  PaySvc->>PaySvc: 17. Create transaction<br/>txn_id=TXN-20241001-50k<br/>audit_log: {<br/>  user: alice_id_2024,<br/>  agent_chain: [payment-processor-v1, risk-assessment-v1],<br/>  jti: uuid-r1,<br/>  risk_decision: APPROVED<br/>}

  PaySvc->>Orch: 18. 201 Created<br/>{txn_id: TXN-20241001-50k,<br/> status: INITIATED}

  Orch->>User: 19. Transfer initiated<br/>Confirmation: TXN-20241001-50k
```

---

## Token Payload Evolution at Each Hop

### Token 1: Human Token (From Alice)

```json
{
  "sub": "alice_id_2024",
  "scope": "payments:initiate accounts:read",
  "exp": "now+3600",
  "jti": "uuid-h1"
}

State: Created by IS 7.3 during App-Native Auth (Day 11)
```

### Token 2: Orchestrator Token (After First Exchange)

```json
{
  "sub": "alice_id_2024",
  "act": {
    "sub": "payment-processor-v1"
  },
  "scope": "payments:initiate",
  "exp": "now+900",
  "jti": "uuid-o1"
}

Changes:
  ✓ sub preserved (still alice_id_2024)
  ✓ act added (payment-processor-v1)
  ✓ scope narrowed (only payments:initiate, removed accounts:read)
  ✓ exp shortened (900s vs. 3600s)
```

### Token 3: Tool Token (After Second Exchange)

```json
{
  "sub": "alice_id_2024",
  "act": {
    "sub": "risk-assessment-v1",
    "act": {
      "sub": "payment-processor-v1"
    }
  },
  "scope": "payments:initiate",
  "exp": "now+300",
  "jti": "uuid-r1"
}

Changes:
  ✓ sub preserved AGAIN (still alice_id_2024)
  ✓ act NESTED (not replaced):
      - outermost act.sub: risk-assessment-v1 (immediate caller)
      - inner act.act.sub: payment-processor-v1 (previous hop)
  ✓ scope unchanged (already narrowed)
  ✓ exp shortened further (300s for per-operation)

Full chain reconstructed: alice → payment-processor → risk-assessment
```

---

## Revocation Propagation Scenario

### Scenario: Alice Revokes at T+10min

```
Timeline:
T+0:     Alice authenticates, gets human_token (exp: T+60min)
T+2:     Orchestrator exchanges, gets orchestrator_token (exp: T+17min)
T+4:     RiskAssessment exchanges, gets tool_token (exp: T+9min)
T+5:     API 1 introspects tool_token → active:true ✓
T+10:    Alice revokes session via IS 7.3 console
T+10.5:  API 2 introspects orchestrator_token

Introspection at T+10.5min:
  IS 7.3 checks: is parent (human_token) revoked?
  Answer: YES (user revoked at T+10)
  IS 7.3 returns: active:false for orchestrator_token
  API 2 rejects the request ✓

Propagation:
  Tool token (tool_token):
    - Already expired at T+9min (5 min lifetime)
    - Next request using it: rejected (token expired)
    - Revocation is moot (token already dead)

  Orchestrator token (orchestrator_token):
    - Expires at T+17min
    - Revocation detected within introspection cache TTL (≤5min)
    - All APIs reject by T+15min ✓

  Risk API (second backend):
    - Introspection cache TTL: 5 min
    - Last introspection at T+5min → cached as active:true
    - At T+10min, still uses cached value (thinks token is active)
    - Cache expires at T+10min + TTL
    - If TTL = 5min, next introspection at T+10:05min detects revocation
    - Request at T+10:06min is rejected ✓

Compliance result: User revocation propagated to all APIs within 5–10 minutes.
```

---

## Key Points

1. **`sub` Preservation**: Every RFC 8693 exchange returns a token with the SAME `sub` claim as the subject_token. This traces every action back to Alice, preserving user accountability.

2. **`act` Nesting**: Each exchange **prepends** (not replaces) the current actor to the `act` chain. A 2-hop chain shows the full delegation path: `act.sub` (immediate caller) and `act.act.sub` (upstream caller).

3. **Scope Narrowing**: The first exchange narrows from `payments:initiate,accounts:read` to `payments:initiate`. The second exchange does not narrow further (already at minimum). This is least-privilege in action: each agent gets only the scope it needs.

4. **Token Lifetime Cascade**: human (3600s) > orchestrator (900s) > tool (300s). This ensures that if a downstream token is stolen, it expires before the upstream token could be re-exchanged for a new downstream token.

5. **Revocation Propagation**: Only if APIs use introspection (not local JWT validation). Introspection checks the exchange chain; a revoked parent token cascades to all derived tokens.
