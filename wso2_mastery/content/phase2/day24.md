# Day 24: Full Gateway — JWT Validation + Subscription Enforcement

## Why

Today you combine everything from Days 21–23:

1. **JWT validation** (Day 21) — extracts and verifies the JWT token, stores claims in context.
2. **Subscription store** (Day 22–23) — in-memory map of subscriptions, keyed by appName + apiName.
3. **Subscription middleware** (Day 23) — checks if the JWT's application is subscribed to the requested API.

The result is a production-like gateway that enforces both authentication (is the token valid?)
and authorization (is the application subscribed to this API?).

---

## WSO2 Source Reading

In WSO2 API Manager, the full request flow is:

```
Incoming Request
    ↓
Validate JWT (signature, expiry, claims)
    ↓ (valid)
Extract claims (applicationname, subscriber, etc.)
    ↓
Check subscription: is applicationname::apiName in the subscription store?
    ↓ (found)
Check throttle policy (see Task 4)
    ↓ (not throttled)
Forward to backend
    ↓
Backend responds
    ↓
Return to client
```

If any step fails:
- **JWT invalid** → 401 Unauthorized
- **JWT missing** → 401 Unauthorized
- **Subscription not found** → 403 Forbidden (this is the new step)
- **Throttle limit exceeded** → 429 Too Many Requests (Task 4)

### WSO2's 403 Response for Missing Subscription

When a request has a valid JWT but the application is not subscribed, WSO2 returns:

```
HTTP 403 Forbidden
Content-Type: application/json
{
  "code": "900908",
  "message": "Resource forbidden"
}
```

The error code `900908` is standardized by WSO2 to mean "application not subscribed".

---

## Core Concepts

### Middleware Chain Order (JWT Validation + Subscription Check)

The order matters:

```
Client Request
    ↓
Incoming Request Handler (mux)
    ↓
Request ID Middleware          ← assign request ID
    ↓
Logging Middleware             ← start timer
    ↓
JWT Validation Middleware      ← validate token, store claims in context
    ↓
Subscription Middleware        ← check if app is subscribed (uses claims from context)
    ↓
Recovery Middleware            ← defer recover
    ↓
Reverse Proxy                  ← forward to backend
    ↓
Backend
```

**Why subscription after JWT?** Because the subscription check needs the claims extracted by
the JWT middleware. If you put subscription before JWT, there's no claims to check.

**Why recovery last?** So it catches panics in the proxy layer.

### Subscription Middleware Factory

The subscription middleware is created with the API name it should check:

```go
// Create middleware for the "myapi" API
apiMiddleware := subscriptionMiddleware("myapi")

// Apply to a route
mux.Handle("/api/myapi", Chain(
    http.HandlerFunc(handler),
    subscriptionMiddleware("myapi"),
    jwtValidationMiddleware(jwksURL),
))
```

If multiple APIs share the same gateway, each route uses its own subscription middleware
instance with the correct API name.

### Admin Endpoint for Subscription Management

The gateway exposes `/admin/subscriptions` (POST) and optionally DELETE to manage subscriptions
at runtime. This simulates the CP pushing subscription data to the gateway:

```bash
# Add subscription
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"myapi","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# Result: app1 is now subscribed to myapi. Requests from app1 with a valid JWT will pass subscription check.
```

### Subscription Tier → Throttle Policy (Preview for Task 4)

The subscription record includes `subscriptionTier` (e.g., "gold", "silver", "bronze").
This tier maps to a throttle policy:

- **gold** → 1000 req/min
- **silver** → 100 req/min
- **bronze** → 10 req/min

Task 4 will implement the throttle middleware, which uses this tier from the subscription record.

---

## Lab

See `labs/phase2/day24/main.go` — complete gateway with JWT validation + subscription enforcement.

### Features

- `/health` — no auth required
- `/admin/subscriptions` POST — add subscriptions
- `/api/hello` — protected by JWT validation + subscription check
- `/api/info` — returns validated claims (diagnostics)

