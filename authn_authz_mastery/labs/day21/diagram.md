# Day 21 Lab — Delegation Chain Sequence Diagram

## 3-Tier Agent Delegation with Token Evolution

Annotate each token exchange with its resulting JWT claims:

```mermaid
sequenceDiagram
  actor User as User<br/>(jane_user_001)
  participant IS73 as IS 7.3<br/>(OAuth2 AS)
  participant Orch as Orchestrator<br/>(payment_orchestrator)
  participant Risk as RiskScorer Tool<br/>(risk_scorer)
  participant API as Payment API<br/>/v1/payments/initiate

  User->>IS73: 1. OIDC Login (App-Native Auth)
  IS73->>User: 2. human_token (JWT)<br/>sub=jane_user_001<br/>scope=payments:initiate,accounts:read<br/>exp=now+3600<br/>jti=uuid-1

  Orch->>IS73: 3. POST /oauth2/token<br/>grant_type=token-exchange<br/>subject_token=human_token<br/>actor_token=orchestrator_jwt<br/>scope=payments:initiate

  Note over IS73: Validates: human_token valid,<br/>orchestrator_jwt signed,<br/>actor trust policy allows<br/>payment_orchestrator

  IS73->>Orch: 4. orchestrator_token (JWT)<br/>sub=jane_user_001<br/>act={sub: payment_orchestrator}<br/>scope=payments:initiate<br/>exp=now+900<br/>jti=uuid-2

  Orch->>Risk: 5. Call RiskScorer<br/>"Assess payment risk"<br/>Needs orchestrator_token exchange

  Risk->>IS73: 6. POST /oauth2/token<br/>grant_type=token-exchange<br/>subject_token=orchestrator_token<br/>actor_token=risk_scorer_jwt<br/>scope=payments:initiate

  IS73->>Risk: 7. risk_scorer_token (JWT)<br/>sub=jane_user_001<br/>act={sub: risk_scorer,<br/>    act: {sub: payment_orchestrator}}<br/>scope=payments:initiate<br/>exp=now+300<br/>jti=uuid-3

  Risk->>API: 8. POST /v1/payments/initiate<br/>Authorization: Bearer risk_scorer_token

  API->>IS73: 9. POST /oauth2/introspect<br/>token=risk_scorer_token

  IS73->>API: 10. introspection_response<br/>active=true<br/>sub=jane_user_001<br/>act={sub: risk_scorer,<br/>    act: {sub: payment_orchestrator}}<br/>scope=payments:initiate<br/>exp=...<br/>iat=...

  Note over API: ✓ Validates:<br/>1. Token is active<br/>2. User is jane_user_001<br/>3. Full delegation chain recorded<br/>4. Scope limited to payments:initiate

  API->>Risk: 11. 200 OK<br/>{status: approved, risk: low}

  Risk->>Orch: 12. Risk assessment result

  Orch->>API: 13. POST /v1/payments/initiate<br/>(with orchestrator_token)

  API->>IS73: 14. Introspect orchestrator_token
  IS73->>API: 15. active=true,<br/>sub=jane_user_001,<br/>act={sub: payment_orchestrator}

  API->>Orch: 16. 201 Created<br/>{txn_id: TX-001,<br/> audit_chain: [jane_user_001,<br/>            payment_orchestrator,<br/>            risk_scorer]}

  Note over User,API: Audit trail complete:<br/>jane_user_001 → orchestrator → risk_scorer<br/>All tokens tracked via jti (uuid-1, uuid-2, uuid-3)
```

## Key Observations

- **Token lifetime strategy**: human=3600s, orchestrator=900s, tool=300s (each hop expires before parent could re-exchange)
- **`sub` preservation**: jane_user_001 remains constant across all three tokens
- **`act` growth**: each hop adds a new `act` level, preserving the previous chain
- **Scope**: all tokens carry the same `payments:initiate` scope (narrowed from user's broader `scope`)
- **Introspection**: the API validates every token against IS 7.3 — enables revocation propagation

## Revocation Scenario

If at T+100min Jane revokes her session:

```
User revokes → IS 7.3 marks human_token as revoked
Next introspection call on any derived token → IS 7.3 returns active=false
All three APIs reject the token within cache TTL (5min max)
```

Note: tool tokens with short exp (300s) may expire before revocation propagates — trade-off between security (short exp) and compliance (timely revocation).
