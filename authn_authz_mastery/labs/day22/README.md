# Day 22 Lab — JWT Bearer Assertion (RFC 7523)

## Objective

Issue a `private_key_jwt` token request to IS 7.3. Success signal: understand all 5 JWT claims and why IS 7.3 requires each one.

## Scenario

A fintech company (`payment-service-co`) has built a payment orchestrator backend that needs to:

1. Register as a client with IS 7.3 using `private_key_jwt` authentication
2. Authenticate to IS 7.3's token endpoint without sharing a secret (asymmetric `private_key_jwt`)
3. Exchange tokens on behalf of users (RFC 8693 token exchange) — this requires client authentication, which uses `private_key_jwt`

The fintech's environment: Kubernetes-based microservices. Storing a client secret in Kubernetes Secrets is a SOC 2 audit risk. Using `private_key_jwt` means the private key is managed as a workload identity (e.g., AWS IAM role JWKS, Kubernetes service account bound JWT).

## What you'll produce

1. A **Mermaid sequence diagram** showing:
   - Client DCR registration with `private_key_jwt` method
   - Client generates a JWT assertion
   - Client makes a token request with `client_assertion` in the POST body (not Authorization header)
   - IS 7.3 fetches JWKS and validates the JWT signature
   - IS 7.3 issues an access token

2. An **annotated HTTP file** (`config/jwt_bearer_client_auth.http`) showing:
   - DCR registration request and response
   - Token request with `client_assertion` in form body
   - Decoded JWT payload at the signing step

3. A **breakdown table** in SOLUTION.md explaining each of the 5 JWT claims and what IS 7.3 checks

## Steps

### Step 1: Review the scenario

The fintech needs to authenticate to IS 7.3 without a shared secret. They have:
- A private key (managed by Kubernetes workload identity)
- A public key endpoint at `https://fintech.local/.well-known/jwks.json`
- A client_id: `payment-orchestrator-v1`

### Step 2: Study the DCR registration

In `config/jwt_bearer_client_auth.http`, examine the DCR registration request:

```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <admin-base64>

{
  "client_name": "payment-orchestrator",
  "grant_types": ["authorization_code", "urn:ietf:params:oauth:grant-type:token-exchange"],
  "redirect_uris": ["https://<PLACEHOLDER: app-host>/callback"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<PLACEHOLDER: client-host>/.well-known/jwks.json"
}
```

**Key fields:**
- `token_endpoint_auth_method`: tells IS 7.3 this client will use `private_key_jwt`
- `jwks_uri`: where IS 7.3 can fetch the client's public keys

### Step 3: Analyze the JWT payload

The fintech generates a JWT assertion with these 5 claims:

- `iss` (issuer): who signed this? → `payment-orchestrator-v1`
- `sub` (subject): who is the subject of this assertion? → `payment-orchestrator-v1` (for client auth, same as iss)
- `aud` (audience): who should accept this JWT? → `https://is.bank.local:9443/oauth2/token` (the token endpoint URL)
- `jti` (JWT ID): unique ID for replay prevention → `<UUIDv4>`
- `exp` (expiration): when does this assertion expire? → `now + 300` (5 minutes)

### Step 4: Construct the token request

Write the form body:

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=<auth-code>
&redirect_uri=https://<app-host>/callback
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<signed-jwt>
```

**Critical**: The JWT goes in the form body as `client_assertion`, **not** in the Authorization header as Bearer.

### Step 5: Trace IS 7.3's validation

IS 7.3 receives the token request and validates:

1. Parses `client_assertion` as a JWT
2. Extracts the `kid` from the JWT header
3. Fetches JWKS from `https://fintech.local/.well-known/jwks.json`
4. Verifies JWT signature using the key matching `kid`
5. Checks: `aud` == token endpoint URL
6. Checks: `exp` not expired
7. Checks: `iss` matches the registered client_id
8. Checks: `jti` not seen before (replay prevention cache)
9. If all valid: authenticates as `payment-orchestrator-v1`
10. Proceeds with authorization_code grant

### Step 6: Verify your understanding

- [ ] I can explain why `exp` must be ≤ 5 minutes
- [ ] I can explain why `jti` must be unique per request
- [ ] I can explain why `aud` must match the token endpoint URL
- [ ] I can explain why the JWT goes in the POST body, not the Authorization header
- [ ] I understand how IS 7.3 prevents JWT reuse attacks

## Success Criteria

- Mermaid sequence diagram is complete and shows JWKS fetching
- HTTP file shows both DCR registration and token request examples
- All 5 JWT claims are explained with their IS 7.3 validation rules
- You can draw the signature verification flow from memory

## Time estimate

40–50 minutes
