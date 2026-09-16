# OAuth2/OIDC Appendix — Design Spec

**Date:** 2026-09-16
**Location:** `wso2_mastery/content/`
**Parent path:** `wso2_mastery/docs/superpowers/specs/2026-08-31-wso2-mastery-design.md`

---

## Purpose & Goals

A standalone pure-theory reference document covering all OAuth2/OIDC concepts, flows,
and protocols — written for a practitioner who wants to master the theory fast and
explain it clearly to teammates. Vendor-neutral (no WSO2-specific APIs), but actor
roles are annotated with WSO2 component mappings so the reader can connect theory to
their production environment.

A companion GLOSSARY rewrite replaces the existing 25-line stub with ~80 entries
covering every term introduced in the appendix.

**Audience:** Strong engineer, already has Go/WSO2 production exposure (from Phases 1-3),
wants the authoritative theory layer to teach teammates and debug from first principles.

---

## Success Criteria

After reading the appendix + glossary, the learner can:

1. Draw the four-actor OAuth2 model from memory and name the WSO2 component that plays each role.
2. Explain every standard grant type — what problem it solves, who initiates it, what flows over the wire — and choose the right one for a given client type.
3. Decode a JWT access token by hand: identify every standard claim, explain what each asserts, and flag which claims would make it invalid.
4. Distinguish an ID Token from an Access Token and explain why conflating them causes security bugs.
5. Explain token introspection vs local JWT validation: when each is appropriate and what the trade-off is.
6. Describe CIBA, token exchange, and device flow at awareness depth: what they solve, when to use them, one-sentence summary of the flow.
7. Explain federated identity / trusted issuer: what trust delegation means and how an IDP chain works.
8. State what SCIM2 is, why it exists alongside OAuth2/OIDC, and name its three core resource types.
9. Teach the Authorization Code + PKCE flow to a teammate using the sequence diagram in the document.

---

## Constraints

| Constraint | Rule |
|---|---|
| Format | Markdown only — no HTML, PDF, or Word |
| Diagrams | Mermaid only (`sequenceDiagram`, `graph LR`, `stateDiagram-v2`) — renders in GitHub, VSCode, Obsidian |
| Vendor neutrality | Theory sections are RFC-level and implementation-agnostic; WSO2 references appear only in parenthetical actor-mapping notes, never in flow diagrams |
| RFC anchors | Every protocol section names its authoritative RFC (e.g. RFC 6749, RFC 7519, RFC 8693) |
| No duplication | Do not duplicate Phase 1 Go code — cross-reference with a one-line pointer when relevant (e.g. "see `labs/phase1/day04/` for the JWT signer implementation") |
| Glossary | Replaces `wso2_mastery/content/GLOSSARY.md` entirely — do not append to existing content |
| Git | No commits — learner handles VCS |
| Credentials | No real tokens or secrets in any example |

---

## File Map

```
wso2_mastery/content/
├── APPENDIX_OAUTH2_OIDC.md    ← new file (this spec)
└── GLOSSARY.md                ← full rewrite of existing 25-line stub
```

---

## APPENDIX_OAUTH2_OIDC.md — Section Spec

### Section 1 — The Four Actors

**Depth:** Full  
**RFC:** RFC 6749 §1.1  
**Diagram:** 1 `graph LR` showing Resource Owner → Client → Authorization Server → Resource Server with labeled arrows (authorization request, token request, token, protected resource request)

Content:
- Resource Owner: the entity that owns the protected resource (usually a human user, sometimes a service)
- Client: the application requesting access on behalf of the Resource Owner; subtypes: confidential vs public, first-party vs third-party
- Authorization Server (AS): issues tokens after authenticating the Resource Owner and obtaining authorization; WSO2 IS plays this role
- Resource Server (RS): hosts the protected resource; validates tokens; WSO2 APIM Universal GW plays this role
- WSO2 mapping table: IS = AS; Universal GW = RS; APIM CP = client (publisher flow); developer portal = client (subscriber flow)
- Trust model: AS and RS must share a trust anchor (shared secret or public key); client must be registered with AS

