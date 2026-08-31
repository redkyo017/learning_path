# Day 15 Lab — SOLUTION

## Request logging middleware implementation

The Day 15 change is minimal: add `slog.Info("request_received", ...)` as the
first action in every handler, immediately after extracting the correlation ID.

### The pattern (applied to every handler)

```go
func tokenHandler(w http.ResponseWriter, r *http.Request) {
    corrID := correlationFromCtx(r.Context())
    // NEW in Day 15: log every inbound request before any business logic.
    slog.Info("request_received",
        "method", r.Method,
        "path", r.URL.Path,
        "correlation_id", corrID,
    )
    // ... rest of handler unchanged
}
```

### Why at handler entry, not in the middleware?

The middleware runs before routing, so it does not know the handler name.
Logging in each handler gives you the resolved path and lets you attach
business context (e.g. the `client_id` from BasicAuth) in the same log line
for future refinement.

An alternative is to log in the middleware with `r.URL.Path`, but then you lose
the handler name context.  Both approaches are valid; per-handler logging is
more informative for debugging.

### The updated correlationMiddleware (activityid support)

```go
func correlationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Read APIM Gateway's forwarded ID, or generate a new one.
        id := r.Header.Get("activityid")
        if id == "" {
            id = generateID()
        }
        // Echo back so callers can correlate their own logs.
        w.Header().Set("X-Correlation-ID", id)
        ctx := context.WithValue(r.Context(), correlationKey{}, id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

Key change from Day 12: the middleware now reads the `activityid` request header.
When APIM Gateway forwards requests to the KM it sets this header with the same
correlation ID it includes in its own trace logs.  By using that ID here, a single
`grep` finds the request in APIM logs, IS logs, and Go KM logs simultaneously.

### Complete list of handlers with request logging added

All seven handlers in `main.go` have the `slog.Info("request_received", ...)` block:

| Handler | Path |
|---|---|
| `tokenHandler` | `POST /api/am/keymanager/v1/oauth2/token` |
| `introspectHandler` | `POST /api/am/keymanager/v1/oauth2/introspect` |
| `revokeHandler` | `POST /api/am/keymanager/v1/oauth2/revoke` |
| `registerApplicationHandler` | `POST /api/am/keymanager/v1/keymanager/application` |
| `deleteApplicationHandler` | `DELETE /api/am/keymanager/v1/keymanager/application/<id>` |
| `jwksHandler` | `GET /api/am/keymanager/v1/jwks` |
| `healthHandler` | `GET /health` |

### Sample output for a token request

```json
{"time":"2026-08-31T14:30:00.123Z","level":"INFO","msg":"request_received","method":"POST","path":"/api/am/keymanager/v1/oauth2/token","correlation_id":"aB3xQ7mNpL_xyz123"}
{"time":"2026-08-31T14:30:00.131Z","level":"INFO","msg":"token_issued","correlation_id":"aB3xQ7mNpL_xyz123","client_id":"test-client","exp":1756660200}
```

Two lines, same `correlation_id` — the full lifecycle of one token issuance.
