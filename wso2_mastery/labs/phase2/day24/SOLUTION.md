# Solution: Day 24 — Full Gateway with JWT Validation + Subscription Enforcement

## Complete Working Code

The `main.go` file in this directory is a complete, production-ready gateway implementation that combines:
1. JWT validation middleware (from Day 21)
2. Subscription store and middleware (from Day 23)
3. Admin endpoints for subscription management
4. Proper error handling with WSO2-standard error codes

## Architecture Summary

### Request Flow for Protected Routes

```
Client Request → Request ID → Logging → JWT Validation → Subscription Check → Recovery → Proxy → Backend
```

Each middleware stage:
1. **Request ID Middleware** — Assigns X-Request-ID if missing
2. **Logging Middleware** — Records request timing
3. **JWT Validation** — Validates token, extracts claims into context (401 on failure)
4. **Subscription Check** — Verifies application has subscription to the API (403 on failure)
5. **Recovery Middleware** — Catches panics from the proxy layer
6. **Proxy** — Forwards to mock backend

### Endpoint Summary

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| /health | GET | No | Health check |
| /api/info | GET | JWT only | Returns validated claims (diagnostics) |
| /api/hello | GET | JWT + Subscription | Protected API route |
| /admin/subscriptions | POST | No | Add subscription |
| /admin/subscriptions | DELETE | No | Remove subscription |

---

## Key Implementation Details

### WSO2Claims Type

```go
type WSO2Claims struct {
    jwt.RegisteredClaims
    Subscriber      string `json:"http://wso2.org/claims/subscriber"`
    ApplicationName string `json:"http://wso2.org/claims/applicationname"`
    ApplicationTier string `json:"http://wso2.org/claims/applicationtier"`
    APIVersion      string `json:"http://wso2.org/claims/version"`
    KeyType         string `json:"http://wso2.org/claims/keytype"`
}
```

The `ApplicationName` claim is crucial — it's used to construct the subscription key:
```
subscriptionKey = claims.ApplicationName + "::" + apiName
```

### JWT Validation Middleware

The middleware follows the two-stage validation approach from Day 20:

1. **First attempt** — Parse and validate with potentially-cached public key
2. **Retry on failure** — Re-fetch public key in case of key rotation
3. **Cache for performance** — Store public keys in `sync.Map` keyed by `kid`

This ensures graceful handling of key rotation without adding significant latency.

### Subscription Middleware

```go
func subscriptionMiddleware(apiName string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Step 1: Get claims from context
            claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
            if !ok || claims == nil {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            // Step 2: Construct key
            key := claims.ApplicationName + "::" + apiName
            // Step 3: Check subscription
            if _, found := subscriptionStore.Load(key); !found {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            // Step 4: Proceed
            next.ServeHTTP(w, r)
        })
    }
}
```

**Critical design choice:** The middleware checks for the absence of claims and returns 403 (not 500).
Why? Because if JWT middleware ran but didn't set claims, it's a programming error in the middleware chain,
and returning 403 "Resource forbidden" is more graceful than 500 "Internal Server Error".

### Error Responses

```go
// Missing token
401 Unauthorized: {"error":"missing_token"}

// Invalid token
401 Unauthorized: {"error":"invalid_token"}

// JWKS unavailable
401 Unauthorized: {"error":"jwks_unavailable"}

// Subscription not found
403 Forbidden: {"code":"900908","message":"Resource forbidden"}

// Internal error
500 Internal Server Error: {"error":"internal_server_error"}
```

The error code `900908` is standardized by WSO2 to distinguish subscription authorization failures
from other types of errors. Clients can parse this code to determine the specific authorization issue.

### Admin Endpoints

```go
func handleSubscriptions(w http.ResponseWriter, r *http.Request) {
    if r.Method == "POST" {
        addSubscriptionHandler(w, r)
    } else if r.Method == "DELETE" {
        deleteSubscriptionHandler(w, r)
    } else {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
    }
}
```

These endpoints are **outside the middleware chain** because:
1. They're for administrative operations, not client API requests
2. They should not require JWT validation (or should have their own auth mechanism)
3. They manage the subscription store directly, bypassing the proxy

---

## Testing Walkthrough

### Test 1: Complete Happy Path

**Setup:** Add subscription, get token, call API successfully.

