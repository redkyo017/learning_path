# Day 05 — DPoP Flow Diagram

## Full DPoP Token Request and Resource Request Flow

```mermaid
sequenceDiagram
    participant C as Client (holds private key)
    participant AS as Authorization Server
    participant RS as Resource Server

    Note over C: Generate EC key pair.<br/>Private key never leaves client.

    Note over C,AS: Token request with DPoP proof
    C->>AS: POST /token<br/>DPoP: proof_1{typ:dpop+jwt, alg:ES256, jwk:{public_key}}<br/>         {jti:uuid1, htm:POST, htu:https://as.bank.com/token, iat:now}<br/>+ grant_type=authorization_code + client_assertion

    AS->>AS: Verify proof_1 signature with jwk in header
    AS->>AS: Verify htm=POST, htu=/token match request
    AS->>AS: Compute jkt = base64url(sha256(canonical jwk JSON))
    AS->>AS: Issue access_token with cnf.jkt = <thumbprint>

    AS-->>C: {access_token, token_type:DPoP, cnf:{jkt:<PLACEHOLDER>}}

    Note over C,RS: Resource request with new DPoP proof
    Note over C: Compute ath = base64url(sha256(access_token bytes))
    Note over C: Generate new proof — different jti, htm=GET, htu=/accounts

    C->>RS: GET /accounts<br/>Authorization: DPoP <access_token><br/>DPoP: proof_2{typ:dpop+jwt, alg:ES256, jwk:{public_key}}<br/>         {jti:uuid2, htm:GET, htu:https://api.bank.com/accounts, iat:now, ath:<hash>}

    RS->>RS: 1. Decode access_token → verify token_type is DPoP
    RS->>RS: 2. Verify proof_2 signature with jwk in proof header
    RS->>RS: 3. Verify ath = sha256(presented access_token)
    RS->>RS: 4. Verify htm=GET matches HTTP method
    RS->>RS: 5. Verify htu matches request URL
    RS->>RS: 6. Check jti not seen before (replay prevention)
    RS->>RS: 7. Verify cnf.jkt in token = thumbprint of jwk in proof

    RS-->>C: 200 Account data
```

## What each validation step prevents

| RS check | Attack prevented |
|----------|-----------------|
| Proof signature | Forged proof without private key |
| `ath` = sha256(token) | Proof used with a different token |
| `htm` match | Proof reused for wrong HTTP method |
| `htu` match | Proof reused for wrong endpoint |
| `jti` replay check | Proof replayed in a second request |
| `cnf.jkt` = thumbprint(jwk) | Different key pair used in proof |
