# Day 5 Solution — Complete tokenHandler → issueJWT Wiring

## Overview

The call chain is:

```
POST /oauth2/token
  → tokenHandler (route on grant_type)
    → handleClientCredentials (validate Basic Auth)
      → issueJWT(clientID, scope, "DefaultApp")
        → WSO2Claims{...}
        → jwt.NewWithClaims(RS256, claims)
        → token.Header["kid"] = keyID
        → token.SignedString(signingKey)
          → returns "header.payload.signature" string
      → JSON response with access_token
```

## Complete tokenHandler

```go
func tokenHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    if err := r.ParseForm(); err != nil {
        oauthError(w, "invalid_request", http.StatusBadRequest)
        return
    }
    switch r.FormValue("grant_type") {
    case "client_credentials":
        handleClientCredentials(w, r)
    default:
        oauthError(w, "unsupported_grant_type", http.StatusBadRequest)
    }
}
```

## Complete handleClientCredentials

```go
func handleClientCredentials(w http.ResponseWriter, r *http.Request) {
    clientID, clientSecret, ok := r.BasicAuth()
    if !ok {
        clientID = r.FormValue("client_id")
        clientSecret = r.FormValue("client_secret")
    }
    if !validateClient(clientID, clientSecret) {
        oauthError(w, "invalid_client", http.StatusUnauthorized)
        return
    }
    scope := r.FormValue("scope")
    tokenStr, err := issueJWT(clientID, scope, "DefaultApp")
    if err != nil {
        log.Printf("issueJWT error: %v", err)
        oauthError(w, "server_error", http.StatusInternalServerError)
        return
    }
    w.Header().Set("Content-Type", "application/json")
    w.Header().Set("Cache-Control", "no-store")
    json.NewEncoder(w).Encode(map[string]any{
        "access_token": tokenStr,
        "token_type":   "Bearer",
        "expires_in":   3600,
        "scope":        scope,
    })
}
```

## Complete issueJWT

```go
func issueJWT(clientID, scope, appName string) (string, error) {
    now := time.Now()
    claims := WSO2Claims{
        RegisteredClaims: jwt.RegisteredClaims{
            Issuer:    "https://localhost:9443/oauth2/token",
            Subject:   clientID,
            IssuedAt:  jwt.NewNumericDate(now),
            ExpiresAt: jwt.NewNumericDate(now.Add(3600 * time.Second)),
            ID:        generateID(),
        },
        Subscriber:      clientID,
        ApplicationName: appName,
        ApplicationTier: "Unlimited",
        APIVersion:      "v1",
        KeyType:         "PRODUCTION",
    }
    token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
    token.Header["kid"] = keyID  // ← CRITICAL: must be before SignedString
    return token.SignedString(signingKey)
}
```

## Key decisions explained

**Why embed `jwt.RegisteredClaims` rather than use `jwt.MapClaims`?**
`jwt.RegisteredClaims` is a typed struct. `ParseWithClaims` can populate it automatically
and performs `exp` / `nbf` / `iss` validation without extra code. `jwt.MapClaims` requires
you to cast every value manually and re-implement time comparisons.

**Why set `token.Header["kid"]` explicitly?**
`jwt.NewWithClaims` creates a default header with only `{"alg":"RS256","typ":"JWT"}`.
The `kid` is not set by the library — you must add it yourself before signing. Once
`SignedString` is called, the header is serialised and included in the signature — you
cannot change it afterwards.

**Why `base64.RawURLEncoding` for the JWKS `n` and `e` values?**
The JWK specification (RFC 7517) requires Base64URL encoding *without* padding characters.
`base64.RawURLEncoding` produces exactly this format. Using `base64.URLEncoding` (which
adds `=` padding) would produce an invalid JWK that many parsers reject.

**Why `big.NewInt(int64(pub.E)).Bytes()`?**
`pub.E` is an `int` in Go. To encode it as a big-endian byte sequence, convert it to
`*big.Int` first (which has a `Bytes()` method that returns a minimal big-endian encoding
with no leading zero bytes). This is what the JWK spec expects for the `e` parameter.
