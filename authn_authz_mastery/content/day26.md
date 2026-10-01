# Day 26 — MCP Service Authentication

## Why this matters

A team builds an MCP tool server for their AI agent and secures it with a static API key per tool. Three months later: a prompt injection attack causes the agent to leak the API key in a response. The attacker uses the key to call the tool directly with arbitrary inputs. API keys have no user context, no scope, no revocation per user, and no audit trail. OAuth2-scoped tokens for MCP tools fix all four problems.

## Core concepts

### MCP (Model Context Protocol) — OAuth2 resource servers

The MCP specification (2024) defines MCP tools as OAuth2 resource servers. Instead of API keys, MCP clients (AI agents) authenticate via OAuth2 grants like Authorization Code or RFC 8693 token exchange. This means:

- MCP tools are first-class OAuth2 resource servers registered with an authorization server (IS 7.3).
- MCP clients are first-class OAuth2 clients registered with the same authorization server.
- All MCP transactions are auditable as OAuth2 events.
- Revocation propagates immediately — if a user revokes consent for an agent, that agent can no longer access MCP tools.

### Tool discovery via `.well-known/oauth-authorization-server`

An MCP server publishes its authorization server metadata at:

```
GET /.well-known/oauth-authorization-server
```

Response:
```json
{
  "issuer": "https://is.bank.com:9443/oauth2/token",
  "authorization_endpoint": "https://is.bank.com:9443/oauth2/authorize",
  "token_endpoint": "https://is.bank.com:9443/oauth2/token",
  "introspection_endpoint": "https://is.bank.com:9443/oauth2/introspect",
  "revocation_endpoint": "https://is.bank.com:9443/oauth2/revoke",
  "jwks_uri": "https://is.bank.com:9443/oauth2/jwks",
  "scopes_supported": [
    "mcp:payments:read",
    "mcp:payments:write",
    "mcp:accounts:read"
  ],
  "grant_types_supported": [
    "authorization_code",
    "urn:ietf:params:oauth:grant-type:token-exchange"
  ],
  "registration_endpoint": "https://is.bank.com:9443/api/identity/oauth2/dcr/v1.1/register"
}
```

An agent can:
1. Discover which MCP tools are available (via `scopes_supported`)
2. Register itself as an OAuth2 client (via `registration_endpoint`)
3. Request tokens for specific tool scopes (via `token_endpoint`)

### DCR for MCP clients

When an agent first encounters an MCP tool server, it registers itself as an OAuth2 client using Dynamic Client Registration (DCR):

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <PLACEHOLDER: admin-base64>

{
  "client_name": "payment-orchestrator-agent",
  "grant_types": ["authorization_code", "urn:ietf:params:oauth:grant-type:token-exchange"],
  "redirect_uris": ["http://localhost:7070/callback"],
  "software_id": "payment-orchestrator-v1",
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://agent.internal:7070/.well-known/jwks.json"
}
```

Response:
```json
{
  "client_id": "payment-orchestrator-mcp-client",
  "client_secret": "<PLACEHOLDER: secret>",
  "registration_access_token": "<PLACEHOLDER: token>"
}
```

The agent stores the `client_id` and uses it in all subsequent token requests.

### Scoped tool tokens

Each MCP tool action is mapped to a scope. Example for a payments tool:

- `mcp:payments:read` — can call `ReadAccount`, `GetBalance`
- `mcp:payments:write` — can call `InitiatePayment`, `ApprovePayment`
- `mcp:payments:write:send` — can call `SendPayment` (even more granular)

When the agent needs to call a specific tool, it requests only that scope:

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<user-access-token>
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&actor_token=<agent-oidc-token>
&actor_token_type=urn:ietf:params:oauth:token-type:jwt
&scope=mcp:payments:read
&requested_token_type=urn:ietf:params:oauth:token-type:access_token
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<agent-jwt>
```

Response: access token with `scope=mcp:payments:read` only. The agent cannot use this token to call write operations.

### IS 7.3 as MCP OAuth2 authorization server

IS 7.3 must be configured to:

