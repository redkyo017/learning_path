# Day 20 — APIM 4.7 + IS 7.3 Token Validation Flow

## Sequence diagram: full token validation path

```mermaid
sequenceDiagram
    participant P as Partner App (sub-org org-abc)
    participant GW as APIM 4.7 Gateway
    participant IS as IS 7.3 Introspect / JWKS
    participant BE as Backend API

    Note over P: Token has: org_id=org-abc, scope=accounts:read

    P->>GW: GET /payments/v1/accounts<br/>Authorization: Bearer <jwt>

    GW->>GW: Check token type

    alt JWT (self-contained)
        GW->>IS: GET /oauth2/jwks (cached, 1h TTL)
        IS-->>GW: JWKS (public keys)
        GW->>GW: Verify JWT signature locally
    else opaque token
        GW->>IS: POST /oauth2/introspect<br/>token=<opaque>
        IS-->>GW: {active:true, scope, org_id, cnf, ...}
    end

    GW->>GW: Subscription enforcement<br/>org_id=org-abc → org-abc subscription
    GW->>GW: Scope check: accounts:read ∈ subscribed scopes?

    GW->>BE: GET /accounts (X-Org-ID: org-abc header added)
    BE-->>GW: 200 accounts data
    GW-->>P: 200 accounts data
```

## Endpoint reference table

| APIM action | IS 7.3 endpoint | When |
|---|---|---|
| JWT validation | `/oauth2/jwks` | Every JWT (cached, ~1h) |
| Opaque token validation | `/oauth2/introspect` | Every opaque token request |
| Client registration (DCR) | `/api/identity/oauth2/dcr/v1.1/register` | At subscription key generation |
| Token generation (for APIM internal calls) | `/oauth2/token` | APIM service account tokens |
| Token revocation | `/oauth2/revoke` | Key deletion in Dev Portal |

## Key Manager config relationship diagram

```mermaid
graph TD
    APIM["APIM 4.7 Gateway\n[[apim.key_manager]]"]

    subgraph IS73["IS 7.3 Endpoints"]
        INTROSPECT["/oauth2/introspect\nOpaque token validation"]
        JWKS["/oauth2/jwks\nJWT public keys (cached)"]
        DCR["/api/identity/oauth2/dcr/v1.1/register\nOAuth2 client registration"]
        TOKEN["/oauth2/token\nAPIM service account tokens"]
        REVOKE["/oauth2/revoke\nKey revocation"]
    end

    APIM -->|"introspect_url\n(per-request, opaque tokens)"| INTROSPECT
    APIM -->|"jwks_url\n(cached 1h, JWT tokens)"| JWKS
    APIM -->|"client_registration_url\n(DCR, at key generation)"| DCR
    APIM -->|"token_url\n(service account)"| TOKEN
    APIM -->|"revoke_url\n(at key deletion)"| REVOKE

    style APIM fill:#1a1a2e,color:#e0e0e0
    style IS73 fill:#16213e,color:#e0e0e0
    style INTROSPECT fill:#0f3460,color:#e0e0e0
    style JWKS fill:#0f3460,color:#e0e0e0
    style DCR fill:#0f3460,color:#e0e0e0
    style TOKEN fill:#0f3460,color:#e0e0e0
    style REVOKE fill:#0f3460,color:#e0e0e0
```
