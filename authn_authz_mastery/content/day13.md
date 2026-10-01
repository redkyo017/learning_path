# Day 13 — FAPI 2.0 Compliance Mode in IS 7.3

## Why this matters
A bank passed its FAPI 2.0 security audit on paper — the IS 7.3 configuration checklist was complete.
But in production, a TPP client was still able to register with `token_endpoint_auth_method: client_secret_basic`
and receive access tokens. IS 7.3's FAPI mode had been enabled at the server level but not enforced at the
application level: per-app overrides were silently accepting non-FAPI clients. The bank's TPP ecosystem
was FAPI-compliant on the server but not on the client registration path. Enabling FAPI mode requires both
the server-level flag and ensuring DCR rejects non-compliant client registrations.

## Core concepts

### What FAPI Compliance Mode enables in IS 7.3
When FAPI 2.0 compliance mode is active for an application, IS 7.3 enforces:
- PAR mandatory: requests without `request_uri` are rejected
- PKCE: `code_challenge_method=S256` required; plain PKCE rejected
- JARM: `response_mode=jwt` required; other response modes rejected
- Client auth: only `private_key_jwt` or `tls_client_auth`; `client_secret_*` rejected
- Response type: `code` only; `token`, `id_token`, hybrid rejected
- Request object: signed JAR (`request` or `request_uri`) required for PAR

### IS 7.3 PAR endpoint
IS 7.3 exposes PAR at `POST /oauth2/par`. The endpoint is always present; FAPI mode makes it mandatory
(requests without PAR are rejected). Discovery via `.well-known/openid-configuration`:
```json
{
  "pushed_authorization_request_endpoint": "https://<PLACEHOLDER: is-host>/oauth2/par"
}
```

### JARM in IS 7.3
IS 7.3 signs authorization responses as JWTs using the server's signing key (PS256 or ES256).
The JARM JWT carries: `iss`, `aud`, `exp`, `iat`, `code`, `state`. The TPP verifies the signature
using IS 7.3's JWKS (`/oauth2/jwks`).

### DCR (Dynamic Client Registration)
IS 7.3's DCR endpoint (`POST /api/identity/oauth2/dcr/v1.1/register`) accepts a client registration
JWT. For FAPI mode, the registration must include:
- `token_endpoint_auth_method`: `private_key_jwt` or `tls_client_auth`
- `response_types`: `["code"]`
- `grant_types`: `["authorization_code", "refresh_token"]`
- `require_pushed_authorization_requests`: `true`
- `authorization_signed_response_alg`: `PS256` or `ES256`
- `jwks_uri`: URL of the TPP's JWKS

```mermaid
sequenceDiagram
    participant TPP as TPP
    participant DCR as IS 7.3 /dcr/register
    participant PAR as IS 7.3 /oauth2/par
    participant AZ as IS 7.3 /oauth2/authorize
    participant TE as IS 7.3 /oauth2/token

    Note over TPP,DCR: One-time registration
    TPP->>DCR: POST /register {software_statement JWT, jwks_uri, require_par=true, auth_method=private_key_jwt}
    DCR-->>TPP: {client_id, client_secret=null (FAPI: no secret)}

    Note over TPP,PAR: Per-transaction flow
    TPP->>PAR: POST /par {client_id, code_challenge, authorization_details, ...}<br/>client_assertion_type=urn:...:jwt-bearer&client_assertion=<signed_jwt>
    PAR-->>TPP: {request_uri, expires_in: 90}

    TPP->>AZ: GET /authorize?client_id=X&request_uri=urn:...
    AZ-->>TPP: JARM JWT (redirect)
    TPP->>TPP: Verify JARM signature via IS 7.3 JWKS

    TPP->>TE: POST /token {code, code_verifier, client_assertion_type=..., client_assertion=<jwt>}
    TE-->>TPP: {access_token, token_type: Bearer/DPoP}
```

## WSO2 IS 7.3 mapping

### Server-level FAPI flag in deployment.toml
```toml
[oauth]
# Enable FAPI 2.0 compliance mode globally — enforces PAR, JARM, strict client auth
fapi_conformance_enabled = true

# JARM: sign all authorization responses
[oauth.oidc.jarm]
jarm_response_jwt_validity = 120
jarm_signing_algorithm = "PS256"

# PAR endpoint settings
[oauth.par]
par_request_expiry_time = 90
```