---

### Section 2 — Token Anatomy

**Depth:** Full  
**RFCs:** RFC 6749 §1.4–1.5, RFC 7519, RFC 7517  
**Diagram:** 1 annotated three-part JWT breakdown (header.payload.signature as code block with field-by-field callouts)

Content:
- Token types: Access Token (opaque vs JWT), Refresh Token, ID Token, Authorization Code (not a token but often confused)
- Opaque vs JWT trade-off: opaque requires introspection on every call; JWT enables local validation at cost of revocation complexity
- Standard JWT claims (all mandatory/optional status per RFC 7519):
  - `iss` (issuer), `sub` (subject), `aud` (audience), `exp` (expiry), `iat` (issued-at), `jti` (JWT ID)
  - `nbf` (not-before), `scope`, `client_id`, `azp` (authorized party)
- OIDC-specific claims: `nonce`, `auth_time`, `acr`, `amr`, `at_hash`, `c_hash`
- Custom/private claims: naming conventions (namespaced), WSO2 typical extensions
- JWK (RFC 7517): what a JSON Web Key Set is, why the RS fetches it from AS's JWKS URI
- Signature algorithms: RS256 (asymmetric, recommended), HS256 (symmetric, avoid in distributed systems), ES256

---

### Section 3 — Grant Types

**Depth:** Full (one subsection per grant)  
**RFC:** RFC 6749, RFC 7636 (PKCE), RFC 8628 (Device), RFC 6819 (security)

Each subsection contains: problem statement → who uses it → full Mermaid `sequenceDiagram` → step-by-step annotation → security notes → when NOT to use it.

#### 3.1 Authorization Code + PKCE

Primary grant for user-facing applications. PKCE (RFC 7636) extension makes it safe for public clients (SPAs, mobile apps) by replacing the client secret with a code verifier/challenge pair.

Sequence: User → Client → AS (authorization endpoint) → User (login+consent) → Client (redirect with code) → Client → AS (token endpoint with code + verifier) → Client (tokens) → Client → RS (protected resource with access token)

PKCE steps: `code_verifier` (random 43-128 char string) → `code_challenge = BASE64URL(SHA256(code_verifier))` → sent in authorization request → `code_verifier` sent in token request → AS verifies

#### 3.2 Client Credentials

For machine-to-machine (service-to-service) flows where there is no human user. Client authenticates directly with AS using its own credentials.

Sequence: Client → AS (token endpoint: client_id + client_secret + grant_type=client_credentials) → Client (access token, no refresh token)

No Resource Owner involvement. No refresh token issued (client can re-authenticate any time).

#### 3.3 Device Authorization Flow (RFC 8628)

For input-constrained devices (smart TVs, CLI tools) that cannot open a browser. Device displays a code; user completes authorization on a secondary device.

Sequence: Device → AS (device authorization endpoint) → Device (device_code + user_code + verification_uri) → Device (display user_code) → User (browser: verification_uri + user_code) → AS (authenticate + authorize) → Device (polling token endpoint with device_code) → Device (access token when user completes)

#### 3.4 ROPC — Resource Owner Password Credentials (deprecated)

Client collects username + password directly and exchanges them for tokens. Violates the OAuth2 principle of never exposing credentials to the client. RFC 6749 §4.3. Deprecated in OAuth 2.1.

Include only as a "what to avoid" section with migration path to Authorization Code + PKCE.

#### 3.5 Implicit (deprecated)

Tokens returned directly in the authorization response URL fragment. No back-channel token exchange. Vulnerable to token leakage in browser history and referrer headers. Replaced by Authorization Code + PKCE. Deprecated in OAuth 2.1.

Include only as a "what to avoid" section.

#### 3.6 Refresh Token Flow

Not an independent grant type — a mechanism used alongside other grants. Access tokens are short-lived; refresh tokens allow obtaining new access tokens without re-authenticating.

