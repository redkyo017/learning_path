# Protocol Decision Tree — 30-Day AuthN/AuthZ Curriculum

## Master Question: What kind of caller is making the API request?

This flowchart routes all caller types (human users, B2B services, AI agents, MCP tools) through the authentication and authorization protocols covered in Days 1–30.

```mermaid
flowchart TD
    A["🤔 What kind of caller<br/>is making the API request?"]

    %% Branch 1: Human Users
    A --> B["👤 Human User<br/>Interactive session"]
    B --> B1{"What regulatory<br/>profile?"}
    
    B1 -->|Banking Payment<br/>PSD2 Regulated| B2["🏦 Customer-Facing<br/>Banking App"]
    B2 --> B3{"SCA<br/>Required?"}
    B3 -->|Yes<br/>Payments, High-Risk| B4["✅ Day 17: FIDO2 Passkey<br/>Day 13: JARM Response<br/>Days 1–10: FAPI 2.0 + PAR + RAR + DPoP"]
    B3 -->|No<br/>Non-Payment,<br/>Low-Risk| B5["✅ Day 11: App-Native Auth<br/>Day 12: Adaptive Auth<br/>Days 1–5: Standard OIDC + PKCE"]
    B4 --> B6["IS 7.3 Config:<br/>- FAPI mode enabled<br/>- DPoP binding required<br/>- JARM response mode<br/>- CIBA for SCA"]

    B5 --> B6

    B1 -->|Non-Banking<br/>No PSD2| B7["🌐 Standard Web Application"]
    B7 --> B8["✅ Days 1–3: OIDC + PKCE<br/>Day 4: PAR (recommended)<br/>Day 14: Consent Management"]
    B8 --> B9["IS 7.3 Config:<br/>- PKCE enforced<br/>- Standard OIDC<br/>- Consent framework"]

    %% Branch 2: B2B Services
    A --> C["🔗 Machine / Service<br/>B2B Integration"]
    C --> C1{"How is this<br/>service identified?"}
    
    C1 -->|Mutual TLS<br/>Certificate Auth| C2["🔐 B2B Partner Payment API"]
    C2 --> C3{"Is certificate<br/>available in<br/>production?"}
    C3 -->|Yes| C4["✅ Day 6: mTLS Mutual Auth<br/>Day 15: WSO2 IS 7.3 mTLS<br/>Day 16: DPoP + mTLS<br/>Day 20: APIM mTLS"]
    C4 --> C5["IS 7.3 Config:<br/>- mTLS endpoint auth<br/>- Cert hash binding cnf.x5t#S256<br/>- Org-scoped tokens"]

    C3 -->|No<br/>DPoP Fallback| C6["⚠️ Day 16: DPoP + Fallback<br/>⚠️ Risk: No cert binding"]
    C6 --> C5

    C1 -->|Client Credentials<br/>with DPoP| C7["Day 16: DPoP Binding<br/>Day 5: Protocol Composition<br/>⚠️ Weaker than mTLS"]
    C7 --> C8["IS 7.3 Config:<br/>- DPoP required for<br/>  client_credentials<br/>- Document risk in ADR"]

    %% Branch 3: AI Agents
    A --> D["🤖 AI Agent<br/>Automated, Unattended"]
    D --> D1{"Acting on behalf of<br/>a specific user?"}

    D1 -->|Yes<br/>User-Initiated Action| D2["👤 + 🤖 Delegation<br/>RFC 8693 OBO"]
    D2 --> D3{"Using<br/>AWS AgentCore?"}
    
    D3 -->|Yes| D4["✅ Day 21: Agent Identity Fundamentals<br/>Day 22: JWT Bearer Assertion<br/>Day 23: OBO Token Exchange<br/>Day 24: AgentCore Gateway<br/>Day 25: AgentCore + OBO Patterns"]
    D4 --> D5["IS 7.3 Config:<br/>- Token exchange grant<br/>- External OIDC IdP (AWS)<br/>- Actor trust policy<br/>- Agent-scoped tokens"]
    D5 --> D6["AgentCore Config:<br/>- Per-agent IAM role<br/>- Session tags agentId/userId<br/>- SigV4 signing<br/>- AWS OIDC federation"]

    D3 -->|No<br/>Direct OBO| D7["✅ Day 23: RFC 8693 OBO<br/>Day 28: End-to-End Chain"]
    D7 --> D8["IS 7.3 Config:<br/>- Token exchange grant<br/>- Actor trust policy<br/>- No AgentCore"]

    D1 -->|No<br/>Pre-Authorized Service| D9["🔑 Pre-Established Trust"]
    D9 --> D10["✅ Day 22: RFC 7523<br/>JWT Bearer Assertion"]
    D10 --> D11["IS 7.3 Config:<br/>- JWT bearer grant<br/>- private_key_jwt client auth<br/>- Pre-authorized agent<br/>- No user delegation"]

    %% Branch 4: MCP Tools
    A --> E["🔧 MCP Tool Call<br/>Model Context Protocol"]
    E --> E1{"Does this tool<br/>need user context<br/>from the agent's session?"}

    E1 -->|Yes<br/>Read User's Data| E2["👤 Authorization Code +<br/>User Context"]
    E2 --> E3["✅ Day 26: MCP Service Auth<br/>Day 25: AgentCore + MCP"]
    E3 --> E4["IS 7.3 Config:<br/>- Authorization Code flow<br/>- MCP-specific scopes<br/>- Short-lived tokens (5min)<br/>- Per-tool revocation"]

    E1 -->|No<br/>No User Context| E5["🤖 Client Credentials +<br/>Scoped Token"]
    E5 --> E6["✅ Day 26: MCP Service Auth<br/>Day 5: client_credentials grant"]
    E6 --> E7["IS 7.3 Config:<br/>- client_credentials grant<br/>- MCP scoped token<br/>- Resource server role<br/>- Tool discovery endpoint"]

    %% Synthesis for all flows
    B6 --> F["📋 Shared IS 7.3 Hub"]
    B9 --> F
    C5 --> F
    C8 --> F
    D6 --> F
    D8 --> F
    D11 --> F
    E4 --> F
    E7 --> F

    F --> G["✅ Day 29: Architecture Synthesis<br/>Single IS 7.3 hub serving all flows<br/>Shared JWKS, introspection, audit"]
    G --> H["📊 Capstone Deliverable<br/>Day 30: ADR + Config + Diagrams"]

    %% Styling
    classDef humanFlow fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef b2bFlow fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef agentFlow fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef mcpFlow fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef hub fill:#fffde7,stroke:#f57f17,stroke-width:3px
    classDef capstone fill:#fce4ec,stroke:#880e4f,stroke-width:3px

    class B,B2,B7,B3,B4,B5,B6,B8,B9 humanFlow
    class C,C2,C3,C4,C5,C6,C7,C8 b2bFlow
    class D,D1,D2,D3,D4,D5,D6,D7,D8,D9,D10,D11 agentFlow
    class E,E1,E2,E3,E4,E5,E6,E7 mcpFlow
    class F,G hub
    class H capstone
```

