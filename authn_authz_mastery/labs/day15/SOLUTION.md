# Day 15 Lab — Solution

## The two gateway configuration requirements for DPoP end-to-end

Both are about forwarding the `DPoP:` HTTP header — but at two different points in the flow.

### Requirement 1: Forward `DPoP:` at the token endpoint (client → IS 7.3)

When the client requests a token, it sends a `DPoP:` proof header. If the API gateway that
sits in front of IS 7.3 strips this header (the default behaviour for unknown/non-standard headers
in most proxies), IS 7.3 never sees the DPoP proof. IS 7.3 therefore issues a regular Bearer
token without `cnf.jkt`.

**NGINX fix:**

```nginx
location /oauth2/ {
    proxy_pass http://is73_upstream;
    proxy_pass_header DPoP;
    # or: proxy_set_header DPoP $http_dpop;
}
```

### Requirement 2: Forward `DPoP:` at the resource server (client → RS)

When the client uses the DPoP-bound token at the resource server, it sends a NEW `DPoP:` proof
header (different from the one used at the token endpoint — `htm`/`htu` match the current
request, and `ath` binds it to the access token). If the gateway between the client and the
resource server strips this header, the resource server receives a token with `cnf.jkt` in
the introspection response but no `DPoP:` header to validate against.

A correctly implemented resource server MUST reject this with `401` — the binding cannot be verified.
An incorrectly implemented resource server (one that ignores `cnf.jkt`) will accept it — defeating
the entire purpose of DPoP, exactly as described in the "Why this matters" scenario.

**These are two separate headers in two separate requests.** The token-endpoint proof and the
resource-server proof are different JWTs, bound to different `htm`/`htu` values.

---

## Where IS 7.3 embeds cnf.jkt — and how

When IS 7.3 processes a token request with a valid `DPoP:` header:

1. It validates the proof JWT (signature, `htm`, `htu`, `iat`, `jti`).
2. It extracts the `jwk` (public key) from the DPoP proof header.
3. It computes the JWK Thumbprint: `SHA-256(canonical_JSON(jwk))`, base64url-encoded.
4. It stores `jkt` in the access token's `cnf` claim.

For JWT access tokens, `cnf.jkt` is embedded directly in the JWT payload. Any party that decodes
the JWT will see it. For opaque tokens, IS 7.3 stores the binding in its internal token store
and exposes it only via the introspection endpoint.

---

## What the resource server is obligated to do when cnf.jkt is present

The `cnf.jkt` claim is not informational — it is a **binding requirement**. When present:

1. Require a `DPoP:` proof header in the request. Reject without it (`401`).
2. Parse the DPoP proof JWT.
3. Verify the proof's signature against the public key whose JWK Thumbprint equals `cnf.jkt`.
4. Verify `htm` matches the request's HTTP method (exact string match, uppercase).
5. Verify `htu` matches the request URL (without query string, without fragment).
6. Verify `ath` = `BASE64URL(SHA-256(ASCII(access_token)))` — binds this proof to this specific token.
7. Verify `iat` is within clock skew tolerance (typically ≤ 60 seconds of the RS clock).
8. Verify `jti` has not been used before (replay detection — store jti values for the token lifetime).

Failing any check → `401 WWW-Authenticate: DPoP error="invalid_dpop_proof"`.

---

## DPoP vs. mTLS precedence

When a client presents BOTH a DPoP proof AND a client certificate:

- IS 7.3 embeds **only `cnf.jkt`** (DPoP thumbprint). mTLS is ignored.
- `token_type` is `DPoP`.

This is per RFC 9449 §5: DPoP supersedes mTLS when both are present simultaneously.

**There is no automatic fallback.** If:
- DPoP is configured and the gateway strips the `DPoP:` header,
- `dpop_token_binding_required = false`,
- mTLS is also configured,

then IS 7.3 does NOT switch to mTLS binding. It issues an **unbound Bearer token** — no `cnf` at all.
To get mTLS binding, the client must NOT send a DPoP header. The two mechanisms are not chained
or fallback-aware.

---

## What fails without each deployment.toml setting

| Setting | What fails if omitted |
|---------|----------------------|
| `dpop_token_binding_enabled = true` | IS 7.3 ignores `DPoP:` headers; issues unbound Bearer tokens; `cnf.jkt` never appears |
| `tls_client_certificate_bound_access_tokens = true` | IS 7.3 ignores client certificates; issues unbound tokens; `cnf.x5t#S256` never appears |
| `ssl_client_cert_header_name = "ssl-client-cert"` | IS 7.3 reads from TLS session (which has no cert behind a proxy); mTLS binding silently inactive |
| `enable_ssl_cert_from_header = true` | Same failure as above — IS 7.3 will not read from the header even if the header is present |