### Running the Lab

```bash
cd labs/phase2/day24
docker-compose up --build

# In another terminal:

# 1. Add a subscription for app1
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"hello",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'

# 2. Get a token for app1 (from the Phase 1 KM on port 8888)
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# 3. Call the API (should succeed)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
# Expected: mock backend response

# 4. Try with an app that has no subscription
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)
curl -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello
# Expected: 403 {"code":"900908","message":"Resource forbidden"}

# 5. Check the validated claims
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
# Expected: JSON with JWT claims (applicationname, subscriber, etc.)
```

---

## Exercises

**Exercise 1:** What is the order of middleware execution for a protected route in the gateway?
Draw or describe the chain.

**Hint:** Refer to the middleware chain diagram above. JWT validation must run before subscription
checks. Recovery must run last (innermost) to catch panics.

**Solution sketch:**

```
Request ID → Logging → JWT Validation → Subscription Check → Recovery → Proxy → Backend

Reversed (innermost to outermost when building the chain):
Chain(proxy, requestIDMiddleware, loggingMiddleware, jwtValidationMiddleware, subscriptionMiddleware, recoveryMiddleware)
```

---

**Exercise 2:** If a request has a valid JWT but the application is not in the subscription store,
what HTTP status and response should the gateway return? Why?

**Hint:** The application is authenticated (JWT is valid) but not authorized (no subscription).
Use the 403 Forbidden status and the WSO2-standard error response.

**Solution sketch:**

```
HTTP 403 Forbidden
Content-Type: application/json
{
  "code": "900908",
  "message": "Resource forbidden"
}
```

The 403 status indicates the request is understood but not permitted due to authorization failure
(no subscription). The standard error code `900908` allows clients to distinguish between
"no subscription" (403) and "token invalid" (401).

---

**Exercise 3:** How would you add a DELETE endpoint to remove subscriptions? What would happen if
a client tried to use an API after their subscription was deleted (while they still have a cached token)?

**Hint:** Create a DELETE endpoint that takes query parameters for appName and apiName. When
a subscription is deleted, subsequent requests from that app will fail at the subscription check,
even if they have a previously-issued token.

**Solution sketch:**

```go
mux.HandleFunc("DELETE /admin/subscriptions", func(w http.ResponseWriter, r *http.Request) {
    appName := r.URL.Query().Get("appname")
    apiName := r.URL.Query().Get("apiname")
    if appName == "" || apiName == "" {
        http.Error(w, `{"error":"missing_params"}`, http.StatusBadRequest)
        return
    }
    key := appName + "::" + apiName
    subscriptionStore.Delete(key)
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"status":"subscription_removed"}`)
})
```

After deletion, if a client tries to use their cached token:
1. JWT validation passes (token is still valid, expiry hasn't reached).
2. Subscription check fails (subscription was deleted from the store).
3. Gateway returns 403 Forbidden.

This immediate revocation is possible because subscriptions are cached locally; there's no
re-validation against a remote service.

---

## Anti-patterns

- **Subscription checks only on certain routes** — If you protect `/api/myapi` but leave `/api/other`
  unprotected, clients can bypass authorization by calling the unprotected endpoint. Middleware
  ensures all routes are protected consistently.

- **Storing JWT token validation result in the subscription store** — Don't cache JWT validation
  results with subscriptions. The JWT middleware runs on every request; don't try to skip it
  for repeat clients.

- **Ignoring subscription tier** — The subscription record includes a tier (gold, silver, bronze),
  which maps to throttle limits. Ignoring it means all apps get unlimited throughput. Task 4
  implements the throttle middleware to enforce tier-based limits.

- **Removing subscriptions without audit logging** — When a subscription is deleted, there's no way
  to audit who deleted it or when. Always log admin endpoint calls.

---

## Teardown

Stop docker-compose with `Ctrl+C`.

