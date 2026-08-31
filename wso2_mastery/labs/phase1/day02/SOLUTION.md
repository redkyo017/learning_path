# Day 2 Lab — Solution Notes

## Exercise 1: Reject wrong Content-Type

Add to `tokenHandler` before `r.ParseForm()`:

```go
if ct := r.Header.Get("Content-Type"); ct != "application/x-www-form-urlencoded" {
    oauthError(w, "invalid_request", http.StatusBadRequest)
    return
}
```

Test:
```bash
# No Content-Type — should return 400
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -d "grant_type=client_credentials"
```

## Exercise 2: Token reuse

Before generating a new token, scan `tokenStore` for an existing active token for this client:

```go
var existing string
tokenStore.Range(func(k, v any) bool {
    rec := v.(tokenRecord)
    if rec.ClientID == clientID &&
        time.Since(rec.IssuedAt) < time.Duration(rec.ExpiresIn)*time.Second {
        existing = k.(string)
        return false // stop iteration
    }
    return true // continue
})
if existing != "" {
    w.Header().Set("Content-Type", "application/json")
    w.Header().Set("Cache-Control", "no-store")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "access_token": existing,
        "token_type":   "Bearer",
        "expires_in":   3600,
    })
    return
}
```

This mirrors WSO2 IS's default behavior: `isTokenRenewalPerRequestEnabled() == false`.

## Exercise 3: Token record fields

The minimum fields that mirror `IDN_OAUTH2_ACCESS_TOKEN`:

```go
type tokenRecord struct {
    ClientID  string
    Scope     string
    IssuedAt  time.Time
    ExpiresIn int
    // Optional extensions:
    // UserID    string    // for user-bound grants (auth_code, password)
    // TokenType string    // "Bearer"
    // State     string    // "ACTIVE" | "EXPIRED" | "REVOKED"
}
```

To check expiry:
```go
func (t tokenRecord) IsExpired() bool {
    return time.Since(t.IssuedAt) >= time.Duration(t.ExpiresIn)*time.Second
}
```

## Exercise 4: Base64 encoding without newline

```bash
echo -n 'test-client:test-secret' | base64
# → dGVzdC1jbGllbnQ6dGVzdC1zZWNyZXQ=
```

The `-n` flag suppresses the newline that `echo` appends by default. Without `-n`,
the encoded value changes and the server returns `invalid_client`.

## Exercise 5: Cache-Control ignored by client

If a client caches the token for 1 hour and the token is revoked at minute 30:
- Minutes 0–30: client sends cached token → gateway accepts it (token still active in IS).
- Minute 30: token revoked in IS (e.g., admin revocation or logout).
- Minutes 30–60: client sends cached token → gateway rejects with 401 (token revoked in IS).
- The client gets a 401 and must handle it — ideally by requesting a new token.
- If the client doesn't handle 401 → retry loop: request fails for the rest of the hour.

Fix: always re-request a token on 401; never cache tokens for longer than `expires_in`.
