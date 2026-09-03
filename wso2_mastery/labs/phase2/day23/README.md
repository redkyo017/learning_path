# Lab: Day 23 — Subscription Store and Middleware in Go

## Objective

Build a gateway with:
1. **Subscription data store** — in-memory `sync.Map` keyed by "appName::apiName"
2. **Subscription middleware** — validates JWT claims and checks if the application is subscribed
3. **Admin endpoint** — `/admin/subscriptions` POST to add subscriptions at runtime

## Prerequisites

- Phase 1 Go Key Manager running on port 8888 (token issuer)
- Docker and Docker Compose installed

## Architecture

```
Client
  ↓
Gateway Port 9090
  ├─ /health (no auth)
  ├─ /admin/subscriptions (POST, add subscriptions)
  ├─ /api/info (JWT validation only, diagnostics)
  └─ /api/hello (JWT validation + subscription check)
      ↓
Mock Backend Port 8080
```

## Running the Lab

### Step 1: Start the Gateway and Backend

```bash
cd labs/phase2/day23
docker-compose up --build
```

You should see:
```
gateway_1  | mock backend starting on port 8080
gateway_1  | gateway starting on port 9090
```

### Step 2: Add a Subscription

In another terminal, add a subscription for application "app1" to API "hello":

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

Expected response:
```json
{"status":"subscription_added"}
```

### Step 3: Get a Token

Assuming you have the Phase 1 Key Manager running on port 8888:

```bash
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
echo $TOKEN
```

### Step 4: Call the Protected API

With the token from app1 (which is subscribed to "hello"), the request should succeed:

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

Expected: Mock backend response (JSON with path and method)

### Step 5: Try with an Unsubscribed App

Get a token for a different application (app2) that has no subscription:

```bash
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)
curl -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello
```

Expected response:
```
HTTP 403 Forbidden
{"code":"900908","message":"Resource forbidden"}
```

### Step 6: Check the Claims

Call the `/api/info` endpoint to see the validated JWT claims:

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/info
```

Expected output: JSON with `subscriber`, `applicationname`, `applicationtier`, etc.

### Step 7: Health Check

The health endpoint requires no authentication:

```bash
curl http://localhost:9090/health
```

Expected:
```json
{"status":"UP"}
```

## Code Walkthrough

### SubscriptionRecord Type

```go
type SubscriptionRecord struct {
    ApplicationName string `json:"applicationname"`
    APIName         string `json:"apiname"`
    SubscriptionTier string `json:"subscriptiontier"`
    KeyType         string `json:"keytype"`
}
```

### Subscription Store

```go
var subscriptionStore sync.Map  // key: "appName::apiName"
```

### Subscription Middleware

```go
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
            if _, found := subscriptionStore.Load(key); !found {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}
```

### Admin Subscription Endpoint

```go
func addSubscriptionHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
        return
    }
    var rec SubscriptionRecord
    if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
        http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
        return
    }
    key := rec.ApplicationName + "::" + rec.APIName
    subscriptionStore.Store(key, &rec)
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"status":"subscription_added"}`)
}
```

### Middleware Chain for /api/hello

```go
apiMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("hello"),
    recoveryMiddleware,
)

mux.Handle("/api/hello", apiMiddleware)
```

Execution order: Request ID → Logging → JWT Validation → Subscription Check → Recovery → Proxy

## Exercises

### Exercise 1: Add a /admin/subscriptions/remove DELETE Endpoint

Extend the gateway to support removing subscriptions. The endpoint should accept query parameters
for `appname` and `apiname`, remove the subscription from the store, and return a success response.

**Hint:** Use `subscriptionStore.Delete(key)`. The endpoint should be `/admin/subscriptions` with
HTTP DELETE method.

**Solution sketch:**

```go
// Add this handler
func deleteSubscriptionHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "DELETE" {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
        return
    }
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
}

// Update the main function to handle both POST and DELETE
mux.HandleFunc("/admin/subscriptions", func(w http.ResponseWriter, r *http.Request) {
    if r.Method == "POST" {
        addSubscriptionHandler(w, r)
    } else if r.Method == "DELETE" {
        deleteSubscriptionHandler(w, r)
    } else {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
    }
})
```

Test:
```bash
# Remove the subscription for app1
curl -X DELETE "http://localhost:9090/admin/subscriptions?appname=app1&apiname=hello"

# Try calling the API again with app1's token (should now get 403)
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
# Expected: 403 Forbidden
```

---

### Exercise 2: Add a GET /admin/subscriptions Endpoint

Implement a diagnostics endpoint that lists all current subscriptions in the store.
The response should be a JSON array of subscription records.

**Hint:** Iterate over the subscription store. `sync.Map` doesn't have a direct iteration method,
so you'll need to use `Range()`.

**Solution sketch:**

```go
func listSubscriptionsHandler(w http.ResponseWriter, r *http.Request) {
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
        "count":         len(subs),
    })
}
```

---

### Exercise 3: What Happens If Multiple APIs Share the Same Gateway?

If you add a `/api/users` endpoint (also protected), how would you apply the subscription middleware?
Should you create a separate middleware for each API?

**Hint:** The `subscriptionMiddleware` factory takes the API name as a parameter. You can create
separate middleware instances for each API.

**Solution sketch:**

```go
// For /api/hello
helloMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("hello"),
    recoveryMiddleware,
)
mux.Handle("/api/hello", helloMiddleware)

// For /api/users
usersMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("users"),
    recoveryMiddleware,
)
mux.Handle("/api/users", usersMiddleware)
```

Each route uses its own subscription middleware instance with the correct API name.
An application must be subscribed to each API separately: "app1::hello" and "app1::users"
are different keys in the store.

---

## Troubleshooting

### "connection refused" on http://localhost:8888/token

Ensure the Phase 1 Key Manager is running. If not, start it:
```bash
cd labs/phase1/day16  # or wherever the KM is
docker-compose up
```

### "invalid_token" or "jwks_unavailable"

The gateway couldn't reach the JWKS endpoint on the KM. Check:
1. KM is running on port 8888
2. JWKS_URL is correct: `http://localhost:8888/oauth2/jwks`

### "Resource forbidden" even with a valid token

The subscription may not be added yet, or the key doesn't match. Check:
1. The subscription was added with `/admin/subscriptions` POST
2. The `applicationname` in the subscription matches the `applicationname` claim in the JWT
3. The `apiname` in the subscription matches "hello" (the API being called)

---

## Next Steps

- Day 24: Combine JWT validation + subscription check with error handling.
- Task 4: Add throttle middleware using the subscription tier.

## Teardown

Stop the gateway:
```bash
Ctrl+C
```

Remove containers:
```bash
docker-compose down
```

