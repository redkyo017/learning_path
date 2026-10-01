# Day 21 Lab — Solution

## Token Payloads at Each Hop

### 1. Human Token (User → IS 7.3)

```json
{
  "sub": "jane_user_001",
  "aud": "https://api.bank.local/v1",
  "iss": "https://is.bank.local:9443/oauth2/token",
  "scope": "payments:initiate accounts:read",
  "exp": 1726845600,
  "iat": 1726842000,
  "jti": "uuid-1-human-token"
}
```

**Claims breakdown:**
- `sub=jane_user_001`: The human user who initiated the session
- `scope`: Maximum scope for this session (both payment initiation and account read)
- `exp`: 1 hour from now (typical human session duration)
- `jti`: Unique token ID for audit trail correlation

### 2. Orchestrator Exchange Token (User → Orchestrator)

Orchestrator calls IS 7.3:
```
POST /oauth2/token
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
subject_token=uuid-1-human-token
subject_token_type=urn:ietf:params:oauth:token-type:access_token
actor_token=<orchestrator-signed-jwt>
actor_token_type=urn:ietf:params:oauth:token-type:jwt
scope=payments:initiate
requested_token_type=urn:ietf:params:oauth:token-type:access_token
client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
client_assertion=<orchestrator-client-assertion>
```

Result token:
```json
{
  "sub": "jane_user_001",
  "act": {
    "sub": "payment_orchestrator"
  },
  "aud": "https://api.bank.local/v1",
  "iss": "https://is.bank.local:9443/oauth2/token",
  "scope": "payments:initiate",
  "exp": 1726845900,
  "iat": 1726845000,
  "jti": "uuid-2-orchestrator-token",
  "azp": "payment_orchestrator"
}
```