1. Understand MCP scopes — register `mcp:payments:read`, `mcp:payments:write`, etc. in the scope registry
2. Accept MCP tool tokens in token exchange requests
3. Issue tokens with MCP scope claims
4. Support introspection for MCP tools

### Token lifetime for MCP tools

MCP tool tokens are short-lived (5 minutes) and tied to the current session's user context:

- If the user revokes consent in IS 7.3 Console, the token becomes invalid.
- If the user's parent session expires, the token expires immediately (via revocation propagation).
- The short 5-minute lifetime limits the blast radius of a leaked token.

## WSO2 IS 7.3 / AgentCore mapping

### IS 7.3 deployment.toml — MCP scope registration

```toml
# deployment.toml — enable MCP scopes
[oauth.scopes]
# Standard MCP scopes for a payments tool
MCP_PAYMENTS_READ = {
  name = "mcp:payments:read",
  description = "Read account and balance information",
  display_name = "Payments Read",
  claims = ["sub", "act", "scope", "aud"]
}

MCP_PAYMENTS_WRITE = {
  name = "mcp:payments:write",
  description = "Initiate and manage payments",
  display_name = "Payments Write",
  claims = ["sub", "act", "scope", "aud"]
}

MCP_ACCOUNTS_READ = {
  name = "mcp:accounts:read",
  description = "Read account details",
  display_name = "Accounts Read",
  claims = ["sub", "act", "scope", "aud"]
}

# Token lifetime for MCP tools (short-lived)
[oauth]
mcp_token_lifetime = 300  # 5 minutes
```

### MCP tool server registration (via API)

The MCP tool server (e.g., the payments tool) must register as a resource server:

```http
POST /api/identity/oauth2/resource-server/register
Content-Type: application/json
Authorization: Bearer <PLACEHOLDER: admin-token>

{
  "resource_server_name": "payments-mcp-tool",
  "resource_server_context": "/mcp/payments",
  "scopes": [
    {
      "name": "mcp:payments:read",
      "display_name": "Read Payments"
    },
    {
      "name": "mcp:payments:write",
      "display_name": "Write Payments"
    }
  ],
  "token_validity_period": 300
}
```

### DCR example for MCP client registration

An agent registers as an MCP client:

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json

