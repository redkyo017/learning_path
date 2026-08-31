# Day 9 Lab — Solution

## Correlation ID middleware (complete implementation)

```go
// correlationKey is an unexported struct used as a context key.
// Using an empty struct type (not a string) makes collisions impossible:
// no imported package can replicate this exact unexported type.
type correlationKey struct{}

func correlationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // generateID uses 16 bytes of crypto/rand, base64url-encoded = 22 chars.
        // This gives 128 bits of randomness — collision probability is negligible
        // even for billions of requests.
        id := generateID()
        ctx := context.WithValue(r.Context(), correlationKey{}, id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func correlationFromCtx(ctx context.Context) string {
    v, _ := ctx.Value(correlationKey{}).(string)
    return v
}
```

## How the middleware is wired

The middleware wraps the entire `http.ServeMux`, so every route automatically gets a correlation ID — including the JWKS endpoint and the protected `/api/hello` route:

```go
mux := http.NewServeMux()
mux.HandleFunc("/oauth2/token", tokenHandler)
// ... other routes ...
handler := correlationMiddleware(mux)
http.ListenAndServe(":9443", handler)
```

## Enabling JSON output

```go
slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
```

This must be called in `main()` before the first handler runs. The `init()` function runs before `main()`, so the RSA key generation message uses the default text handler. After `main()` installs the JSON handler, all subsequent log lines are JSON.

## Complete set of logged events

| msg | Level | When | Fields |
|---|---|---|---|
| `server_starting` | INFO | main() | addr, day |
| `rsa_key_generated` | INFO | init() | kid, note |
| `token_issued` | INFO | successful client_credentials grant | correlation_id, client_id, exp |
| `token_validated` | INFO | authMiddleware accepts JWT | correlation_id, client_id, sub |
| `token_invalid` | WARN | any auth failure | correlation_id, reason |
| `introspect_called` | INFO | introspectHandler completes | correlation_id, caller_client_id, active, sub (if valid), reason (if inactive) |
| `token_revoked` | INFO | revokeHandler stores token | correlation_id, client_id, token_prefix |
| `revoke_called` | INFO | revokeHandler completes | correlation_id, client_id |

## Why `token_prefix` instead of the full token?

A JWT is a credential. Logging the full value would mean the log file is itself a credential store — anyone who reads the logs can replay requests. Logging only the first 8 characters (`safePrefix(token, 8)`) is enough to correlate log lines across issue/revoke/introspect events while not exposing the token itself.

## Querying structured logs with jq

```bash
# All messages in order
jq -r .msg logs.json

# All introspect calls that returned active:false, with reason
jq 'select(.msg == "introspect_called" and .active == false) | {correlation_id, reason}' logs.json

# Reconstruct the lifecycle for a specific token prefix
jq 'select(.token_prefix == "eyJhbGci")' logs.json
```
