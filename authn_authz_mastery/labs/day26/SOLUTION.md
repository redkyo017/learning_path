# Day 26 Lab — Solution

## Overview

This solution demonstrates how IS 7.3 acts as an OAuth2 authorization server for MCP (Model Context Protocol) tools, replacing static API keys with scoped, revocable tokens.

## Key Design Principles

### 1. MCP Scopes: From API Keys to OAuth2

**Static API Key Model (❌ Insecure):**
```
Single key for all operations:
GET /mcp/payments/balance?key=sk-mcp-123456
POST /mcp/payments/initiate?key=sk-mcp-123456  # Same key for everything!

Problems:
- No differentiation between read and write
- Single key leaked = full access
- No per-user revocation
- No audit trail per user
- No consent framework
```

**OAuth2 Scoped Token Model (✅ Secure):**
```
Separate scopes per operation:
GET /mcp/payments/balance
  Authorization: Bearer <token_with_scope:mcp:payments:read>

POST /mcp/payments/initiate
  Authorization: Bearer <token_with_scope:mcp:payments:write:initiate>

Benefits:
- Read and write are separated
- Token leaked for read operations cannot write
- Per-user revocation (user can revoke orchestrator agent)
- Full audit trail (which user authorized which agent call)
- Consent framework (user explicitly allows agent to access tool)
```

### 2. Scope Hierarchy Design

**Recommended structure for a payments MCP tool:**

```
mcp:payments:read
  ├─ ReadBalance
  ├─ ListAccounts
  └─ ListTransactions

mcp:payments:write:initiate
  └─ InitiatePayment

mcp:payments:write:approve  (sensitive — separate scope)
  └─ ApprovePayment

mcp:payments:write:cancel
  └─ CancelPayment
```

**Why separate scopes for sensitive operations?**

1. **Approval operations are high-privilege** — only trusted agents should have this scope
2. **Compliance segregation** — payment approval requires separate authorization
3. **Audit clarity** — easy to answer "which agent approved this payment?"
4. **Least privilege** — orchestrator may initiate but NOT approve

### 3. Agent Token Request: Scope Narrowing

**Orchestrator agent requesting token:**

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<user-access-token>
&actor_token=<agent-oidc-token>
&scope=mcp:payments:read mcp:payments:write:initiate
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<agent-jwt>
```

**What agent CANNOT do:**

```http
# ❌ FAIL: Requesting approval scope (agent not trusted)
scope=mcp:payments:write:approve

# ❌ FAIL: Requesting wildcard (violates least privilege)
scope=mcp:*

# ❌ FAIL: Exceeding user's scope (if user only has mcp:payments:read)
scope=mcp:payments:write:initiate
```

### 4. Token Validation at MCP Tool

**Payment tool receives request:**

```http
POST /mcp/payments/initiate
Authorization: Bearer <exchange-token>
Content-Type: application/json

{ "amount": 100, "recipient": "account-456" }
```

**Tool validation logic:**

```
1. Extract token from Authorization header
2. Introspect at IS 7.3
   POST /oauth2/introspect
   token=<exchange-token>

3. IS 7.3 Response:
{
  "active": true,
  "scope": "mcp:payments:read mcp:payments:write:initiate",
  "sub": "user-123",
  "act": {"sub": "arn:aws:iam::...:role/PaymentOrchestratorAgentRole"},
  "aud": "payments-mcp-tool"
}

4. Tool validation:
   ✅ active=true (token not revoked)
   ✅ scope contains "mcp:payments:write:initiate" (authorized for this op)
   ✅ sub=user-123 (scope data access to this user)
   ✅ act.sub=agent-role (log which agent)

5. Execute operation
   - Scope data access to user-123
   - Return result with audit log entry:
     agent: PaymentOrchestratorRole,
     user: user-123,
     operation: InitiatePayment,
     amount: 100,
     timestamp: 2026-10-01T14:33:45Z
```

### 5. User Revocation: Immediate Invalidation

**Scenario: User discovers unauthorized agent use and revokes consent**

```
T0: User allows Orchestrator Agent to call MCP payment tool
    IS 7.3: grant consent for {orchestrator_agent, mcp:payments:read, mcp:payments:write:initiate}

