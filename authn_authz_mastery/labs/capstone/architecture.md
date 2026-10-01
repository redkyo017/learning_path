# Architecture Diagrams — IS 7.3 + AgentCore Hub

Five Mermaid sequence diagrams covering the three integration flows, their convergence on IS 7.3, and token lifecycle with revocation.

## Diagram 1: Customer-Facing Banking App (FAPI 2.0 + PAR + RAR + DPoP + SCA)

```mermaid
sequenceDiagram
    participant User
    participant MobileApp
    participant PAR as IS 7.3 PAR
    participant AuthZ as IS 7.3 AuthZ
    participant SCA as SCA Backend
    participant JARM as IS 7.3 JARM
    participant APIM
    participant PaymentAPI

    User->>MobileApp: Open app, tap "Pay"
    MobileApp->>PAR: POST /oauth2/par (client_id, redirect_uri, scope=payments:write accounts:read, authorization_details=<PLACEHOLDER:RAR>)
    PAR-->>MobileApp: request_uri, expires_in=600
    MobileApp->>AuthZ: GET /oauth2/authorize (request_uri, PKCE challenge)
    AuthZ->>User: [UI] Verify identity + consent
    AuthZ->>SCA: Out-of-band: FIDO2 passkey or TOTP challenge
    User->>SCA: Approve
    SCA-->>AuthZ: SCA verified
    AuthZ-->>MobileApp: HTTP 302 redirect to redirect_uri?code=<PLACEHOLDER:code>&state=<PLACEHOLDER:state> (JARM response, signed JWT)
    MobileApp->>JARM: POST /oauth2/token (code, code_verifier, client_assertion_type=private_key_jwt, client_assertion=<PLACEHOLDER:jwt>)
    Note over JARM: Verify PKCE, client auth
    JARM-->>MobileApp: access_token (1h, sub=<PLACEHOLDER:user_id>, aud=payment-api, scope=payments:write accounts:read, cnf.jkt=<PLACEHOLDER:dpop_binding>), refresh_token
    Note over MobileApp: Bind token to DPoP public key
    MobileApp->>APIM: POST /api/payments/initiate + Authorization: DPoP <token> + DPoP: <PLACEHOLDER:dpop_proof>
    APIM->>APIM: Verify DPoP binding, token signature
    Note over APIM: Cache introspection (TTL=5min)
    APIM->>PaymentAPI: Forward request with validated context
    PaymentAPI->>PaymentAPI: Execute payment, log: sub=<PLACEHOLDER:user_id>, jti=<PLACEHOLDER:trace_id>
    PaymentAPI-->>APIM: 200 OK
    APIM-->>MobileApp: 200 OK
```

---

## Diagram 2: B2B Partner Payment API (mTLS + Org-Scoped Token)

```mermaid
sequenceDiagram
    participant Partner
    participant PartnerApp
    participant mTLS as IS 7.3 mTLS
    participant TokenEndpoint as IS 7.3 Token
    participant APIM
    participant PaymentAPI

    Partner->>PartnerApp: Trigger payment batch job
    PartnerApp->>mTLS: Establish TLS connection with client certificate (cert=<PLACEHOLDER:partner_cert>, subject=partner-org)
    Note over mTLS: Verify cert, extract org_id from subject
    PartnerApp->>TokenEndpoint: POST /oauth2/token (client_id=partner-app, grant_type=client_credentials, scope=partner-api:write) [over mTLS]
    TokenEndpoint->>TokenEndpoint: Verify mTLS cert, bind org_id
    TokenEndpoint-->>PartnerApp: access_token (24h, sub=<PLACEHOLDER:org_id>, aud=partner-api, scope=partner-api:write, cnf.x5t#S256=<PLACEHOLDER:cert_hash>), cert_binding
    Note over PartnerApp: Store token, reuse for 24h
    PartnerApp->>APIM: POST /api/partner-payments/initiate + Authorization: Bearer <token>
    APIM->>APIM: Verify token JWT signature locally or introspect (cache TTL=1h for B2B)
    Note over APIM: Rate limit: per org_id (10K/hour)
    APIM->>PaymentAPI: Forward request with org_id context
    PaymentAPI->>PaymentAPI: Validate org subscription, execute payment, log: sub=<PLACEHOLDER:org_id>, cnf.x5t#S256=<PLACEHOLDER:cert_hash>
    PaymentAPI-->>APIM: 200 OK
    APIM-->>PartnerApp: 200 OK
```

