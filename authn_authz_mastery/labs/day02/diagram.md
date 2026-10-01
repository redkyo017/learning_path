# Day 02 — PAR Front-Channel vs Back-Channel Separation

```mermaid
sequenceDiagram
    participant C as Client Server
    participant AS as Auth Server /par
    participant B as Browser
    participant AZ as Auth Server /authorize

    Note over C,AS: Step 1 — Back channel (server-to-server)
    C->>AS: POST /par<br/>Content-Type: application/x-www-form-urlencoded<br/>client_id=s6BhdRkqt3<br/>response_type=code<br/>redirect_uri=https://tpp.example.com/callback<br/>code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM<br/>code_challenge_method=S256<br/>scope=openid+payments<br/>authorization_details=[{"type":"payment_initiation",...}]
    AS-->>C: HTTP 201 Created<br/>{"request_uri":"urn:ietf:params:oauth:request_uri:6esc_11ACC5bwc014ltc14eY",<br/>"expires_in":90}

    Note over C,B: Step 2 — Front channel (tiny URL, no params)
    C->>B: HTTP 302<br/>Location: /authorize?client_id=s6BhdRkqt3&request_uri=urn:ietf:...
    B->>AZ: GET /authorize?client_id=s6BhdRkqt3&request_uri=urn:ietf:...

    Note over B,AZ: User authenticates — auth server fetches full request by request_uri internally
    AZ-->>B: JARM response JWT in redirect
```

## What gets logged at each step

| Step | What is in server logs | Risk if exposed |
|------|----------------------|-----------------|
| PAR POST | Full auth params — but it is back-channel TLS | No browser, no proxy, safe |
| Redirect URL | Only `client_id` + `request_uri` (opaque) | Opaque reference — no sensitive data |
| JARM redirect | Signed JWT | Tamper-evident; replaying fails `exp` check |
