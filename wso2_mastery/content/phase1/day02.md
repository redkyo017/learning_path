# Day 2 — Client Credentials Grant: Go Implementation

## Why this matters
`client_credentials` is the grant type your company's service-to-service APIs use.
Building it in Go forces you to handle every edge case: missing headers, wrong content
type, unknown client — the same cases WSO2 IS handles in `ClientCredentialsGrantHandler`.

After today you will be able to: read a real `client_credentials` token request, predict
what WSO2 IS checks in order, and diagnose `invalid_client` vs. `invalid_grant` errors
without guessing.

## WSO2 source reading
- File: `wso2is-7.3.0/...ClientCredentialsGrantHandler.java`
  Key insight: the handler validates client, scope, then delegates token generation.
  The token itself is opaque (random bytes) or JWT — configurable via `OAuthServerConfiguration`.

- Look for `validateGrant()` — this is where scope is checked.
- Look for `issue()` — this is where the token record is written.
- The handler does NOT parse Basic Auth itself; that is done upstream by
  `OAuthClientAuthnService` before the handler is invoked.

## Core concepts

### The client_credentials flow
```
POST /oauth2/token HTTP/1.1
Authorization: Basic base64(clientId:clientSecret)
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=read:api
```
Response:
```json
{"access_token":"abc123","token_type":"Bearer","expires_in":3600,"scope":"read:api"}
```

The `Authorization` header value is: `Basic ` followed by `base64(clientId:clientSecret)`.
For example, `test-client:test-secret` encodes to `dGVzdC1jbGllbnQ6dGVzdC1zZWNyZXQ=`.

There is no user involved. The client authenticates itself directly. This makes it
suitable for background jobs, microservices, and API-to-API calls.

### Validation order in WSO2 IS
1. Parse and validate the HTTP request (method, content-type, body).
2. Authenticate the client (Basic Auth header) via `OAuthClientAuthnService`.
3. Look up the application registration in `SP_APP` / `IDN_OAUTH_CONSUMER_APPS`.
4. Validate the requested scope against allowed scopes for this application.
5. Check for an existing active token for this client (token reuse logic).
6. Generate and store the token; return JSON response.

### Token storage (opaque tokens)
WSO2 stores a random token in the DB; validation requires a DB lookup (`/introspect`).
JWT tokens are self-contained — validation needs only the public key.
Your Go lab uses opaque tokens stored in a `sync.Map` (no DB needed for the lab).

The DB row looks like:
```sql
INSERT INTO IDN_OAUTH2_ACCESS_TOKEN
  (TOKEN_ID, ACCESS_TOKEN, CONSUMER_KEY, AUTHZ_USER, TOKEN_STATE,
   TIME_CREATED, VALIDITY_PERIOD, TOKEN_SCOPE)
VALUES
  (uuid(), sha256(token), 'test-client', 'test-client@carbon.super',
   'ACTIVE', now_ms(), 3600000, 'read:api');
```

### Token reuse
By default, WSO2 IS reuses an existing active token when the same client requests a
new one with the same scope. This avoids token sprawl.

Controlled by: `OAuthServerConfiguration.isTokenRenewalPerRequestEnabled()`.
If `false` (default): existing token is returned. If `true`: new token always issued.

Your Go lab implements the simpler "always new" behavior. The Day 2 exercises ask you
to add reuse — see `SOLUTION.md`.

### Error responses (RFC 6749 §5.2)
| Scenario | `error` value | HTTP status |
|---|---|---|
| Unknown/invalid client | `invalid_client` | 401 |
| Wrong grant type | `unsupported_grant_type` | 400 |
| Bad scope | `invalid_scope` | 400 |
| Missing required param | `invalid_request` | 400 |
| Server error | `server_error` | 500 |

The error response body is always JSON:
```json
{"error":"invalid_client","error_description":"Client Authentication failed."}
```
The `error_description` field is optional per RFC but WSO2 IS always includes it.

### Cache-Control on token responses
RFC 6749 §5.1 requires token responses to include:
```
Cache-Control: no-store
Pragma: no-cache
```
This prevents proxies from caching tokens. If your gateway or CDN strips these headers,
tokens can leak to unintended clients. Always verify these headers in production.

## Lab
See `labs/phase1/day02/`. Goal: run the Go token server and issue a `client_credentials`
token with `curl`. Success signal: `curl` returns
`{"access_token":"...","token_type":"Bearer","expires_in":3600}`.

## Exercises
1. Extend the lab server to reject requests without `Content-Type: application/x-www-form-urlencoded`.
   **Hint:** Check `r.Header.Get("Content-Type")` before `r.ParseForm()`.
   **Solution sketch:** Return `{"error":"invalid_request"}` with 400 if content type is missing or wrong.

2. What does WSO2 IS do when the same `client_id` requests a second token before the first expires?
   **Hint:** Search for `REUSE_TOKEN` in the WSO2 IS source or config.
   **Solution sketch:** By default WSO2 reuses the existing active token rather than issuing a new one (`OAuthServerConfiguration.isTokenRenewalPerRequestEnabled()`).

3. Add an in-memory token store to the lab server (a `map[string]tokenRecord`). What fields does each record need?
   **Hint:** Look at `IDN_OAUTH2_ACCESS_TOKEN` columns in WSO2 schema.
   **Solution sketch:** `{Token, ClientID, Scope, IssuedAt time.Time, ExpiresIn int}`.

4. What `curl` flag produces the Base64 encoding of `test-client:test-secret` without a trailing newline?
   **Hint:** `echo -n` suppresses the newline before piping to `base64`.
   **Solution sketch:** `echo -n 'test-client:test-secret' | base64` — the `-n` flag is essential; a trailing newline changes the encoded value.

5. Your lab server returns `Cache-Control: no-store`. What happens to a client that ignores this header and caches the token for 1 hour?
   **Hint:** Think about token revocation and multi-instance deployments.
   **Solution sketch:** The client may use a revoked or expired token because it never re-requests. The server will return 401 from the gateway, but the client won't know why until it re-requests a fresh token. Always honor `no-store`.

## Anti-patterns / Common mistakes
- Returning 403 for an invalid client — RFC 6749 requires 401.
- Not setting `Cache-Control: no-store` on the token response — tokens must not be cached by proxies.
- Issuing a new token on every request by default — WSO2 reuses active tokens; your lab should too.
- Calling `r.ParseForm()` without checking the method — `ParseForm` on a GET request reads
  query params, not the body, which can cause subtle bugs.
- Logging the `client_secret` or `access_token` value — these are secrets; log only
  `client_id` and token metadata (issued-at, expires-in).

## Teardown
See `labs/phase1/day02/teardown.md`. Stop the Go process with `Ctrl+C`; no cloud resources.
