# Day 28 Lab — End-to-End Delegation Chain Diagram

## Complete 6-Step Banking AI Agent Flow

```mermaid
sequenceDiagram
  actor User as User<br/>(alice_001)
  participant Mobile as Mobile App
  participant IS73 as IS 7.3<br/>(OAuth2 AS)
  participant Orch as Orchestrator<br/>(payment_orchestrator)
  participant Risk as RiskScorer Tool<br/>(risk_scorer)
  participant AC as AgentCore<br/>(SigV4 proxy)
  participant API as Payment API<br/>/v1/payments/initiate

  User->>Mobile: 1. Initiate payment<br/>Amount: $1000
  Mobile->>IS73: 2. OIDC Login (App-Native Auth)
  IS73->>Mobile: human_token (JWT)<br/>sub=alice_001<br/>scope=payments:read payments:write accounts:read<br/>exp=now+3600<br/>jti=550e8400-e29b-41d4-a716-446655440000

  Mobile->>Orch: 3. User intent + human_token
  Orch->>IS73: POST /oauth2/token<br/>grant_type=token-exchange<br/>subject_token=human_token<br/>actor_token=<orchestrator_jwt><br/>scope=agent:payments:initiate

  IS73->>IS73: Validate:<br/>human_token active?<br/>orchestrator_jwt signed?<br/>actor trust policy allows?

  IS73->>Orch: orchestrator_token (JWT)<br/>sub=alice_001<br/>act={sub: payment_orchestrator}<br/>scope=agent:payments:initiate<br/>exp=now+900<br/>jti=550e8400-e29b-41d4-a716-446655440001

  Orch->>Risk: 4. Decompose task<br/>Call RiskScorer<br/>Pass orchestrator_token

  Risk->>IS73: POST /oauth2/token<br/>grant_type=token-exchange<br/>subject_token=orchestrator_token<br/>actor_token=<risk_scorer_jwt><br/>scope=agent:payments:initiate

  IS73->>IS73: Validate:<br/>orchestrator_token active?<br/>risk_scorer_jwt signed?<br/>actor trust policy allows?

  IS73->>Risk: risk_scorer_token (JWT)<br/>sub=alice_001<br/>act={sub: risk_scorer, act: {sub: payment_orchestrator}}<br/>scope=agent:payments:initiate<br/>exp=now+300<br/>jti=550e8400-e29b-41d4-a716-446655440002

  Risk->>AC: 5. API call<br/>POST /v1/payments/initiate<br/>Authorization: Bearer risk_scorer_token

  AC->>AC: SigV4 sign request<br/>Extract session tags:<br/>userId=alice_001<br/>agentId=risk_scorer<br/>sessionId=<PLACEHOLDER: session-uuid>

  AC->>API: Forward request<br/>Authorization: Bearer risk_scorer_token<br/>X-AgentCore-Caller-Identity: {...session tags...}

  API->>IS73: 6a. POST /oauth2/introspect<br/>token=risk_scorer_token

  IS73->>IS73: Check token validity<br/>Check delegation chain<br/>(human → orch → tool)

  IS73->>API: introspection_response<br/>active=true<br/>sub=alice_001<br/>act={sub: risk_scorer, act: {sub: payment_orchestrator}}<br/>scope=agent:payments:initiate<br/>aud=payment-api<br/>exp=1696105229<br/>jti=550e8400-e29b-41d4-a716-446655440002

  Note over API: ✓ Validate delegation chain<br/>✓ Verify scope<br/>✓ Log jti + agentcore_session_id

  API->>API: Process payment<br/>User=alice_001<br/>Agent chain=[risk_scorer, payment_orchestrator]<br/>Log: {<br/>  txn_id: PAY-001,<br/>  jti: 550e8400-e29b-41d4-a716-446655440002,<br/>  agentcore_session_id: <session-uuid>,<br/>  amount: 1000.00<br/>}

  API->>Risk: 6b. 201 Created<br/>{txn_id: PAY-001, status: approved}

  Risk->>Orch: Risk assessment result

  Orch->>Mobile: Payment result
  Mobile->>User: 6c. Confirmation<br/>Payment processed ($1000 sent)

  Note over User,API: Audit trail complete:<br/>jti=550e8400-e29b-41d4-a716-446655440002<br/>Traceable across IS 7.3 audit, AgentCore CloudTrail, Payment API log
```

## Token Payload Evolution

| Step | Token Name | `sub` | `act` | `scope` | `exp` | `jti` |
|------|-----------|-------|-------|---------|-------|-------|
| 2 | human_token | `alice_001` | (none) | `payments:read payments:write accounts:read` | now+3600 | `uuid-0` |
| 4 | orchestrator_token | `alice_001` | `{sub: payment_orchestrator}` | `agent:payments:initiate` | now+900 | `uuid-1` |
| 5 | risk_scorer_token | `alice_001` | `{sub: risk_scorer, act: {sub: payment_orchestrator}}` | `agent:payments:initiate` | now+300 | `uuid-2` |

