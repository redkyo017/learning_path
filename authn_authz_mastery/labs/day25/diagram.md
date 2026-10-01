# Day 25 Lab — Diagrams

## 1. Complete 8-Step AgentCore → IS 7.3 → Payment API Flow

```mermaid
sequenceDiagram
    participant User as User
    participant IS73 as IS 7.3
    participant AgentCore as AgentCore
    participant Agent as Orchestrator Agent
    participant AWS as AWS STS/OIDC
    participant PaymentAPI as Payment API

    User->>IS73: 1. Authenticate (App-Native Auth)
    IS73->>User: User access token {sub=user-123, scope=payments:initiate, exp=1h}

    User->>Agent: 2. Pass user token to agent (secure context)

    Agent->>AWS: 3. Get OIDC token<br/>(via AgentCore-obtained IAM credentials)
    AWS->>Agent: OIDC identity token {sub=agent-role-arn, aud=is.bank.com, exp=1h}

    Agent->>IS73: 4. Token exchange request<br/>(POST /oauth2/token)
    Note over Agent,IS73: grant_type=token-exchange<br/>subject_token=user-123 token<br/>actor_token=AWS OIDC token<br/>scope=payments:initiate

    Note over IS73: 5. Validate actor_token:<br/>- Fetch JWKS from AWS OIDC Discovery<br/>- Verify signature<br/>- Check aud=is.bank.com<br/>- Check actor trust policy

    IS73->>IS73: ✅ Validation passed

    IS73->>Agent: 6. Exchange result token<br/>{sub=user-123, act.sub=agent-role, scope=payments:initiate, exp=15min}

    Agent->>PaymentAPI: 7. Call payment API<br/>Authorization: Bearer <exchange-token>

    PaymentAPI->>IS73: Introspect token
    IS73->>PaymentAPI: {active=true, sub=user-123, act.sub=agent-role, scope=payments:initiate}

    PaymentAPI->>Agent: 8. ✅ Payment initiated<br/>Response includes: transaction_id, timestamp, actor info
```

**Key observations:**
- Step 1: User gets IS 7.3 token with `sub=user-123`
- Step 3: Agent obtains AWS OIDC token with `sub=agent-role`
- Step 4: Agent sends BOTH tokens to IS 7.3
- Step 5: IS 7.3 validates actor (AWS OIDC signature)
- Step 6: IS 7.3 issues token with both `sub` and `act`
- Step 7-8: Payment API uses introspection to validate the chain

## 2. Trust Federation: AWS OIDC Discovery → IS 7.3 Validation

```mermaid
flowchart TD
    A["IS 7.3 configured with:<br/>AWS OIDC Discovery URL"] -->|"GET /.well-known/openid-configuration"| B["AWS OIDC Discovery Endpoint"]
    B -->|"Returns: jwks_uri, issuer, aud"| C["IS 7.3 caches metadata"]

    Agent -->|"Has AWS OIDC token<br/>(signed by AWS private key)"| D["Agent sends to IS 7.3<br/>POST /oauth2/token<br/>actor_token=OIDC"]

    D --> E["IS 7.3 extracts kid from JWT header"]
    E -->|"GET JWKS (kid lookup)"| F["AWS OIDC JWKS Endpoint"]
    F -->|"Returns public key for kid"| G["IS 7.3 has public key"]

    G --> H["Verify JWT signature<br/>using AWS public key"]
    H -->|"✅ Signature valid"| I["Check aud claim<br/>=is.bank.com"]
    I -->|"✅ Matches"| J["Check actor trust policy<br/>sub=agent-role allowed?"]
    J -->|"✅ Yes, agent is trusted"| K["✅ actor_token accepted<br/>Issue exchange token"]

    H -->|"❌ Invalid"| L["❌ Reject<br/>invalid_client"]
    I -->|"❌ Mismatch"| M["❌ Reject<br/>actor_audience_mismatch"]
    J -->|"❌ Not trusted"| N["❌ Reject<br/>actor_not_trusted"]

    style K fill:#90EE90
    style L fill:#FFB6C6
    style M fill:#FFB6C6
    style N fill:#FFB6C6
```

