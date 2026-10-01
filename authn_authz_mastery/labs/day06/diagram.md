# Day 06 — mTLS Certificate-Bound Token Flow

## Full mTLS Flow: Handshake → Token Issuance → Resource Request → Validation

```mermaid
sequenceDiagram
    participant C as TPP Client
    participant AS as Authorization Server
    participant GW as API Gateway (TLS termination)
    participant B as Backend Service

    Note over C,AS: Phase 1: mTLS Client Auth + Token Issuance

    C->>AS: TLS handshake — presents client certificate
    AS->>AS: Validate cert chain OR thumbprint match<br/>(tls_client_auth or self_signed_tls_client_auth)
    AS->>AS: Extract x5t#S256 from client cert

    C->>AS: POST /token<br/>grant_type=authorization_code + code + client auth via mTLS

    AS->>AS: Issue access_token with cnf.x5t#S256 = <cert thumbprint>
    AS-->>C: {access_token: ..., cnf: {x5t#S256: <PLACEHOLDER>}}

    Note over C,B: Phase 2: Resource Request via API Gateway

    C->>GW: TLS handshake — presents same client certificate
    GW->>GW: Validate client cert<br/>Compute x5t#S256 thumbprint

    C->>GW: GET /accounts<br/>Authorization: Bearer <bound_access_token>

    GW->>B: GET /accounts<br/>Authorization: Bearer <bound_access_token><br/>X-Client-Cert-Thumbprint: <x5t#S256>

    Note over GW,B: Full PEM is NOT forwarded — thumbprint only

    Note over B: Phase 3: Backend Validation

    B->>AS: POST /introspect<br/>token=<bound_access_token>
    AS-->>B: {active:true, cnf:{x5t#S256:<PLACEHOLDER>}}

    B->>B: Assert:<br/>X-Client-Cert-Thumbprint == cnf.x5t#S256

    B-->>GW: 200 Account data
    GW-->>C: 200 Account data
```

## What each step prevents

| Step | Security property |
|------|------------------|
| mTLS client auth at AS | Only the registered client with the matching cert can obtain tokens |
| `cnf.x5t#S256` in token | Token is bound to the cert used at issuance |
| Gateway extracts thumbprint | Backend never sees raw TLS; thumbprint is forwarded |
| Backend verifies thumbprint == cnf | Stolen token without matching cert is rejected |
| Gateway strips cert headers from external requests | Prevents thumbprint spoofing by external callers |
