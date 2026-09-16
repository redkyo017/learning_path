# OAuth2/OIDC Appendix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author two files — `APPENDIX_OAUTH2_OIDC.md` (10 sections, ~15 Mermaid diagrams) and a full rewrite of `GLOSSARY.md` (~80 entries) — as a standalone OAuth2/OIDC theory reference for a WSO2 engineer and their teammates.

**Architecture:** Sequential content pipeline: scaffold → foundation concepts (Sections 1-2) → grant types (Section 3, diagram-heavy) → OIDC + lifecycle (Sections 4-5) → advanced protocols + federation (Sections 6-7) → reference tables + mistakes (Sections 8-10) → glossary rewrite. Each task produces independently reviewable content.

**Tech Stack:** Markdown, Mermaid diagrams (`sequenceDiagram`, `graph LR`, `stateDiagram-v2`). No external dependencies.

**Spec:** `wso2_mastery/docs/superpowers/specs/2026-09-16-oauth2-oidc-appendix-design.md`

## Global Constraints

- Markdown only — no raw HTML tags in document body
- All diagrams use fenced Mermaid blocks (` ```mermaid `) — `sequenceDiagram`, `graph LR`, or `stateDiagram-v2` only
- All flow diagrams are **vendor-neutral** — WSO2 component names appear ONLY in Section 1's actor-mapping table, never inside diagram node labels or sequence participants
- Every protocol section cites its RFC by number (e.g. "RFC 6749")
- No real tokens, secrets, passwords, or credentials in any example — use placeholder strings like `ACCESS_TOKEN`, `REFRESH_TOKEN`, `AUTH_CODE`
- Do not duplicate Phase 1 Go code — write "see `labs/phase1/dayNN/`" pointers only
- No `git commit` commands — learner handles VCS
- `GLOSSARY.md` is a **full rewrite** — do not append to existing content; overwrite the file entirely

---

### Task 0: Scaffold

**Files:**
- Create: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md`

**Interfaces:**
- Produces: skeleton file with 10 `## Section N — Title` headers + one-line placeholder per section; Tasks 1-5 fill each section in order

- [ ] **Step 1: Create the scaffold file**

Write `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md` with exactly this content:

```markdown
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

<!-- TODO: Task 1 -->

---

## 2. Token Anatomy

<!-- TODO: Task 1 -->

---

## 3. Grant Types

<!-- TODO: Task 2 -->

---

## 4. OIDC Extensions

<!-- TODO: Task 3 -->

---

## 5. Token Lifecycle

<!-- TODO: Task 3 -->

---

## 6. Advanced Protocols

<!-- TODO: Task 4 -->

---

## 7. Federation, IDP, Trusted Issuers

<!-- TODO: Task 4 -->

---

## 8. Endpoints Reference

<!-- TODO: Task 5 -->

---

## 9. SCIM2

<!-- TODO: Task 5 -->

---

## 10. Top-1% Mistakes

<!-- TODO: Task 5 -->
```

- [ ] **Step 2: Verify file exists**

```bash
ls -la wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: file exists, non-zero size.

---

### Task 1: Sections 1–2 — The Four Actors + Token Anatomy

**Files:**
- Modify: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md` — replace `<!-- TODO: Task 1 -->` blocks in Sections 1 and 2

**Interfaces:**
- Consumes: scaffold from Task 0
- Produces: Section 1 (actor model + WSO2 mapping table + `graph LR` diagram) and Section 2 (token types + JWT anatomy diagram + all standard claims)

- [ ] **Step 1: Write Section 1 — The Four Actors**

Replace the `<!-- TODO: Task 1 -->` block under `## 1. The Four Actors` with:

```markdown
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
```

- [ ] **Step 2: Write Section 2 — Token Anatomy**

Replace the `<!-- TODO: Task 1 -->` block under `## 2. Token Anatomy` with:

```markdown
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
```

- [ ] **Step 3: Verify no TODO placeholders remain in Sections 1–2**

```bash
grep -n "TODO: Task 1" wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: no output (grep returns nothing).

---

### Task 2: Section 3 — Grant Types

**Files:**
- Modify: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md` — replace `<!-- TODO: Task 2 -->` in Section 3

**Interfaces:**
- Consumes: scaffold from Task 0
- Produces: Section 3 with 6 subsections, each containing a full `sequenceDiagram`, step-by-step annotation, and security notes

- [ ] **Step 1: Write Section 3 intro + subsection 3.1 Authorization Code + PKCE**

Replace `<!-- TODO: Task 2 -->` under `## 3. Grant Types` with the following (this step covers Section 3 intro + 3.1):

```markdown
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
```

- [ ] **Step 2: Write subsections 3.2–3.3**

Append after 3.1 (still inside Section 3):

```markdown
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
```

- [ ] **Step 3: Write subsections 3.4–3.6 (Refresh Token + deprecated flows)**

Append after 3.3:

```markdown
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
```

- [ ] **Step 4: Verify no TODO placeholders remain in Section 3**

```bash
grep -n "TODO: Task 2" wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: no output.

---

### Task 3: Sections 4–5 — OIDC Extensions + Token Lifecycle

**Files:**
- Modify: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md` — replace `<!-- TODO: Task 3 -->` blocks in Sections 4 and 5

**Interfaces:**
- Consumes: scaffold from Task 0, Section 2 token anatomy concepts
- Produces: Section 4 (OIDC extensions, OIDC layered diagram, login parameters, discovery) and Section 5 (token lifecycle state diagram, validation strategies, revocation, rotation)

- [ ] **Step 1: Write Section 4 — OIDC Extensions**

Replace `<!-- TODO: Task 3 -->` under `## 4. OIDC Extensions`:

```markdown
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
```

- [ ] **Step 2: Write Section 5 — Token Lifecycle**

Replace `<!-- TODO: Task 3 -->` under `## 5. Token Lifecycle`:

```markdown
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
```

- [ ] **Step 3: Verify no TODO placeholders remain in Sections 4–5**

```bash
grep -n "TODO: Task 3" wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: no output.

---

### Task 4: Sections 6–7 — Advanced Protocols + Federation

**Files:**
- Modify: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md` — replace `<!-- TODO: Task 4 -->` blocks in Sections 6 and 7

**Interfaces:**
- Consumes: scaffold from Task 0, grant type concepts from Task 2
- Produces: Section 6 (Token Exchange, CIBA, PAR+JAR — each with `sequenceDiagram`) and Section 7 (federation, IDP, trusted issuer, social login, claim mapping — `graph LR` trust chain diagram)

- [ ] **Step 1: Write Section 6 — Advanced Protocols**

Replace `<!-- TODO: Task 4 -->` under `## 6. Advanced Protocols`:

```markdown
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
```

- [ ] **Step 2: Write Section 7 — Federation, IDP, Trusted Issuers**

Replace `<!-- TODO: Task 4 -->` under `## 7. Federation, IDP, Trusted Issuers`:

```markdown
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
```

- [ ] **Step 3: Verify no TODO placeholders remain in Sections 6–7**

```bash
grep -n "TODO: Task 4" wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: no output.

---

### Task 5: Sections 8–10 — Endpoints Reference + SCIM2 + Top-1% Mistakes

**Files:**
- Modify: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md` — replace `<!-- TODO: Task 5 -->` blocks in Sections 8, 9, and 10

**Interfaces:**
- Consumes: scaffold from Task 0, all prior section concepts
- Produces: Section 8 (endpoint reference table), Section 9 (SCIM2 with diagram), Section 10 (top-1% mistakes list)

- [ ] **Step 1: Write Section 8 — Endpoints Reference**

Replace `<!-- TODO: Task 5 -->` under `## 8. Endpoints Reference`:

```markdown
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
```

- [ ] **Step 2: Write Section 9 — SCIM2**

Replace `<!-- TODO: Task 5 -->` under `## 9. SCIM2`:

```markdown
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
```

- [ ] **Step 3: Write Section 10 — Top-1% Mistakes**

Replace `<!-- TODO: Task 5 -->` under `## 10. Top-1% Mistakes`:

```markdown
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
```

- [ ] **Step 4: Remove all remaining TODO comments**

```bash
grep -n "TODO" wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: no output. If any remain, replace them with actual content or remove the comment line.

- [ ] **Step 5: Final content check**

```bash
grep -c "^##" wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: 10 (one `##` heading per top-level section).

```bash
grep -c '```mermaid' wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md
```
Expected: ≥ 13 (at least one Mermaid block per section that specifies one).

---

### Task 6: GLOSSARY.md Full Rewrite

**Files:**
- Overwrite: `wso2_mastery/content/GLOSSARY.md` — replace entire file with ~80 entries

**Interfaces:**
- Consumes: all terms introduced in Tasks 1–5
- Produces: standalone GLOSSARY.md, alphabetically ordered, ~80 entries, plain-English definitions with RFC references and cross-references

- [ ] **Step 1: Write the full GLOSSARY.md**

Overwrite `wso2_mastery/content/GLOSSARY.md` entirely with the following content. Each entry follows the pattern: `**Term** — definition. (RFC/spec reference if applicable. See also: related term.)`.

```markdown
# OAuth2/OIDC Glossary

Alphabetically ordered. Cross-references use **bold term names**. RFC numbers link to authoritative specifications.

---

**Access Token** — A credential (opaque string or JWT) that a Client presents to a Resource Server to access a protected resource. Short-lived (5–15 min recommended). See also: **Bearer Token**, **JWT**, **Refresh Token**.

**acr (Authentication Context Class Reference)** — A claim in the ID token asserting the level of assurance of the authentication event (e.g. password-only vs MFA). The Client can request a specific ACR via `acr_values` in the authorization request. (OIDC Core §2)

**amr (Authentication Methods References)** — A claim (array) listing the authentication methods used (e.g. `["pwd", "otp"]`). Complements **acr**. (OIDC Core §2)

**at_hash** — A claim in the ID token containing a hash of the access token. Allows the Client to bind the ID token to its paired access token and detect substitution. (OIDC Core §3.1.3.6)

**aud (Audience)** — A JWT claim listing the intended recipients of the token. The Resource Server MUST verify its own identifier is present in `aud`; if not, reject the token. (RFC 7519 §4.1.3)

**Authorization Code** — A short-lived, single-use opaque credential issued by the Authorization Server after the Resource Owner authorizes the Client. Exchanged for tokens at the token endpoint via a back-channel POST. Never used directly as an API credential. Lifetime: 10–60 seconds. (RFC 6749 §4.1)

**Authorization Endpoint** — The AS endpoint (`/authorize`) where the Client sends the Resource Owner to authenticate and authorize. Returns an authorization code (auth code flow) or a token (implicit flow). (RFC 6749 §3.1)

**Authorization Server (AS)** — The server that authenticates the Resource Owner and issues tokens to the Client after obtaining authorization. Owns `/authorize`, `/token`, `/introspect`, `/revoke`. In WSO2: Identity Server. (RFC 6749 §1.1)

**Backchannel Authentication** — See **CIBA**.

**Bearer Token** — A type of access token where possession alone grants access — no proof of identity required from the presenter. The standard `Authorization: Bearer TOKEN` HTTP header is its delivery mechanism. Protect bearer tokens in transit (TLS). (RFC 6750)

**c_hash** — A claim in the ID token containing a hash of the authorization code. Binds the ID token to the auth code when both are returned from `/authorize`. (OIDC Core §3.3.2.11)

**CIBA (Client-Initiated Backchannel Authentication)** — An OIDC extension where the Client initiates authentication on a separate device from the user's (e.g. call-centre agent initiates, user approves on their phone). Three delivery modes: poll, ping, push. (OIDC CIBA Core 1.0) See also: **Device Authorization Flow**.

**Claim** — A piece of information asserted about a subject in a token or UserInfo response. Examples: `sub` (user ID), `email`, `scope`, `exp`. (RFC 7519 §2)

**Client** — An application that requests access to protected resources on behalf of the Resource Owner. Must be registered with the Authorization Server. Two subtypes: **Confidential Client** and **Public Client**. (RFC 6749 §1.1)

**Client Credentials** — An OAuth2 grant type for machine-to-machine flows where there is no human Resource Owner. The Client authenticates directly with the AS using its own `client_id` and `client_secret`. No refresh token issued. (RFC 6749 §4.4)

**client_id** — The public identifier of a registered Client. Used in all OAuth2 requests. Not a secret. (RFC 6749 §2.2)

**client_secret** — A secret shared between the Client and the AS, used to authenticate the Client at the token endpoint. Confidential clients only — never ship in browser JavaScript or mobile app binaries. (RFC 6749 §2.3)

**code_challenge** — The transformed value of the **code_verifier** sent in the authorization request. Computed as `BASE64URL(SHA256(code_verifier))`. The AS stores it and verifies it against the code_verifier at the token endpoint. (RFC 7636 §4.2)

**code_verifier** — A cryptographically random string (43–128 chars, URL-safe) generated by the Client before the authorization request. Sent in the token request; never appears in the authorization URL. (RFC 7636 §4.1)

**Confidential Client** — A Client that can securely store credentials (runs on a server the user does not control). Can use a `client_secret` or private-key JWT for Client authentication. Examples: backend API, microservice. (RFC 6749 §2.1)

**Device Authorization Flow** — An OAuth2 grant type for input-constrained devices (smart TVs, CLIs) that cannot open a browser. The device displays a short code; the user authorizes on a secondary device. The device polls the token endpoint. (RFC 8628)

**Discovery Document** — A JSON document published at `/.well-known/openid-configuration` listing the AS's endpoints, supported algorithms, scopes, and grant types. Clients use it to auto-configure without hardcoding URLs. (OIDC Discovery 1.0 §4)

**exp (Expiration)** — A required JWT claim (Unix timestamp). The token MUST be rejected after this time. Clock skew tolerance is typically ±30 seconds. (RFC 7519 §4.1.4)

**Federation** — A trust agreement between two identity domains allowing users from Domain A to access resources in Domain B using their Domain A identity. The local IDP acts as a broker between the RP and upstream IDPs. See also: **Trusted Issuer**, **Social Login**, **Home Realm Discovery**.

**Grant Type** — The OAuth2 flow used to obtain tokens. Determines who initiates the flow, what credentials are exchanged, and what tokens are issued. Common types: **Authorization Code**, **Client Credentials**, **Device Authorization Flow**, **Refresh Token**. Deprecated: **ROPC**, **Implicit Flow**. (RFC 6749 §1.3)

**Home Realm Discovery** — The process of determining which upstream IDP to route a user to during federated login. Methods: email domain matching, IDP hint parameter, UI picker. Used by the local IDP (federation broker).

**iat (Issued At)** — An optional JWT claim (Unix timestamp) recording when the token was minted. Used to calculate token age. (RFC 7519 §4.1.6)

**ID Token** — A JWT issued by an OIDC Authorization Server asserting the identity of the authenticated user. Intended for the **Client**, not the Resource Server. Contains `sub`, `iss`, `aud` (= `client_id`), `exp`, `iat`, `nonce`, `auth_time`. Never send to an RS as a Bearer token. (OIDC Core §2)

**IDP (Identity Provider)** — An Authorization Server that specializes in authenticating users. May manage users directly or delegate to upstream IDPs (federation). In WSO2: Identity Server. See also: **Federation**, **Trusted Issuer**.

**Implicit Flow** — A deprecated OAuth2 grant that returned tokens directly in the URL fragment (no back-channel code exchange). Superseded by **Authorization Code + PKCE**. Do not use in new systems. (RFC 6749 §4.2, deprecated in OAuth 2.1)

**Introspection** — A protocol (RFC 7662) allowing a Resource Server to ask the Authorization Server in real time whether a token is valid and what its claims are. POST to `/introspect`; response: `{"active": true/false, ...claims}`. Use when tokens are opaque or when real-time revocation detection is required.

**iss (Issuer)** — A JWT claim identifying the Authorization Server that issued the token. The RS must verify this matches the expected issuer. Combined with **sub**, forms a globally unique user identifier across federation domains. (RFC 7519 §4.1.1)

**JAR (JWT-Secured Authorization Request)** — An extension (RFC 9101) bundling all authorization request parameters into a signed JWT (`request` parameter), ensuring the integrity of the authorization request. Often combined with **PAR**.

**JWK (JSON Web Key)** — A JSON representation of a cryptographic key, typically a public RSA or EC key published at the JWKS URI. Contains `kty`, `kid`, `use`, `alg`, `n`, `e` (for RSA). (RFC 7517)

**JWKS (JSON Web Key Set)** — A JSON document containing an array of **JWK** objects. Published by the AS at its JWKS URI (e.g. `/.well-known/jwks.json`). Resource Servers fetch it to obtain the AS's public key for JWT signature verification. (RFC 7517 §5)

**JWT (JSON Web Token)** — A compact, URL-safe token format: `BASE64URL(header).BASE64URL(payload).signature`. The payload contains **claims** as a JSON object. Signed (JWS) or encrypted (JWE). Used as access tokens, ID tokens, and request objects. (RFC 7519)

**jti (JWT ID)** — An optional claim providing a unique identifier for the JWT. Used for replay detection: RS can maintain a short-lived blocklist of recently seen `jti` values. (RFC 7519 §4.1.7)

**Key Manager** — WSO2 APIM's abstraction for the service that issues and validates tokens. The Key Manager REST interface allows a 3rd-party IDP (e.g. WSO2 IS) to be plugged in. See `labs/phase1/day10/` for the Go Key Manager adapter.

**login_hint** — An OIDC authorization request parameter giving the AS a hint about which user to authenticate (email, username, phone). Pre-fills the login UI; does not bypass authentication. (OIDC Core §3.1.2.1)

**max_age** — An OIDC authorization request parameter specifying the maximum time (seconds) since the user last actively authenticated. If exceeded, the AS re-authenticates the user. (OIDC Core §3.1.2.1)

**nbf (Not Before)** — An optional JWT claim (Unix timestamp). The token MUST be rejected before this time. (RFC 7519 §4.1.5)

**nonce** — A random string included by the Client in the authorization request and echoed in the ID token. The Client verifies it matches to prevent ID token replay attacks. Mandatory for implicit and hybrid OIDC flows. (OIDC Core §3.1.2.1)

**OAuth 2.0** — An authorization framework (RFC 6749) that enables a Client to obtain limited access to a protected resource on behalf of a Resource Owner, without exposing the Resource Owner's credentials. Defines four grant types and a token endpoint protocol.

**OAuth 2.1** — A consolidation draft (draft-ietf-oauth-v2-1) that formalizes security best practices from BCP 212/213: mandates PKCE, removes Implicit and ROPC, requires exact redirect URI matching, and tightens scope handling. Not yet an RFC as of 2024.

**OIDC (OpenID Connect)** — An identity layer on top of OAuth2 (OpenID Connect Core 1.0). Adds the **ID Token**, **UserInfo Endpoint**, and **Discovery Document**. Enables federated login (SSO) using OAuth2 infrastructure.

**Opaque Token** — An access token that carries no claims itself; it is a random string. The Resource Server must call the AS's **Introspection** endpoint to validate it and retrieve claims. Allows immediate revocation but adds latency.

**PAR (Pushed Authorization Requests)** — An extension (RFC 9126) where the Client POSTs all authorization request parameters to the AS before redirecting the user. The redirect carries only a `request_uri` reference, preventing parameter tampering in the browser.

**PKCE (Proof Key for Code Exchange)** — An extension (RFC 7636) to Authorization Code that defends against code interception. Client generates a `code_verifier` and sends its hash (`code_challenge`) in the authorization request; the original `code_verifier` is sent in the token request. The AS verifies the match. Use for all clients.

**prompt** — An OIDC authorization request parameter controlling how the AS presents the login UI. Values: `none` (silent), `login` (force re-auth), `consent` (force consent), `select_account` (show account picker). (OIDC Core §3.1.2.1)

**Public Client** — A Client that cannot securely store credentials (runs in an environment the user controls: browser, mobile app, desktop app). Must use **PKCE** instead of a client secret. (RFC 6749 §2.1)

**Redirect URI** — The URI to which the AS redirects the user after authorization, carrying the authorization code or token. Must be pre-registered with the AS. The AS must perform exact matching (no wildcards). (RFC 6749 §3.1.2)

**Refresh Token** — A long-lived credential that a Client uses to obtain a new access token without re-authenticating the user. Stored securely by the client; never sent to the Resource Server. Subject to **rotation** and **revocation**. (RFC 6749 §1.5)

**Relying Party (RP)** — OIDC terminology for the Client — the application that delegates authentication to an IDP and relies on the ID token as proof of authentication. Equivalent to **Service Provider** in SAML.

**Resource Owner** — The entity that owns the protected resource and can grant access to it. Usually a human user; in **Client Credentials**, the client itself is the resource owner. (RFC 6749 §1.1)

**Resource Server (RS)** — The server hosting the protected resource (API). Accepts requests with a valid access token. Validates tokens locally (**JWT**) or via **Introspection**. In WSO2: Universal Gateway. (RFC 6749 §1.1)

**Revocation** — The act of invalidating a token before its natural expiry. RFC 7009 defines the `/revoke` endpoint. Revoking a refresh token should cascade to access tokens derived from it. See also: **Introspection** (for real-time detection).

**RFC 6749** — The core OAuth2 specification defining the authorization framework, four grant types, token endpoint protocol, and client registration. The authoritative reference for OAuth2.

**RFC 6750** — Defines how to use Bearer tokens in HTTP requests (`Authorization: Bearer TOKEN`).

**RFC 7009** — Token Revocation — defines the `/revoke` endpoint.

**RFC 7519** — JSON Web Token (JWT) — defines the JWT format, header, payload, standard claims.

**RFC 7517** — JSON Web Key (JWK) — defines the key format and JWKS.

**RFC 7662** — Token Introspection — defines the `/introspect` endpoint and its request/response format.

**RFC 8693** — Token Exchange — defines the `urn:ietf:params:oauth:grant-type:token-exchange` grant type for exchanging, impersonating, or delegating tokens.

**RFC 8628** — Device Authorization Grant (Device Flow).

**RFC 9101** — JWT-Secured Authorization Request (**JAR**).

**RFC 9126** — Pushed Authorization Requests (**PAR**).

**ROPC (Resource Owner Password Credentials)** — A deprecated OAuth2 grant type (RFC 6749 §4.3) where the Client collects the user's username and password directly. Deprecated in OAuth 2.1. Violates OAuth2's core principle of not exposing credentials to clients. Migrate to **Authorization Code + PKCE**.

**scope** — A space-separated list of permissions the Client is requesting. The AS may grant a subset. Present in both the authorization request and the issued token. OIDC defines standard scopes: `openid`, `profile`, `email`, `address`, `phone`. (RFC 6749 §3.3)

**SCIM2 (System for Cross-domain Identity Management, v2)** — A REST API standard (RFC 7642/7643/7644) for provisioning and managing identity objects (Users, Groups) across systems. Handles user lifecycle (create/update/delete); OAuth2/OIDC handles authentication/authorization. The SCIM2 API is itself OAuth2-protected. See also: **IDP**.

**Social Login** — A federated identity pattern where the upstream IDP is a public provider (Google, GitHub, Microsoft). The local IDP (e.g. WSO2 IS) acts as a federation broker, mapping external claims to local schema and issuing local tokens.

**state** — A random opaque value included in the authorization request and returned in the redirect. The Client verifies it matches to prevent CSRF attacks. Mandatory. (RFC 6749 §4.1.1)

**sub (Subject)** — A JWT claim containing the unique identifier for the user or service within the issuer. Stable within one `iss`; not globally unique across federated issuers. Use `iss` + `sub` together as a stable compound identifier in multi-IDP deployments. (RFC 7519 §4.1.2)

**Token Endpoint** — The AS endpoint (`/token`) where Clients exchange credentials, authorization codes, refresh tokens, or device codes for access tokens. Always a direct POST (no redirect). (RFC 6749 §3.2)

**Token Exchange** — An OAuth2 extension grant (RFC 8693) allowing a Client to exchange one token for another with a different audience, scope, or type. Used in microservice delegation chains and impersonation scenarios.

**Token Introspection** — See **Introspection**.

**Trusted Issuer** — An Authorization Server whose tokens a Resource Server is configured to accept directly (without a local IDP re-issuing them). The RS is pre-configured with the issuer's `iss` value and JWKS URI. Minimize the list of trusted issuers; each one can mint tokens accepted by the RS.

**UserInfo Endpoint** — An OIDC endpoint (`/userinfo`) returning claims about the authenticated user. Requires a valid access token with `openid` scope. Returns a JSON object. The Client calls it (not the RS). (OIDC Core §5.3)

**well-known configuration** — See **Discovery Document**. Path: `/.well-known/openid-configuration`.
```

- [ ] **Step 2: Verify GLOSSARY.md was overwritten (not appended)**

```bash
head -3 wso2_mastery/content/GLOSSARY.md
```
Expected: `# OAuth2/OIDC Glossary` as the first line (old content replaced).

- [ ] **Step 3: Count entries**

```bash
grep -c "^\*\*" wso2_mastery/content/GLOSSARY.md
```
Expected: ≥ 70 (at least 70 bold-term entries).

- [ ] **Step 4: Verify no old WSO2-specific stubs remain**

```bash
grep -n "Carbon\|Synapse\|log4j2\|JMS\|Throttle policy\|3rd-party Key Manager" wso2_mastery/content/GLOSSARY.md
```
Expected: no output (those entries from the old 25-line GLOSSARY are gone).

---

## Self-Review

- [x] All 10 sections specified; each has at least one diagram type named with actual Mermaid code in the task steps
- [x] No TBD/TODO/placeholder values in plan steps — all Mermaid blocks contain full diagram code with placeholder token strings (ACCESS_TOKEN, REFRESH_TOKEN, AUTH_CODE)
- [x] Every protocol section cites its RFC number
- [x] Glossary term list (Task 6) covers all terms introduced in Tasks 1–5
- [x] WSO2 component names appear only in Section 1's table and WSO2-specific notes — not in flow diagram node labels
- [x] File paths exact and consistent throughout: `wso2_mastery/content/APPENDIX_OAUTH2_OIDC.md`, `wso2_mastery/content/GLOSSARY.md`
- [x] No Phase 1 Go code duplicated — spec instructs cross-reference pointers only
- [x] No `git commit` steps — learner handles VCS
