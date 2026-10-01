# Day 01 — FAPI 2.0 Security Profile

## Why this matters

In 2022, a European bank's open banking implementation used a standard OAuth 2.0 redirect flow for payment authorisation. The TPP sent the full authorisation request — including `authorization_details` carrying the payment amount (€15,000) and the payee IBAN — as query parameters in the browser redirect URL. Within hours, the bank's application server logs (which recorded every inbound GET URL) had accumulated thousands of records containing complete payment details. A contractor with read access to those logs could reconstruct every pending payment transaction before the user had even authenticated. The bank failed its PSD2 security audit.

FAPI 2.0 exists to close exactly this class of attack: front-channel parameter leakage, authorization code interception, CSRF, and PKCE downgrade attacks. It does not invent new cryptography — it assembles existing RFCs into a mandatory, auditable security profile.

## Core concepts

### FAPI 2.0 threat model

FAPI 2.0 addresses four primary attack classes:

- **Front-channel leakage**: Authorization parameters sent in redirect URLs appear in browser history, server access logs, referrer headers, and mobile OS screenshots. Any sensitive data in the URL is at risk.
- **Authorization code interception**: An attacker who can intercept the authorization code in the redirect response can exchange it for tokens without knowing the original request parameters.
- **CSRF**: A forged authorization response can be injected, binding the victim's session to an attacker-controlled token.
- **PKCE downgrade**: Servers that make PKCE optional can be tricked into accepting code exchanges without a verifier.

### FAPI 2.0 vs OAuth 2.0 vs FAPI 1.0

| Feature | Plain OAuth 2.0 | FAPI 1.0 Baseline | FAPI 1.0 Advanced | FAPI 2.0 Security Profile |
|---------|----------------|-------------------|-------------------|--------------------------|
| PAR | Not defined | Optional | Recommended | **Mandatory** |
| PKCE | Optional | Required | Required | **Mandatory (S256 only)** |
| Client auth | Any method | `private_key_jwt` or mTLS | `private_key_jwt` or mTLS | **`private_key_jwt` or mTLS only** |
| Response mode | `query`, `fragment` | `query`, `fragment` | `jwt` recommended | **`response_mode=jwt` (JARM) mandatory** |
| `response_type` | `code`, `token`, `id_token` | `code`, hybrid | `code` only | **`code` only** |
| JAR (signed request object) | Not required | Not required | Required | Required |

### PAR as a mandatory requirement

FAPI 2.0 mandates Pushed Authorization Requests (RFC 9126). All authorization parameters are POSTed directly to the authorization server's PAR endpoint over a back-channel TLS connection before the browser redirect occurs. The redirect carries only an opaque `request_uri` and `client_id`. This removes all sensitive parameters from the front channel entirely.

### PKCE enforcement: S256 only

FAPI 2.0 requires PKCE with `code_challenge_method=S256`. The `plain` method is prohibited — it provides no meaningful security because the verifier and challenge are identical. Making PKCE optional is also prohibited: every authorization code flow must use S256 PKCE.

### JARM: JWT Secured Authorization Response Mode

FAPI 2.0 mandates `response_mode=jwt`. Instead of redirecting with `?code=abc&state=xyz`, the authorization server returns a signed JWT containing the authorization response:

```
/callback?response=eyJhbGciOiJQUzI1NiIsInR5cCI6IkpXVCJ9...
```

The JWT is signed with the authorization server's private key. The client verifies:
- The JWT signature against the server's published JWKS
- `iss` (issuer) matches the expected authorization server
- `aud` (audience) matches the client's `client_id`
- `exp` / `iat` are within the acceptable window (prevents replay)

This prevents an attacker from injecting a forged authorization response or replaying a captured one.

### `response_type=code` only

FAPI 2.0 prohibits implicit (`response_type=token`), hybrid (`response_type=code token`), and `response_type=id_token` flows. These modes return tokens or token references directly in the front-channel redirect, which reintroduces the leakage that PAR eliminates. Only the authorization code flow (`response_type=code`) is permitted — tokens are always obtained via a back-channel token endpoint request.

