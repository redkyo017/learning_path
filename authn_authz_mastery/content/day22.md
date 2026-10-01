# Day 22 — JWT Bearer Assertion (RFC 7523)

## Why this matters

A fintech integrates their backend service with the bank's WSO2 IS 7.3 using a client secret stored in Kubernetes Secrets. During a routine SOC 2 audit: the secret was accidentally committed to the Git repository 18 months ago. The old commit is still in history. The bank is exposed. JWT Bearer Assertion (RFC 7523) eliminates the shared secret entirely — the client proves identity by signing a short-lived JWT with its private key. The private key never leaves the client.

## Core concepts

### 1. RFC 7523 client authentication (section 2.2)

Token request uses `client_assertion_type` and `client_assertion` as POST body parameters, **NOT in the Authorization header**:

- `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`
- `client_assertion=<signed JWT>` — the JWT proving the client's identity
- The JWT is signed with the client's private key; IS 7.3 verifies with the registered public key (from JWKS)

### 2. Required JWT claims for `private_key_jwt` client authentication

- `iss`: client_id (who signed this assertion)
- `sub`: client_id (same as iss for client auth — the assertion is about this client)
- `aud`: token endpoint URL (e.g., `https://is.bank.com/oauth2/token`) — prevents reuse at other endpoints
- `jti`: UUIDv4 (replay prevention — IS 7.3 caches recent jtis; duplicate = rejected)
- `exp`: ≤ 5 minutes from now (short-lived assertion; NOT the access token expiry)

### 3. IS 7.3 `private_key_jwt` client configuration

- DCR field: `"token_endpoint_auth_method": "private_key_jwt"`
- DCR field: `"jwks_uri": "https://<client-host>/jwks"` — IS 7.3 fetches public keys from here
- Alternative: `"jwks": { ... }` — embed JWKS directly in DCR registration
- IS 7.3 verifies: JWT signature (against JWKS), `aud` == token endpoint, `exp` not expired, `iss` == registered client_id, `jti` not seen before

### 4. Asymmetric advantage over `client_secret`

- Private key never leaves the client (asymmetric — only public key is shared)
- Rotating the key: update the JWKS endpoint (no secret distribution to IS 7.3)
- Compromise scope: leaked private key → revoke/replace JWKS entry; no shared secret to rotate at IS 7.3
- Audit: IS 7.3 logs which client authenticated; `jti` provides per-request trace

### 5. RFC 7523 section 2.1 — JWT bearer authorization grant

- `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`
- `assertion=<JWT with sub=user>` — a pre-authorized service presents a JWT about a user and gets an access token for that user
- Used when there's a pre-established trust relationship (e.g., a service with pre-authorization to act for users without interactive consent)
- **Distinct from section 2.2** (client auth) — section 2.1 is an authorization grant, not client authentication

## WSO2 IS 7.3 / AgentCore mapping

### IS 7.3 DCR registration for `private_key_jwt` client

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <PLACEHOLDER: admin-base64>

{
  "client_name": "payment-orchestrator",
  "grant_types": ["authorization_code", "urn:ietf:params:oauth:grant-type:token-exchange"],
  "redirect_uris": ["https://<PLACEHOLDER: app-host>/callback"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<PLACEHOLDER: client-host>/.well-known/jwks.json"
}
```

### Token request with `private_key_jwt` (FORM BODY — NOT Authorization: Bearer)

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=<PLACEHOLDER: auth-code>
&redirect_uri=https://<PLACEHOLDER: app-host>/callback
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: signed-jwt>
```

### JWT payload for `client_assertion`

```json
{
  "iss": "<PLACEHOLDER: client_id>",
  "sub": "<PLACEHOLDER: client_id>",
  "aud": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "jti": "<PLACEHOLDER: UUIDv4>",
  "exp": "<PLACEHOLDER: now+300>",
  "iat": "<PLACEHOLDER: now>"
}
```

### AgentCore mapping

AgentCore agents register with IS 7.3 as `private_key_jwt` clients. The agent's JWKS is derived from its IAM role's OIDC credentials or a dedicated JWT signing key. IS 7.3 fetches the JWKS on first authentication and caches it (TTL configurable).

## Anti-patterns

1. **`exp` more than 5 minutes in the future** — IS 7.3 may enforce a maximum assertion lifetime; large `exp` values create a wide replay window and may cause IS 7.3 to reject the assertion with `invalid_client`

2. **Reusing the same `jti` across requests** — IS 7.3 caches recent jtis to prevent replay; a duplicate `jti` returns `invalid_client`. Generate a fresh UUIDv4 per request

3. **Using `Authorization: Bearer <client_assertion>`** — the `Bearer` scheme signals resource access authorization, not client authentication. IS 7.3 treats this as an anonymous request with a malformed Authorization header, not a `private_key_jwt` client auth attempt

## Exercises

**Exercise 1:** Write the complete token request form body for `private_key_jwt` client authentication to IS 7.3's token endpoint with `client_credentials` grant.

**Hint:** `client_assertion_type` and `client_assertion` go in the POST body — same place as `grant_type`.

**Solution sketch:** `POST /oauth2/token`, Content-Type: `application/x-www-form-urlencoded`. Body: `grant_type=client_credentials&scope=payments:read&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=<signed JWT>`. The JWT has `iss`=`sub`=client_id, `aud`=token endpoint URL, `jti`=fresh UUIDv4, `exp`=now+300, `iat`=now. No `Authorization` header.

---

**Exercise 2:** An engineer generates a `client_assertion` JWT with `exp=now+7200` (2 hours) and reuses the same UUIDv4 `jti` for all requests in that window. Which IS 7.3 validation will fail, and why?

**Hint:** IS 7.3 caches `jti` values for replay prevention — how long?

**Solution sketch:** The second request with the same `jti` will be rejected with `invalid_client` — IS 7.3 has already seen this `jti`. The 2h `exp` compounds the problem: IS 7.3 must cache the `jti` for up to 2h, increasing memory pressure. Fix: UUIDv4 per request, `exp` ≤ 300s. Most IS 7.3 deployments enforce a configurable max assertion lifetime; exceeding it returns `invalid_client` before the replay check.

---

**Exercise 3:** An AgentCore agent needs to authenticate to IS 7.3 using `private_key_jwt`. During testing, the engineer gets `invalid_client: JWKS validation failed`. What are the three most likely causes?

**Hint:** IS 7.3 fetches the JWKS and verifies: signature, `kid` match, key algorithm.

**Solution sketch:** (1) The JWKS URI registered in DCR is unreachable from IS 7.3's network — IS 7.3 can't fetch the public key. (2) The JWT uses `"alg": "RS256"` but the JWKS has only an `"alg": "ES256"` key — algorithm mismatch. (3) The JWT's `kid` doesn't match any key in the JWKS — IS 7.3 can't find the right public key to verify the signature. Check in order: network reachability → JWKS key algorithm → `kid` consistency.

## Lab

See `labs/day22/README.md` — issue a `private_key_jwt` token request to IS 7.3 and understand all 5 JWT claims.
