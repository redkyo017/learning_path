# Lab: Day 24 — Full Gateway with JWT Validation + Subscription Enforcement

## Objective

Integrate JWT validation and subscription enforcement into a complete gateway. This lab combines:
1. JWT validation middleware (Day 21)
2. Subscription store and middleware (Day 23)
3. Admin endpoints for runtime subscription management
4. Full error handling with WSO2-standard error codes

## Architecture

```
Client
  ↓
Gateway Port 9090
  ├─ /health (no auth required)
  ├─ /admin/subscriptions (POST to add, DELETE to remove)
  ├─ /api/info (JWT validation only)
  └─ /api/hello (JWT validation + subscription enforcement)
      ↓
Mock Backend Port 8080
```

## Request Flow for Protected Route (/api/hello)

```
1. Client sends: GET /api/hello with Authorization: Bearer <JWT>
   ↓
2. Request ID Middleware: Assigns X-Request-ID if missing
   ↓
3. Logging Middleware: Starts timer
   ↓
4. JWT Validation: Validates token signature, extracts claims into context
   ↓ (JWT invalid → return 401)
5. Subscription Check: Looks up "appName::apiName" in subscription store
   ↓ (subscription not found → return 403)
6. Recovery Middleware: Defers panic recovery
   ↓
7. Reverse Proxy: Forwards to mock backend (port 8080)
   ↓
8. Mock Backend: Returns response
   ↓
9. Response to client
```

## Prerequisites

- Phase 1 Go Key Manager running on port 8888 (token issuer)
- Docker and Docker Compose installed

## Running the Lab

### Step 1: Start the Gateway and Backend

```bash
cd labs/phase2/day24
docker-compose up --build
```

You should see:
```
gateway_1  | mock backend starting on port 8080
gateway_1  | gateway starting on port 9090
```

### Step 2: Add a Subscription

```bash
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"hello",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'
```

Expected response: `{"status":"subscription_added"}`

### Step 3: Get a Token

```bash
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
echo $TOKEN
```

### Step 4: Call the Protected API (Should Succeed)

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

Expected: Mock backend response (JSON with path and method)

### Step 5: Try an Unsubscribed App (Should Fail with 403)

```bash
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)
curl -v -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello
```

Expected response:
```
HTTP 403 Forbidden
Content-Type: application/json
{"code":"900908","message":"Resource forbidden"}
```

The error code `900908` indicates "Resource forbidden" (standard WSO2 error code for missing subscriptions).

### Step 6: Check Claims

Retrieve the validated JWT claims:

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info | jq
```

Expected output: JSON with claims including `subscriber`, `applicationname`, `applicationtier`.

### Step 7: Delete a Subscription (Should Fail After Deletion)

Remove the subscription for app1:

```bash
curl -X DELETE "http://localhost:9090/admin/subscriptions?appname=app1&apiname=hello"
```

Expected response: `{"status":"subscription_removed"}`

Now try calling the API again with app1's token:

```bash
curl -v -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

Expected: `HTTP 403 Forbidden` (subscription was deleted)

### Step 8: Invalid Token (Should Fail with 401)

```bash
curl -v -H "Authorization: Bearer invalid" http://localhost:9090/api/hello
```

Expected response:
```
HTTP 401 Unauthorized
{"error":"invalid_token"}
```

### Step 9: Missing Token (Should Fail with 401)

```bash
curl -v http://localhost:9090/api/hello
```

Expected response:
```
HTTP 401 Unauthorized
{"error":"missing_token"}
```

### Step 10: Health Check (No Auth Required)

```bash
curl http://localhost:9090/health
```

Expected: `{"status":"UP"}`

---

## Error Responses Reference

| Scenario | Status Code | Response |
|----------|------------|----------|
| Missing token | 401 | `{"error":"missing_token"}` |
| Invalid token | 401 | `{"error":"invalid_token"}` |
| JWKS unavailable | 401 | `{"error":"jwks_unavailable"}` |
| Subscription not found | 403 | `{"code":"900908","message":"Resource forbidden"}` |
| Internal error | 500 | `{"error":"internal_server_error"}` |

---

## Key Concepts from Previous Days

### Day 21: JWT Validation

The JWT validation middleware:
- Extracts the token from the Authorization header
- Parses the JWT and validates the signature using the JWKS endpoint
- Caches public keys for performance
- Stores the validated claims in the request context

### Day 22: Subscription Store Architecture

