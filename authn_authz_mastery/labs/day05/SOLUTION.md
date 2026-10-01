# Day 05 Lab — Solution

## Why the JWK is embedded in the proof header (not referenced by kid)

DPoP proofs are self-contained: the public key is embedded so the RS can verify the proof without a network call to a JWKS URI. The RS never has to trust a key ID registry — it verifies the proof signature using the inline `jwk`, then cross-checks that the `jwk`'s thumbprint matches `cnf.jkt` in the access token. This eliminates a key-lookup round-trip on every resource request and prevents key ID substitution attacks.

`typ: "dpop+jwt"` prevents a DPoP proof from being confused with an access token, ID token, or client assertion. Each token type has a distinct `typ` value; processors that see an unexpected `typ` must reject the JWT.

## Claim-by-claim explanations

| Claim | What it binds / prevents |
|-------|--------------------------|
| `jti` | Unique per proof — RS caches seen values to prevent replay. A captured proof cannot be resubmitted. |
| `htm` | Binds proof to one HTTP method. Cannot reuse a GET proof for POST. |
| `htu` | Binds proof to one URL. Cannot reuse a proof for `/accounts` at `/payments`. |
| `iat` | Short-lived proof window. RS rejects proofs older than ~60 seconds. |
| `ath` | Binds proof to a specific access token. Proof is useless with a different token. |
| `nonce` | Server-issued; prevents offline pre-generation of proof batches. |

## How cnf.jkt is derived

1. Take the `jwk` object from the DPoP proof header
2. Serialize it to canonical JSON (RFC 7638): lexicographic key order, no whitespace
3. Compute SHA-256 of the UTF-8 bytes
4. Base64url-encode the result (no padding)
5. That value becomes `cnf.jkt` in the access token

The AS does this at token issuance. The RS does this when verifying a resource request. Both must produce the same value for the proof to be accepted.

## RS validation sequence (in order)

1. Parse the DPoP proof JWT
2. Verify `typ` header is `dpop+jwt`
3. Verify the proof JWT signature using the `jwk` in the proof header
4. Verify `ath` = `base64url(sha256(access_token_bytes))`
5. Verify `htm` matches the actual HTTP method of the request
6. Verify `htu` matches the actual HTTP URL of the request
7. Verify `iat` is within the acceptable window (e.g., within ±60 seconds)
8. Verify `jti` has not been seen before (replay check)
9. If nonce is required: verify `nonce` matches the issued nonce
10. Compute `thumbprint(jwk from proof header)` and verify it equals `cnf.jkt` from the access token

If any check fails, the RS returns `401` with `WWW-Authenticate: DPoP error="..."`.

## What jti prevents

`jti` (JWT ID) is a unique identifier that the RS stores after seeing a valid proof. If an attacker captures a valid DPoP proof (e.g., from a log or network dump) and replays it, the RS recognises the `jti` and rejects it. The replay prevention window is bounded by the `iat` check — the RS only needs to cache `jti` values for the duration of the acceptable `iat` window.

Without `jti`, an attacker who captures a proof (and the matching access token) could replay the exact same request repeatedly until the token expires.
