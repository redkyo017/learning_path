# Phase 1 Composite Flow Checklist — Solution

## Filled checklist

| Security Property | Protocol | Day covered |
|------------------|----------|-------------|
| Authorization request parameters off the front channel | PAR — Pushed Authorization Requests (RFC 9126) | Day 02 |
| Fine-grained authorization data (payment amount, payee) | RAR — Rich Authorization Requests (RFC 9396) | Day 03 |
| Client authentication without shared secrets | FAPI 2.0 client auth — `private_key_jwt` (RFC 7523) or mTLS (`tls_client_auth`) | Day 01 |
| Auth response tamper protection | JARM — JWT Secured Authorization Response Mode | Day 01 |
| Authorization code interception protection | PKCE — Proof Key for Code Exchange (RFC 7636), S256 only | Day 01 |
| Token binding to client key (application layer) | DPoP — Demonstrating Proof of Possession (RFC 9449) | Day 05 |
| Token binding to TLS certificate (transport layer) | mTLS Certificate-Bound Access Tokens (RFC 8705) | Day 06 |
| Headless authentication (no browser) | CIBA — Client-Initiated Backchannel Authentication | Day 04 |
| Transaction binding (dynamic linking) | SCA Dynamic Linking (PSD2 RTS Art. 5) | Day 09 |
| User provisioning and deprovisioning | SCIM 2.0 (RFC 7643, RFC 7644) | Day 07 |
| Consent lifecycle management | PSD2 Consent Management | Day 08 |
| SCA factor requirements | SCA — Strong Customer Authentication (PSD2 RTS Art. 4) | Day 09 |

---

## Explanations

**PAR (Pushed Authorization Requests)**
All authorization parameters — including `scope`, `redirect_uri`, `code_challenge`, and `authorization_details` — are posted directly to the AS over a back-channel HTTPS connection. The browser URL carries only the opaque `request_uri`. This prevents sensitive parameters from appearing in browser history, access logs, or referrer headers.

**RAR (Rich Authorization Requests)**
The `authorization_details` JSON array allows a TPP to specify fine-grained authorization constraints — payment amount, currency, payee account, reference — that `scope` strings cannot express. These constraints flow from the PAR body into the consent record and the access token, enabling the RS to enforce them.

**FAPI 2.0 client auth (`private_key_jwt`)**
The TPP proves its identity by signing a JWT with its private key (RSA PS256 or EC ES256). The AS verifies the signature against the TPP's registered public key. No shared secret (client_secret) is involved — compromise of the wire does not expose the client credential.

**JARM (JWT Secured Authorization Response Mode)**
The authorization response (containing the authorization code and state) is wrapped in a signed JWT before being sent via the browser redirect. The TPP verifies the JWT signature, `iss`, `aud`, and `exp` claims before extracting the code. This prevents code substitution and response replay attacks.

**PKCE (Proof Key for Code Exchange, S256)**
The TPP generates a random `code_verifier`, computes `code_challenge = BASE64URL(SHA256(code_verifier))`, and sends the challenge in the PAR request. At the token endpoint, it sends the original `code_verifier`. The AS recomputes the challenge and verifies it matches. This prevents an intercepted authorization code from being exchanged by a third party without the verifier.

**DPoP (Demonstrating Proof of Possession)**
DPoP binds the access token to the TPP's asymmetric key at the application layer. The token contains a `cnf.jkt` claim (key thumbprint). Each API request includes a DPoP proof JWT signed with that key, containing `ath` (hash of the access token), `htm` (HTTP method), `htu` (HTTP URL), and a unique `jti`. A stolen access token is useless without the private key.

**mTLS Certificate-Bound Tokens (RFC 8705)**
mTLS binds the access token to the client's TLS certificate at the transport layer. The token contains a `cnf.x5t#S256` claim (certificate thumbprint). The RS verifies the thumbprint against the TLS client certificate presented in the connection handshake. Works at infrastructure level without application-layer changes, but requires a PKI chain.

**CIBA (Client-Initiated Backchannel Authentication)**
CIBA allows an authorization flow to complete without a browser redirect. The consumption device (call centre agent, backend server) POSTs to `/bc-authorize` with a `login_hint` and `binding_message`. The authentication device (user's mobile app) receives a push notification and approves or rejects. The consumption device polls or receives a push to obtain the token.

**SCA Dynamic Linking (PSD2 RTS Art. 5)**
The SCA approval must be dynamically linked to the specific transaction. The user must see and approve the amount and payee before SCA is considered complete. In CIBA flows, the `binding_message` carries the transaction details to both devices. In redirect flows, the consent screen displays `authorization_details`. An SCA approval without dynamic linking does not satisfy PSD2 RTS.

**SCIM 2.0 (RFC 7643, RFC 7644)**
SCIM provides a standardised API for provisioning and deprovisioning user identities across systems. Banks use SCIM to receive user records from partner institutions, federate identities, and synchronise deactivations. A `PATCH active=false` must trigger cascading revocation of all active consents and tokens for that user.

**PSD2 Consent Management (Day 08)**
The consent lifecycle (AwaitingAuthorisation → Authorised → Expired/Revoked) governs how long a TPP may access a PSU's data. Consents must be linked to specific `authorization_details` (AIS or PIS), have a defined expiry (max 90 days for AIS), and be revocable by the PSU or ASPSP at any time. Active tokens must be revoked when the consent is revoked.

**SCA Factor Requirements (PSD2 RTS Art. 4)**
SCA requires authentication using at least two of three factor categories: knowledge (something the user knows), possession (something the user has), and inherence (something the user is). For payment initiation above thresholds, no exemption applies and both factors must be verified in the same authentication ceremony.

---

## Stretch question answer

**Data dependency between PAR and the consent record:**

The `authorization_details` JSON array is the critical field. It is posted in the PAR body at Step A, and the AS must copy it verbatim into the consent record when the consent object is created at Step C. If this handoff is broken — for example, the consent service normalises `authorization_details` to a scope string, or omits the `instructed_amount` for "brevity" — the RS loses the ability to enforce payment limits. The RS reads `authorization_details` from the access token claims (which are derived from the consent record), so any information loss at the PAR → consent boundary propagates forward and cannot be recovered downstream.

---

## Reflection notes

**Most likely handoff to fail in a real system:**

The `authorization_details` propagation chain (PAR → consent → token → RS) is the most failure-prone because it crosses four team/service boundaries. Each team may make reasonable local decisions — normalize for storage, abbreviate for JWT size, cache for performance — that individually look correct but collectively destroy the fine-grained authorization information. The fix is a single end-to-end test that checks `authorization_details` content at the RS boundary, run from day one of development.
