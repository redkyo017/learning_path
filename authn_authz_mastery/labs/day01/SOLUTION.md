# Day 01 Lab — Solution

## Field-by-field annotations

| Field | Purpose | FAPI 2.0 requirement |
|-------|---------|----------------------|
| `grant_types: ["authorization_code"]` | Only auth code flow | FAPI 2.0 prohibits implicit and hybrid |
| `response_types: ["code"]` | Auth code only | No `id_token` or hybrid response types |
| `token_endpoint_auth_method: "private_key_jwt"` | Client authenticates with signed JWT | FAPI 2.0 mandates `private_key_jwt` or mTLS; `client_secret_*` disallowed |
| `token_endpoint_auth_signing_alg: "PS256"` | RSA-PSS SHA-256 | FAPI 2.0 requires PS256 or ES256; RS256 disallowed |
| `authorization_signed_response_alg: "PS256"` | JARM signing algorithm | FAPI 2.0 mandates JARM (`response_mode=jwt`); this sets the signing key |
| `require_pushed_authorization_requests: true` | Server rejects non-PAR requests | FAPI 2.0 mandates PAR |
| `require_signed_request_object: true` | Authorization request must be a JWT | FAPI 2.0 Advanced requirement; prevents parameter tampering |
| `tls_client_certificate_bound_access_tokens: true` | Access tokens are certificate-bound | mTLS token binding (RFC 8705); DPoP is an alternative |
| `jwks_uri` | Public keys for client_assertion verification | Required for `private_key_jwt` client auth |

## Fields absent from plain OAuth2 registration

A plain OAuth2 client registration would not have:
- `require_pushed_authorization_requests` (plain OAuth2 has no PAR concept)
- `authorization_signed_response_alg` (no JARM requirement)
- `tls_client_certificate_bound_access_tokens` (no RFC 8705 binding)
- `require_signed_request_object` (JAR not required by plain OAuth2)
