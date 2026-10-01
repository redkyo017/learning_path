# Day 01 — FAPI 2.0 Authorization Flow Diagram

## Full FAPI 2.0 Flow

```mermaid
sequenceDiagram
    participant C as Client (TPP)
    participant PAR as PAR Endpoint
    participant AS as Authorization Server
    participant U as User (Browser)
    participant TE as Token Endpoint
    participant RS as Resource Server

    Note over C,PAR: Back channel — parameters never touch browser
    C->>PAR: POST /par<br/>client_id, redirect_uri, code_challenge,<br/>response_type=code, scope, authorization_details
    PAR-->>C: 201 {request_uri, expires_in: 90}

    Note over C,U: Front channel — only opaque reference
    C->>U: Redirect to /authorize?client_id=X&request_uri=urn:...
    U->>AS: GET /authorize?client_id=X&request_uri=urn:...
    AS->>AS: Fetch PAR request by request_uri<br/>Validate client, scopes, authorization_details
    AS->>U: Login + consent UI
    U->>AS: Authenticate (SCA factors)
    AS->>AS: Issue auth code, bind code_challenge

    Note over AS,U: JARM — response as signed JWT
    AS->>U: Redirect to redirect_uri?response=JWT
    U->>C: Deliver JARM JWT
    C->>C: Verify JARM signature, iss, aud, exp

    Note over C,TE: Back channel — code exchange with PKCE
    C->>TE: POST /token<br/>code, code_verifier, client_assertion (private_key_jwt)
    TE->>TE: Verify code_verifier against code_challenge<br/>Verify client_assertion signature
    TE-->>C: {access_token, token_type, ...}

    C->>RS: GET /resource<br/>Authorization: Bearer access_token
    RS-->>C: 200 Resource data
```

## Key security properties at each step

| Step | Protocol | What it prevents |
|------|----------|-----------------|
| PAR POST | PAR (RFC 9126) | Front-channel parameter leakage |
| `request_uri` only in redirect | PAR | Authorization params in browser logs/history |
| JARM response | JARM | Response tampering, replay |
| `code_verifier` at token endpoint | PKCE | Authorization code interception |
| `private_key_jwt` client auth | FAPI 2.0 | Client impersonation |
