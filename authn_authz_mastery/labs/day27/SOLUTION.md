# Day 27 Lab — Solution

## Complete IS 7.3 Agent IdP Configuration

### deployment.toml — Global settings

```toml
[oauth]
allowed_grant_types = [
  "authorization_code",
  "refresh_token",
  "client_credentials",
  "urn:ietf:params:oauth:grant-type:token-exchange"
]

[oauth.token_exchange]
enable = true
max_actor_chain_depth = 3
introspection_cache_ttl_seconds = 300

[log.audit]
log_format = "structured"
```

**Explanation:**
- `allowed_grant_types`: Global declaration; each app decides which grants it uses
- `token_exchange.enable`: RFC 8693 token exchange is active
- `max_actor_chain_depth = 3`: Prevents runaway nesting (user → orch → tool → API, then stop)
- `introspection_cache_ttl_seconds = 300`: 5-minute cache; complies with banking requirement for timely revocation propagation
- `log.audit.log_format = "structured"`: JSON logging; `act.sub` is queryable as first-class field

### Agent DCR registration requests

**Agent 1: payment_orchestrator**

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <PLACEHOLDER: base64(admin:password)>

{
  "client_name": "payment_orchestrator",
  "description": "Orchestrator for payment workflows",
  "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<PLACEHOLDER: orchestrator.bank.com>:8443/.well-known/jwks.json",
  "response_types": [],
  "contacts": ["<PLACEHOLDER: ops@bank.com>"]
}
```

**IS 7.3 response:**
```json
{
  "client_id": "payment_orchestrator",
  "client_id_issued_at": 1696104000,
  "client_secret_expires_at": 0,
  "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"]
}
```

**Agent 2: risk_scorer**

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <PLACEHOLDER: base64(admin:password)>

{
  "client_name": "risk_scorer",
  "description": "Risk assessment tool",
  "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<PLACEHOLDER: risk-scorer.bank.com>:8443/.well-known/jwks.json",
  "response_types": [],
  "contacts": ["<PLACEHOLDER: security@bank.com>"]
}
```

**IS 7.3 response:**
```json
{
  "client_id": "risk_scorer",
  "client_id_issued_at": 1696104100,
  "client_secret_expires_at": 0,
  "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"]
}
```

**Why private_key_jwt?**
- No shared secrets to manage (Day 22)
- Agent's private key stays on-premises; only public key is shared
- Each agent has a distinct JWKS endpoint; IS 7.3 fetches and validates signatures per-agent

### Actor trust policies (per-application in Console)

**Console path:** Application → OAuth / OpenID Connect → Actor Trust

**Policy configuration (JSON):**

```json
{
  "application_id": "<PLACEHOLDER: payment-api-app-id>",
  "actor_trust_policies": [
    {
      "actor": "payment_orchestrator",
      "subject": "group:financial-users",
      "effect": "Allow",
      "description": "Production-ready; approved for regular customers"
    },
    {
      "actor": "payment_orchestrator",
      "subject": "group:admins",
      "effect": "Deny",
      "description": "Admins call APIs directly; no agent mediation for high-privilege"
    },
    {
      "actor": "risk_scorer",
      "subject": "group:financial-users",
      "effect": "Deny",
      "description": "New agent; pending security review"
    },
    {
      "actor": "risk_scorer",
      "subject": "group:admins",
      "effect": "Deny",
      "description": "Never approved for high-privilege group"
    },
    {
      "actor": "*",
      "subject": "group:super-admins",
      "effect": "Deny",
      "description": "Super-admins must authenticate directly; no agent delegation"
    }
  ]
}
```

**Policy interpretation:**
- `payment_orchestrator` + `group:financial-users` = Allow: orchestrator is approved for customer operations
- `payment_orchestrator` + `group:admins` = Deny: prevent orchestrator from elevating via admin token exchange
- `risk_scorer` + `group:financial-users` = Deny: risk_scorer not yet approved (policy blocks until security approves)
- `risk_scorer` + `group:admins` = Deny: redundant safety (defense in depth)
- `*` + `group:super-admins` = Deny: catch-all; no agents for super-admins

### Approval workflow — updating the policy

**Before security review:**
```
risk_scorer → group:financial-users: Deny
```

**After security team approves risk_scorer:**

Update the policy in Console:
```json
{
  "actor": "risk_scorer",
  "subject": "group:financial-users",
  "effect": "Allow",
  "description": "Security review complete; approved for production"
}
```

