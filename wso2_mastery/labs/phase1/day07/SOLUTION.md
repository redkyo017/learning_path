# Day 7 Lab — Solution

## Core implementation: `introspectHandler`

The introspect endpoint has three distinct outcomes:

1. **Caller not authenticated** → `401 Unauthorized` with `WWW-Authenticate` header.
2. **Token invalid (bad signature, expired, malformed)** → `{"active": false}`.
3. **Token revoked (found in `revokedTokens`)** → `{"active": false}`.
4. **Token valid and not revoked** → full RFC 7662 response body with `"active": true`.

```go
func introspectHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }

    // Step 1: authenticate the introspection caller (RFC 7662 §2.1).
    clientID, clientSecret, ok := r.BasicAuth()
    if !ok || !validateClient(clientID, clientSecret) {
        w.Header().Set("WWW-Authenticate", `Basic realm="introspection"`)
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }

    r.ParseForm()
    tokenStr := r.FormValue("token")

    w.Header().Set("Content-Type", "application/json")

    // Step 2: validate JWT signature + expiry.
    claims, err := validateJWT(tokenStr)
    if err != nil {
        json.NewEncoder(w).Encode(map[string]any{"active": false})
        return
    }

    // Step 3: check the server-side revocation map.
    if _, revoked := revokedTokens.Load(tokenStr); revoked {
        json.NewEncoder(w).Encode(map[string]any{"active": false})
        return
    }

    // Step 4: token is valid and not revoked.
    json.NewEncoder(w).Encode(map[string]any{
        "active":     true,
        "sub":        claims.Subject,
        "exp":        claims.ExpiresAt.Unix(),
        "iat":        claims.IssuedAt.Unix(),
        "iss":        claims.Issuer,
        "client_id":  claims.Subscriber,
        "token_type": "Bearer",
        "http://wso2.org/claims/applicationname": claims.ApplicationName,
        "http://wso2.org/claims/keytype":          claims.KeyType,
    })
}
```

## Key design decisions

### Why authenticate the introspect caller?

Without authentication, any HTTP client can submit arbitrary strings and learn which ones are valid tokens — a token enumeration (oracle) attack. RFC 7662 §2.1 requires the endpoint to be protected.

### Why `active:false` for revoked tokens too?

RFC 7662 §2.2: the response when `active` is `false` must not include any other claims. Returning different bodies for "expired" vs "revoked" vs "malformed" would let an attacker infer the reason from the response shape.

### Why `sync.Map` for `revokedTokens`?

HTTP handlers run in separate goroutines (one per request). A plain `map[string]any` is not safe for concurrent reads and writes. `sync.Map` provides concurrent-safe `Load` and `Store` operations without needing an explicit mutex in simple cases.

## Full round-trip commands

```bash
# Start server
go run main.go &

# Issue
TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret -d grant_type=client_credentials | jq -r .access_token)

# Introspect — active:true
curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret -d "token=$TOKEN" | jq .active

# Stop server
kill %1
```