**Key points:**
- IS 7.3 must have AWS OIDC discovery URL configured
- IS 7.3 fetches JWKS on first validation (then caches)
- Every token validation checks: signature → aud claim → actor trust policy

## 3. Claim Evolution Through the Flow

```mermaid
graph TD
    A["User gets IS 7.3 token<br/>sub=user-123<br/>scope=payments:initiate<br/>exp=3600"]

    B["Agent gets AWS OIDC<br/>sub=arn:aws:iam::123...:role/...<br/>aud=is.bank.com<br/>exp=3600"]

    C["Exchange: User token + OIDC token"]

    A --> C
    B --> C

    C --> D["IS 7.3 Issues Exchange Token<br/>sub=user-123 (preserved)<br/>act.sub=arn:aws:iam::123...:role/...<br/>scope=payments:initiate (narrowed or same)<br/>exp=900 (15 min TTL)"]

    D --> E["Payment API introspects"]

    E --> F["Response:<br/>active=true<br/>sub=user-123 (original user)<br/>act.sub=agent (acting principal)<br/>scope=payments:initiate<br/>aud=payment-api"]

    F --> G["✅ Payment API trusts chain:<br/>User authorized this<br/>Agent executed it<br/>Scope matches operation"]

    style A fill:#E3F2FD
    style B fill:#FCE4EC
    style D fill:#F3E5F5
    style G fill:#90EE90
```

**Key points:**
- `sub` is PRESERVED from user token → exchange result
- `act` is ADDED by IS 7.3 from agent's OIDC token
- `scope` is narrowed (if requested scope < subject_token scope)
- Exchange token TTL is shorter (15min vs user token 1h)

## 4. Revocation Propagation: User Revokes → Agent Token Invalidated

```mermaid
timeline
    title User Revokes Session → Agent Token Invalidated via Introspection

    section T0 (Setup)
        T0: User authenticated
        T0: User token issued {sub=user-123, exp=1h}
        T0: Agent gets exchange token {sub=user-123, act.sub=agent, exp=15min}

    section T5min (Agent calls Payment API)
        T5min: Agent calls Payment API with exchange token
        T5min: Payment API introspects token at IS 7.3
        T5min: IS 7.3 checks: parent token active? YES
        T5min: ✅ Response: active=true

    section T10min (User revokes)
        T10min: User revokes session in IS 7.3 Console
        T10min: IS 7.3 marks user's token as revoked

    section T12min (Agent calls again)
        T12min: Agent calls Payment API with same exchange token
        T12min: Payment API introspects token at IS 7.3
        T12min: IS 7.3 checks: parent token active? NO (revoked)
        T12min: ❌ Response: active=false
        T12min: ❌ Payment API rejects request

    section T15min (Token expires anyway)
        T15min: Exchange token TTL expires
        T15min: Token is useless (would be rejected even without revocation)
```

**Key points:**
- Introspection-based validation enables immediate revocation
- User revocation invalidates ALL derived tokens immediately
- If APIs use local JWT validation (no introspection), revocation is not seen until TTL expires

## 5. Actor Trust Policy: Which Agents Can Exchange?

```mermaid
flowchart TD
    A["Actor Trust Policy<br/>Configured in IS 7.3 Console<br/>per-application"]

    A --> B["allowed_actors:<br/>1. PaymentOrchestratorRole<br/>2. FraudCheckerToolRole"]

    B --> C["Request: agent=AdminProvisioningRole<br/>tries token exchange"]

    C --> D{"Is AdminProvisioningRole<br/>in allowed_actors list?"}

    D -->|"No"| E["❌ Deny<br/>actor_not_trusted_for_exchange"]

    B --> F["Request: agent=PaymentOrchestratorRole<br/>tries token exchange"]

    F --> G{"Is PaymentOrchestratorRole<br/>in allowed_actors list?"}

    G -->|"Yes"| H["✅ Allow exchange<br/>Issue token with act.sub=PaymentOrchestratorRole"]

    style E fill:#FFB6C6
    style H fill:#90EE90
```

**Key points:**
- Actor trust policy is the final gate (after OIDC signature validation)
- Prevents unauthorized agents from exchanging user tokens
- Configured per-application in IS 7.3 (not in this role, but in Console)
- Essential for compliance: ensures only known, vetted agents can delegate
