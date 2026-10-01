# Day 27 — WSO2 IS 7.3 as Agent IdP

## Why this matters

A bank deploys an AI payment agent. All the security architecture is sound: RFC 8693 token exchange (Day 23), AgentCore gateway (Day 24), MCP service auth (Day 26). But during a compliance audit, the regulator asks: "If we revoke a user's consent, do the agent's delegated tokens get revoked?" The security team realizes: agent tokens are registered as OAuth2 clients, but agent policies aren't enforced at the IS 7.3 level. Any agent can exchange any user token. A rogue agent could escalate privileges by exchanging a high-privilege user's token. IS 7.3's token exchange grant + agent policy enforcement makes AI agents first-class principals under the bank's existing identity governance — revoking a user's consent now revokes derived agent tokens automatically.

## Core concepts

### 1. IS 7.3 token exchange grant — enabling per-application

RFC 8693 token exchange is not enabled by default in IS 7.3. Enable it in two places:

- **Global** (deployment.toml): `[oauth]` section declares support
- **Per-application** (Console or DCR): each app that uses token exchange must explicitly opt in
- **DCR field**: `"grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"]`

Without per-application enablement, IS 7.3 silently rejects exchange requests with `unsupported_grant_type`.

### 2. Agent client registration via DCR

An agent is a first-class OAuth2 client in IS 7.3. Register via Dynamic Client Registration (DCR):

```
POST /api/identity/oauth2/dcr/v1.1/register
{
  "client_name": "payment_orchestrator",
  "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<agent-host>/.well-known/jwks.json"
}
```

IS 7.3 returns `client_id` (e.g., `"client_id": "payment_orchestrator"`). This `client_id` appears as `act.sub` in exchange tokens.

### 3. Agent policy enforcement — restricting which agents can exchange which users

Token exchange is not unconditional. IS 7.3 enforces an **actor trust policy**: which agent client_ids can exchange for which user groups/roles.

**Policy structure (per-application in Console):**
- Application X → Actor Trust → Add Policy
- Actor: `payment_orchestrator` (agent client_id)
- Subject: `group:financial-users` (user group or role)
- Effect: Allow

Without this policy, IS 7.3 may allow any authenticated agent to exchange any user token.

**Alternative:** Configure via `deployment.toml`:
```toml
[oauth.token_exchange]
actor_trust_enable = true
# Per-app policies in Console; no TOML syntax for fine-grained policy (use Console)
```

### 4. Scope mapping for agent principals

Distinguish agent-originated calls from user-originated calls by scope. Define separate scopes:

- **User scope**: `payments:initiate` (user calling payment API directly)
- **Agent scope**: `agent:payments:initiate` (agent calling on behalf of user)

IS 7.3 preserves whichever scope the exchange request specifies. The APIM gateway or payment API uses scope to apply different rate limits, SLAs, or audit trails per principal type.

### 5. Audit log tagging — making agent calls traceable

IS 7.3 audit log records all token exchange events. To make agent calls traceable, the log must record:

- `sub` — the user being delegated to
- `act.sub` — the agent exchanging
- `azp` — authorized party (the OAuth2 client receiving the token)
- `jti` — unique token ID for correlation

**Configuration (deployment.toml):**
```toml
[log.audit]
log_format = "structured"  # Enables JSON logging
```

With structured logging, parse `act.sub` as a dedicated field for queries like: `act.sub="risk_scorer" AND timestamp > now-1h` (all risk_scorer calls in the past hour).

### 6. IS 7.3 token exchange grant configuration

**In Console (preferred for per-app control):**
- Application → OAuth / OpenID Connect → Allowed Grant Types
- Check: `urn:ietf:params:oauth:grant-type:token-exchange`

**In deployment.toml (global):**
```toml
[oauth]
allowed_grant_types = ["authorization_code", "refresh_token", "urn:ietf:params:oauth:grant-type:token-exchange"]

[oauth.token_exchange]
# Optional: actor trust policies can also be configured here (advanced)
# Most deployments use Console for per-app actor trust
```

