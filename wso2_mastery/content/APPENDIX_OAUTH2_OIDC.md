# OAuth2/OIDC — Theory Reference

> A standalone theory reference covering all OAuth2/OIDC concepts, flows, and protocols.
> Vendor-neutral. All RFC references are authoritative. Actor-to-WSO2 mappings in Section 1 only.

---

## Table of Contents

1. [The Four Actors](#1-the-four-actors)
2. [Token Anatomy](#2-token-anatomy)
3. [Grant Types](#3-grant-types)
4. [OIDC Extensions](#4-oidc-extensions)
5. [Token Lifecycle](#5-token-lifecycle)
6. [Advanced Protocols](#6-advanced-protocols)
7. [Federation, IDP, Trusted Issuers](#7-federation-idp-trusted-issuers)
8. [Endpoints Reference](#8-endpoints-reference)
9. [SCIM2](#9-scim2)
10. [Top-1% Mistakes](#10-top-1-mistakes)

---

## 1. The Four Actors

**RFC 6749 §1.1**

OAuth2 defines four roles. Every flow involves some combination of these actors.

```mermaid
graph LR
    RO["Resource Owner\n(Human User / Service)"]
    C["Client\n(Application)"]
    AS["Authorization Server\n(issues tokens)"]
    RS["Resource Server\n(hosts protected resource)"]

    RO -->|"1. grants authorization"| C
    C -->|"2. authorization request"| AS
    AS -->|"3. access token"| C
    C -->|"4. API call + token"| RS
    RS -->|"5. protected resource"| C
    AS -. "JWKS / trust anchor" .-> RS
```

### Resource Owner

The entity whose protected resources are being accessed. Usually a human user; can also be a service acting on its own behalf (the client and resource owner are the same entity in Client Credentials flow).

### Client

The application requesting access. Two subtypes:

| Type | Description | Examples |
|---|---|---|
| **Confidential** | Can securely store a client secret (runs on a server) | Backend API, microservice |
| **Public** | Cannot keep a secret (runs in an environment the user controls) | SPA, mobile app, CLI |

Clients must be **registered** with the Authorization Server before any flow can begin. Registration produces a `client_id` (and optionally a `client_secret` for confidential clients).

### Authorization Server (AS)

Issues tokens after authenticating the Resource Owner and obtaining their authorization. Owns the `/authorize` and `/token` endpoints. Publishes its JWKS (public keys) so Resource Servers can verify tokens locally.

### Resource Server (RS)

Hosts the protected resource (an API). Accepts requests bearing a valid access token. Validates the token — either locally (JWT) or by calling the AS's introspection endpoint.

### WSO2 Component Mapping

| OAuth2 Role | WSO2 Component |
|---|---|
| Authorization Server | WSO2 Identity Server (IS) |
| Resource Server | WSO2 Universal Gateway (GW) |
| Client (publisher) | WSO2 APIM Control Plane (API Publisher UI / REST API) |
| Client (subscriber) | WSO2 Developer Portal / consumer application |
| Resource Owner | End-user or service account in WSO2 IS user store |

---

## 2. Token Anatomy

**RFC 6749 §1.4–1.5, RFC 7519, RFC 7517**

### Token Types

| Token | Description | Format | Lifetime |
|---|---|---|---|
| **Access Token** | Credential for accessing a protected resource | Opaque string or JWT | Short (5–15 min) |
| **Refresh Token** | Credential for obtaining a new access token without re-authentication | Opaque string | Long (hours–days) |
| **ID Token** | Assertion about the identity of the authenticated user (OIDC only) | Always JWT | Short (same as session) |
| **Authorization Code** | Short-lived one-time code exchanged for tokens at the token endpoint | Opaque string | Very short (seconds) |

### Opaque vs JWT Access Tokens

| | Opaque | JWT |
|---|---|---|
| **Validation** | Must call AS introspection endpoint | Local: verify signature + claims |
| **Revocation** | Immediate (AS marks invalid) | Eventual (wait for `exp`; or maintain blocklist) |
| **Performance** | Extra network call per request | Zero extra calls |
| **Best for** | High-security, real-time revocation required | High-throughput APIs, distributed RS |

### JWT Structure

A JWT has three Base64URL-encoded parts separated by dots: `header.payload.signature`

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImtleS0yMDI0LTAxIn0
.
eyJpc3MiOiJodHRwczovL2FzLmV4YW1wbGUuY29tIiwic3ViIjoidXNlcjEyMyIsImF1ZCI6ImFwaS5leGFtcGxlLmNvbSIsImV4cCI6MTcyNjUwMDAwMCwiaWF0IjoxNzI2NDk2NDAwLCJqdGkiOiJhYmMteHl6LTc4OSIsInNjb3BlIjoicmVhZDpvcmRlcnMiLCJjbGllbnRfaWQiOiJteS1hcHAifQ
.
SIGNATURE
```

**Header claims:**

| Claim | Meaning | Example |
|---|---|---|
| `alg` | Signature algorithm | `RS256` (preferred), `ES256`, `HS256` (avoid) |
| `typ` | Token type | `JWT` |
| `kid` | Key ID — which key in the JWKS was used to sign | `key-2024-01` |

**Standard payload claims (RFC 7519):**

| Claim | Mandatory? | Meaning |
|---|---|---|
| `iss` | Recommended | Issuer — URI of the Authorization Server |
| `sub` | Recommended | Subject — unique identifier for the user or service within this issuer |
| `aud` | Recommended | Audience — the RS(s) this token is intended for; RS must reject if its ID is not listed |
| `exp` | Required | Expiration — Unix timestamp; token MUST be rejected after this time |
| `iat` | Optional | Issued-at — Unix timestamp when token was minted |
| `nbf` | Optional | Not-before — token MUST be rejected before this time |
| `jti` | Optional | JWT ID — unique identifier for this token; used for replay detection |
| `scope` | Not in RFC 7519 (de-facto) | Space-separated list of granted scopes |
| `client_id` | Not in RFC 7519 (de-facto) | The OAuth2 client that requested this token |
| `azp` | OIDC | Authorized party — the client the token was issued to when `aud` is multi-valued |

**OIDC-specific claims (OIDC Core):**

| Claim | Meaning |
|---|---|
| `nonce` | Replay protection: value from the authorization request, echoed in ID token |
| `auth_time` | Unix timestamp of the user's most recent authentication event |
| `acr` | Authentication Context Class Reference — the level/method of authentication used |
| `amr` | Authentication Methods References — array, e.g. `["pwd", "otp"]` |
| `at_hash` | Hash of the access token — binds the ID token to its paired access token |
| `c_hash` | Hash of the authorization code — present in ID tokens returned from `/authorize` |

### JWK and JWKS (RFC 7517)

The AS publishes its signing public key(s) at a JWKS URI (e.g. `/.well-known/jwks.json`). Each key is a JSON Web Key (JWK). The RS fetches this at startup (or on `kid` cache miss) and uses the public key to verify JWT signatures locally.

```json
{
  "keys": [{
    "kty": "RSA",
    "kid": "key-2024-01",
    "use": "sig",
    "alg": "RS256",
    "n": "...",
    "e": "AQAB"
  }]
}
```

**Signature algorithms:**

| Algorithm | Type | Use |
|---|---|---|
| `RS256` | Asymmetric (RSA) | **Recommended for distributed systems** — AS signs with private key, RS verifies with public key |
| `ES256` | Asymmetric (ECDSA) | Smaller signatures than RSA; good for mobile |
| `HS256` | Symmetric (HMAC) | Shared secret — AS and RS must share the secret; **avoid in distributed systems** |

---

## 3. Grant Types

**RFC 6749, RFC 7636 (PKCE), RFC 8628 (Device), RFC 6819 (Security)**

A grant type is the OAuth2 flow a client uses to obtain tokens. The right choice depends on the client type, whether a human user is involved, and the security model.

| Grant Type | RFC | Use case | Has Refresh Token? |
|---|---|---|---|
| Authorization Code + PKCE | RFC 6749 + RFC 7636 | User-facing apps (web, mobile, SPA) | Yes |
| Client Credentials | RFC 6749 §4.4 | Machine-to-machine, no user | No |
| Device Authorization | RFC 8628 | Input-constrained devices (TV, CLI) | Yes |
| Refresh Token | RFC 6749 §6 | Extend access without re-authentication | Replaces itself |
| ROPC (deprecated) | RFC 6749 §4.3 | **Avoid** — client sees credentials | Yes |
| Implicit (deprecated) | RFC 6749 §4.2 | **Avoid** — token in URL fragment | No |

---

### 3.1 Authorization Code + PKCE

**Problem:** How can a user authorize a client to access their data without giving the client their credentials? And how can we prevent an attacker from intercepting the authorization code?

**PKCE (RFC 7636)** solves code interception for public clients by replacing the client secret with a cryptographic challenge. Use PKCE for **all** clients — confidential and public.

**PKCE generation:**
1. Client generates `code_verifier`: a random string, 43–128 characters, URL-safe
2. Client computes `code_challenge = BASE64URL(SHA256(code_verifier))`
3. `code_challenge` travels in the authorization request (public channel)
4. `code_verifier` travels in the token request (back channel, never exposed in URL)

```mermaid
sequenceDiagram
    participant RO as Resource Owner
    participant C as Client
    participant AS as Authorization Server
    participant RS as Resource Server

    C->>C: Generate code_verifier (random 43-128 chars)
    C->>C: code_challenge = BASE64URL(SHA256(code_verifier))
    C->>AS: GET /authorize?response_type=code&client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&scope=openid profile&state=STATE&code_challenge=CHALLENGE&code_challenge_method=S256
    AS->>RO: Display login + consent screen
    RO->>AS: Authenticate + authorize
    AS->>C: Redirect → REDIRECT_URI?code=AUTH_CODE&state=STATE
    C->>C: Verify state matches (CSRF protection)
    C->>AS: POST /token {grant_type=authorization_code, code=AUTH_CODE, redirect_uri=REDIRECT_URI, client_id=CLIENT_ID, code_verifier=VERIFIER}
    AS->>AS: Verify BASE64URL(SHA256(VERIFIER)) == CHALLENGE
    AS->>C: {access_token, token_type, expires_in, refresh_token, id_token}
    C->>RS: GET /resource Authorization: Bearer ACCESS_TOKEN
    RS->>RS: Validate JWT (sig, iss, aud, exp)
    RS->>C: Protected resource
```

**Key steps annotated:**
- `state` parameter: random value; client verifies it matches on redirect to prevent CSRF
- `redirect_uri` must exactly match the registered URI — no wildcards
- Token request is a direct back-channel POST (not a redirect) — AUTH_CODE never touches the URL again
- AS verifies the PKCE challenge before issuing tokens

**Security notes:**
- Always use `code_challenge_method=S256` — plain is insecure
- `state` is mandatory; `nonce` mandatory for OIDC flows
- Short code lifetime: 10 seconds–1 minute; single-use

---

### 3.2 Client Credentials

**Problem:** A backend service needs to call another service's API. There is no human user.

**Who uses it:** Machine-to-machine (M2M) — microservices, batch jobs, daemons, CI pipelines.

```mermaid
sequenceDiagram
    participant C as Client (Service)
    participant AS as Authorization Server
    participant RS as Resource Server

    C->>AS: POST /token {grant_type=client_credentials, client_id=CLIENT_ID, client_secret=CLIENT_SECRET, scope=read:data}
    AS->>AS: Authenticate client, check scope
    AS->>C: {access_token, token_type=bearer, expires_in, scope}
    Note over C,AS: No refresh token — client re-authenticates directly
    C->>RS: GET /resource Authorization: Bearer ACCESS_TOKEN
    RS->>C: Protected resource
```

**Key points:**
- No Resource Owner — the client IS the resource owner of its own service identity
- No refresh token issued; client re-authenticates when the token expires
- Client authentication: `client_secret` in request body, or HTTP Basic Auth, or private_key_jwt (preferred for high-security)
- Use narrow scopes — principle of least privilege applies here too

---

### 3.3 Device Authorization Flow (RFC 8628)

**Problem:** A device with no browser or limited input (smart TV, CLI tool, IoT sensor) needs the user to authorize it. The device cannot complete the browser redirect itself.

**Key insight:** Decouples the authorization device (TV/CLI) from the user's authentication device (phone/laptop browser).

```mermaid
sequenceDiagram
    participant D as Device (Input-Constrained)
    participant AS as Authorization Server
    participant U as User (Phone/Browser)

    D->>AS: POST /device_authorization {client_id=CLIENT_ID, scope=openid profile}
    AS->>D: {device_code=DEVICE_CODE, user_code=ABCD-1234, verification_uri=https://as.example/activate, expires_in=600, interval=5}
    D->>U: Display: "Visit https://as.example/activate — enter code ABCD-1234"
    loop Poll every `interval` seconds until authorized or expired
        D->>AS: POST /token {grant_type=urn:ietf:params:oauth:grant-type:device_code, device_code=DEVICE_CODE, client_id=CLIENT_ID}
        AS->>D: {error: authorization_pending} or {error: slow_down} or tokens
    end
    U->>AS: Browser: visit verification_uri, enter user_code
    AS->>U: Login + consent screen
    U->>AS: Authenticate + authorize
    D->>AS: POST /token (next poll)
    AS->>D: {access_token, refresh_token, expires_in, ...}
```

**Key points:**
- `user_code` is short and human-typeable (e.g. `ABCD-1234`)
- Client polls at the `interval` from the response; back off on `slow_down` error
- `expires_in` in the device authorization response: the device code's lifetime (typically 600s)
- Verification URI may also be provided as a QR code for convenience

---

### 3.4 Refresh Token Flow

**Problem:** Access tokens are short-lived (5–15 min). Re-authenticating the user every 15 minutes is disruptive. How do we extend access silently?

**Note:** Refresh Token is not an independent grant type — it is a mechanism layered on top of other grants (Authorization Code, Device Flow) that issued the refresh token.

```mermaid
sequenceDiagram
    participant C as Client
    participant AS as Authorization Server
    participant RS as Resource Server

    Note over C,RS: Access token has expired (exp exceeded)
    C->>AS: POST /token {grant_type=refresh_token, refresh_token=REFRESH_TOKEN, client_id=CLIENT_ID, client_secret=CLIENT_SECRET}
    AS->>AS: Validate refresh token, check rotation policy
    AS->>C: {access_token (NEW), token_type, expires_in, refresh_token (NEW if rotation on)}
    Note over C,AS: Old refresh token is now invalid (single-use rotation)
    C->>RS: GET /resource Authorization: Bearer NEW_ACCESS_TOKEN
    RS->>C: Protected resource
```

**Rotation policy — single-use (recommended):**
- AS issues a new refresh token on every use; old one is immediately invalidated
- If the same refresh token is presented twice: AS treats it as theft — revoke the entire token family
- Rotation provides theft detection: a reuse attempt is a signal of compromise

**Rotation policy — sliding window (avoid if possible):**
- Same refresh token reused; expiry extended on each use
- No theft detection; harder to reason about session lifetime

**Key points:**
- Refresh tokens should be stored securely (httpOnly cookies or encrypted storage)
- Scope cannot be widened via refresh — token inherits the scope of the original grant
- Client Credentials grant does NOT issue refresh tokens

---

### 3.5 ROPC — Resource Owner Password Credentials (DEPRECATED)

> **Do not use ROPC in new systems.** Migrate to Authorization Code + PKCE.

**Why it was created:** Legacy systems where the client was trusted (e.g., first-party mobile app of the same company) and a redirect-based flow was impractical.

**Why it is deprecated (OAuth 2.1):** The client collects the user's credentials directly, fundamentally violating the OAuth2 principle of not exposing credentials to intermediaries. No way to support MFA. No consent screen.

```mermaid
sequenceDiagram
    participant RO as Resource Owner
    participant C as Client
    participant AS as Authorization Server

    RO->>C: Provides username + password directly to the client UI
    C->>AS: POST /token {grant_type=password, username=USER, password=PASS, client_id=CLIENT_ID, scope=...}
    AS->>C: {access_token, refresh_token, ...}
    Note over RO,AS: ⚠ Client saw credentials. No consent screen. No MFA support.
    Note over RO,AS: Migration: Authorization Code + PKCE with prompt=login
```

---

### 3.6 Implicit Flow (DEPRECATED)

> **Do not use Implicit in new systems.** Migrate to Authorization Code + PKCE.

**Why it was created:** Before PKCE existed, SPAs and mobile apps (public clients) could not safely use Authorization Code because they cannot store a client secret. Implicit skipped the code exchange and returned tokens directly in the URL fragment.

**Why it is deprecated (OAuth 2.1):** Token in the URL fragment leaks into browser history, server logs, and Referrer headers. Fragment is accessible to JavaScript on the page and to third-party scripts.

```mermaid
sequenceDiagram
    participant RO as Resource Owner
    participant C as Client (SPA/Browser)
    participant AS as Authorization Server

    C->>AS: GET /authorize?response_type=token&client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&scope=...
    AS->>RO: Login + consent
    RO->>AS: Authenticate + authorize
    AS->>C: Redirect → REDIRECT_URI#access_token=ACCESS_TOKEN&token_type=bearer&expires_in=3600
    Note over C,AS: ⚠ Token in URL fragment — leaks in browser history and referrer headers
    Note over C,AS: Migration: Authorization Code + PKCE (code_challenge_method=S256)
```

---

## 4. OIDC Extensions

**OpenID Connect Core 1.0, OpenID Connect Discovery 1.0**

OpenID Connect (OIDC) is an **identity layer** built on top of OAuth2. OAuth2 handles authorization (what the client can do); OIDC adds authentication (who the user is).

```mermaid
graph LR
    subgraph OAuth2Layer["OAuth2 — Authorization Layer (RFC 6749)"]
        AE["Authorization Endpoint\n/authorize"]
        TE["Token Endpoint\n/token"]
        AT["Access Token"]
    end
    subgraph OIDCLayer["OpenID Connect — Identity Layer"]
        IT["ID Token (JWT)"]
        UI["UserInfo Endpoint\n/userinfo"]
        DIS["Discovery\n/.well-known/openid-configuration"]
    end
    OAuth2Layer --> OIDCLayer
    OIDCLayer --> RP["Relying Party\n(Client)"]
```

### ID Token vs Access Token

| | ID Token | Access Token |
|---|---|---|
| **Purpose** | Asserts the identity of the authenticated user to the **client** | Grants the client access to a protected resource on the **RS** |
| **Audience** | The client (`client_id`) | The Resource Server (API) |
| **Who validates it** | The client | The Resource Server |
| **Send to RS?** | **Never** — the RS is not in its `aud` | Yes — in `Authorization: Bearer` header |
| **Contains** | `sub`, `iss`, `aud`, `exp`, `iat`, `nonce`, `auth_time`, `acr`, `amr` | `sub`, `iss`, `aud`, `exp`, `scope`, `client_id`, custom claims |

> **Common bug:** Sending the ID Token to the Resource Server as a Bearer token. The RS will reject it (wrong `aud`) or, worse, accept it without proper validation. Always send the Access Token to the RS.

### UserInfo Endpoint

The `/userinfo` endpoint returns additional claims about the authenticated user. The client calls it with the access token (not the ID token) that has the `openid` scope.

```
GET /userinfo
Authorization: Bearer ACCESS_TOKEN

Response:
{
  "sub": "user123",
  "name": "Jane Doe",
  "email": "jane@example.com",
  "email_verified": true,
  "picture": "https://example.com/photo.jpg"
}
```

### OIDC Scopes and Claim Sets

| Scope | Claims returned (UserInfo / ID Token) |
|---|---|
| `openid` | `sub` (required; triggers OIDC) |
| `profile` | `name`, `family_name`, `given_name`, `middle_name`, `nickname`, `preferred_username`, `profile`, `picture`, `website`, `gender`, `birthdate`, `zoneinfo`, `locale`, `updated_at` |
| `email` | `email`, `email_verified` |
| `address` | `address` (JSON object) |
| `phone` | `phone_number`, `phone_number_verified` |

### Login Flow Parameters

These parameters are sent on the authorization request to control authentication behavior:

| Parameter | Values | Effect |
|---|---|---|
| `prompt` | `none` | Silent auth — fail if interaction required (use for session checks) |
| `prompt` | `login` | Force re-authentication even if session exists |
| `prompt` | `consent` | Force consent screen even if previously consented |
| `prompt` | `select_account` | Show account selector (multi-account scenario) |
| `max_age` | Integer (seconds) | Maximum time since last active authentication; AS re-authenticates if exceeded |
| `login_hint` | Email or username | Hint to the AS about which user to authenticate; pre-fills login UI |
| `acr_values` | Space-separated ACR values | Requested authentication assurance level (e.g. `urn:mace:incommon:iap:silver`) |
| `nonce` | Random string | Included in ID token; client verifies it matches to prevent replay attacks |

### Claims Request Parameter

The `claims` parameter allows the client to request specific claims in the ID token or UserInfo response:

```json
{
  "userinfo": {
    "email": { "essential": true },
    "phone_number": null
  },
  "id_token": {
    "auth_time": { "essential": true },
    "acr": { "values": ["urn:mace:incommon:iap:silver"] }
  }
}
```

### Discovery Document

The AS publishes metadata at `/.well-known/openid-configuration`. Clients can auto-configure from this endpoint.

Key fields:

```json
{
  "issuer": "https://as.example.com",
  "authorization_endpoint": "https://as.example.com/authorize",
  "token_endpoint": "https://as.example.com/token",
  "userinfo_endpoint": "https://as.example.com/userinfo",
  "jwks_uri": "https://as.example.com/.well-known/jwks.json",
  "introspection_endpoint": "https://as.example.com/introspect",
  "revocation_endpoint": "https://as.example.com/revoke",
  "response_types_supported": ["code", "token", "id_token", "code token"],
  "grant_types_supported": ["authorization_code", "client_credentials", "refresh_token"],
  "scopes_supported": ["openid", "profile", "email"],
  "id_token_signing_alg_values_supported": ["RS256", "ES256"],
  "claims_supported": ["sub", "iss", "aud", "exp", "iat", "name", "email"]
}
```

### Session Management (Logout)

| Mechanism | How it works |
|---|---|
| **Front-channel logout** | RP renders a hidden `<iframe>` to the AS logout URL; requires browser |
| **Back-channel logout** | AS POSTs a signed logout token to the RP's back-channel logout URI; no browser required; preferred |

---

## 5. Token Lifecycle

**RFC 7662 (Introspection), RFC 7009 (Revocation)**

```mermaid
stateDiagram-v2
    [*] --> Issued : POST /token (grant succeeds)
    Issued --> Active : token_type=bearer, stored by client
    Active --> Expired : exp timestamp exceeded
    Active --> Revoked : POST /revoke called
    Expired --> [*]
    Revoked --> [*]

    state "Refresh Token" as RT {
        [*] --> RTValid
        RTValid --> RTUsed : POST /token grant_type=refresh_token
        RTUsed --> RTRotated : single-use rotation — new RT issued
        RTUsed --> RTCompromised : same RT used twice → revoke token family
        RTValid --> RTRevoked : POST /revoke
        RTRotated --> [*]
        RTRevoked --> [*]
        RTCompromised --> [*]
    }
```

### Token Endpoint Response

A successful token grant returns:

```json
{
  "access_token": "ACCESS_TOKEN",
  "token_type": "Bearer",
  "expires_in": 900,
  "refresh_token": "REFRESH_TOKEN",
  "scope": "read:orders",
  "id_token": "ID_TOKEN_JWT"
}
```

- `expires_in`: seconds until the access token expires (not a timestamp — add to `iat` to get absolute expiry)
- `id_token` present only in OIDC flows with `openid` scope
- `refresh_token` absent in Client Credentials and Implicit grants

### Local JWT Validation

The RS validates the access token without calling the AS. Steps:

1. Parse the JWT and extract `kid` from the header
2. Fetch the JWKS from the AS's JWKS URI (cache it; refresh on `kid` cache miss)
3. Verify the signature using the public key matching `kid`
4. Validate claims:
   - `iss`: must match expected issuer
   - `aud`: must contain this RS's identifier
   - `exp`: must be in the future (with a small clock skew tolerance, e.g. ±30s)
   - `nbf`: if present, must be in the past
5. Optionally: check `jti` against a local blocklist for revoked tokens

**Pros:** Zero network calls, low latency, scales horizontally  
**Cons:** Cannot detect revocation until `exp` — accepts tokens up to `expires_in` after revocation

### Introspection (RFC 7662)

The RS calls the AS's `/introspect` endpoint to validate a token in real time.

```
POST /introspect
Authorization: Basic RS_CLIENT_CREDENTIALS
Content-Type: application/x-www-form-urlencoded

token=ACCESS_TOKEN&token_type_hint=access_token

Response:
{
  "active": true,
  "sub": "user123",
  "scope": "read:orders",
  "client_id": "my-app",
  "exp": 1726500000,
  "iss": "https://as.example.com"
}
```

For inactive/expired/revoked tokens: `{"active": false}` — no other fields guaranteed.

**Pros:** Real-time revocation detection, works for opaque tokens  
**Cons:** Extra network call per request, RS depends on AS availability, latency

### When to Use Each

| Scenario | Strategy |
|---|---|
| High-throughput API, short token lifetime (≤15 min) | Local JWT validation |
| High-security, revocation must be immediate | Introspection |
| Opaque access tokens (no JWT to parse) | Introspection (only option) |
| Distributed RS with no connectivity to AS | Local JWT validation |

### Revocation (RFC 7009)

```
POST /revoke
Authorization: Basic CLIENT_CREDENTIALS
Content-Type: application/x-www-form-urlencoded

token=REFRESH_TOKEN&token_type_hint=refresh_token
```

- `token_type_hint`: `access_token` or `refresh_token` (advisory, not mandatory)
- Response: `200 OK` regardless of whether the token was valid (to prevent oracle attacks)
- Revoking a refresh token should cascade to revoke derived access tokens

### Token Expiry Best Practices

| Token | Recommended Lifetime | Rationale |
|---|---|---|
| Access Token | 5–15 minutes | Short enough to limit exposure; long enough to avoid constant refresh |
| Refresh Token (user) | 1–24 hours depending on sensitivity | Longer sessions for trusted clients; shorter for sensitive APIs |
| Refresh Token (service) | N/A — use Client Credentials re-auth | Services should not have long-lived sessions |
| Authorization Code | 10–60 seconds | Single-use, should be exchanged immediately |
| ID Token | Session lifetime | Not used for API calls; can be longer |

---

## 6. Advanced Protocols

These protocols extend the core OAuth2/OIDC model for specialized scenarios. Each is presented at awareness depth: what problem it solves, how it works, when to use it.

---

### 6.1 Token Exchange (RFC 8693)

**Problem:** Service A has a token for User X. It calls Service B on User X's behalf. How does Service B receive a token that correctly represents the delegation chain?

**Use cases:** Impersonation, delegation, cross-service propagation in microservice architectures, converting token types.

```mermaid
sequenceDiagram
    participant C as Client (Service A)
    participant AS as Authorization Server
    participant B as Service B

    Note over C: Has access_token for User X (subject_token)
    C->>AS: POST /token {grant_type=urn:ietf:params:oauth:grant-type:token-exchange, subject_token=SUBJECT_TOKEN, subject_token_type=urn:ietf:params:oauth:token-type:access_token, requested_token_type=urn:ietf:params:oauth:token-type:access_token, audience=service-b, scope=read:data}
    AS->>AS: Validate subject_token, check delegation policy
    AS->>C: {access_token=NEW_TOKEN, issued_token_type=access_token, token_type=Bearer}
    C->>B: GET /resource Authorization: Bearer NEW_TOKEN
    B->>B: Validate token (aud=service-b, delegation chain in claims)
    B->>C: Protected resource
```

**Key parameters:**
- `subject_token`: the token being exchanged
- `subject_token_type`: the type URI of `subject_token`
- `actor_token`: present in delegation flows — identifies the service acting on behalf of the subject
- `requested_token_type`: the type of token desired
- `audience`: the RS the new token is intended for

**When to use:** Microservice-to-microservice calls where the user's identity must propagate downstream; token format conversion (e.g. SAML → JWT).

---

### 6.2 CIBA — Client-Initiated Backchannel Authentication (OIDC CIBA Core 1.0)

**Problem:** The application cannot drive a browser redirect. The user may be on a different device or channel (phone call, in-person interaction, IoT).

**Example:** A call-centre agent initiates a payment on behalf of a customer. The customer receives a push notification on their phone to approve it.

Three delivery modes:
- **Poll:** client repeatedly polls the token endpoint
- **Ping:** AS sends a notification to a client-registered callback URL, then client polls once
- **Push:** AS POSTs the tokens directly to the client's callback URL

```mermaid
sequenceDiagram
    participant App as Client Application
    participant AS as Authorization Server
    participant AuthDevice as User's Auth Device (Phone)

    App->>AS: POST /bc-authorize {login_hint=USER_EMAIL, scope=openid, binding_message="Payment $50 to Merchant", client_id=CLIENT_ID}
    AS->>App: {auth_req_id=AUTH_REQ_ID, expires_in=120, interval=5}
    AS->>AuthDevice: Push notification: "Approve payment $50 to Merchant?"
    AuthDevice->>AS: User approves (out-of-band)
    loop Poll (poll mode) until authorized or expired
        App->>AS: POST /token {grant_type=urn:openid:params:grant-type:ciba, auth_req_id=AUTH_REQ_ID, client_id=CLIENT_ID}
        AS->>App: {error: authorization_pending} or tokens
    end
    AS->>App: {access_token, id_token, refresh_token}
```

**When to use:** Call-centre flows, delegated consent, IoT scenarios, any flow where the consumption device and authentication device are different.

---

### 6.3 PAR — Pushed Authorization Requests (RFC 9126)

**Problem:** In a standard authorization redirect, all parameters are in the URL. An attacker can tamper with them (change `redirect_uri`, `scope`, etc.) in the browser.

**How it works:** Client POSTs the full authorization request to the AS first; AS returns a `request_uri`. The browser redirect carries only `client_id` and `request_uri` — the sensitive parameters never appear in the URL.

```mermaid
sequenceDiagram
    participant C as Client
    participant AS as Authorization Server
    participant RO as Resource Owner (Browser)

    C->>AS: POST /par {client_id=CLIENT_ID, client_secret=CLIENT_SECRET, response_type=code, redirect_uri=REDIRECT_URI, scope=openid, state=STATE, code_challenge=CHALLENGE, code_challenge_method=S256}
    AS->>C: {request_uri=urn:ietf:params:oauth:request_uri:ABC123, expires_in=60}
    C->>RO: Redirect → /authorize?client_id=CLIENT_ID&request_uri=urn:ietf:params:oauth:request_uri:ABC123
    RO->>AS: Login + consent
    AS->>C: Redirect → REDIRECT_URI?code=AUTH_CODE&state=STATE
    C->>AS: POST /token {code=AUTH_CODE, ...}
    AS->>C: Tokens
```

**When to use:** High-security applications (banking, healthcare); combined with JAR for maximum integrity.

---

### 6.4 JAR — JWT-Secured Authorization Request (RFC 9101)

**Problem:** Even with PAR protecting parameters from URL tampering, the parameters themselves travel as plain form data in the POST. JAR bundles all authorization request parameters into a signed (and optionally encrypted) JWT.

**How it works:** Client signs the request parameters as a JWT (`request` parameter or `request_uri` after PAR). AS verifies the signature before processing.

**Benefit:** End-to-end integrity of the authorization request. Attacker cannot modify any parameter because the signature would break.

**When to use:** High-assurance flows where parameter integrity must be cryptographically verifiable (financial-grade APIs, FAPI compliance).

---

## 7. Federation, IDP, Trusted Issuers

**OIDC Core §1.2 (Relying Party), RFC 7591 (Dynamic Client Registration)**

### Core Concepts

**IDP (Identity Provider):** An Authorization Server specialized in authenticating users. May act as the primary identity source (manages users directly) or as a federation broker (delegates to upstream IDPs).

**Relying Party (RP):** The application that delegates authentication to an IDP. In OIDC terminology, the RP is the Client.

**Service Provider (SP):** Equivalent to RP in SAML terminology. Often used interchangeably.

**Federation:** A trust agreement between two identity domains. Users in Domain A can access resources in Domain B without a separate account in Domain B.

### Trust Chain Diagram

```mermaid
graph LR
    U["User"]
    RP["Relying Party\n(Application)"]
    LI["Local IDP / Federation Broker\ne.g. WSO2 IS"]
    UI1["Upstream IDP 1\nEnterprise AD / LDAP"]
    UI2["Upstream IDP 2\nGoogle / GitHub"]

    U -->|"1. login request"| RP
    RP -->|"2. OIDC auth request"| LI
    LI -->|"3a. SAML/OIDC auth request\n(if external user)"| UI1
    LI -->|"3b. OIDC auth request\n(social login)"| UI2
    UI1 -->|"4a. authenticated assertion"| LI
    UI2 -->|"4b. ID token"| LI
    LI -->|"5. maps claims → local schema\nissues local token"| RP
    RP -->|"6. local access token"| U
```

### Federated Identity Flow

1. RP sends the user to the local IDP (WSO2 IS)
2. Local IDP performs **Home Realm Discovery** — determines which upstream IDP to use (by email domain, UI selection, or policy)
3. Local IDP redirects to the upstream IDP (OIDC authorization request or SAML AuthnRequest)
4. User authenticates at the upstream IDP
5. Upstream IDP returns an authenticated assertion (ID token for OIDC; SAMLResponse for SAML)
6. Local IDP **maps claims** from the upstream schema to the local schema
7. Local IDP issues a local token (using its own key, local `iss`) to the RP
8. RP and RS only ever see the local IDP's tokens — the upstream IDP is invisible to them

### Home Realm Discovery

Determining which upstream IDP to route to:
- **Email domain:** `user@company.com` → enterprise AD; `user@gmail.com` → Google
- **IDP hint:** RP passes `idp=google` as a custom parameter
- **UI picker:** local IDP presents a "Sign in with…" selection screen

### Trusted Issuer

A **trusted issuer** is an AS whose tokens the RS accepts directly, without a local IDP re-issuing them. The RS is pre-configured with:
- The issuer's `iss` claim value
- The issuer's JWKS URI (to fetch the public key for signature verification)

The RS then validates incoming JWTs against these configurations. If `iss` matches a trusted issuer and the signature verifies, the token is accepted.

**Use case:** Multi-tenant platforms where different tenants have their own IDP; service mesh where microservices accept tokens from a shared internal AS.

**Risk:** Every trusted issuer can mint tokens accepted by the RS. Minimize the list; audit it regularly.

### Social Login

Social login is a specific federation pattern where the upstream IDP is a public provider (Google, GitHub, Microsoft, Apple). The local IDP acts as a federation broker:

1. User clicks "Sign in with Google"
2. Local IDP (WSO2 IS) initiates an OIDC authorization flow with Google as the upstream IDP
3. Google authenticates the user and returns an ID token to WSO2 IS
4. WSO2 IS maps Google's `sub` + `iss` to a local user account (or creates one on first login — **Just-In-Time provisioning**)
5. WSO2 IS issues a local token to the RP

**Stable user identifier in federation:** `iss` + `sub` together. `sub` alone is only unique within one issuer.

### Claim Mapping

Upstream IDPs use different claim schemas. The local IDP maps external claims to its internal schema:

| Upstream (Google) | Local Schema |
|---|---|
| `email` | `http://wso2.org/claims/emailaddress` |
| `name` | `http://wso2.org/claims/displayName` |
| `sub` | `http://wso2.org/claims/userid` (prefixed with Google IDP name) |

---

## 8. Endpoints Reference

All standard OAuth2/OIDC endpoints. Paths are conventional; the actual path is published in the AS's discovery document (`/.well-known/openid-configuration`).

| Endpoint | Method | Grant/Purpose | Key Request Parameters | Key Response Fields | RFC/Spec |
|---|---|---|---|---|---|
| `/authorize` | GET | Start Authorization Code, Implicit, Device flows | `response_type`, `client_id`, `redirect_uri`, `scope`, `state`, `code_challenge`, `code_challenge_method`, `nonce`, `prompt`, `max_age`, `login_hint`, `acr_values` | Redirect with `code` + `state` (auth code) or `#access_token` (implicit) | RFC 6749 §3.1 |
| `/token` | POST | Exchange code/credentials/device code/refresh token for tokens | `grant_type`, `code`, `redirect_uri`, `client_id`, `client_secret`, `code_verifier`, `refresh_token`, `device_code`, `username`, `password` | `access_token`, `token_type`, `expires_in`, `refresh_token`, `scope`, `id_token` | RFC 6749 §3.2 |
| `/introspect` | POST | Validate a token + retrieve its claims (real-time) | `token`, `token_type_hint` | `active` (bool), `sub`, `scope`, `exp`, `iss`, `client_id` | RFC 7662 |
| `/revoke` | POST | Invalidate an access or refresh token | `token`, `token_type_hint` | `200 OK` (always, to prevent oracle) | RFC 7009 |
| `/userinfo` | GET | Fetch user claims for an authenticated session | `Authorization: Bearer ACCESS_TOKEN` | JSON object with requested claims (`sub`, `name`, `email`, etc.) | OIDC Core §5.3 |
| `/.well-known/jwks.json` | GET | Fetch AS public keys for local JWT signature verification | — | `{"keys": [...JWK objects...]}` | RFC 7517 |
| `/.well-known/openid-configuration` | GET | AS metadata: endpoints, supported algorithms, scopes | — | JSON object with all AS metadata | OIDC Discovery §4 |
| `/device_authorization` | POST | Start device authorization flow | `client_id`, `scope` | `device_code`, `user_code`, `verification_uri`, `expires_in`, `interval` | RFC 8628 §3.1 |
| `/bc-authorize` | POST | Start CIBA backchannel authentication | `client_id`, `login_hint`, `scope`, `binding_message` | `auth_req_id`, `expires_in`, `interval` | OIDC CIBA Core §7 |
| `/par` | POST | Push authorization request parameters before redirect | Same as `/authorize` params + client auth | `request_uri`, `expires_in` | RFC 9126 §2 |

### Token Endpoint: `grant_type` Values

| `grant_type` Value | Flow |
|---|---|
| `authorization_code` | Authorization Code |
| `client_credentials` | Client Credentials |
| `refresh_token` | Refresh Token |
| `urn:ietf:params:oauth:grant-type:device_code` | Device Authorization |
| `urn:ietf:params:oauth:grant-type:token-exchange` | Token Exchange (RFC 8693) |
| `urn:openid:params:grant-type:ciba` | CIBA |
| `password` | ROPC (deprecated) |

---

## 9. SCIM2

**RFC 7642 (Concepts), RFC 7643 (Core Schema), RFC 7644 (Protocol)**

### What Is SCIM2?

SCIM2 (System for Cross-domain Identity Management, version 2) is a REST API standard for **provisioning and managing identity objects** — creating, updating, and deleting Users and Groups across systems.

**SCIM2 is not OAuth2/OIDC.** They solve different problems:

| | OAuth2/OIDC | SCIM2 |
|---|---|---|
| **What it handles** | Authentication and authorization for API access | Lifecycle management of identity objects |
| **Who calls it** | Applications requesting access | Provisioning systems (HR, directory sync) |
| **Key verbs** | GET token, use token | Create/Read/Update/Delete users and groups |
| **When used** | Every API call | When users are hired, transferred, or offboarded |

They work together: the SCIM2 API is itself an OAuth2-protected resource — the provisioner must present an access token (obtained via Client Credentials) to call SCIM2 endpoints.

```mermaid
graph LR
    HR["HR System\n(SCIM2 Client)"]
    AS["Authorization Server\n(WSO2 IS — also the SCIM2 Server)"]
    SCIM["SCIM2 API\n(hosted on WSO2 IS)"]

    HR -->|"1. POST /token {grant_type=client_credentials}"| AS
    AS -->|"2. access_token"| HR
    HR -->|"3. POST /Users Authorization: Bearer TOKEN"| SCIM
    SCIM -->|"4. 201 Created {id, userName, ...}"| HR
```

### Core Resource Types

| Resource | SCIM2 Endpoint | Description |
|---|---|---|
| **User** | `/scim2/v2/Users` | Individual identity — maps to a user account in the IDP |
| **Group** | `/scim2/v2/Groups` | Collection of users — maps to a role or team |
| **EnterpriseUser** | Extension of User | Adds `employeeNumber`, `organization`, `manager`, `department` |

### Key Endpoints

```
# Create user
POST /scim2/v2/Users
{
  "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
  "userName": "jane.doe@example.com",
  "password": "TEMP_PASSWORD",
  "name": { "familyName": "Doe", "givenName": "Jane" },
  "emails": [{ "value": "jane@example.com", "primary": true }],
  "active": true
}

# Get user by ID
GET /scim2/v2/Users/USER_ID

# Update user (replace)
PUT /scim2/v2/Users/USER_ID

# Partial update (patch)
PATCH /scim2/v2/Users/USER_ID
{"Operations": [{"op": "replace", "path": "active", "value": false}]}

# Delete user
DELETE /scim2/v2/Users/USER_ID

# Filter users
GET /scim2/v2/Users?filter=userName eq "jane.doe@example.com"

# List group members
GET /scim2/v2/Groups/GROUP_ID
```

### SCIM2 Filter Syntax

```
userName eq "jane"               # exact match
emails.value co "@example.com"  # contains
active eq true                  # boolean
meta.lastModified gt "2024-01-01T00:00:00Z"  # date comparison
```

### When You'll Encounter SCIM2 as a WSO2 Engineer

- **"User not found" errors at runtime:** the provisioning pipeline may have failed to create the user via SCIM2 before they tried to log in
- **Group/role membership issues:** the SCIM2 client may have assigned the user to the wrong group, or the group → role mapping is misconfigured in WSO2 IS
- **Deprovisioning delays:** a terminated employee still has an active session because SCIM2 DELETE hasn't propagated yet (check SCIM2 audit logs in IS)

---

## 10. Top-1% Mistakes

These six mistakes waste the most time for engineers learning OAuth2/OIDC. Each one causes real production bugs or security vulnerabilities.

---

### Mistake 1: Using the ID Token as an Access Token

**What happens:** The client receives both an ID token and an access token. It sends the ID token to the Resource Server in the `Authorization: Bearer` header.

**Why it's wrong:** The ID token's `aud` claim is set to the client's `client_id`. The Resource Server's identifier is NOT in `aud`. A correct RS will reject it. A careless RS might accept it — accepting a token it was never meant to verify, potentially bypassing scope enforcement.

**Fix:** Always send the access token to the RS. The ID token is for the client only — parse it to get user claims, then discard it.

---

### Mistake 2: Skipping PKCE for Confidential Clients

**What happens:** Developer reads "PKCE is for public clients" and skips it for their server-side app.

**Why it's wrong:** PKCE defends against authorization code interception attacks at the redirect URI. Even confidential clients are exposed to this if an attacker can intercept the redirect (via open redirectors, referrer leakage, or misconfigured proxies).

**Fix:** Use PKCE (`code_challenge_method=S256`) for all clients, always.

---

### Mistake 3: Long-Lived Access Tokens with No Revocation Strategy

**What happens:** Access tokens are set to 24-hour expiry. Local JWT validation is used. An employee is terminated; their token keeps working for hours.

**Why it's wrong:** Local JWT validation cannot see revocation. The token is valid until `exp` regardless of what the AS knows.

**Fix:** Short expiry (5–15 min) + refresh token rotation, OR introspection for flows that require immediate revocation. Choose based on your latency/security trade-off.

---

### Mistake 4: Conflating Authentication and Authorization

**What happens:** Team refers to "OAuth2 login" and uses the access token as proof of identity. Or: they use the ID token for API authorization.

**Why it's wrong:**
- OAuth2 is **authorization** — it says what the client is allowed to do, not who the user is
- OIDC is **authentication** — the ID token says who authenticated, for the client's benefit
- Mixing them causes: sending ID tokens to RSs, accepting access tokens as identity proofs, building authorization logic on the wrong claims

**Fix:** Keep the mental model clean. OIDC (`id_token`) = "who is this user" for the **client**. OAuth2 (`access_token`) = "what can this client do" for the **RS**.

---

### Mistake 5: Not Rotating Refresh Tokens

**What happens:** The same refresh token is accepted indefinitely. A stolen refresh token provides permanent access.

**Why it's wrong:** A static refresh token is as dangerous as a permanent password stored in the client. There is no signal when it's stolen.

**Fix:** Enable single-use rotation. Each use issues a new refresh token and invalidates the old one. A reuse attempt (stolen token re-presented) triggers family revocation — the AS revokes all tokens derived from the compromised refresh token.

---

### Mistake 6: Using `sub` Alone as a Stable User Identifier

**What happens:** Application stores `sub` from the token as the primary user key. Works fine with one IDP. Later: federation is added, or the IDP is migrated. Different issuer, different `sub` for the same human. User accounts duplicate.

**Why it's wrong:** `sub` is only unique within one `iss`. Across federated issuers, two different users from different IDPs can have the same `sub` value.

**Fix:** Use `iss` + `sub` together as the stable compound user identifier in any system that may involve federation. Index on both fields.
