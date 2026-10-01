# Day 15 Lab — DPoP + mTLS Token Binding Diagrams

## Diagram 1: DPoP end-to-end flow through IS 7.3

The diagram shows where `DPoP:` headers must pass, where IS 7.3 embeds `cnf.jkt`,
and where the resource server validates binding. **Both gateway hops** must forward
the `DPoP:` header or the flow breaks.

```mermaid
sequenceDiagram
    participant C as Client (Mobile App)
    participant GW as API Gateway<br/>(TLS termination, NGINX)
    participant IS as WSO2 IS 7.3<br/>Token Endpoint
    participant RS as Resource Server
    participant IN as IS 7.3<br/>Introspection

    Note over C,GW: Phase 1 — Token issuance with DPoP proof
    C->>GW: POST /oauth2/token<br/>DPoP: <proof_jwt_1><br/>  ├─ jwk: {client public key}<br/>  ├─ htm: "POST"<br/>  ├─ htu: "https://identity.bank.com/oauth2/token"<br/>  ├─ iat: 1789008700<br/>  └─ jti: "<unique_id_1>"<br/>grant_type=authorization_code<br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>

    Note over GW: GATEWAY CONFIG REQUIRED:<br/>proxy_pass_header DPoP;<br/>or: add_header / proxy_set_header DPoP $http_dpop;
    GW->>IS: Forward with DPoP header intact
    IS->>IS: Validate DPoP proof:<br/>  1. Verify proof JWT signature<br/>  2. Check htm="POST", htu matches token endpoint URL<br/>  3. Check iat within skew tolerance (60s)<br/>  4. Check jti not seen before (replay)<br/>  5. Extract public key from proof jwk header<br/>  6. Compute SHA-256 thumbprint of jwk → jkt

    IS->>IS: Embed cnf.jkt in access token<br/>{..., "cnf": {"jkt": "<thumbprint>"}}
    IS-->>GW: 200<br/>{access_token (with cnf.jkt), token_type:"DPoP", expires_in:3600}
    GW-->>C: {access_token, token_type:"DPoP"}

    Note over C,GW: Phase 2 — API call with DPoP-bound token
    C->>GW: GET /api/payments<br/>Authorization: DPoP <access_token><br/>DPoP: <proof_jwt_2><br/>  ├─ jwk: {same client public key}<br/>  ├─ htm: "GET"<br/>  ├─ htu: "https://api.bank.com/api/payments"<br/>  ├─ ath: base64url(SHA-256(access_token))<br/>  ├─ iat: 1789008750<br/>  └─ jti: "<unique_id_2>"

    Note over GW: GATEWAY CONFIG REQUIRED (second hop):<br/>DPoP header must reach the resource server.
    GW->>RS: GET /api/payments<br/>Authorization: DPoP <access_token><br/>DPoP: <proof_jwt_2>

    Note over RS: Phase 3 — Resource server validates binding
    RS->>IN: POST /oauth2/introspect<br/>token=<access_token>
    IN-->>RS: {active:true, cnf:{jkt:"<thumbprint>"}, sub:..., scope:...}

    RS->>RS: DPoP validation checklist:<br/>  1. cnf.jkt present → REQUIRE DPoP: header<br/>  2. Parse proof_jwt_2<br/>  3. Verify signature against public key whose jkt = cnf.jkt<br/>  4. Check htm="GET" matches request method<br/>  5. Check htu matches this endpoint URL<br/>  6. Verify ath = base64url(SHA-256(access_token))<br/>  7. Check iat within skew tolerance<br/>  8. Check jti not replayed<br/>  → ALL checks pass → request accepted

    RS-->>GW: 200 Resource data
    GW-->>C: 200 Resource data
```

---

## Diagram 2: mTLS token binding — IS 7.3 behind a reverse proxy

```mermaid
sequenceDiagram
    participant C as Client
    participant GW as NGINX<br/>(mTLS termination)
    participant IS as WSO2 IS 7.3<br/>(plain HTTP internally)
    participant RS as Resource Server

    Note over C,GW: Client presents certificate in TLS handshake
    C->>GW: POST /oauth2/token [mTLS: client cert presented]<br/>grant_type=authorization_code<br/>client_assertion_type=...jwt-bearer<br/>client_assertion=<PLACEHOLDER>

    Note over GW: NGINX terminates mTLS.<br/>Extracts client cert, PEM-encodes, URL-escapes.<br/>Forwards in header: ssl-client-cert: <cert>
    GW->>IS: POST /oauth2/token (plain HTTP)<br/>ssl-client-cert: <PLACEHOLDER: url_escaped_pem_cert><br/>(IS 7.3 reads cert from this header per deployment.toml)

    IS->>IS: Read cert from ssl-client-cert header<br/>(requires: ssl_client_cert_header_name = "ssl-client-cert"<br/>           enable_ssl_cert_from_header = true)<br/>Compute SHA-256 thumbprint of cert → x5t<br/>Embed cnf.x5t#S256 in access token

    IS-->>GW: 200 {access_token with cnf.x5t#S256}
    GW-->>C: {access_token}

    Note over C,RS: Client presents same cert when using token
    C->>GW: GET /api/accounts [mTLS: same client cert]<br/>Authorization: Bearer <access_token>
    GW->>RS: GET /api/accounts<br/>ssl-client-cert: <PLACEHOLDER: cert><br/>Authorization: Bearer <access_token>

    RS->>RS: Introspect token → cnf.x5t#S256 present<br/>Compute thumbprint of presented cert<br/>Compare to cnf.x5t#S256 — must match
    RS-->>GW: 200 Account data
    GW-->>C: 200 Account data
```

---

## Diagram 3: DPoP vs. mTLS binding precedence

```mermaid
flowchart TD
    A([Token request arrives at IS 7.3]) --> B{DPoP: header present<br/>AND valid?}
    B -->|Yes| C[Validate DPoP proof<br/>Extract public key<br/>Compute jkt thumbprint]
    C --> D[Issue token with<br/>cnf.jkt = jkt<br/>token_type = DPoP]
    D --> E([mTLS cert IGNORED<br/>even if also present])

    B -->|No| F{mTLS cert available?<br/>tls_client_certificate_bound_access_tokens=true?}
    F -->|Yes| G[Extract cert thumbprint]
    G --> H[Issue token with<br/>cnf.x5t#S256 = thumbprint<br/>token_type = Bearer]

    F -->|No| I{dpop_token_binding_required = true?}
    I -->|Yes| J[400 invalid_dpop_proof<br/>DPoP proof required]
    I -->|No| K[Issue unbound Bearer token<br/>No cnf claim]
```
