# Day 26 Lab — Diagrams

## 1. MCP Tool Discovery and OAuth2 Registration Flow

```mermaid
sequenceDiagram
    participant Agent as AI Agent
    participant MCPTool as MCP Payments Tool
    participant IS73 as IS 7.3

    Agent->>MCPTool: 1. GET /.well-known/oauth-authorization-server
    MCPTool->>Agent: 2. Returns OAuth2 AS metadata
    Note over Agent: {<br/>issuer: https://is.bank.com:9443<br/>scopes_supported: [mcp:payments:read, mcp:payments:write]<br/>token_endpoint: /oauth2/token<br/>registration_endpoint: /api/identity/oauth2/dcr/v1.1/register<br/>}

    Agent->>IS73: 3. POST /api/identity/oauth2/dcr/v1.1/register<br/>client_name=orchestrator-agent<br/>grant_types=[authorization_code, token-exchange]<br/>token_endpoint_auth_method=private_key_jwt

    IS73->>Agent: 4. Returns client_id + registration credentials

    Agent->>IS73: 5. POST /oauth2/token<br/>grant_type=token-exchange<br/>scope=mcp:payments:read

    IS73->>Agent: 6. Returns scoped token {scope=mcp:payments:read}

    Agent->>MCPTool: 7. Call ReadBalance()<br/>Authorization: Bearer <mcp-token>

    MCPTool->>IS73: 8. Introspect token

    IS73->>MCPTool: 9. {active=true, scope=mcp:payments:read}

    MCPTool->>Agent: 10. ✅ Balance returned
```

## 2. Scope Hierarchy: Read vs Write Operations

```mermaid
graph TD
    A["Payments MCP Tool"] --> B["Read Operations"]
    A --> C["Write Operations"]

    B --> B1["ReadBalance<br/>Scope: mcp:payments:read"]
    B --> B2["ListAccounts<br/>Scope: mcp:payments:read"]
    B --> B3["ListTransactions<br/>Scope: mcp:payments:read"]

    C --> C1["InitiatePayment<br/>Scope: mcp:payments:write"]
    C --> C2["ApprovePayment<br/>Scope: mcp:payments:write"]
    C --> C3["CancelPayment<br/>Scope: mcp:payments:write"]

    style B fill:#E3F2FD
    style C fill:#FCE4EC
    style B1 fill:#BBDEFB
    style B2 fill:#BBDEFB
    style B3 fill:#BBDEFB
    style C1 fill:#F8BBD0
    style C2 fill:#F8BBD0
    style C3 fill:#F8BBD0
```

**Alternative: Fine-grained scopes**

```mermaid
graph TD
    A["Payments MCP Tool"] --> B["mcp:payments:read"]
    A --> C["mcp:payments:write:initiate"]
    A --> D["mcp:payments:write:approve"]
    A --> E["mcp:payments:write:cancel"]

    style B fill:#BBDEFB
    style C fill:#F8BBD0
    style D fill:#F8BBD0
    style E fill:#F8BBD0
```

**Decision:** Use fine-grained scopes for high-privilege operations (payment approval, cancellation).

## 3. Token Lifecycle: API Key vs MCP OAuth2

```mermaid
timeline
    title API Key vs MCP OAuth2 Token

    section API Key (❌ Insecure)
        Created: Key generated (no expiry)
        Day 0-365: Key valid for entire year
        Leaked: No automatic invalidation
        Revocation: Manual key rotation process
        Per-user: Single key for all users (no per-user revocation)

    section MCP OAuth2 Token (✅ Secure)
        Request: Agent requests token for mcp:payments:read
        Issued: Token with 5-min TTL
        User Context: sub=user-123 attached
        Revoke: User revokes consent in IS 7.3 Console
        Immediate: Token active=false on next introspection
        Per-user: Separate token per user session
        Auto-expire: Token expires after 5 minutes if not revoked
```

## 4. User Revocation: Consent Workflow

```mermaid
sequenceDiagram
    participant User as User
    participant Console as IS 7.3 Console
    participant IS73 as IS 7.3
    participant Agent as Agent
    participant MCPTool as MCP Tool

    User->>Console: 1. Open IS 7.3 Console
    User->>Console: 2. Find "Orchestrator Agent"
    User->>Console: 3. Click "Revoke Consent"

    Console->>IS73: 4. Mark agent consent as WITHDRAWN

    Agent->>IS73: 5. Request new token (unaware of revocation)
    IS73->>Agent: ❌ Error: invalid_grant<br/>user_consent_withdrawn

    Agent->>MCPTool: 6. Try to call with old token
    MCPTool->>IS73: 7. Introspect token

    IS73->>MCPTool: 8. {active=false, error=revoked}

    MCPTool->>Agent: ❌ 401 Unauthorized
```

**Key difference from API keys:**
- API keys: Still valid until manually rotated
- OAuth2 tokens: Immediately invalid via consent withdrawal

## 5. Scope Narrowing: Least Privilege Enforcement

```mermaid
graph TD
    A["Agent requests MCP token"] --> B["What scopes does the agent need?"]

    B -->|"Only read operations"| C["Request: scope=mcp:payments:read"]
    B -->|"Payment initiation only"| D["Request: scope=mcp:payments:write:initiate"]
    B -->|"Admin: all operations"| E["Request: scope=mcp:payments:read mcp:payments:write"]

    C --> C1["IS 7.3 issues token"]
    C1 --> C2["Token has: scope=mcp:payments:read"]
    C2 --> C3["Agent can call: ReadBalance, ListAccounts"]
    C2 --> C4["❌ Agent CANNOT call: InitiatePayment"]

    D --> D1["IS 7.3 issues token"]
    D1 --> D2["Token has: scope=mcp:payments:write:initiate"]
    D2 --> D3["Agent can call: InitiatePayment"]
    D2 --> D4["❌ Agent CANNOT call: ApprovePayment"]

    E --> E1["IS 7.3 issues token"]
    E1 --> E2["Token has: scope=mcp:payments:read mcp:payments:write"]
    E2 --> E3["Agent can call: ANY operation"]

    style C3 fill:#90EE90
    style C4 fill:#FFB6C6
    style D3 fill:#90EE90
    style D4 fill:#FFB6C6
    style E3 fill:#90EE90
```

## 6. MCP Tool Access Control Decision Tree

```mermaid
flowchart TD
    A["MCP Tool receives call<br/>Authorization: Bearer token"]
    A --> B["Is token present?"]

    B -->|"No"| C["❌ 401 Unauthorized"]
    B -->|"Yes"| D["Introspect token at IS 7.3"]

    D --> E["Is token active?"]
    E -->|"No"| C
    E -->|"Yes"| F["Extract sub, scope from response"]

    F --> G["What operation is being called?"]

    G -->|"ReadBalance (requires mcp:payments:read)"| H["scope contains mcp:payments:read?"]
    G -->|"InitiatePayment (requires mcp:payments:write:initiate)"| I["scope contains mcp:payments:write:initiate?"]
    G -->|"ApprovePayment (requires mcp:payments:write:approve)"| J["scope contains mcp:payments:write:approve?"]

    H -->|"Yes"| K["✅ Scope check passed"]
    H -->|"No"| L["❌ 403 Forbidden<br/>insufficient_scope"]

    I -->|"Yes"| K
    I -->|"No"| L

    J -->|"Yes"| K
    J -->|"No"| L

    K --> M["Scope data access to sub=<user>"]
    M --> N["Execute operation"]
    N --> O["Log: agent call for this user"]
    O --> P["✅ Return result"]

    style P fill:#90EE90
    style C fill:#FFB6C6
    style L fill:#FFB6C6
```