---

## Decision Tree Walkthrough

### Path 1: Customer-Facing Banking App (Human User, FAPI 2.0)

**Caller:** Mobile banking app user

**Protocol chain:**
1. **Day 1-3: OIDC + PKCE** — Foundation
2. **Day 4: PAR** — Pushed Authorization Request (secure request submission)
3. **Day 8: RAR** — Rich Authorization Request (granular consent: which accounts, payment limit)
4. **Day 9: JARM** — JWT-encoded authorization response (prevents parameter tampering)
5. **Day 13: SCA** — Strong Customer Authentication (FIDO2 passkey or TOTP)
6. **Day 16: DPoP** — Demonstration of Possession (token binding to client device)
7. **Day 17: Consent & Revocation** — User can revoke session in-app; revocation propagates via introspection

**IS 7.3 Configuration Needed:**
```toml
[server.fapi]
enable_fapi_mode = true
[oauth]
allowed_grant_types = ["authorization_code", "refresh_token"]
[oauth.dpop]
require_dpop_for_fapi = true
[oauth.jarm]
enable_jarm = true
```

---

### Path 2: B2B Partner Integration (Service, mTLS)

**Caller:** Partner organization's payment processing service

**Protocol chain:**
1. **Day 6: mTLS** — Mutual TLS (certificate-based client auth)
2. **Day 15: WSO2 IS 7.3 mTLS** — Configure IS 7.3 to accept partner certs
3. **Day 20: APIM Integration** — APIM gateway validates org-scoped tokens
4. **Token binding:** `cnf.x5t#S256` (certificate thumbprint)
5. **Scope:** Partner-specific (e.g., `partner-api:write`), not user-scoped

