# Day 3 — Authorization Code Grant + PKCE

## Why this matters
When a user logs into a portal backed by WSO2 IS, the authorization_code grant runs.
Understanding it explains WSO2 IS session management, consent pages, and the difference
between an authorization code (short-lived, single-use) and an access token.

The authorization code grant is the most complex grant type. It involves two separate
HTTP round-trips and requires careful state management. Bugs here — reused codes, mismatched
redirect URIs, missing PKCE — are a common source of OAuth2 security vulnerabilities.

## WSO2 source reading
- File: `AuthorizationCodeGrantHandler.java`, `OAuthAuthzEndpoint.java`
  Key insight: the *authorization endpoint* issues a code; the *token endpoint* exchanges it.
  The code is stored in `IDN_OAUTH2_AUTHORIZATION_CODE` for single-use validation.

- `OAuthAuthzEndpoint.java` handles the redirect — this is the `/oauth2/authorize` path.
  It builds the redirect URL with the `code` parameter and sends a 302 to the client.
- `AuthorizationCodeGrantHandler.java` handles the code exchange at `/oauth2/token`.
  Look for where it calls `loadAuthorizationCode()` and then invalidates the code.
- The consent page is a separate flow — look for `OAuthConsentPage` or `ConsentManager`.

## Core concepts

### Two-step flow
```
Step 1 — redirect user to /oauth2/authorize:
  GET /oauth2/authorize?response_type=code&client_id=X&redirect_uri=Y&state=Z

  → WSO2 IS authenticates the user (login page / SSO)
  → WSO2 IS redirects to redirect_uri with ?code=<code>&state=Z

Step 2 — exchange code at /oauth2/token:
  POST /oauth2/token
  Authorization: Basic base64(clientId:clientSecret)
  Content-Type: application/x-www-form-urlencoded

  grant_type=authorization_code&code=<code>&redirect_uri=Y
  → Response: {"access_token":"...","token_type":"Bearer","expires_in":3600}
```

The `state` parameter is opaque to the AS — it passes it through unchanged. The client
uses it to prevent CSRF attacks by binding the authorization request to the response.

### Authorization code properties
- **Short-lived**: WSO2 IS sets a 10-minute expiry by default (configurable).
- **Single-use**: Once exchanged, the code is deleted from `IDN_OAUTH2_AUTHORIZATION_CODE`.
  A second exchange attempt returns `invalid_grant`.
- **Bound to redirect_uri**: The URI in the token exchange must match the URI in the
  authorization request exactly (including trailing slashes, query params).
- **Bound to client**: The code is tied to the client that requested it. Another client
  cannot exchange it.

### PKCE (RFC 7636) — why it exists
Without PKCE, a malicious app that intercepts the redirect URI gets the code and can
exchange it. This is a real attack on mobile apps where any app can register a URI scheme.

PKCE adds a `code_verifier` (random string, 43-128 chars) sent only at token exchange,
and a `code_challenge` (SHA256 of verifier) sent at authorization. The AS verifies they match.

```
code_verifier  = high-entropy random string (e.g., 64 random bytes, base64url-encoded)
code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
```

At authorization (step 1):
```
GET /oauth2/authorize?...&code_challenge=<challenge>&code_challenge_method=S256
```

At token exchange (step 2):
```
POST /oauth2/token
...&code_verifier=<verifier>
```

The AS computes `SHA256(code_verifier)` and compares with stored `code_challenge`.
Only the legitimate client knows the `code_verifier`.

In Go:
```go
h := sha256.Sum256([]byte(verifier))
challenge := base64.RawURLEncoding.EncodeToString(h[:])
```

WSO2 IS enforces PKCE for public clients by default in IS 7.x. The `S256` method is
required; `plain` is insecure (verifier = challenge, no protection) and disabled in IS 7.x.