## WSO2 IS 7.3 / AgentCore mapping

### IS 7.3 deployment.toml additions for token exchange + agent policy

See `labs/day27/config/agent_idp_deployment.toml` for a complete annotated deployment.toml snippet showing:
1. Global token exchange grant enablement
2. Per-application actor trust policy (described via JSON config example)
3. Audit log structured format for agent call tracing

### Agent client DCR request (private_key_jwt auth)

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <PLACEHOLDER: admin-credentials-base64>

{
  "client_name": "payment_orchestrator",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange"
  ],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<PLACEHOLDER: orchestrator-host>/.well-known/jwks.json",
  "response_types": [],
  "contacts": ["<PLACEHOLDER: ops-email>"]
}
```

IS 7.3 responds:
```json
{
  "client_id": "payment_orchestrator",
  "client_secret": null,
  "client_id_issued_at": 1696104000,
  "client_secret_expires_at": 0,
  "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"]
}
```

### Agent policy configuration (via Console or config API)

Once the agent is registered (client_id = `payment_orchestrator`), configure its actor trust policy:

**Console path:** Application → OAuth / OpenID Connect → Actor Trust

**Policy entry (JSON):**
```json
{
  "application_id": "<PLACEHOLDER: app-id>",
  "actor_trust_policies": [
    {
      "actor": "payment_orchestrator",
      "subject": "group:financial-users",
      "effect": "Allow"
    },
    {
      "actor": "risk_scorer",
      "subject": "group:financial-users",
      "effect": "Allow"
    }
  ]
}
```

**Semantics:** Only agents `payment_orchestrator` and `risk_scorer` are permitted to exchange tokens on behalf of users in `group:financial-users`. If a user in `group:admins` attempts to use `payment_orchestrator`, IS 7.3 may reject the exchange.

### Agent scope mapping in APIM gateway

Once the agent gets an exchange token with `scope=agent:payments:initiate`, the APIM gateway enforces different SLAs:

```yaml
# APIM policy: rate limiting by scope
- if scope contains "agent:": apply rate_limit(1000/min)  # agent rate limit
- else: apply rate_limit(100/min)  # user rate limit
```

### AgentCore mapping

AgentCore agents (Bedrock-based) authenticate to IS 7.3 using `private_key_jwt` (Day 22). Each agent's IAM role carries a distinct service principal identifier, which maps to a distinct IS 7.3 client_id.

```
Bedrock Agent → AgentCore vends STS credentials → Bedrock signs JWT with STS key
→ JWT includes agent_id as `iss`/`sub` → IS 7.3 validates against OIDC provider
→ IS 7.3 exchanges for user token with `act.sub=agent_id`
```

## Anti-patterns

1. **No actor trust policy — IS 7.3 allows any authenticated agent to exchange any user token** — a compromised low-privilege agent can escalate by exchanging a high-privilege user's token. Example: a `risk_scorer` agent (limited scope) is compromised and uses its authenticated session to exchange a SUPER_ADMIN's token. Without a policy restricting `risk_scorer` to `group:financial-users` only, the exchange succeeds, and the attacker gets a high-privilege delegated token. Fix: define actor trust policies per-application; restrict each agent to specific user groups.

2. **Agent scopes overlapping with human scopes — the APIM gateway can't distinguish agent-originated calls from user calls** — rate limiting, audit trails, and fraud detection become indistinguishable. Example: both human and agent use `scope=payments:initiate`; if an agent is compromised and makes fraudulent calls, the audit log shows `scope=payments:initiate` (same as legitimate users), making it hard to correlate fraud to a specific agent. Fix: define separate scopes like `agent:payments:initiate` for agents; the APIM gateway and audit log can then filter and analyze agent calls separately.

3. **Not tagging agent calls in IS 7.3 audit log — the question "which agent made this call?" requires a full log scan** — compliance officers cannot quickly prove whether a specific agent was involved in a fraud incident. Example: Bank needs to audit all calls by `risk_scorer` agent in the past 24 hours; without `act.sub` indexed as a structured field, the audit system must scan all 10M tokens issued in that period and parse each JWT to extract `act.sub`. Fix: enable structured JSON audit logging in IS 7.3; parse `act.sub` as a first-class field; queries then run in milliseconds instead of hours.

## Exercises

**Exercise 1:** A bank has two agents: `payment_orchestrator` (trusted, carefully tested) and `risk_scorer` (new, not yet approved by security). Both are registered in IS 7.3 with token exchange grant enabled. A user in `group:financial-users` attempts to initiate a payment using `payment_orchestrator`. The exchange succeeds. Then, during testing, the same user attempts to use `risk_scorer` (which has not been approved by the security team). Without an explicit actor trust policy, what happens? How does a policy fix this?

**Hint:** Actor trust policies restrict which agents can exchange for which users. What does "no policy" mean?

**Solution sketch:** Without an explicit policy, IS 7.3 may allow the exchange. Both agents get delegated tokens for the same user. If `risk_scorer` is compromised or malfunctioning, the bank has no enforcement mechanism to block it. Fix: Configure an actor trust policy in IS 7.3 that allows `payment_orchestrator` to exchange for `group:financial-users` but denies `risk_scorer` (or allows only after explicit approval). Policy entry:
```json
{
  "actor": "risk_scorer",
  "subject": "group:financial-users",
  "effect": "Deny"
}
```
Subsequent exchange requests from `risk_scorer` will be rejected with `invalid_request` or `invalid_scope` (policy-enforced). The policy can be updated to `"effect": "Allow"` once `risk_scorer` passes security review.

---

**Exercise 2:** Design agent scopes for a banking payment API. The API has three use cases: (1) a user calling directly, (2) an orchestrator agent, (3) a specialized risk-scoring tool. Should all three use the same scope or different scopes? Justify your choice with an example of how the APIM gateway would enforce different behavior.

**Hint:** scope is visible to APIM and audit logs; use it to distinguish principals.

**Solution sketch:** Define separate scopes:
- User: `payments:initiate` (1000 calls/hour rate limit)
- Orchestrator: `agent:payments:initiate` (5000 calls/hour, higher limit because it aggregates many user requests)
- Risk scorer: `agent:payments:risk-assess` (10000 calls/hour, separate limit for a high-volume tool)

APIM gateway policy:
```yaml
- if scope == "payments:initiate": rate_limit(1000/hour, per_user_id)
- if scope == "agent:payments:initiate": rate_limit(5000/hour, per_agent_id)
- if scope == "agent:payments:risk-assess": rate_limit(10000/hour, per_agent_id)
```

Audit log query: `SELECT * FROM audit_log WHERE scope LIKE "agent:%" AND timestamp > now-1h` (all agent calls in the past hour). Without scope separation, queries become ambiguous.

---

**Exercise 3:** An auditor needs to answer: "What calls did the `risk_scorer` agent make on behalf of user `alice_001` in the past 24 hours?" Assume IS 7.3 audit log is structured (JSON). Write a pseudocode query to answer this question.

**Hint:** IS 7.3 audit log records `sub` (user), `act.sub` (agent), and `timestamp` as structured fields.

**Solution sketch:**
```sql
SELECT jti, act.sub, scope, timestamp FROM audit_log
WHERE sub = "alice_001"
  AND act.sub = "risk_scorer"
  AND timestamp > now - interval '24 hours'
  AND event_type = "token_exchange"
ORDER BY timestamp DESC
```

Each row gives a token issued for alice_001 by risk_scorer. The `jti` can then be correlated with API access logs (payment API records `jti` in its transaction log). Without structured logging (if `act.sub` is buried in a string), this query is impossible; teams must parse every audit log entry.

## Lab

See `labs/day27/README.md` — configure IS 7.3 token exchange grant + agent policy + audit logging for a banking payment system.