```bash
# 1. Add subscription
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# 2. Get token for app1
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# 3. Call protected API
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

**Expected flow:**
1. Request arrives at gateway
2. Request ID middleware assigns X-Request-ID
3. Logging middleware starts timer
4. JWT validation middleware validates token, extracts claims with `applicationname: "app1"`
5. Subscription middleware constructs key "app1::hello", finds it in store ✓
6. Request forwarded to backend
7. Backend returns mock response

**Response:** Mock backend JSON response (success)

### Test 2: Authorization Failure (No Subscription)

**Setup:** Get token for app that has no subscription.

```bash
# Get token for app2 (never added subscription)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Call protected API
curl -v -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello
```

**Expected flow:**
1. Request arrives at gateway
2. Request ID middleware assigns X-Request-ID
3. Logging middleware starts timer
4. JWT validation middleware validates token, extracts claims with `applicationname: "app2"` ✓
5. Subscription middleware constructs key "app2::hello", does NOT find it in store ✗
6. Returns 403 immediately; backend is never called

**Response:**
```
HTTP 403 Forbidden
Content-Type: application/json
{"code":"900908","message":"Resource forbidden"}
```

### Test 3: Authentication Failure (Invalid Token)

```bash
curl -v -H "Authorization: Bearer invalid" http://localhost:9090/api/hello
```

**Expected flow:**
1. Request arrives at gateway
2. Request ID middleware assigns X-Request-ID
3. Logging middleware starts timer
4. JWT validation middleware tries to parse "invalid" as JWT ✗
5. Returns 401 immediately; subsequent middleware is never called

**Response:**
```
HTTP 401 Unauthorized
{"error":"invalid_token"}
```

### Test 4: Missing Authorization Header

```bash
curl -v http://localhost:9090/api/hello
```

**Expected flow:**
1. Request arrives at gateway (no Authorization header)
2. Request ID middleware assigns X-Request-ID
3. Logging middleware starts timer
4. JWT validation middleware checks for Authorization header ✗
5. Returns 401 immediately

**Response:**
```
HTTP 401 Unauthorized
{"error":"missing_token"}
```

### Test 5: Subscription Revocation

Demonstrates that subscriptions are checked on every request (not cached).

```bash
# 1. Verify subscription works
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
# Returns: Mock backend response ✓

# 2. Delete subscription
curl -X DELETE "http://localhost:9090/admin/subscriptions?appname=app1&apiname=hello"

# 3. Try calling API again (same token, still valid)
curl -v -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
# Returns: 403 Forbidden (subscription is gone) ✗
```

**Why this works:** The JWT token is still valid (signature is still good, expiry hasn't passed).
But the subscription store no longer has the "app1::hello" entry, so the subscription middleware
rejects the request with 403.

---

## Exercise Solutions

### Exercise 1: List Subscriptions (GET /admin/subscriptions)

```go
func listSubscriptionsHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "GET" {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
        return
    }
    var subs []SubscriptionRecord
    subscriptionStore.Range(func(key, value interface{}) bool {
        if rec, ok := value.(*SubscriptionRecord); ok {
            subs = append(subs, *rec)
        }
        return true  // continue iterating
    })
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "subscriptions": subs,
        "count":         len(subs),
    })
}

// Update handler:
func handleSubscriptions(w http.ResponseWriter, r *http.Request) {
    if r.Method == "POST" {
        addSubscriptionHandler(w, r)
    } else if r.Method == "DELETE" {
        deleteSubscriptionHandler(w, r)
    } else if r.Method == "GET" {
        listSubscriptionsHandler(w, r)
    } else {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
    }
}
```

**Test:**
```bash
curl http://localhost:9090/admin/subscriptions | jq
# Response:
{
  "subscriptions": [
    {
      "applicationname": "app1",
      "apiname": "hello",
      "subscriptiontier": "gold",
      "keytype": "PRODUCTION"
    }
  ],
  "count": 1
}
```

---

### Exercise 2: Multiple Protected APIs

```go
// Create separate middleware chains for each API
helloMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("hello"),
    recoveryMiddleware,
)

usersMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("users"),
    recoveryMiddleware,
)

mux.Handle("/api/hello", helloMiddleware)
mux.Handle("/api/users", usersMiddleware)
```

**Test:**
```bash
# Add subscriptions for both APIs
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}'

curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"users","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# Both APIs should work
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello  # ✓
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/users  # ✓
```

The key insight: Each API has its own subscription key ("app1::hello" vs "app1::users").
An application must be subscribed to each API independently.

---

### Exercise 3: Subscription Expiration

Add expiration check to the subscription middleware:

```go
type SubscriptionRecord struct {
    ApplicationName  string    `json:"applicationname"`
    APIName          string    `json:"apiname"`
    SubscriptionTier string    `json:"subscriptiontier"`
    KeyType          string    `json:"keytype"`
    ExpiresAt        time.Time `json:"expiresat"`  // New field
}