### Application-level FAPI enforcement
In IS 7.3 Console → Applications → [FAPI App] → Advanced:
- Set "Token Endpoint Auth Method" to `Private Key JWT`
- Enable "FAPI Conformance"
- Set "Response Mode" to `jwt`
- Set "Request Object Method" to `PAR`

### DCR registration for a FAPI client
```http
POST /api/identity/oauth2/dcr/v1.1/register HTTP/1.1
Host: <PLACEHOLDER: is-host>
Content-Type: application/json
Authorization: Bearer <PLACEHOLDER: dcr-registration-token>

{
  "client_name": "PSD2 TPP Banking Client",
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "private_key_jwt",
  "token_endpoint_auth_signing_alg": "PS256",
  "authorization_signed_response_alg": "PS256",
  "require_pushed_authorization_requests": true,
  "jwks_uri": "https://tpp.example.com/.well-known/jwks.json",
  "redirect_uris": ["https://tpp.example.com/callback"],
  "scope": "openid accounts payments"
}
```

### Verifying FAPI mode is enforced
```http
# Attempt non-PAR request — must fail with FAPI mode enabled
GET /oauth2/authorize?client_id=<PLACEHOLDER>&response_type=code&scope=openid HTTP/1.1
Host: <PLACEHOLDER: is-host>
# Expected response: 400 error=invalid_request, error_description="PAR is mandatory for FAPI"
```

## Anti-patterns / Common mistakes
- **Enabling FAPI at server level but not per-application** — IS 7.3 applies FAPI constraints only
  to applications registered with FAPI enabled; a non-FAPI app on the same IS 7.3 instance ignores the flag.
- **Using `Authorization: Bearer <client_assertion>` for `private_key_jwt` client auth** — FAPI requires
  `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer` and `client_assertion=<jwt>`
  as form body params in the POST body. Bearer header is rejected.
- **JARM signing key mismatch** — if IS 7.3's JARM signing key is rotated but the TPP's cached JWKS is stale,
  the TPP will reject valid JARM responses; always check `kid` in the JARM header against current JWKS.

## Exercises
1. A TPP attempts to register with DCR using `token_endpoint_auth_method: client_secret_basic`.
   IS 7.3 FAPI mode is enabled. What happens, and what must the TPP change?
   **Hint:** FAPI 2.0 disallows `client_secret_*` methods.
   **Solution sketch:** IS 7.3 rejects the DCR request with `400 Bad Request` and
   `error: invalid_client_metadata`, `error_description: "client_secret_basic not allowed in FAPI mode"`.
   The TPP must change `token_endpoint_auth_method` to `private_key_jwt` (preferred) or `tls_client_auth`,
   provide a `jwks_uri`, and ensure its signing algorithm is `PS256` or `ES256`.

2. Write the `deployment.toml` stanza that enables FAPI compliance, sets JARM signing to PS256,
   and sets PAR expiry to 60 seconds.
   **Hint:** Three separate config sections: `[oauth]`, `[oauth.oidc.jarm]`, `[oauth.par]`.
   **Solution sketch:**
   ```toml
   [oauth]
   fapi_conformance_enabled = true
   [oauth.oidc.jarm]
   jarm_response_jwt_validity = 120
   jarm_signing_algorithm = "PS256"
   [oauth.par]
   par_request_expiry_time = 60
   ```

3. A FAPI client sends a PAR request with `client_assertion` in the `Authorization: Bearer` header
   instead of the POST body. IS 7.3 rejects it. Explain why and write the corrected request.
   **Hint:** `private_key_jwt` is a form-body client auth method per RFC 7521.
   **Solution sketch:** RFC 7521 and FAPI 2.0 require `private_key_jwt` as form-body parameters.
   `Authorization: Bearer` is for access tokens, not client assertions. Corrected request:
   ```http
   POST /oauth2/par HTTP/1.1
   Host: <PLACEHOLDER: is-host>
   Content-Type: application/x-www-form-urlencoded

   client_id=<PLACEHOLDER>
   &client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
   &client_assertion=<PLACEHOLDER: signed-jwt>
   &response_type=code
   &redirect_uri=https://tpp.example.com/callback
   &code_challenge=<PLACEHOLDER>
   &code_challenge_method=S256
   ```

## Lab
See `labs/day13/`. Goal: enable FAPI mode in IS 7.3 via `deployment.toml` and register a FAPI client
via DCR. Success signal: you can identify each FAPI-required field in the config stubs and explain
why removing any one of them would cause a compliance failure.
