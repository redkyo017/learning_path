# Day 21: Full Gateway with JWT Validation Middleware

## Why

Days 19–20 gave you the JWT validation theory and a standalone middleware. Today you wire it
into the complete gateway from Day 18, combining recovery, logging, request ID, and JWT validation
into a single coherent middleware chain.

You'll also add an `/api/info` endpoint that returns the validated claims, proving the JWT
validation middleware actually ran and extracted subscription metadata. This endpoint is used
for diagnostics and end-to-end testing.

---

## WSO2 Source Reading

In WSO2 API Gateway, the JWT validation handler is part of the main handler chain:

```
Incoming Request
    ↓
Handler Chain (in order):
  1. AuthenticationHandler (includes JWT validation)
  2. ThrottleHandler
  3. AuthorizationHandler
  4. APIResourceHandler
```

The gateway does **not** skip downstream handlers if JWT validation fails. Instead, it returns
a structured 401 JSON response immediately, terminating the request before it reaches the backend.

### Fail-Closed vs Fail-Open

**Fail-closed** (WSO2's approach):
- If the JWKS endpoint is unreachable and no cached keys exist, return 401 `jwks_unavailable`.
- The gateway does not allow requests to bypass validation.
- Uptime requirement: the JWKS endpoint must be highly available (ideally on the same network
  as the gateway or cached forever with graceful degradation).

**Fail-open** (anti-pattern):
- If the JWKS endpoint is unreachable, allow the request anyway.
- This is convenient for testing but catastrophic in production if the key server fails.

---

## Core Concepts

### Middleware Chain Order

Execution order (request in):

```
Client Request
    ↓
mux.Handle("/", Chain(proxy, requestIDMiddleware, loggingMiddleware, jwtValidationMiddleware, recoveryMiddleware))
    ↓
requestIDMiddleware     ← assigns X-Request-ID if missing
    ↓
loggingMiddleware       ← records start time
    ↓
jwtValidationMiddleware ← validates JWT, stores claims in context
    ↓
recoveryMiddleware      ← wraps in defer/recover
    ↓
ReverseProxy
    ↓
Backend
```

**Key detail**: Recovery is still last (innermost) so it catches panics in the proxy.
JWT validation runs **before** the proxy, so invalid tokens are rejected before
reaching the backend.

If JWT validation returns 401, the response is sent to the client and the proxy is never called.

### Storing and Retrieving Claims from Context

Inside the middleware, store claims:

```go
type claimsKey struct{}
ctx := context.WithValue(r.Context(), claimsKey{}, claims)
next.ServeHTTP(w, r.WithContext(ctx))
```

In an endpoint handler (or another middleware), retrieve them:

```go
handler := func(w http.ResponseWriter, r *http.Request) {
    claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
    if !ok {
        http.Error(w, `{"error":"claims_missing"}`, http.StatusInternalServerError)
        return
    }
    // Use claims
}
```

### The `/api/info` Endpoint

This endpoint is inside the middleware chain, so JWT validation has already run.
It returns the validated claims as JSON for diagnostics and testing:

```go
mux.Handle("/api/info", Chain(
    http.HandlerFunc(apiInfoHandler),
    jwtValidationMiddleware,
))

func apiInfoHandler(w http.ResponseWriter, r *http.Request) {
    claims, _ := r.Context().Value(claimsKey{}).(*WSO2Claims)
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(claims)
}
```

### End-to-End Testing with Phase 1 Go KM

The Phase 1 learning path includes a Go Key Manager that issues JWTs. You'll run both in parallel:

- Gateway on port `:9090`
- Phase 1 KM (token issuer) on port `:8888`
- Mock backend on port `:8080`

Flow:

```
1. Client calls KM: GET /token?username=user1&appname=app1
   KM returns: {"token": "<JWT>"}

2. Client calls gateway: GET /api/info
   Header: Authorization: Bearer <JWT>
   Gateway validates JWT against KM's JWKS endpoint
   Gateway returns: {"subscriber": "user1", "applicationname": "app1", ...}
```

---

## Lab

See `labs/phase2/day21/` — full gateway with JWT validation integrated.

Run with docker-compose:

```bash
cd labs/phase2/day21
docker-compose up --build

# In another terminal:
# Get a token from KM
TOKEN=$(curl -s http://localhost:8888/token?username=alice | jq -r .token)

# Call the gateway's /api/info endpoint with the token
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info

# Try calling the mock backend through the gateway
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/mock/test

# Try calling with an invalid token (should get 401)
curl -H "Authorization: Bearer invalid" http://localhost:9090/api/info
```

---

## Exercises

**Exercise 1:** Add the JWT validation middleware to the middleware chain from Day 18.
Position it so that invalid tokens are rejected before reaching the proxy.

**Hint:** Place JWT validation between logging and recovery in the chain:
`Chain(proxy, requestIDMiddleware, loggingMiddleware, jwtValidationMiddleware, recoveryMiddleware)`.

**Solution sketch:**

```go
gateway := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    recoveryMiddleware,
)
```

---

**Exercise 2:** Implement an `/api/info` endpoint that returns the validated claims from context.

**Hint:** Use `r.Context().Value(claimsKey{})` to retrieve the claims stored by the JWT
validation middleware. Type-assert to `*WSO2Claims`. Encode as JSON.

**Solution sketch:**

```go
mux.Handle("/api/info", Chain(
    http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
        if !ok {
            http.Error(w, `{"error":"claims_missing"}`, http.StatusInternalServerError)
            return
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(claims)
    }),
    jwtValidationMiddleware(jwksURL),
))
```

---

**Exercise 3:** When the JWKS endpoint is unreachable and the cache is empty, what status code
should the gateway return? Why?

**Hint:** Refer to Day 19's fail-closed semantics. If the gateway cannot fetch or find the `kid`
in the JWKS, it has no public key to validate the token.

**Solution sketch:**

Return `401 Unauthorized` with error `{"error":"jwks_unavailable"}`. The gateway cannot trust
the token without a public key, so it must reject the request. This fail-closed approach
prioritizes security over availability: tokens are not accepted unless the gateway can verify them.

---

## Anti-patterns

- **JWT validation outside the middleware chain** — If you validate JWTs in individual endpoint
  handlers instead of in a middleware, you risk forgetting to validate a new endpoint. Middleware
  ensures all requests (except explicitly excluded ones like `/health`) are validated.

- **Not excluding `/health` from JWT validation** — Health checks should not fail due to auth
  issues. Always exclude `/health` and other diagnostic endpoints from JWT validation.

- **Storing claims in a string key instead of typed key** — Using `context.WithValue(r.Context(),
  "claims", claims)` allows other middleware to accidentally clobber your claims. Use
  `type claimsKey struct{}` to ensure unique, typed keys.

- **Panicking in JWT validation middleware** — If the JWT validation middleware panics (e.g.,
  on a nil pointer), the recovery middleware catches it and returns 500. Validate inputs
  defensively and return proper error responses instead of panicking.

---

## Teardown

Stop docker-compose with `Ctrl+C`. Containers are removed with `docker-compose down`.

