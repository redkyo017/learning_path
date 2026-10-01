# Day 27 Lab — Agent IdP Configuration Diagram

## IS 7.3 Agent Policy Enforcement Flow

```mermaid
sequenceDiagram
  actor User as User<br/>(alice_001)<br/>group:financial-users
  participant IS73 as IS 7.3<br/>(OAuth2 AS)
  participant Orch as Orchestrator<br/>(payment_orchestrator)
  participant Risk as RiskScorer<br/>(risk_scorer)
  participant API as Payment API<br/>/v1/payments/initiate

  User->>IS73: 1. OIDC Login<br/>(App-Native Auth, Day 11)
  IS73->>User: 2. human_token (JWT)<br/>sub=alice_001<br/>scope=payments:initiate<br/>exp=now+3600<br/>jti=uuid-1

  Orch->>IS73: 3. Token Exchange<br/>grant_type=token-exchange<br/>subject_token=human_token<br/>actor_token=<orchestrator_jwt>

  Note over IS73: 4. IS 7.3 checks<br/>actor trust policy:<br/>actor=payment_orchestrator<br/>subject=alice_001 ∈ group:financial-users?<br/>→ Policy allows → Exchange succeeds

  IS73->>Orch: 5. orchestrator_token (JWT)<br/>sub=alice_001<br/>act={sub: payment_orchestrator}<br/>scope=payments:initiate<br/>exp=now+900<br/>jti=uuid-2

  Risk->>IS73: 6. Token Exchange attempt<br/>grant_type=token-exchange<br/>subject_token=human_token<br/>actor_token=<risk_scorer_jwt>

  Note over IS73: 7. IS 7.3 checks<br/>actor trust policy:<br/>actor=risk_scorer<br/>subject=alice_001 ∈ group:financial-users?<br/>→ Policy denies (not yet approved)<br/>→ Exchange FAILS

  IS73->>Risk: 8. 400 Bad Request<br/>error=invalid_request<br/>error_description=actor_not_authorized

  Note over User,API: Policy enforcement blocks<br/>unapproved risk_scorer

  rect rgb(200, 150, 255)
    Note over IS73: Later: Security team approves risk_scorer
    IS73->>IS73: 9. Update actor trust policy<br/>to allow risk_scorer
  end

  Risk->>IS73: 10. Token Exchange (retry)<br/>grant_type=token-exchange<br/>subject_token=human_token<br/>actor_token=<risk_scorer_jwt>

  Note over IS73: 11. IS 7.3 checks policy<br/>(now updated)<br/>→ Policy allows → Exchange succeeds

  IS73->>Risk: 12. risk_scorer_token (JWT)<br/>sub=alice_001<br/>act={sub: risk_scorer}<br/>scope=payments:initiate<br/>exp=now+300<br/>jti=uuid-3

  Risk->>API: 13. API call with risk_scorer_token

  API->>IS73: 14. Introspect risk_scorer_token

  IS73->>API: 15. introspection response<br/>active=true<br/>sub=alice_001<br/>act={sub: risk_scorer}<br/>scope=payments:initiate

  Note over API: ✓ Valid: user=alice_001,<br/>agent=risk_scorer, scope verified
```

## Revocation Propagation with Actor Trust

```mermaid
sequenceDiagram
  actor User as User<br/>(alice_001)
  participant IS73 as IS 7.3<br/>(OAuth2 AS)
  participant API as Payment API

  User->>IS73: 1. Revoke session<br/>POST /oauth2/revoke

  IS73->>IS73: 2. Mark human_token as revoked<br/>AND all derived tokens<br/>(orchestrator_token, risk_scorer_token)

  Orch->>API: 3. API call<br/>(orchestrator has token from before revocation)

  API->>IS73: 4. Introspect orchestrator_token

  IS73->>API: 5. introspection response<br/>active=false<br/>(chain broken: parent token revoked)

  API->>Orch: 6. 401 Unauthorized

  Note over User,API: Revocation propagates<br/>within cache TTL (5min)
```

## Actor Trust Policy Matrix

| Agent | Subject Group | Policy Effect | Justification |
|-------|---------------|---------------|---------------|
| `payment_orchestrator` | `group:financial-users` | **Allow** | Trusted, production-ready agent; operates on behalf of regular customers |
| `payment_orchestrator` | `group:admins` | **Deny** | Orchestrator should not exchange admin tokens; admins call APIs directly, not via agent |
| `risk_scorer` | `group:financial-users` | **Deny** (initially) | New agent; awaiting security review before production |
| `risk_scorer` | `group:admins` | **Deny** | Not approved for any user group yet |
| (any agent) | (special groups like `group:super-admins`) | **Deny** | No agents should exchange high-privilege tokens; high-risk users must authenticate directly |

## Key Observations

- **Per-actor, per-subject policy:** Granular control; not all agents approved for all users
- **Approval workflow:** Risk scorer starts with Deny; once security approves, change to Allow
- **Revocation propagates:** User revokes → next introspection returns `active: false` → all derived tokens rejected
- **Audit trail:** IS 7.3 logs each exchange attempt (success or failure) with `sub`, `act`, `jti` for tracing
- **Scope separation:** Agent scopes (e.g., `agent:payments:initiate`) separate from user scopes; APIM gateway applies different rate limits

## Audit Log Query Example

After the flow completes, the IS 7.3 audit log contains:

```json
{
  "timestamp": "2026-10-01T10:15:00Z",
  "event_type": "token_exchange",
  "subject_client": "alice_001",
  "actor_client": "payment_orchestrator",
  "issued_scope": "payments:initiate",
  "jti": "uuid-2",
  "policy_result": "ALLOW"
}
```

Query: Find all token exchanges by `risk_scorer` for `alice_001`:

```sql
SELECT timestamp, actor_client, issued_scope, jti, policy_result
FROM is73_audit
WHERE subject_client = "alice_001"
  AND actor_client = "risk_scorer"
  AND event_type = "token_exchange"
ORDER BY timestamp DESC
```

Result: Initially empty (Deny policy rejected the exchange). After security approval and policy update, future exchanges are logged with `policy_result=ALLOW`.
