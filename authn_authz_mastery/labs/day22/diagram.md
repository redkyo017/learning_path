# Day 22 Lab — RFC 7523 Client Authentication Sequence

## `private_key_jwt` Token Request Flow

```mermaid
sequenceDiagram
  participant Client as Payment Service<br/>(payment-orchestrator-v1)
  participant IS73 as IS 7.3<br/>(OAuth2 AS)
  participant JWKS as Fintech JWKS<br/>/.well-known/jwks.json

  Note over Client: Step 1: DCR Registration<br/>(one-time setup)

  Client->>IS73: POST /api/identity/oauth2/dcr/v1.1/register<br/>client_name: payment-orchestrator<br/>token_endpoint_auth_method: private_key_jwt<br/>jwks_uri: https://fintech.local/.well-known/jwks.json

  IS73->>Client: 201 Created<br/>client_id: payment-orchestrator-v1<br/>client_secret: (not provided)<br/>token_endpoint_auth_method: private_key_jwt

  Note over Client: Step 2: Generate JWT Assertion<br/>for this token request

  Note over Client: JWT Payload:<br/>{<br/>  "iss": "payment-orchestrator-v1",<br/>  "sub": "payment-orchestrator-v1",<br/>  "aud": "https://is.bank.local:9443/oauth2/token",<br/>  "jti": "uuid-<PLACEHOLDER>",<br/>  "exp": now+300,<br/>  "iat": now<br/>}

  Note over Client: Sign with private key<br/>alg: RS256

  Client->>IS73: POST /oauth2/token<br/>grant_type=authorization_code<br/>&code=<auth-code><br/>&redirect_uri=https://fintech.local/callback<br/>&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer<br/>&client_assertion=<PLACEHOLDER: base64-jwt>

  Note over IS73: Step 3: Validate JWT Assertion

  IS73->>IS73: 1. Parse JWT<br/>2. Extract kid from header<br/>3. Check aud == token endpoint

  IS73->>JWKS: GET /.well-known/jwks.json<br/>(fetch public keys)

  JWKS->>IS73: 200 OK<br/>{<br/>  "keys": [<br/>    {<br/>      "kid": "2024-001",<br/>      "kty": "RSA",<br/>      "use": "sig",<br/>      "alg": "RS256",<br/>      "n": "<PLACEHOLDER: modulus>",<br/>      "e": "AQAB"<br/>    }<br/>  ]<br/>}

  IS73->>IS73: 4. Find key matching kid<br/>5. Verify JWT signature<br/>6. Check exp not expired<br/>7. Check iss == client_id<br/>8. Check jti not in replay cache

  alt JWT validation succeeds
    IS73->>IS73: Add jti to replay cache<br/>(TTL = exp time)
    IS73->>IS73: Authenticate as<br/>payment-orchestrator-v1
    IS73->>Client: 200 OK<br/>{<br/>  "access_token": "<jwt>",<br/>  "token_type": "Bearer",<br/>  "expires_in": 3600<br/>}
  else JWT validation fails
    IS73->>Client: 400 Bad Request<br/>{<br/>  "error": "invalid_client",<br/>  "error_description": "JWT validation failed"<br/>}
  end

  Note over Client,IS73: Token is now usable for:<br/>- Token exchange (RFC 8693)<br/>- Resource server calls<br/>- Additional OAuth2 flows
```

## Key Validation Steps in Order

1. **Parse JWT**: Verify it's well-formed base64.url.base64
2. **Extract `kid`**: JWT header contains algorithm + key ID
3. **Fetch JWKS**: GET from `jwks_uri` registered in DCR
4. **Signature Verification**: Find the key matching `kid`, verify signature with client's public key
5. **`aud` Check**: `aud` claim must equal the token endpoint URL (prevents reuse at other endpoints)
6. **`exp` Check**: Assertion must not be expired
7. **`iss` Check**: `iss` must match the registered client_id
8. **`jti` Check**: `jti` must not have been seen before (replay prevention cache)

If any check fails → `invalid_client` error

## Error Scenarios

### Scenario A: `exp` More than 5 Minutes

```
JWT payload: "exp": now+7200 (2 hours)
IS 7.3 validation: May enforce max assertion lifetime (e.g., 600s)
Result: 400 invalid_client "assertion_lifetime_exceeds_limit"
```

### Scenario B: Reused `jti`

```
Request 1: client_assertion with jti=uuid-123
IS 7.3: Validates, stores uuid-123 in cache with TTL=exp_time
Result: 200 OK, token issued

Request 2 (same second): client_assertion with jti=uuid-123
IS 7.3: Looks up cache, finds uuid-123 already present
Result: 400 invalid_client "assertion_already_used"
```

### Scenario C: Incorrect `aud`

```
JWT payload: "aud": "https://wrong-server.com/oauth2/token"
IS 7.3 token endpoint: https://is.bank.local:9443/oauth2/token
Mismatch detected
Result: 400 invalid_client "aud_mismatch"
```

### Scenario D: Wrong Authorization Header

```
POST /oauth2/token
Authorization: Bearer <client_assertion>

IS 7.3: Sees Authorization header
Treats as anonymous request with malformed Bearer token
Result: 401 Unauthorized "Invalid bearer token"
(The actual client_assertion in the header is ignored!)
```

## JWKS Fetch Optimization

IS 7.3 typically **caches** the JWKS response:

- **First request**: Fetch from `jwks_uri` (cache miss)
- **Subsequent requests**: Use cached JWKS (cache hit) — faster validation
- **Cache TTL**: Usually 1 hour (configurable in IS 7.3)
- **Cache expiration**: On cache miss, re-fetch from `jwks_uri`

This reduces latency but introduces a potential key rotation delay:
- Fintech rotates private key → updates JWKS endpoint
- IS 7.3 cache still has old key → new JWTs fail validation until cache expires
- Mitigation: Set `kid` in JWT header and JWKS to enable gradual rollover
