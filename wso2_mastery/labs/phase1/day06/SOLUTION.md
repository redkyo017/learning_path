# Day 6 Solution — Context Key Type + Full authMiddleware

## Context key type definition

The critical pattern here is using a *private named type* as the context key, not a bare
`string`. This prevents key collisions between packages:

```go
// contextKey is a private type — its zero value cannot be constructed outside this package.
type contextKey string

// claimsContextKey is the actual key value.
// Because contextKey is not string, context.Value(claimsContextKey) will NOT match
// context.Value("wso2claims") — even though the underlying string content is the same.
const claimsContextKey contextKey = "wso2claims"
```

If you used `context.WithValue(ctx, "wso2claims", claims)` (a bare string), and another
package in your gateway binary also used `context.WithValue(ctx, "wso2claims", something)`,
they would collide and overwrite each other's values. The typed key prevents this silently.

## Full authMiddleware

```go
func authMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        authHeader := r.Header.Get("Authorization")
        if !strings.HasPrefix(authHeader, "Bearer ") {
            w.Header().Set("Content-Type", "application/json")
            w.WriteHeader(http.StatusUnauthorized)
            json.NewEncoder(w).Encode(map[string]string{"error": "missing_token"})
            return
        }
        bearer := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))

        claims, err := validateJWT(bearer)
        if err != nil {
            log.Printf("JWT validation failed: %v", err)
            w.Header().Set("Content-Type", "application/json")
            w.WriteHeader(http.StatusUnauthorized)
            json.NewEncoder(w).Encode(map[string]string{"error": "invalid_token"})
            return
        }

        ctx := context.WithValue(r.Context(), claimsContextKey, claims)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

## Full validateJWT

```go
func validateJWT(tokenStr string) (*WSO2Claims, error) {
    token, err := jwt.ParseWithClaims(
        tokenStr,
        &WSO2Claims{},
        func(t *jwt.Token) (any, error) {
            if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
            }
            return &signingKey.PublicKey, nil
        },
    )
    if err != nil {
        return nil, err
    }
    claims, ok := token.Claims.(*WSO2Claims)
    if !ok || !token.Valid {
        return nil, fmt.Errorf("invalid token claims")
    }
    return claims, nil
}
```

## Wiring the middleware in main()

```go
func main() {
    // Public endpoints — no auth required
    http.HandleFunc("/oauth2/token", tokenHandler)
    http.HandleFunc("/oauth2/jwks", jwksHandler)

    // Protected endpoint — wrapped with authMiddleware
    // http.Handle (not HandleFunc) because authMiddleware returns http.Handler
    http.Handle("/api/hello", authMiddleware(http.HandlerFunc(helloHandler)))

    log.Fatal(http.ListenAndServe(":9443", nil))
}
```

Note `http.Handle` vs `http.HandleFunc`: `http.Handle` accepts an `http.Handler` (the type
returned by `authMiddleware`); `http.HandleFunc` accepts a `func(http.ResponseWriter, *http.Request)`.

## Reading claims in the protected handler

```go
func helloHandler(w http.ResponseWriter, r *http.Request) {
    // claimsFromContext uses the same typed key — must match authMiddleware exactly
    claims := claimsFromContext(r.Context())
    if claims == nil {
        http.Error(w, "no claims in context", http.StatusInternalServerError)
        return
    }
    // Use claims.Subject, claims.ApplicationName, etc.
}

func claimsFromContext(ctx context.Context) *WSO2Claims {
    v := ctx.Value(claimsContextKey)   // ← typed key, not "wso2claims"
    if v == nil {
        return nil
    }
    c, _ := v.(*WSO2Claims)
    return c
}
```

## Why double-check `token.Valid`?

`jwt.ParseWithClaims` can return a partially-populated token even when `err != nil` (for
example, with an expired token, the claims are populated but an error is also returned so
you can inspect them). Checking both `err == nil` AND `token.Valid` guards against using
claims from a token that failed validation in any way.