**IS 7.3 Configuration Needed:**
```toml
[oauth.mtls]
enable_client_cert_auth = true
client_cert_validation_mode = "STRICT"
cert_claim_mapping { org_id = "CN" }
[oauth]
allowed_grant_types = ["client_credentials"]
```

---

### Path 3a: AI Agent with User Delegation (AgentCore + OBO)

**Caller:** Bedrock agent (via AgentCore)

**User involved:** Yes — agent acts on behalf of user

**Protocol chain:**
1. **Day 21: Agent Identity Fundamentals** — Why delegated tokens, not `client_credentials`
2. **Day 22: RFC 7523 JWT Bearer** — Agent authenticates via `private_key_jwt`
3. **Day 23: RFC 8693 OBO** — Agent exchanges user token for narrowed agent token
4. **Day 24: AgentCore Gateway** — AWS STS credential vending with session tags
5. **Day 25: AgentCore + OBO** — Full integration: AgentCore SigV4 + IS 7.3 token exchange
6. **Day 26: MCP** — If agent calls MCP tools, MCP tools get scoped tokens
7. **Day 27: IS 7.3 Agent IdP** — IS 7.3 as identity hub for agents
8. **Day 28: End-to-End Chain** — Full trace: user → orchestrator → tool → API

**Token structure:**
```json
{
  "sub": "<user_id>",
  "act": {"sub": "agent_client_id"},
  "scope": "agent:payments:initiate",
  "exp": "<T+900>"
}
```

**IS 7.3 Configuration Needed:**
```toml
[oauth.token_exchange]
enable_token_exchange = true
[identity_provider.federated_idps]
name = "AWS_AgentCore"
type = "OIDC"
oidc_discovery_url = "https://oidc.eks.region.amazonaws.com/id/<cluster-id>/.well-known/openid-configuration"
```

---

### Path 3b: AI Agent Without User (Pre-Authorized Service)

**Caller:** Service account agent (no user context)

**User involved:** No — agent operates independently

**Protocol chain:**
1. **Day 22: RFC 7523 JWT Bearer** — Agent authenticates via private key; gets pre-authorized token
2. **No user identity** — `sub` is the agent client_id, no `act` claim
3. **Use case:** Scheduled batch jobs, maintenance tasks, no user accountability required

**Not suitable for:** Banking payments, user-initiated actions (regulatory requirement: must have user context)

---

### Path 4: MCP Tool Authentication

**Caller:** MCP tool (sub-agent)

**Scenarios:**