---

## Diagram 3: AI Agent Delegation Chain (OBO + AgentCore + MCP Tool)

```mermaid
sequenceDiagram
    participant User
    participant OrchestratorAgent
    participant ToolAgent
    participant IS73Exchange as IS 7.3 Token Exchange
    participant AgentCore
    participant MCPServer
    participant PaymentAPI

    User->>OrchestratorAgent: [App-level] "Process my transfer" (user_token=<PLACEHOLDER:user_access_token>)
    Note over OrchestratorAgent: user_token has: sub=<user_id>, scope=payments:read payments:write

    OrchestratorAgent->>IS73Exchange: POST /oauth2/token (subject_token=user_token, subject_token_type=access_token, actor_token=<PLACEHOLDER:orchestrator_jwt>, actor_token_type=jwt, scope=payments:initiate, client_assertion=<PLACEHOLDER:client_assertion>)
    Note over IS73Exchange: Verify actor_token, narrow scope
    IS73Exchange-->>OrchestratorAgent: orch_token (15min, sub=<user_id>, act.sub=orchestrator_id, scope=payments:initiate)

    OrchestratorAgent->>ToolAgent: "Initiate transfer" (orch_token, transfer_details)
    Note over ToolAgent: Needs to narrow scope further

    ToolAgent->>IS73Exchange: POST /oauth2/token (subject_token=orch_token, subject_token_type=access_token, actor_token=<PLACEHOLDER:tool_jwt>, actor_token_type=jwt, scope=payments:initiate, client_assertion=<PLACEHOLDER:client_assertion>)
    Note over IS73Exchange: Verify tool actor token, preserve user sub
    IS73Exchange-->>ToolAgent: tool_token (5min, sub=<user_id>, act.sub=tool_id, act.act.sub=orchestrator_id, scope=payments:initiate)

    ToolAgent->>AgentCore: [SigV4] GET /mcp/payments/validate (Authorization: AWS SigV4 <creds>, X-AgentCore-Session-Id=<PLACEHOLDER:session_id>)
    AgentCore->>AgentCore: Verify SigV4 signature, add X-AgentCore-Caller-Identity={agentId=tool_id, userId=<user_id>, sessionId=<PLACEHOLDER:session_id>}
    AgentCore->>MCPServer: [MCP Protocol] Forward request

    ToolAgent->>PaymentAPI: POST /payments/initiate + Authorization: Bearer tool_token + X-AgentCore-Caller-Identity
    PaymentAPI->>IS73Exchange: POST /oauth2/introspect (token=tool_token)
    Note over IS73Exchange: Check: active=true, verify sub, act chain
    IS73Exchange-->>PaymentAPI: {active:true, sub=<user_id>, act={sub=tool_id, act={sub=orchestrator_id}}, scope=payments:initiate, exp=<PLACEHOLDER:exp>}
    PaymentAPI->>PaymentAPI: Execute transfer, log: jti=<PLACEHOLDER:trace_id>, caller_chain=[tool_id, orchestrator_id], user=<user_id>
    PaymentAPI-->>ToolAgent: 200 OK
```

---

## Diagram 4: IS 7.3 Hub — All Three Flows Converging