Sequence: Client → AS (token endpoint: grant_type=refresh_token + refresh_token) → Client (new access token + optionally new refresh token)

Rotation policy: single-use rotation (recommended) vs sliding window. Revocation cascade: revoking refresh token invalidates derived access tokens.

---

### Section 4 — OIDC Extensions

**Depth:** Full  
**RFCs:** OpenID Connect Core 1.0, OpenID Connect Discovery 1.0  
**Diagram:** 1 layered diagram showing OAuth2 as foundation layer, OIDC as extension layer above it, with the ID Token and UserInfo endpoint as OIDC-specific additions

Content:
- OIDC as an identity layer on top of OAuth2: adds authentication semantics to authorization
- ID Token: a JWT asserting the identity of the authenticated user; contains `sub`, `iss`, `aud`, `exp`, `iat`, `nonce`, `auth_time`; NOT for resource authorization
- Access Token vs ID Token: access token = "what you can do"; ID token = "who you are" — conflating them is a common security bug
- UserInfo endpoint: returns claims about the authenticated user; requires a valid access token with `openid` scope; returns JSON
- OIDC scopes: `openid` (required), `profile`, `email`, `address`, `phone` — each maps to a standard claim set
- Login flow parameters:
  - `prompt`: `none` (silent), `login` (force re-auth), `consent`, `select_account`
  - `max_age`: maximum seconds since last active authentication
  - `login_hint`: hint to AS about which user to authenticate (email, phone)
  - `acr_values`: requested Authentication Context Class Reference (MFA level)
  - `nonce`: replay attack protection; must be validated by client
- Claims request parameter: allows requesting specific claims in ID token or UserInfo response
- Discovery: `/.well-known/openid-configuration` returns AS metadata (issuer, JWKS URI, supported grant types, scopes, etc.)
- Session management: front-channel logout, back-channel logout (OIDC Session Management spec)

---

### Section 5 — Token Lifecycle

**Depth:** Full  
**RFC:** RFC 7662 (introspection), RFC 7009 (revocation)  
**Diagram:** 1 `stateDiagram-v2` showing token states: issued → active → expired / revoked; separate path for refresh token rotation

Content:
- Issuance: token endpoint contract, response fields (`access_token`, `token_type`, `expires_in`, `refresh_token`, `scope`, `id_token`)
- Local JWT validation: verify signature (JWKS), validate `iss`, `aud`, `exp`, `nbf`, check `jti` against revocation list if maintained
- Introspection (RFC 7662): POST to introspection endpoint; AS returns active/inactive + claims; use when tokens are opaque or when real-time revocation is needed; latency cost vs local validation
- When to use each: local JWT validation = low latency, high throughput, accepts revocation lag; introspection = real-time accuracy, higher latency, RS must trust AS availability
- Revocation (RFC 7009): POST to revocation endpoint with token + token_type_hint; AS marks token invalid; propagation to RS depends on validation strategy
- Refresh token rotation: single-use (recommended) — AS issues new refresh token on each use, old one invalidated; detect reuse as compromise signal
- Token expiry best practices: access token 5-15 min; refresh token hours-to-days depending on sensitivity

---

### Section 6 — Advanced Protocols (Awareness Depth)

Each subsection: problem statement → one-paragraph explanation → Mermaid `sequenceDiagram` → when to use → RFC reference.

#### 6.1 Token Exchange (RFC 8693)

Allows a client to exchange one token for another — different audience, different scope, or different token type (e.g. impersonation, delegation, cross-service propagation). Key parameters: `subject_token`, `subject_token_type`, `actor_token`, `requested_token_type`.

#### 6.2 CIBA — Client-Initiated Backchannel Authentication (OIDC CIBA Core 1.0)

Decouples the authentication device from the consumption device. Client initiates auth request to AS; AS contacts the user's authentication device (push notification, SMS) out-of-band; client polls for or receives (via callback) the resulting tokens. Used in call-centre, IoT, and delegated-auth scenarios.

Three modes: poll, ping (AS notifies client URL), push (AS posts tokens directly to client).