**Key changes:**
- `sub` **preserved** as `jane_user_001` (user remains traceable)
- `act` **added**: `{"sub": "payment_orchestrator"}` (records the orchestrator's identity)
- `scope` **narrowed** to `payments:initiate` only (orchestrator doesn't need account read)
- `exp` shortened to 900s (15 minutes — short-lived delegation)
- `azp`: authorized party (the OAuth2 client that received this token)

### 3. RiskScorer Tool Token (Orchestrator → Tool)

Tool calls IS 7.3:
```
POST /oauth2/token
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
subject_token=uuid-2-orchestrator-token
subject_token_type=urn:ietf:params:oauth:token-type:access_token
actor_token=<risk-scorer-signed-jwt>
actor_token_type=urn:ietf:params:oauth:token-type:jwt
scope=payments:initiate
requested_token_type=urn:ietf:params:oauth:token-type:access_token
client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
client_assertion=<risk-scorer-client-assertion>
```

Result token (2-hop nested `act`):
```json
{
  "sub": "jane_user_001",
  "act": {
    "sub": "risk_scorer",
    "act": {
      "sub": "payment_orchestrator"
    }
  },
  "aud": "https://api.bank.local/v1",
  "iss": "https://is.bank.local:9443/oauth2/token",
  "scope": "payments:initiate",
  "exp": 1726845300,
  "iat": 1726845000,
  "jti": "uuid-3-tool-token",
  "azp": "risk_scorer"
}
```

**Key changes:**
- `sub` **still** `jane_user_001` (user identity preserved through 2 hops)
- `act` **nested**: `{"sub": "risk_scorer", "act": {"sub": "payment_orchestrator"}}` (full chain recorded)
- Each hop is recorded in the chain — API can read full delegation path
- `exp` shortened to 300s (5 minutes — per-operation token)
- `jti` unique for this exchange (enables transaction-level correlation)

## Completed Comparison Table

| Dimension | `client_credentials` | Impersonation (Raw Token) | OBO (RFC 8693) |
|-----------|----------------------|---------------------------|----------------|
| **Audit Trail — What does `sub` record?** | `sub`=client_id (service account). No user context. Auditor cannot answer "who authorized?" | `sub`=user (from passed token). But `azp` still shows user, not agent. Agent is invisible. Auditor sees only user actions. | `sub`=user (preserved). `act`=agent_id (nested per hop). Full chain visible: user → agent1 → agent2. Auditor can answer all three questions. |
| **Scope Control — min/max** | MAX: agent inherits full client scope. If agent is compromised, attacker has full service account permissions. No per-operation narrowing. | MAX: agent receives user's full scope (e.g., `payments:write+read`, `accounts:read+write`). A tool that only reads gets write permission. | MIN: per-exchange scope narrowing. Risk scorer requests only `payments:initiate`. IS 7.3 enforces: requested_scope ⊆ subject_token.scope. |
| **Revocation Granularity** | Revoke client → affects all agent instances equally. No per-session revocation. | Revoke user token → all agents lose access. But revocation is not recorded in audit (agent was invisible). No audit trail of which agents were affected. | Revoke user token → all derived agent tokens revoked via introspection within 5min cache TTL. Per-user revocation is auditable. Independent users' tokens unaffected. |
| **Confused Deputy Risk** | LOW risk but wrong reason: agent has no user context, so no confusion possible. But also NO user authorization recorded (breaks compliance). | HIGH: agent inherited full user scope and user identity. Prompt-injected agent can call any API the user can access with full scope. No `act` claim to identify the compromised agent. | LOW: `act.sub` identifies agent. IS 7.3 actor trust policy restricts which agents can exchange. Scope narrowing limits blast radius: compromised tool cannot escalate to full user scope. |
| **Regulatory Compliance (Banking)** | FAIL: cannot prove human user authorized payment. Service account tokens are not part of consent/revocation framework. Audit log shows only service account. | FAIL: agent is not an auditable principal in token. Audit log shows user actions, but not that an agent performed them. Cannot distinguish "user clicked" vs. "agent initiated on behalf of user." | PASS: every call traces to user + full agent chain. Agents are first-class OAuth2 principals. Fits into IS 7.3 consent + revocation governance. Token `jti` enables transaction-level audit correlation across all APIs. |
| **Token Lifetime Strategy** | N/A: service accounts use long-lived credentials or refresh tokens. Compromise window can be hours. | N/A: agent inherits user token lifetime (1+ hour). If agent is compromised, attacker has user-level access for up to 1h (or until session revoked). | SHORT: human=3600s, orchestrator=900s, tool=300s. Compromise window reduces at each hop. Tool token useless after 5 min even if stolen. |

## Key Takeaways

1. **`sub` preservation is critical**: Every RFC 8693 exchange must preserve the original user's `sub` claim. This ensures the full delegation chain can be traced back to the human who initiated the session.

2. **`act` nesting records the chain**: Each exchange adds a new `act` level. A 3-hop chain (user → orchestrator → tool → API) creates an `act` structure three levels deep. The API can traverse this to identify every principal in the chain.

3. **Scope narrowing prevents escalation**: The RiskScorer tool only needs `payments:initiate`, not the full `payments:initiate+accounts:read` that the user has. IS 7.3 enforces that the exchanged token's scope is a subset of the subject_token's scope.

4. **Token lifetime trade-offs**:
   - Shorter `exp` reduces compromise window but requires frequent token refreshes
   - Tool tokens (300s) expire before orchestrator tokens (900s), which expire before human tokens (3600s)
   - Each hop's token should expire before the parent could be used to re-exchange (defend against chain-poisoning attacks)

5. **Revocation propagation requires introspection**: APIs must call `POST /oauth2/introspect` to validate tokens, not just verify JWT signatures locally. Only introspection checks the exchange chain and detects revoked parent tokens.

## Audit Trail Reconstruction

Given the token payloads above, here's how a compliance officer reconstructs a transaction:

1. **Find transaction TX-001** in Payment API logs
2. **Extract token `jti`**: `uuid-3-tool-token`
3. **Query IS 7.3 audit log** for token issuance event with `jti=uuid-3-tool-token`
4. **Find the exchange chain**:
   - `subject_token` had `jti=uuid-2-orchestrator-token`
   - That token was issued via exchange with `subject_token` `jti=uuid-1-human-token`
   - `uuid-1-human-token` was issued to `jane_user_001` via OIDC login
5. **Reconstruct chain**: jane_user_001 → OIDC login → human token → orchestrator exchange → orchestrator token → tool exchange → tool token → TX-001 ✓

**Compliance answer**: Transaction TX-001 was authorized by user jane_user_001 and executed by the risk_scorer tool via the payment_orchestrator orchestrator.