```mermaid
flowchart TD
    A["Caller Types"] --> B["Human User<br/>Interactive"]
    A --> C["B2B Partner<br/>Service"]
    A --> D["AI Agent<br/>Orchestrator/Tool"]

    B --> B1["Customer-Facing<br/>Banking App"]
    B1 --> B2["POST /oauth2/par<br/>Scope: payments:read<br/>Auth Details: RAR"]
    B2 --> B3["GET /oauth2/authorize<br/>PKCE required<br/>SCA step-up"]
    B3 --> B4["SCA Verification<br/>FIDO2/TOTP"]
    B4 --> B5["POST /oauth2/token<br/>client_assertion_type=private_key_jwt"]
    B5 --> B6["Token: sub=user<br/>scope=payments<br/>cnf.jkt=DPoP_key"]
    B6 --> B7["APIM: DPoP + Introspect"]

    C --> C1["B2B Partner API"]
    C1 --> C2["Establish mTLS<br/>Client Cert Auth"]
    C2 --> C3["POST /oauth2/token<br/>grant_type=client_credentials<br/>scope=partner-api"]
    C3 --> C4["POST /oauth2/token<br/>token_endpoint_auth_method=mtls_client_auth"]
    C4 --> C5["Token: sub=org_id<br/>cnf.x5t#S256=cert_hash"]
    C5 --> C6["APIM: Local JWT or<br/>Introspect TTL=1h"]

    D --> D1["OBO Token Exchange"]
    D1 --> D2["User → Orchestrator<br/>First Exchange"]
    D2 --> D3["POST /oauth2/token<br/>subject_token=user_token<br/>actor_token=orchestrator_jwt"]
    D3 --> D4["Result: sub=user<br/>act.sub=orchestrator_id<br/>scope narrowed"]
    D4 --> D5["Orchestrator → Tool<br/>Second Exchange"]
    D5 --> D6["POST /oauth2/token<br/>subject_token=orch_token<br/>actor_token=tool_jwt"]
    D6 --> D7["Result: sub=user<br/>act.sub=tool_id<br/>act.act.sub=orchestrator_id"]
    D7 --> D8["AgentCore SigV4<br/>+ MCP Tool Call"]
    D8 --> D9["APIM/Backend:<br/>Introspect + Verify<br/>act chain"]

    B7 --> E["Single IS 7.3<br/>JWKS Endpoint"]
    C6 --> E
    D9 --> E

    E --> F["Single Introspection<br/>Endpoint<br/>Active/Sub/Act/Scope"]
    E --> G["Single Audit Log<br/>All three flows<br/>Correlated by jti"]

    F -.->|Revocation<br/>Propagates| H["User Revokes<br/>Session"]
    H -.->|next introspect<br/>returns| I["active:false for all<br/>derived tokens"]
```

---

## Diagram 5: Token Lifecycle and Revocation Propagation