#### 6.3 PAR — Pushed Authorization Requests (RFC 9126)

Client POSTs authorization parameters to AS before redirecting the user, receives a `request_uri`. Authorization request carries only `client_id` and `request_uri`. Prevents parameter tampering in the redirect URL.

#### 6.4 JAR — JWT-Secured Authorization Request (RFC 9101)

Authorization request parameters are bundled into a signed (and optionally encrypted) JWT. Integrity-protects the request. Often combined with PAR.

---

### Section 7 — Federation, IDP, Trusted Issuers

**Depth:** Structured awareness  
**RFC:** OIDC Core §1.2 (Relying Party), RFC 7591 (Dynamic Client Registration for federation context)  
**Diagram:** 1 `graph LR` trust chain: User → SP-IDP (WSO2 IS) → upstream IDP (Google/AD/etc.) with labeled trust arrows

Content:
- IDP (Identity Provider): an AS specialized in authenticating users; may be an upstream identity source (enterprise AD, social login)
- Service Provider (SP): the application that delegates authentication to an IDP; in OIDC, SP = Relying Party (RP)
- Federation: trust agreement between two identity domains; user authenticates in domain A, accesses resources in domain B
- Trusted issuer: an AS whose tokens the RS is configured to accept directly without re-validation through a local AS; requires pre-configured JWKS URI and issuer claim match
- Federated identity flow: RP → local IDP (WSO2 IS) → upstream IDP (OIDC or SAML) → IS maps external claims to internal claims → issues token to RP
- Social login: a specific federation pattern where the upstream IDP is a public provider (Google, GitHub, Facebook); IS acts as federation broker
- Claim mapping: translating claims from upstream IDP's schema to the local schema; WSO2 IS has a claim mapping UI for this
- Home Realm Discovery: determining which upstream IDP to redirect to based on user's email domain

---

### Section 8 — Endpoints Reference

**Depth:** Reference table (no narrative)

| Endpoint | Method | Purpose | Key Parameters | RFC/Spec |
|---|---|---|---|---|
| `/authorize` | GET | Start authorization flow | `response_type`, `client_id`, `redirect_uri`, `scope`, `state`, `code_challenge` | RFC 6749 §3.1 |
| `/token` | POST | Exchange code/credentials for tokens | `grant_type`, `code`, `client_id`, `client_secret`, `code_verifier` | RFC 6749 §3.2 |
| `/introspect` | POST | Validate and inspect a token | `token`, `token_type_hint` | RFC 7662 |
| `/revoke` | POST | Revoke a token | `token`, `token_type_hint` | RFC 7009 |
| `/userinfo` | GET | Fetch user claims | Authorization: Bearer `<access_token>` | OIDC Core §5.3 |
| `/jwks` | GET | Fetch public keys | — | RFC 7517 |
| `/.well-known/openid-configuration` | GET | AS discovery document | — | OIDC Discovery §4 |
| `/device_authorization` | POST | Start device flow | `client_id`, `scope` | RFC 8628 |
| `/bc-authorize` | POST | Start CIBA flow | `login_hint`, `scope`, `binding_message` | CIBA Core §7 |
| `/par` | POST | Push authorization request | All `/authorize` params | RFC 9126 |

---

### Section 9 — SCIM2

**Depth:** Structured awareness  
**RFC:** RFC 7642, RFC 7643, RFC 7644  
**Diagram:** 1 `graph LR` showing SCIM2 client (provisioner) → SCIM2 server (IDP) → OAuth2 AS (for SCIM2 API auth)