### WSO2 IS PKCE enforcement
In `OAuthServerConfiguration`, look for `isForcePKCE()` or `isPKCESupportEnabled()`.
In IS 7.x, PKCE is mandatory for applications configured as "public clients". For
confidential clients (those with a `client_secret`), PKCE is optional but recommended.

### State in the Go lab (Day 3)
The Go server stores issued codes in a `sync.Map` with expiry. On exchange, it removes
the code (single-use) and returns a token. Redirect URI must match exactly.

Each code record contains:
```go
type codeRecord struct {
    ClientID      string
    RedirectURI   string
    Scope         string
    CodeChallenge string    // PKCE: SHA256(code_verifier), base64url
    IssuedAt      time.Time
}
```

Expiry is checked at exchange time: if `time.Since(rec.IssuedAt) > 10*time.Minute`,
return `invalid_grant`.

### Error responses for the authorization endpoint
The authorization endpoint has different error handling than the token endpoint:
- If `redirect_uri` is valid and registered: redirect to `redirect_uri?error=<code>&state=<state>`
- If `redirect_uri` is missing or invalid: return 400 directly (do NOT redirect)

This distinction matters: redirecting with an error to an unknown URI would let attackers
steal error information or mount open-redirect attacks.

## Lab
See `labs/phase1/day03/`. Goal: implement `/oauth2/authorize` (returns a code) and extend
`/oauth2/token` to exchange it. Test the full round-trip with `curl`.
Success signal: code issued → exchanged → token returned; second exchange of the same code
returns `invalid_grant`.

## Exercises
1. Why must the `redirect_uri` in the token exchange match the one in the authorization request?
   **Hint:** RFC 6749 §4.1.3.
   **Solution sketch:** Prevents an attacker from replacing the redirect_uri to steal the code — the AS binds the code to the original URI at issuance.

2. Implement PKCE verification in the Go lab: store `code_challenge` with the code, verify `code_verifier` at exchange.
   **Hint:** `sha256.Sum256([]byte(verifier))` then `base64.RawURLEncoding.EncodeToString(hash[:])`.
   **Solution sketch:** See `labs/phase1/day03/SOLUTION.md` §PKCE.

3. What HTTP status should the `/oauth2/authorize` endpoint return if `response_type` is not `code`?
   **Hint:** RFC 6749 §4.1.2.1 error response for authorization endpoint.
   **Solution sketch:** Redirect to `redirect_uri?error=unsupported_response_type` (if redirect_uri is valid); 400 if redirect_uri is missing or unregistered.

4. Why is authorization code expiry (10 minutes) much shorter than access token expiry (1 hour)?
   **Hint:** Think about what an attacker can do with each artifact.
   **Solution sketch:** The code is transmitted via the browser (in the URL/redirect), making it more exposed. A short window limits the damage if intercepted. The access token is exchanged server-to-server (not via browser redirect), so a longer lifetime is acceptable.

5. In WSO2 IS, where is the authorization code deleted after exchange? What happens to the corresponding row in `IDN_OAUTH2_AUTHORIZATION_CODE`?
   **Hint:** Look for `invalidateAuthorizationCode()` or a state change in `AuthorizationCodeGrantHandler`.
   **Solution sketch:** WSO2 IS changes the `STATE` column to `INACTIVE` (or deletes the row, depending on config). It does not physically delete it immediately — this allows audit logging. A `LoadAndDelete` in Go simulates the logical deletion.

## Anti-patterns / Common mistakes
- Reusing authorization codes — each code is single-use; store and delete on first exchange.
- Not checking `redirect_uri` match — the most common authorization code attack vector.
- Confusing PKCE `code_challenge_method=plain` with `S256` — WSO2 IS requires `S256`; `plain` is insecure.
- Not validating `state` at the client side — if the client does not check that the `state`
  in the redirect matches what it sent, it is vulnerable to CSRF.
- Logging the authorization code — codes are secrets for their short lifetime; treat them
  like passwords in logs.

## Teardown
See `labs/phase1/day03/teardown.md`. Stop the Go process with `Ctrl+C`; no cloud resources.