The subscription store is an in-memory cache:
- Keyed by "appName::apiName"
- Thread-safe using `sync.Map`
- Updated by admin endpoints (simulating CP→GW event sync)

### Day 23: Subscription Middleware

The middleware:
- Retrieves claims from the context (set by JWT middleware)
- Constructs the subscription key: "appName::apiName"
- Checks if the key exists in the store
- Returns 403 if the subscription is not found

### Day 24: Integration

All components work together:
1. JWT validation runs first to extract and validate claims
2. Subscription check runs second to verify authorization
3. Both fail-closed (reject on any error)
4. Standard WSO2 error codes distinguish between authentication (401) and authorization (403) failures

---

## Code Walkthrough

### Request Path for /api/hello

```go
// This is the middleware chain for /api/hello
apiMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("hello"),
    recoveryMiddleware,
)

mux.Handle("/api/hello", apiMiddleware)
```

**Execution order (innermost first):**
1. Recovery middleware
2. Subscription middleware
3. JWT validation middleware
4. Logging middleware
5. Request ID middleware
6. Proxy to backend

### Admin Endpoints

```go
// Add subscription
func addSubscriptionHandler(w http.ResponseWriter, r *http.Request) { ... }

// Remove subscription
func deleteSubscriptionHandler(w http.ResponseWriter, r *http.Request) { ... }

// Handle both POST and DELETE
mux.HandleFunc("/admin/subscriptions", handleSubscriptions)
```

---

## Exercises

### Exercise 1: Add a Diagnostics Endpoint

Create a GET endpoint at `/admin/subscriptions` that lists all current subscriptions.

**Hint:** Use `subscriptionStore.Range()` to iterate over all keys and values.

**Solution sketch:**

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
        return true
    })
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "subscriptions": subs,
        "count": len(subs),
    })
}
```

Then update the handler:

```go
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

---

### Exercise 2: Add a Second Protected API Route

Add `/api/users` to the gateway, also protected by JWT validation + subscription check.

**Hint:** Create a second middleware chain with `subscriptionMiddleware("users")`. Both apps can have
subscriptions to "hello" and/or "users" independently.

**Solution sketch:**

```go
usersMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("users"),
    recoveryMiddleware,
)

mux.Handle("/api/users", usersMiddleware)
```

Test:
```bash
# Add subscription for app1 to both APIs
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}'

curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"users","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# Now app1 can call both /api/hello and /api/users
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/users
```

---

### Exercise 3: What Happens After a Subscription Expires?

In a real API Manager, subscriptions have an expiration date. Today's implementation doesn't check
expiration. How would you add an expiration check to the subscription middleware?

**Hint:** Add an `ExpiresAt` field to the `SubscriptionRecord` struct. In the middleware, check
if the current time is before `ExpiresAt`.

**Solution sketch:**

```go
type SubscriptionRecord struct {
    ApplicationName string    `json:"applicationname"`
    APIName         string    `json:"apiname"`
    SubscriptionTier string   `json:"subscriptiontier"`
    KeyType         string    `json:"keytype"`
    ExpiresAt       time.Time `json:"expiresat"`
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

---

## Testing Scenarios

### Scenario 1: Happy Path

1. Add subscription
2. Get token for subscribed app
3. Call API → succeeds

### Scenario 2: Unsubscribed App

1. Don't add subscription for app2
2. Get token for app2
3. Call API → 403 Forbidden

### Scenario 3: Invalid Token

1. Call API with invalid token → 401 Unauthorized

### Scenario 4: Missing Token

1. Call API without Authorization header → 401 Unauthorized

### Scenario 5: Subscription Revocation

1. Add subscription
2. Call API → succeeds
3. Delete subscription
4. Call API → 403 Forbidden

---

## Common Mistakes

- **Forgetting to add a subscription before calling the API** — Always add the subscription first via `/admin/subscriptions` POST.
- **Using the wrong application name in the subscription** — The `applicationname` in the subscription must match the `applicationname` claim in the JWT.
- **Confusing 401 vs 403** — 401 is for authentication failures (invalid token), 403 is for authorization failures (no subscription).
- **Not checking that claims exist** — Always verify `claims != nil` before using them.

---

## Next Steps

- **Task 4:** Add throttle middleware using the `subscriptionTier` field from the subscription record.
- **Production considerations:** Add audit logging to admin endpoints, rate limiting for subscription management, and authentication for the `/admin/subscriptions` endpoint itself.

---

## Teardown

Stop the gateway and remove containers:

```bash
Ctrl+C
docker-compose down -v
```