{
  "client_name": "payment-orchestrator-agent",
  "grant_types": [
    "authorization_code",
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "redirect_uris": [
    "http://localhost:7070/callback",
    "http://agent.internal:7070/callback"
  ],
  "response_types": ["code", "id_token"],
  "application_type": "service",
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://agent.internal:7070/.well-known/jwks.json",
  "software_id": "payment-orchestrator-v1",
  "software_version": "1.0.0"
}
```

IS 7.3 returns:
```json
{
  "client_id": "payment-orchestrator-mcp",
  "client_secret": "<PLACEHOLDER: secret>",
  "client_secret_expires_at": 0,
  "redirect_uris": [...],
  "token_endpoint_auth_method": "private_key_jwt"
}
```

## Anti-patterns

### 1. One API key for all tool calls

**Problem:** No per-user revocation, no audit trail per user, no scope differentiation between read and write operations.

**Anti-pattern:**
```bash
# DO NOT DO THIS
MCP_TOOL_API_KEY="sk-mcp-123456"  # One key for all operations
```

The agent uses this key to call all MCP tools, regardless of:
- Which user authorized it
- Whether the user revoked consent
- What scope the specific operation needs

If the key leaks, an attacker has full access to all MCP tools.

**Fix:** Use OAuth2 — one token per scope, revocable per user, with audit trail.

### 2. Not using OAuth2 authorization code flow for user-context tools

**Problem:** A tool that accesses user data with a `client_credentials` token has no `sub` claim. The tool cannot enforce per-user access control.

**Scenario:** A `GetAccountBalance` MCP tool is called with a `client_credentials` token:
```json
{
  "sub": "payment-orchestrator-service",
  "scope": "mcp:accounts:read",
  "aud": "mcp-accounts-tool"
}
```

The tool cannot determine which user's balance to return — the token is for the service, not the user. The agent must pass `userId` in the request body, but then the tool must trust the agent not to lie about the user ID.

**Fix:** Use RFC 8693 token exchange with the user's IS 7.3 token:
```json
{
  "sub": "user-123",
  "act": {"sub": "agent-id"},
  "scope": "mcp:accounts:read",
  "aud": "mcp-accounts-tool"
}
```

Now the tool trusts that `sub=user-123` came from IS 7.3's token exchange — it's auditable and cannot be spoofed by the agent.

### 3. Tool tokens with overly broad scopes

**Problem:** An agent that requests `scope=mcp:*` can call all tools regardless of the specific action needed.

**Anti-pattern:**
```http
POST /oauth2/token
...
scope=mcp:*
```

The agent gets a token for all MCP operations. If the agent is compromised or prompt-injected, the attacker can use the same token to:
- Read sensitive account data
- Initiate unauthorized payments
- Modify user records

**Fix:** Request only the scope for the specific tool call being made:

```http
POST /oauth2/token
...
scope=mcp:payments:read
```

This token can only read payments — it cannot write or access other tools.

## Exercises

### Exercise 1: MCP tool discovery

**Hint:** The tool publishes its metadata at a well-known endpoint.

**Question:** An AI agent encounters an MCP payments tool for the first time. How can the agent discover: (a) which authorization server manages the tool, (b) which scopes are available, (c) how to register itself as an OAuth2 client?

**Solution sketch:**

1. Agent GETs `/.well-known/oauth-authorization-server` from the MCP tool.
2. Response includes:
   - `issuer` — the authorization server (IS 7.3)
   - `scopes_supported` — available scopes (e.g., `mcp:payments:read`, `mcp:payments:write`)
   - `registration_endpoint` — where to register as an OAuth2 client
3. Agent POSTs to the registration endpoint with its DCR request, receives `client_id`.
4. Agent uses the `token_endpoint` to request tokens for specific scopes as needed.

This is self-discovery — the agent does not need hardcoded configuration for each MCP tool.

### Exercise 2: Scoped tool token design

**Hint:** Think about the principle of least privilege applied to MCP operations.

**Question:** Design the scope hierarchy for a banking tool that has three operations: `ListAccounts`, `GetBalance`, `InitiatePayment`. How many scopes do you need, and what should they be?

**Solution sketch:**

Minimum: 3 scopes (one per operation):
- `mcp:banking:list-accounts`
- `mcp:banking:get-balance`
- `mcp:banking:initiate-payment`

Alternatively, 2 scopes (read vs. write):
- `mcp:banking:read` — covers ListAccounts and GetBalance
- `mcp:banking:write` — covers InitiatePayment

The agent requests only the scope it needs for each call:
- To list accounts: request `mcp:banking:list-accounts` (or `mcp:banking:read`)
- To initiate payment: request `mcp:banking:initiate-payment` (or `mcp:banking:write`)

This prevents a tool from performing operations outside its intended scope. If the agent is compromised, the blast radius is limited to the scopes it currently holds.

### Exercise 3: Revocation propagation for MCP tokens

**Hint:** The user revokes consent in IS 7.3 Console. What happens to active MCP tool tokens?

**Question:** A user revokes consent for the `payment-orchestrator` agent in IS 7.3 Console. The agent has an active MCP token for `mcp:payments:write` with 2 minutes remaining on its TTL. When the agent makes the next call to the payments MCP tool, what happens?

**Solution sketch:**

The MCP tool receives the request with the token in the Authorization header. It introspects the token at IS 7.3:

```http
POST /oauth2/introspect
...
token=<mcp-token>
```

IS 7.3 checks: the user's consent for this agent has been revoked. IS 7.3 returns:

```json
{
  "active": false,
  "error": "revoked"
}
```

The MCP tool rejects the request with 401 Unauthorized. The agent's active token is invalidated immediately — revocation does not wait for the TTL to expire.

This is the key advantage of MCP tokens over API keys: revocation is immediate and enforced by IS 7.3.

## Lab

See `labs/day26/README.md` — configure IS 7.3 as an MCP OAuth2 authorization server and design scoped tokens for payment operations. Success signal: understand how OAuth2 scoping prevents overprivileged agent tokens and enables per-user revocation.