T5min: Orchestrator agent calls InitiatePayment successfully
       Payment MCP tool introspects: active=true

T10min: User revokes consent in IS 7.3 Console
        Console: DELETE /oauth2/revoke?client_id=orchestrator_agent

T10min+1s: IS 7.3 marks consent as WITHDRAWN
           Any NEW token exchange for this agent fails:
           HTTP 400 {
             "error": "invalid_grant",
             "error_description": "user_consent_withdrawn"
           }

T10min+10s: Orchestrator agent tries to call again with old token
            Payment tool introspects: active=false (revoked)
            Payment tool: 401 Unauthorized
```

**Why this works:**

- Revocation is **immediate** (no waiting for token TTL)
- **Per-user** (one user's revocation doesn't affect other users)
- **Audit trail** (IS 7.3 logs the revocation event)
- **Automatic** (agent doesn't need to know it was revoked)

### 6. MCP Client Registration (DCR)

**Orchestrator agent self-registers on first encounter with MCP tool:**

```http
POST https://is.bank.com:9443/api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Bearer <admin-token>

{
  "client_name": "payment-orchestrator-agent",
  "client_type": "service",
  "grant_types": [
    "authorization_code",
    "urn:ietf:params:oauth:grant-type:token-exchange"
  ],
  "redirect_uris": [
    "http://localhost:7070/callback",
    "http://agent.internal:7070/callback"
  ],
  "response_types": ["code"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://agent.internal:7070/.well-known/jwks.json",
  "software_id": "payment-orchestrator-v1",
  "software_version": "1.0.0"
}
```

**Response:**

```json
{
  "client_id": "payment-orchestrator-mcp",
  "client_secret": "<PLACEHOLDER: secret>",
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://agent.internal:7070/.well-known/jwks.json",
  "registration_access_token": "<PLACEHOLDER: registration-token>"
}
```

Agent stores `client_id` and uses it in all subsequent token requests.

### 7. MCP Discovery: Agent Learns About Scopes

**Agent discovers MCP tool metadata:**

```http
GET https://payments-mcp-tool.bank.com/.well-known/oauth-authorization-server

Response:
{
  "issuer": "https://is.bank.com:9443/oauth2/token",
  "token_endpoint": "https://is.bank.com:9443/oauth2/token",
  "introspection_endpoint": "https://is.bank.com:9443/oauth2/introspect",
  "registration_endpoint": "https://is.bank.com:9443/api/identity/oauth2/dcr/v1.1/register",
  "scopes_supported": [
    "mcp:payments:read",
    "mcp:payments:write:initiate",
    "mcp:payments:write:approve",
    "mcp:accounts:read"
  ],
  "grant_types_supported": [
    "authorization_code",
    "urn:ietf:params:oauth:grant-type:token-exchange"
  ]
}
```

Agent learns:
- Which IS 7.3 instance is the authorization server
- Which scopes are available (mcp:payments:read, mcp:payments:write:initiate, etc.)
- How to register as a client
- How to obtain tokens

No hardcoding needed — full self-discovery.

## Common Implementation Mistakes

### Mistake 1: Wildcard Scopes

```json
// ❌ WRONG
{
  "scope": "mcp:*"
}
```

Problem: Agent can call ANY MCP operation, violating least privilege.

**Fix:**
```json
// ✅ CORRECT
{
  "scope": "mcp:payments:read mcp:payments:write:initiate"
}
```

Request only the scopes needed for the specific operations.

### Mistake 2: Using `client_credentials` for User-Context Tools

```json
// ❌ WRONG
{
  "grant_type": "client_credentials",
  "scope": "mcp:payments:write"
}
```

Problem: Token has no `sub` claim (no user context). Tool cannot enforce per-user access control.

**Fix:**
```json
// ✅ CORRECT
{
  "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
  "subject_token": "<user-token>",
  "actor_token": "<agent-oidc-token>",
  "scope": "mcp:payments:write:initiate"
}
```

Result token has `sub=user`, enabling per-user data scoping.

### Mistake 3: Not Validating Token Before Every Call

```javascript
// ❌ WRONG
agent.call(mcp_tool, {
  token: access_token,
  operation: "ReadBalance",
  user_id: "user-123"  // Trust agent to pass correct user
});
```

Problem: Tool trusts agent to pass correct `user_id`. If agent is compromised, it can access wrong user's data.

**Fix:**
```javascript
// ✅ CORRECT
agent.call(mcp_tool, {
  token: access_token,
  operation: "ReadBalance"
  // Tool introspects token → gets sub=user-123 from IS 7.3
  // Tool scopes access to that user only
});
```

Tool validates token, extracts user from token (not from agent).

### Mistake 4: Caching Introspection Without TTL

```javascript
// ❌ WRONG
introspection_result = cache.get(token);
if (!introspection_result) {
  introspection_result = is73.introspect(token);
  cache.put(token, introspection_result);  // Cache forever
}
```

Problem: User revokes consent, but cached introspection result is "active=true". Tool allows call that should be denied.

**Fix:**
```javascript
// ✅ CORRECT
introspection_result = cache.get_with_ttl(token, ttl=5min);
if (!introspection_result || introspection_result.expired) {
  introspection_result = is73.introspect(token);
  cache.put_with_ttl(token, introspection_result, ttl=5min);
}
```

Cache introspection results with 5-minute TTL. Revocation propagates within 5 minutes.

## Assessment: Answer Key

**Q1: Why is `scope=mcp:*` a security anti-pattern?**

A: Wildcard scope violates the principle of least privilege. It allows the agent to call ANY MCP operation, including ones outside its intended use case. If the agent is compromised or prompt-injected, the attacker has unrestricted access to all MCP tools.

**Q2: How does MCP token revocation differ from API key revocation?**

A: API key revocation is manual and async (rotate the key, deploy new config, wait for propagation). MCP token revocation is automatic and immediate — user clicks "Revoke" in IS 7.3 Console, next introspection returns `active=false`. No manual intervention, no deployment needed.

**Q3: Scope hierarchy for three operations**

A: Minimum 3 scopes (one per operation):
- `mcp:payments:get-balance`
- `mcp:payments:initiate`
- `mcp:payments:approve`

Or grouped (2 scopes):
- `mcp:payments:read`
- `mcp:payments:write`

Or fine-grained (if approve is high-privilege):
- `mcp:payments:read`
- `mcp:payments:write:initiate`
- `mcp:payments:write:approve` (separate, restricted scope)

**Q4: Can agent with `mcp:payments:read` call write operation?**

A: No. IS 7.3 will reject the call with `insufficient_scope` at the token endpoint. If somehow the agent has an old token with only `mcp:payments:read`, the MCP tool will introspect, see that `scope` doesn't contain `mcp:payments:write`, and return `403 Forbidden: insufficient_scope`.

**Q5: How does consent enable compliance?**

A: User consent is a compliance requirement (e.g., PSD2 for banking). IS 7.3 consent framework:
- User explicitly grants consent: "Allow Orchestrator Agent to access payment operations"
- Consent is logged (audit trail)
- Consent has expiry (automatic cleanup)
- Revocation is logged
- Revocation invalidates all derived tokens immediately

This satisfies: authentication, authorization, auditability, and revocation requirements.

## Key Configuration Checklist

- ✅ MCP scopes defined in `[oauth.scopes]`
- ✅ Resource server registered with IS 7.3 (payments MCP tool)
- ✅ Token lifetime configured (5 minutes for MCP operations)
- ✅ Introspection cache TTL (≤5 minutes for compliance)
- ✅ Token exchange grant enabled (`urn:ietf:params:oauth:grant-type:token-exchange`)
- ✅ Scope narrowing enforced (agent can't exceed subject_token scope)
- ✅ Actor trust policy configured (which agents can exchange)
- ✅ Consent framework enabled (user must authorize)
- ✅ Revocation propagation enabled (immediate via introspection)
- ✅ Audit logging enabled (all token exchanges and introspections logged)
- ✅ Discovery endpoint enabled (agents can discover MCP scopes at `/.well-known/...`)

## Files to Review

- `config/mcp_oauth2_server.toml` — Complete IS 7.3 configuration for MCP OAuth2
- `diagram.md` — Visual representation of MCP token flow and decision trees
- Day 26 content: `content/day26.md` — Full technical deep-dive on MCP authentication
