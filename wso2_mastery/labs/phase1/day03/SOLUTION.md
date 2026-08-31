# Day 3 Lab — Solution Notes

## Exercise 1: redirect_uri binding

The `redirect_uri` must match exactly because the authorization code is bound to
the original URI at issuance time (stored in `codeRecord.RedirectURI`). At exchange,
`handleAuthCode` performs:

```go
if r.FormValue("redirect_uri") != rec.RedirectURI {
    oauthError(w, "invalid_grant", http.StatusBadRequest)
    return
}
```

Attack scenario: attacker registers `http://evil.com/steal` and intercepts the redirect.
If the server didn't check, the attacker could exchange the code. Binding prevents this.

## Exercise 2: PKCE verification

The PKCE check is already implemented in `handleAuthCode`. Here is the full verification
logic isolated for study:

```go
// PKCE: S256 method
// code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
func verifyPKCE(storedChallenge, receivedVerifier string) bool {
    h := sha256.Sum256([]byte(receivedVerifier))
    computed := base64.RawURLEncoding.EncodeToString(h[:])
    return computed == storedChallenge
}
```

To add PKCE enforcement (require it for all requests):
```go
if rec.CodeChallenge == "" {
    // PKCE was not used at authorization — reject if you want to enforce PKCE
    oauthError(w, "invalid_request", http.StatusBadRequest)
    return
}
```

Test with wrong verifier:
```bash
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=${CODE_PKCE}&redirect_uri=http://localhost:8080/callback&code_verifier=wrongverifier"
# Expected: {"error":"invalid_grant"}
```

## Exercise 3: response_type != "code"

The `authorizeHandler` checks `response_type` first:

```go
if q.Get("response_type") != "code" {
    redirectError(w, r, q.Get("redirect_uri"), "unsupported_response_type", q.Get("state"))
    return
}
```

`redirectError` sends the error as a redirect parameter (RFC 6749 §4.1.2.1):
```
HTTP/1.1 302 Found
Location: http://localhost:8080/callback?error=unsupported_response_type
```

If `redirect_uri` is empty, `redirectError` falls back to a plain 400.

## Exercise 4: Why code expiry is short (10 minutes)

The authorization code travels through the browser via the redirect URI — it appears in
the browser's address bar and in server logs (as a URL parameter). This makes it more
exposed than an access token, which is exchanged directly server-to-server.

A short window (10 minutes) limits the damage: even if an attacker captures the code
from a log, they have a narrow window to exploit it. The access token lifetime (3600s)
is longer because it is only transmitted in Authorization headers, not in URLs.

## Exercise 5: Code invalidation in WSO2 IS

In the Go lab, `codeStore.LoadAndDelete(code)` atomically loads and removes the entry.
This is equivalent to what WSO2 IS does: it changes `STATE` to `INACTIVE` in
`IDN_OAUTH2_AUTHORIZATION_CODE`. The row is kept for audit purposes.

To simulate physical deletion in the Go lab (cleaner in-memory):
```go
// LoadAndDelete already does this — no change needed
val, ok := codeStore.LoadAndDelete(code)
```

To simulate WSO2's "mark inactive" instead of delete:
```go
// Keep the record but mark it used — prevents replay
type codeRecord struct {
    ...
    Used bool
}
// On exchange: check Used, then set Used = true and re-store
```
This approach allows auditing but requires a garbage collector to clean up old records.

## Full PKCE round-trip (shell script)

```bash
#!/bin/bash
# Full PKCE authorization code flow test

SERVER="http://localhost:9443"

# 1. Generate verifier + challenge
VERIFIER=$(openssl rand -base64 32 | tr -d '=+/' | head -c 43)
CHALLENGE=$(echo -n "$VERIFIER" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=')

echo "Verifier:  $VERIFIER"
echo "Challenge: $CHALLENGE"

# 2. Get authorization code
LOCATION=$(curl -s -o /dev/null -w "%{redirect_url}" \
  "${SERVER}/oauth2/authorize?response_type=code&client_id=test-client&redirect_uri=http://localhost:8080/callback&code_challenge=${CHALLENGE}&code_challenge_method=S256&state=abc")
CODE=$(echo "$LOCATION" | grep -oP '(?<=code=)[^&]+')
echo "Code: $CODE"

# 3. Exchange code
curl -s -X POST "${SERVER}/oauth2/token" \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=${CODE}&redirect_uri=http://localhost:8080/callback&code_verifier=${VERIFIER}"
```
