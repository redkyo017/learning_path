# Day 8 Lab — Solution

## Core implementation: `revokeHandler`

```go
func revokeHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    // Authenticate the requesting client.
    // RFC 7009 §2.1: the client MUST authenticate itself to the revocation endpoint.
    clientID, clientSecret, ok := r.BasicAuth()
    if !ok || !validateClient(clientID, clientSecret) {
        oauthError(w, "invalid_client", http.StatusUnauthorized)
        return
    }

    r.ParseForm()
    token := r.FormValue("token")

    if token != "" {
        revokedTokens.Store(token, time.Now())
        log.Printf("token_revoked client_id=%s token_prefix=%s",
            clientID, safePrefix(token, 8))
    }

    // RFC 7009 §2.2: always return 200 OK.
    // Do NOT return 404 for unknown tokens — that leaks token existence.
    w.WriteHeader(http.StatusOK)
}
```

## Why `revokedTokens.Store` for unknown tokens?

If a client submits a random string as a token, storing it in `revokedTokens` has no functional effect — `validateJWT` will reject it before the revocation check is reached. The only consequence is a small amount of memory used. The behaviour is correct: the 200 response is indistinguishable from a successful revocation.

## The introspect–revoke interaction

`introspectHandler` checks `revokedTokens` after successful JWT validation:

```go
claims, err := validateJWT(tokenStr)
if err != nil {
    json.NewEncoder(w).Encode(map[string]any{"active": false})
    return
}

// JWT is cryptographically valid and not expired — but may still be revoked.
if _, revoked := revokedTokens.Load(tokenStr); revoked {
    json.NewEncoder(w).Encode(map[string]any{"active": false})
    return
}
```

The order matters: `validateJWT` first (cheap — no map lookup), then `revokedTokens` (covers explicitly cancelled tokens).

## Complete lifecycle walkthrough

```
curl POST /oauth2/token      → JWT issued, stored nowhere server-side
curl POST /oauth2/introspect → validateJWT OK, revokedTokens miss → active:true
curl POST /oauth2/revoke     → revokedTokens.Store(jwt, now) → 200
curl POST /oauth2/introspect → validateJWT OK, revokedTokens hit → active:false
```

The JWT's signature is still valid after revocation — only the server-side map makes it inactive. This is the mechanism that bridges the JWT revocation gap for in-process validation.

## safePrefix helper

```go
func safePrefix(s string, n int) string {
    if len(s) <= n {
        return s
    }
    return s[:n]
}
```

Logs only the first 8 characters of the token string. This is enough to correlate log lines across issue/revoke/introspect events without logging the full token value (which is a credential).