**4a: Tool needs user context (e.g., read user's account balance)**
- Use Authorization Code flow
- Tool gets token with `sub=user`, `scope=mcp:accounts:read`
- Token lifetime: 5min (short-lived for per-operation permission)

**4b: Tool does not need user context (e.g., validate payment amount against rules)**
- Use client_credentials grant
- Tool gets token with `sub=tool_id`, `scope=mcp:validate`
- Tokens are scoped narrowly per tool capability

**IS 7.3 Configuration Needed:**
```toml
[[oauth.scope.definitions]]
scope = "mcp:payments:read"
apps = ["MCPPaymentsTool"]

[[oauth.scope.definitions]]
scope = "mcp:payments:write"
apps = ["MCPPaymentsTool"]
```

---

## Anti-Pattern: How NOT to Route Requests

| Anti-Pattern | Why It's Wrong | Correct Path |
|---|---|---|
| Use `client_credentials` for all agent tokens | No user context; breaks auditability and revocation; PSD2 non-compliant | Use RFC 8693 OBO for user-initiated actions |
| Pass user's token directly to agent | Agent inherits full user scope; agent appears as user in logs; confused deputy risk | Exchange user token for narrowed agent token with `act` claim |
| Route B2B via Authorization Code + user account | B2B is service-to-service; no user; authorization code requires user browser | Use mTLS + client_credentials with org-scoped tokens |
| Skip FAPI 2.0 for banking apps | Missing PSD2 compliance requirements (PAR, RAR, SCA, DPoP) | Follow Path 1: FAPI 2.0 full chain |
| Use API keys for MCP tools | No OAuth2 scope, no revocation per user, no audit trail | Use OAuth2 with scoped MCP tokens |

---

## Integration Matrix: Caller Type vs. IS 7.3 Endpoint

| Caller Type | Endpoint | Grant Type | Auth Method | User Context | Audit Claims |
|---|---|---|---|---|---|
| **Customer (FAPI)** | `/oauth2/authorize` | `authorization_code` | PKCE + private_key_jwt | `sub`=user | `sub`, `scope`, `jti` |
| **B2B Partner** | `/oauth2/token` | `client_credentials` | `mtls_client_auth` | None (org-scoped) | `sub`=org_id, `cnf.x5t#S256` |
| **AI Agent (with user)** | `/oauth2/token` | `token-exchange` | `private_key_jwt` | `sub`=user, `act`=agent | `sub`, `act`, `scope`, `jti` |
| **AI Agent (pre-auth)** | `/oauth2/token` | `jwt-bearer` | `private_key_jwt` | None | `sub`=agent_id |
| **MCP Tool (user context)** | `/oauth2/authorize` | `authorization_code` | `private_key_jwt` + PKCE | `sub`=user | `sub`, `scope`, `mcp:*` |
| **MCP Tool (no user)** | `/oauth2/token` | `client_credentials` | `private_key_jwt` | None | `sub`=tool_id, `scope=mcp:*` |

---

## Success Criteria for This Decision Tree

✅ **Can you explain why each path uses the protocol it does?**
- Example: "Customer uses FAPI 2.0 because PSD2 requires SCA for payments."

✅ **Can you trace a request from caller to IS 7.3 endpoint without looking at day files?**
- Example: "B2B partner → mTLS cert auth → IS 7.3 `/oauth2/token` → `client_credentials` → org-scoped token."

✅ **Can you identify anti-patterns and suggest the correct path?**
- Example: "Agent using `client_credentials` with no user → should use RFC 8693 OBO → recommends Day 23."

✅ **Can you explain which protocols share endpoints and which diverge?**
- Example: "Customer and B2B both use `/oauth2/token`, but different grant types and auth methods."

---

## References to Day Files

- **Days 1–10 (Phase 1):** Hard protocols — FAPI 2.0, PAR, RAR, DPoP, mTLS, CIBA, SCIM, Consent, SCA, Protocol Composition
- **Days 11–20 (Phase 2):** WSO2 IS 7.3 deep-dive — App-Native Auth, Adaptive Auth, FAPI mode, CIBA, DPoP+mTLS, B2B Org, FIDO2, RAR+Consent, Extension Points, APIM integration
- **Days 21–30 (Phase 3):** AI Agent Identity — Fundamentals, JWT Bearer, OBO, AgentCore, AgentCore+OBO, MCP, IS 7.3 Agent IdP, End-to-End Chain, Synthesis, Capstone