Content:
- SCIM2 (System for Cross-domain Identity Management): a REST API standard for provisioning and managing identity objects (Users, Groups) across systems
- Relationship to OAuth2/OIDC: SCIM2 handles *lifecycle* (create/update/delete users); OAuth2/OIDC handles *authentication and authorization*; they are complementary, not overlapping
- Core resource types: User, Group, EnterpriseUser extension
- Key endpoints: `GET /Users`, `POST /Users`, `PUT /Users/{id}`, `PATCH /Users/{id}`, `DELETE /Users/{id}`, `GET /Groups`, same CRUD for Groups
- Filtering: `GET /Users?filter=userName eq "john"` — SCIM2 filter syntax
- SCIM2 API protection: the SCIM2 server requires the caller to present an OAuth2 access token; the provisioner is an OAuth2 client using Client Credentials grant
- WSO2 IS implements SCIM2: used by HR systems and admin automation tools to provision users into WSO2 IS; GW learner mainly encounters it when debugging "user not found" or "group membership" issues

---

### Section 10 — Top-1% Mistakes

**Depth:** Full — opinionated, direct

1. **Using the ID Token as an Access Token** — ID tokens are assertions about identity for the client; they are not meant to be sent to a Resource Server. An RS that accepts an ID token is trusting claims it was not designed to verify.
2. **Skipping PKCE for confidential clients** — PKCE is not just for public clients. It defends against authorization code interception even when client secrets are in use. Use it everywhere.
3. **Long-lived access tokens with no introspection** — local JWT validation cannot see revocation. If your access tokens live longer than your tolerable revocation lag, you need introspection or short expiry.
4. **Conflating authentication and authorization** — OIDC is authentication (who is this user?); OAuth2 is authorization (what can this client do?). Mixing their tokens causes both security holes and debugging confusion.
5. **Re-using refresh tokens without rotation** — a stolen refresh token is permanent access unless rotation is on. Single-use rotation also lets you detect theft: a reuse attempt signals compromise.
6. **Treating the `sub` claim as a stable user identifier** — `sub` is stable within one issuer. Across federated issuers, `iss` + `sub` together is the stable identifier. Building user lookup on `sub` alone breaks in multi-IDP deployments.

---

## GLOSSARY.md — Rewrite Spec

Full replacement of `wso2_mastery/content/GLOSSARY.md`.

Structure: alphabetically ordered entries. Each entry: **Term** — one to three sentence plain-English definition + RFC/spec reference where applicable + cross-reference to related terms.

Target: ~80 entries covering every term introduced in the appendix plus common WSO2/APIM terms from prior phases. Terms must include at minimum:

Access Token, acr (Authentication Context Class Reference), amr (Authentication Methods References), Authorization Code, Authorization Endpoint, Authorization Server, at_hash, aud (audience), Backchannel Authentication (CIBA), Bearer Token, c_hash, Claim, Client, Client Credentials, Client ID, Client Secret, code_challenge, code_verifier, Confidential Client, Device Authorization Flow, Discovery Document, exp (expiration), Federation, Grant Type, Home Realm Discovery, ID Token, IDP (Identity Provider), Implicit Flow (deprecated), Introspection, iss (issuer), JAR (JWT-Secured Authorization Request), jti (JWT ID), JWKS (JSON Web Key Set), JWK (JSON Web Key), JWT (JSON Web Token), Key Manager (WSO2), login_hint, max_age, nonce, OAuth 2.0, OAuth 2.1, OIDC (OpenID Connect), opaque token, PAR (Pushed Authorization Requests), PKCE, prompt, Public Client, Redirect URI, Refresh Token, Relying Party, Resource Owner, Resource Server, revocation, RFC 6749, RFC 7519, RFC 7662, RFC 7009, RFC 8693, RFC 8628, RFC 9101, RFC 9126, ROPC (deprecated), scope, SCIM2, Social Login, state parameter, sub (subject), Token Endpoint, Token Exchange, Token Introspection, Trusted Issuer, UserInfo Endpoint, well-known configuration

---

## Self-Review Checklist

- [ ] All 10 sections have at least one diagram specified
- [ ] No TBD or placeholder text in section specs
- [ ] RFC numbers cited for every section
- [ ] Glossary term list covers all terms used in appendix sections
- [ ] WSO2 references are annotation-only (not in flow diagrams)
- [ ] File paths are exact and consistent
- [ ] No duplication with Phase 1 lab code (cross-reference pointers only)