func subscriptionMiddleware(apiName string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
            if !ok || claims == nil {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            key := claims.ApplicationName + "::" + apiName
            val, found := subscriptionStore.Load(key)
            if !found {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            rec := val.(*SubscriptionRecord)
            // NEW: Check expiration
            if time.Now().After(rec.ExpiresAt) {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}
```

**Test:**
```bash
# Add subscription with expiration 1 hour from now
expiresAt := time.Now().Add(1 * time.Hour).Format(time.RFC3339)
curl -X POST http://localhost:9090/admin/subscriptions \
  -d "{\"applicationname\":\"app1\",\"apiname\":\"hello\",\"subscriptiontier\":\"gold\",\"keytype\":\"PRODUCTION\",\"expiresat\":\"$expiresAt\"}"

# API calls work (subscription is not yet expired)
# After the expiration time, calls will get 403
```

---

## Key Design Decisions

### 1. Fail-Closed Strategy

Both authentication and authorization are fail-closed:
- **Authentication:** If JWT validation fails for any reason, return 401 (don't allow unvalidated tokens).
- **Authorization:** If subscription is not found, return 403 (don't allow unsubscribed requests).

This is safer than fail-open (allowing requests on errors), at the cost of availability during outages.

### 2. sync.Map for Subscriptions

The subscription store uses `sync.Map` because:
- **Read-heavy:** Every request queries it; subscriptions are rarely updated.
- **No lock contention:** Concurrent reads don't block each other.
- **Simple semantics:** No manual locking required.

### 3. Middleware Chain Order

JWT validation **must** run before subscription checks because:
- Subscription checks depend on claims extracted by JWT middleware.
- If subscription checks ran first, they couldn't access claims.

Recovery middleware **must** run last (innermost) because:
- It defers a recover() to catch panics in the proxy layer.
- If recovery were first, panics in JWT middleware wouldn't be caught.

### 4. Admin Endpoints Outside Middleware

The `/admin/subscriptions` endpoints are **not** protected by the gateway middleware because:
- They're administrative operations, not client API calls.
- Protecting them would create a bootstrap problem (can't add subscriptions if API requires subscription).
- In production, these should have their own authentication (API key, OAuth) and audit logging.

---

## Performance Considerations

### Subscription Lookup

```go
_, found := subscriptionStore.Load(key)
```

This is O(1) and very fast because `sync.Map` is optimized for concurrent reads.

### JWT Caching

```go
pub, _ := jwksCache.Load(kid)
if pub == nil {
    pub, err = fetchPublicKey(jwksURL, kid)
}
```

Public keys are cached by `kid`, so repeated requests with the same key don't re-fetch from JWKS.

### Two-Stage JWT Validation

If a key is not found or validation fails on the first attempt, we re-fetch the public key once.
This handles key rotation without requiring manual cache invalidation.

---

## Production Considerations

1. **Authentication for admin endpoints** — Protect `/admin/subscriptions` with a separate auth mechanism
   (API key, OAuth, mTLS).

2. **Audit logging** — Log all subscription add/delete operations with timestamps and requestor identity.

3. **Rate limiting** — Rate limit admin endpoints to prevent abuse.

4. **Subscription expiration** — Add an `ExpiresAt` field and check it in the middleware.

5. **Subscription event sync** — Replace admin POST/DELETE with proper event-driven sync from the CP
   (JMS, HTTP webhooks, or message queues).

6. **Health check endpoints** — Separate health checks (e.g., `/health`, `/readiness`) from protected APIs.

7. **Monitoring and tracing** — Add structured logging and distributed tracing to the middleware chain.

---

## Common Issues and Troubleshooting

### Issue: "403 Resource forbidden" even with a valid token

**Causes:**
- Subscription was never added via `/admin/subscriptions`
- The `applicationname` in the subscription doesn't match the claim in the JWT
- The `apiname` in the subscription doesn't match the route being called (should be "hello")

**Solution:**
- Verify the subscription was added: `curl http://localhost:9090/admin/subscriptions`
- Check the token's claims: `curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info`
- Ensure the claim's `applicationname` matches the subscription's `applicationname` exactly

### Issue: "401 Unauthorized" when token should be valid

**Causes:**
- JWKS endpoint is unreachable
- Token signature is invalid
- Token has expired

**Solution:**
- Verify JWKS_URL is correct: `curl http://localhost:8888/oauth2/jwks`
- Verify token was issued by the KM: `echo $TOKEN | jq -R 'split(".")[0] | @base64d'`
- Check token expiry: `echo $TOKEN | jq -R 'split(".")[1] | @base64d | jq .exp'`

### Issue: Gateway crashes on startup

**Causes:**
- BACKEND_URL is unreachable
- PORT or BACKEND_PORT already in use

**Solution:**
- Verify mock backend is running on port 8080
- Check for port conflicts: `lsof -i :9090`

---

## Summary

Day 24 completes the authentication and authorization components of the gateway:
- **Authentication** via JWT validation middleware (Day 21)
- **Authorization** via subscription middleware (Day 23)

Together, they enforce both that the client's identity is verified (JWT) and that the client's
application is authorized for the requested API (subscription).

Task 4 will add throttling, using the `subscriptionTier` field from the subscription record.