**Token exchange attempt by risk_scorer:**
- Before update: IS 7.3 returns `error=invalid_request` (policy denies)
- After update: IS 7.3 returns `error=invalid_request` (if risk_scorer's JWKS is not yet added) or succeeds (if JWKS is valid)

### Scope mapping — agent vs. user scopes

**User scopes (customer-initiated):**
- `payments:read` — read payment history
- `payments:write` — initiate payments (write permission)
- `accounts:read` — read account details
- `accounts:write` — modify account settings

**Agent scopes (orchestrator/tool-initiated):**
- `agent:payments:initiate` — agent can initiate payments (narrower than `payments:write`; specific to payment workflow)
- `agent:payments:read` — agent can read payment status (narrower than `payments:read`)
- `agent:accounts:read` — agent can read account balances (narrower than `accounts:read`)

**Token exchange request:**
```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<PLACEHOLDER: user_token_with_scope_payments:write>
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&actor_token=<PLACEHOLDER: orchestrator_jwt>
&actor_token_type=urn:ietf:params:oauth:token-type:jwt
&scope=agent:payments:initiate
&requested_token_type=urn:ietf:params:oauth:token-type:access_token
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: orchestrator_client_assertion>
```

**IS 7.3 validation:**
1. User token has `scope=payments:write` (broader)
2. Agent requests `scope=agent:payments:initiate` (narrower; specific to orchestrator)
3. IS 7.3 maps both to their base scope: `payments:write` ⊇ `agent:payments:initiate`? Yes → Exchange succeeds
4. Result token has `scope=agent:payments:initiate` (narrowed)

**APIM gateway enforcement:**
```yaml
- if token.scope contains "agent:": rate_limit(5000/min)  # higher for agents
- else: rate_limit(1000/min)  # user rate limit
```

### Audit logging — structured format

**Audit log entry (JSON) for successful exchange:**
```json
{
  "timestamp": "2026-10-01T10:15:30Z",
  "event_type": "token_exchange",
  "subject_client": "alice_001",
  "actor_client": "payment_orchestrator",
  "issued_scope": "agent:payments:initiate",
  "jti": "550e8400-e29b-41d4-a716-446655440000",
  "policy_result": "ALLOW",
  "http_status": 200
}
```

**Audit log entry for policy denial:**
```json
{
  "timestamp": "2026-10-01T10:15:31Z",
  "event_type": "token_exchange",
  "subject_client": "alice_001",
  "actor_client": "risk_scorer",
  "requested_scope": "agent:payments:read",
  "jti": "550e8400-e29b-41d4-a716-446655440001",
  "policy_result": "DENY",
  "http_status": 403,
  "error": "actor_not_authorized"
}
```

### Audit query examples

**Query 1: All exchanges by risk_scorer in past 24 hours**
```sql
SELECT timestamp, subject_client, actor_client, issued_scope, jti, policy_result
FROM is73_audit
WHERE actor_client = "risk_scorer"
  AND event_type = "token_exchange"
  AND timestamp >= now() - interval '24 hours'
ORDER BY timestamp DESC
```

**Result before security approval:**
- (empty — all attempts denied by policy)

**Result after security approval:**
- Rows showing `policy_result=ALLOW` + successful exchanges

**Query 2: Audit trail for user alice_001 by all agents**
```sql
SELECT timestamp, actor_client, issued_scope, jti, policy_result, http_status
FROM is73_audit
WHERE subject_client = "alice_001"
  AND actor_client IS NOT NULL
  AND event_type = "token_exchange"
  AND timestamp >= now() - interval '7 days'
ORDER BY timestamp DESC
```

**Query 3: Policy violations (denied exchanges)**
```sql
SELECT timestamp, subject_client, actor_client, policy_result, http_status
FROM is73_audit
WHERE policy_result = "DENY"
  AND event_type = "token_exchange"
  AND timestamp >= now() - interval '1 hour'
ORDER BY timestamp DESC
```

**Security team monitors this to detect:**
- Compromised agents attempting unauthorized exchanges
- Unregistered agents attempting token exchange (generic "agent_not_authorized" error)
- Attempts to exchange high-privilege tokens (group:admins, group:super-admins)

### Revocation chain — how user revocation propagates

**Step 1: User revokes session**
```
User action: "Sign out everywhere" in mobile app
→ Mobile app calls POST /oauth2/revoke with human_token
```

**Step 2: IS 7.3 marks token as revoked**
```
IS 7.3 audit log entry:
{
  "timestamp": "2026-10-01T10:16:00Z",
  "event_type": "token_revoke",
  "subject_client": "alice_001",
  "revoked_token_jti": "550e8400-e29b-41d4-a716-446655440000",
  "initiator": "alice_001"
}
```

**Step 3: Derived tokens are implicitly revoked**
- IS 7.3 does NOT explicitly revoke orchestrator_token or risk_scorer_token
- But IS 7.3 remembers the chain: orchestrator_token.subject = human_token.jti, and human_token is revoked
- When APIM or payment API calls introspect(orchestrator_token), IS 7.3 checks the chain

**Step 4: Next API call with orchestrator_token**
```
Payment API call:
POST /v1/payments/initiate
Authorization: Bearer <orchestrator_token>

Payment API calls:
POST /oauth2/introspect
token=<orchestrator_token>

IS 7.3 response:
{
  "active": false,
  "error": "invalid_token",
  "error_description": "Subject token revoked"
}

Payment API logs rejection and returns 401 Unauthorized
```

**Result:** User revocation propagates to all derived agent tokens within the introspection cache TTL (300s = 5 minutes).

## Key Takeaways

1. **Actor trust policy** is the security gate: which agents can exchange which user tokens
2. **Scope narrowing** happens at exchange time: agents request narrower scopes; IS 7.3 validates the narrowing
3. **Structured audit logging** makes agent calls traceable: query by `actor_client`, `subject_client`, `jti`
4. **Revocation propagates** via introspection chain check: user revocation invalidates all derived tokens
5. **Approval workflow** can be dynamic: security team updates policies without redeploying agents