```mermaid
sequenceDiagram
    participant User as User
    participant IS73 as IS 7.3
    participant Orch as Orchestrator
    participant Tool as Tool Agent
    participant PaymentAPI

    rect rgb(200, 255, 200)
    Note over User,PaymentAPI: T=0: Token Issuance
    User->>IS73: Authenticate (App-Native Auth)
    IS73-->>User: human_token (exp=1h, sub=<PLACEHOLDER:user_id>, scope=payments:* accounts:*)
    Note over User,IS73: Token 1: sub=<user_id>, exp=T+1h, scope=payments accounts
    end

    rect rgb(200, 220, 255)
    Note over User,PaymentAPI: T=5min: First Exchange (Orch)
    Orch->>IS73: Token exchange (human_token, orchestrator_actor)
    IS73-->>Orch: orch_token (exp=15min, sub=<user_id>, act.sub=orchestrator_id, scope=payments:initiate)
    Note over Orch,IS73: Token 2: sub=<user_id>, act.sub=orch_id, exp=T+15min, scope=payments:initiate
    end

    rect rgb(255, 220, 200)
    Note over User,PaymentAPI: T=10min: Second Exchange (Tool)
    Tool->>IS73: Token exchange (orch_token, tool_actor)
    IS73-->>Tool: tool_token (exp=5min, sub=<user_id>, act.sub=tool_id, act.act.sub=orchestrator_id, scope=payments:initiate)
    Note over Tool,IS73: Token 3: sub=<user_id>, act.sub=tool_id, act.act.sub=orch_id, exp=T+5min
    end

    rect rgb(200, 200, 255)
    Note over User,PaymentAPI: T=12min: Payment API Call
    Tool->>PaymentAPI: POST /payments (tool_token)
    PaymentAPI->>IS73: POST /introspect (token=tool_token)
    IS73-->>PaymentAPI: {active:true, sub=<user_id>, act={sub=tool_id, act={sub=orchestrator_id}}, scope=payments:initiate, exp=T+5min}
    PaymentAPI->>PaymentAPI: Grant access, log: jti=<PLACEHOLDER:trace_id>, sub=<user_id>, act_chain=[tool_id, orchestrator_id]
    PaymentAPI-->>Tool: 200 OK (transfer completed)
    end

    rect rgb(255, 200, 200)
    Note over User,PaymentAPI: T=13min: User Revokes Session
    User->>IS73: POST /revoke (human_token)
    IS73->>IS73: Mark human_token as revoked
    Note over IS73: Token 1: revoked (active=false)
    Note over IS73: Tokens 2, 3 marked for revocation (derived from token 1)
    end

    rect rgb(255, 230, 200)
    Note over User,PaymentAPI: T=15min: Tool Makes Another Payment (Late)
    Tool->>PaymentAPI: POST /payments (tool_token, still in memory)
    PaymentAPI->>IS73: POST /introspect (token=tool_token)
    Note over IS73: Check exchange chain: orch_token -> human_token
    Note over IS73: human_token is revoked!
    IS73-->>PaymentAPI: {active:false, reason:parent_revoked}
    PaymentAPI->>PaymentAPI: Deny access, log: access_denied, reason=revoked_parent_token, trace=<PLACEHOLDER:trace_id>
    PaymentAPI-->>Tool: 401 Unauthorized
    end

    rect rgb(200, 200, 200)
    Note over User,PaymentAPI: T=65min: Token Expiry (Local Validation)
    Note over Tool: tool_token expires (T+5min = T+5min < T+65min)
    Note over Orch: orch_token expires (T+15min < T+65min)
    Note over User: human_token expires (T+60min close to T+65min)
    Tool->>PaymentAPI: POST /payments (expired tool_token)
    PaymentAPI->>PaymentAPI: If local validation: rejected (exp < now)
    PaymentAPI->>PaymentAPI: If introspection: rejected (active=false due to expiry)
    PaymentAPI-->>Tool: 401 Unauthorized
    end
```

---

## Diagram Notes

1. **Diagram 1 (Customer FAPI 2.0)**: Shows the full FAPI 2.0 + PAR + RAR + DPoP + SCA flow. The token is DPoP-bound (`cnf.jkt`), meaning it cannot be used without proof of possession of the corresponding DPoP key. JARM is used for the redirect response (signed JWT instead of plain redirect parameters).

2. **Diagram 2 (B2B mTLS)**: Demonstrates mTLS client authentication. The client certificate is used to authenticate and to bind the token (`cnf.x5t#S256` = certificate thumbprint). Unlike the customer flow, there is no user; the `sub` is the partner organization's `org_id`.

3. **Diagram 3 (AI Agent OBO + AgentCore + MCP)**: The orchestrator agent exchanges the user's token for an agent-scoped token via RFC 8693. The tool agent then exchanges the orchestrator token for its own narrower token. The `act` claim nests to show the full delegation chain. AgentCore provides SigV4-signed credentials for additional access control.

4. **Diagram 4 (IS 7.3 Hub)**: Visual representation of all three flows converging on a single IS 7.3 instance. Key endpoints: PAR, authorization, token, introspection. All three flows share the same JWKS, audit log, and revocation mechanism.

5. **Diagram 5 (Token Lifecycle)**: Traces a token through its full lifecycle: issuance, exchange chain, use, revocation, and expiry. Shows that introspection-based revocation propagates through the chain immediately, while local JWT validation does not detect revocation until token expiry.