### Short-lived `request_uri` TTL

The PAR endpoint's `request_uri` must expire within 60–90 seconds (the spec recommends no more than 90 seconds). This limits the window during which an intercepted `request_uri` could be replayed. After expiry or first use, the server must invalidate the URI.

### FAPI 2.0 client authentication

Permitted methods:
- `private_key_jwt` (RFC 7523): Client signs a JWT with its private key; server verifies against the client's registered JWKS URI.
- mTLS (RFC 8705): Client presents a certificate during TLS handshake; server validates against the registered certificate or DN.

Prohibited methods:
- `client_secret_basic`
- `client_secret_post`
- `client_secret_jwt`
- `none` (public clients)

### FAPI 2.0 full authorization flow

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

## Anti-patterns / Common mistakes

- **Making PAR optional ("we'll add it later")**: FAPI 2.0 mandates PAR. A server that accepts authorization requests without a prior PAR POST is not FAPI 2.0 compliant. Partial compliance fails conformance testing and open banking certification audits.

- **Accepting `response_mode=query` alongside `jwt`**: An authorization server that supports both allows a downgrade attack. An attacker who can manipulate the client's request can force `response_mode=query`, putting the authorization code in the URL where it gets logged. The server must reject any authorization request that does not specify `response_mode=jwt`.

- **Using `client_secret_basic` for FAPI clients**: `client_secret_basic` and `client_secret_post` are explicitly prohibited by FAPI 2.0. They rely on a shared secret that can be brute-forced or leaked. All FAPI 2.0 clients must authenticate with asymmetric credentials: `private_key_jwt` or mTLS.

## Exercises

1. List the four protocol-level differences between FAPI 1.0 Advanced and FAPI 2.0 Security Profile.

   **Hint:** Compare PAR requirements, client auth methods, response modes, and PKCE mandates.

   **Solution sketch:** FAPI 2.0 mandates PAR (FAPI 1.0 Advanced only recommended it); FAPI 2.0 removes `response_type=id_token` and hybrid flows; FAPI 2.0 mandates `private_key_jwt` or mTLS (FAPI 1.0 still allowed `client_secret_jwt`); FAPI 2.0 mandates JARM (`response_mode=jwt`).

2. A bank's auth server receives an authorization request via redirect with `response_mode=query`. Explain why this violates FAPI 2.0 and what specific attack it enables.

   **Hint:** Think about where `code` appears in a query-mode response and what systems log it.

   **Solution sketch:** `response_mode=query` puts the authorization `code` in the redirect URL, which gets logged by web servers, proxies, and referrer headers. An attacker with log access can replay the code. FAPI 2.0 mandates `response_mode=jwt` (JARM) so the response is a signed JWT; the code is inside the JWT payload, not in the URL. Replay is prevented by the JARM `iat`/`exp` and the `code` is bound to the client via the PKCE verifier.

3. Draw the FAPI 2.0 authorization flow from memory: label each step, identify where PAR, PKCE, and JARM each appear, and mark which steps happen on the front channel vs. back channel.

   **Hint:** Front channel = browser redirect. Back channel = direct HTTP from client server.

   **Solution sketch:** Back channel: (1) Client POSTs full auth request to PAR endpoint → receives `request_uri`. Front channel: (2) Redirect to auth server with `request_uri` only. Auth server: (3) Authenticates user, verifies PKCE `code_challenge`. Front channel: (4) JARM response JWT redirected back to client. Back channel: (5) Client POSTs to token endpoint with `code` + `code_verifier` → receives access token.

## Lab

See `labs/day01/`. Goal: annotate a FAPI 2.0 client registration JSON and trace the auth flow in the sequence diagram. Success signal: you can identify which fields enforce which FAPI 2.0 requirements without referring to the spec.