## Introspection Response (Step 6a)

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
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "client_id": "risk_scorer",
  "token_type": "Bearer"
}
```

**What this proves:**
- `active: true` — token is not revoked
- `sub: alice_001` — original user is preserved
- `act` chain — full delegation chain is visible (risk_scorer ← payment_orchestrator ← user)
- `jti` — unique correlation ID for audit trail reconstruction
- `exp` — token expires in 5 minutes (minimal blast radius for a compromised tool)

## Audit Trail Reconstruction

### Payment API transaction log (Step 6b)

```json
{
  "timestamp": "2026-10-01T10:15:30Z",
  "txn_id": "PAY-001",
  "user_sub": "alice_001",
  "act_chain": ["risk_scorer", "payment_orchestrator"],
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "agentcore_session_id": "<PLACEHOLDER: session-uuid>",
  "status": "approved",
  "amount": 1000.00,
  "currency": "USD"
}
```

### IS 7.3 audit log (token exchanges)

**Entry 1: First exchange (user → orchestrator)**
```json
{
  "timestamp": "2026-10-01T10:15:10Z",
  "event_type": "token_exchange",
  "subject_client": "alice_001",
  "actor_client": "payment_orchestrator",
  "issued_scope": "agent:payments:initiate",
  "jti": "550e8400-e29b-41d4-a716-446655440001",
  "policy_result": "ALLOW"
}
```

**Entry 2: Second exchange (orchestrator → tool)**
```json
{
  "timestamp": "2026-10-01T10:15:15Z",
  "event_type": "token_exchange",
  "subject_client": "alice_001",
  "actor_client": "risk_scorer",
  "issued_scope": "agent:payments:initiate",
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "policy_result": "ALLOW"
}
```

### AgentCore CloudTrail (API call)

```json
{
  "eventTime": "2026-10-01T10:15:25Z",
  "eventName": "AssumeRole",
  "sourceIPAddress": "<PLACEHOLDER: agent-ip>",
  "requestParameters": {
    "roleArn": "arn:aws:iam::<PLACEHOLDER: account>:role/RiskScorerRole",
    "roleSessionName": "<PLACEHOLDER: session-uuid>"
  },
  "responseElements": {
    "credentials": {
      "sessionToken": "<PLACEHOLDER: sts-token>"
    }
  },
  "additionalEventData": {
    "sessionTags": {
      "userId": "alice_001",
      "agentId": "risk_scorer",
      "sessionId": "<PLACEHOLDER: session-uuid>"
    }
  }
}
```

## Revocation Scenario

```mermaid
sequenceDiagram
  actor User
  participant IS73 as IS 7.3
  participant API as Payment API

  User->>IS73: 1. At T+60min: Revoke session<br/>POST /oauth2/revoke

  IS73->>IS73: Mark human_token as revoked<br/>(jti=550e8400-e29b-41d4-a716-446655440000)

  rect rgb(255, 200, 200)
    Note over User,IS73: T+62min: Tool tries to exchange<br/>orchestrator_token
  end

  Risk->>IS73: 2. Exchange request<br/>subject_token=orchestrator_token<br/>(jti=550e8400-e29b-41d4-a716-446655440001)

  IS73->>IS73: 3. Check exchange validity<br/>orchestrator_token.exp > now?<br/>Yes, token not expired<br/>BUT: Check parent chain<br/>orchestrator_token.subject = human_token<br/>human_token.revoked?<br/>YES → DENY

  IS73->>Risk: 4. 400 Bad Request<br/>error=invalid_request<br/>error_description=subject_token_revoked

  Note over Risk,API: Exchange fails<br/>Tool cannot get a new token<br/>Revocation propagated
```

## Cache Strategy Impact

| Scenario | API Behavior | Result |
|----------|--------------|--------|
| **No cache** | Introspect every request | Fast revocation (<100ms), high IS 7.3 load |
| **5min cache** | Introspect, cache result | Revocation latency ~5min, reduced IS 7.3 load; complies with banking requirement |
| **1h cache** | Introspect, cache result | Revocation latency ~60min; banking compliance violation |

**Banking compliance requirement:** Revocation must propagate within 5 minutes. 5-minute cache meets this requirement:
- User revokes at T
- Next introspection at T+0 to T+5 may use cached result (old: `active=true`)
- Introspection at T+5 onwards hits cache expiry; new query returns `active=false`
- All existing tokens rejected within 5min window

## Key Observations

- **`jti` correlation** — all three systems log `jti` or a derivative (`agentcore_session_id` links to CloudTrail)
- **`sub` preservation** — user identity is preserved at every hop; APIs know which user initiated the action
- **`act` growth** — each hop adds a nesting level; full chain is visible at the API
- **Scope narrowing** — orchestrator narrowed from user's full scope; tool inherits orchestrator's already-narrowed scope
- **Revocation chain** — user revocation breaks the parent token, preventing further exchanges or introspections
- **Lifetime hierarchy** — human (3600s) > orchestrator (900s) > tool (300s); each expires before parent could cause damage
