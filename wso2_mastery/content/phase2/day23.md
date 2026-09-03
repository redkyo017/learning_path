# Day 23: Building a Subscription Store and Middleware in Go

## Why

Now that you understand WSO2's subscription store (Day 22), you'll implement it in Go.
Today you build:

1. **Subscription data model** — a Go struct to represent subscriptions.
2. **In-memory store** — using `sync.Map` for thread-safe caching.
3. **Subscription middleware** — extract the JWT claims, check if the application is subscribed
   to the API being requested, reject with 403 if not.
4. **Admin endpoint** — `/admin/subscriptions` to add/remove subscriptions at runtime (simulates
   CP→GW event sync).

---

## WSO2 Source Reading

From Day 22, you identified that WSO2 stores subscriptions as a keyed map:

```
Key: applicationName + "::" + apiName
Value: {applicationName, apiName, apiVersion, subscriptionTier, keyType}
```

Access is **read-heavy** (every request queries the store) and **write-light** (subscriptions
updated occasionally from the CP). This pattern justifies `sync.Map` over `map + mutex`.

---

## Core Concepts

### The SubscriptionRecord Type

In Go, represent a subscription as a struct:

```go
type SubscriptionRecord struct {
    ApplicationName string
    APIName         string
    SubscriptionTier string
    KeyType         string
}
```

Store it in a `sync.Map` with key `"appName::apiName"`:

```go
var subscriptionStore sync.Map  // key: "appName::apiName" → value: *SubscriptionRecord
```

### The Subscription Middleware

After JWT validation passes (claims are in context), check the subscription:

```go
func subscriptionMiddleware(apiName string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Get claims from context (set by JWT validation middleware)
            claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
            if !ok || claims == nil {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            // Check subscription
            key := claims.ApplicationName + "::" + apiName
            if _, found := subscriptionStore.Load(key); !found {
                http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
                    http.StatusForbidden)
                return
            }
            // Subscription found, proceed
            next.ServeHTTP(w, r)
        })
    }
}
```

### Admin Endpoint for Runtime Subscription Management

Simulate CP→GW event sync by exposing an `/admin/subscriptions` POST endpoint:

```go
mux.HandleFunc("POST /admin/subscriptions", func(w http.ResponseWriter, r *http.Request) {
    var rec SubscriptionRecord
    if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
        http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
        return
    }
    key := rec.ApplicationName + "::" + rec.APIName
    subscriptionStore.Store(key, &rec)
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"status":"subscription_added"}`)
})
```

---

## Lab

See `labs/phase2/day23/main.go` — a complete gateway with subscription middleware and admin endpoint.

Run with:

```bash
cd labs/phase2/day23
docker-compose up --build

# In another terminal:
# Add a subscription (app "app1" subscribed to API "myapi")
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"myapi",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'

# Get a token (from Phase 1 KM on port 8888)
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# Call the API with subscription check
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello

# Try with an app that has no subscription (should get 403)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)
curl -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello
# Expected: 403 {"code":"900908","message":"Resource forbidden"}
```

---

## Exercises

**Exercise 1:** Implement the `subscriptionMiddleware` function. It should check the JWT claims
from context, look up the subscription key in the store, and reject with 403 if not found.

**Hint:** Use `r.Context().Value(claimsKey{})` to retrieve claims. The key format is
`"appName::apiName"`. Check `subscriptionStore.Load(key)` to see if the subscription exists.

**Solution sketch:**

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

---

**Exercise 2:** Implement the `/admin/subscriptions` POST endpoint. It should decode a JSON
subscription record, store it in the subscription store with the key "appName::apiName",
and return a success response.

**Hint:** Use `json.NewDecoder(r.Body).Decode(&rec)` to parse the request. Construct the key
as `rec.ApplicationName + "::" + rec.APIName`. Store with `subscriptionStore.Store(key, &rec)`.

**Solution sketch:**

```go
mux.HandleFunc("POST /admin/subscriptions", func(w http.ResponseWriter, r *http.Request) {
    var rec SubscriptionRecord
    if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
        http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
        return
    }
    key := rec.ApplicationName + "::" + rec.APIName
    subscriptionStore.Store(key, &rec)
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"status":"subscription_added"}`)
})
```

---

**Exercise 3:** Design a `/admin/subscriptions/remove` DELETE endpoint. What parameters should it take?
How would you construct the key to remove from the store?

**Hint:** The endpoint should accept query parameters for application name and API name. Use
`subscriptionStore.Delete(key)` to remove.

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

---

## Anti-patterns

- **Subscription check without JWT validation** — Always validate the JWT first. A malicious actor
  could forge an `applicationname` claim. The middleware chain ensures JWT validation runs before
  subscription checks.

- **Storing subscriptions in a regular `map` without locking** — This causes race conditions. Use
  `sync.Map` or protect with `sync.RWMutex` for concurrent access.

- **Hardcoding API name in subscription check** — The API name should be passed as a parameter to
  the middleware factory, not hardcoded. This allows you to reuse the middleware on different routes.

- **No validation of subscription record fields** — Always validate that `ApplicationName` and
  `APIName` are non-empty before storing. Silently accepting invalid records leads to hard-to-debug
  authorization failures.

---

## Teardown

Stop docker-compose with `Ctrl+C`.

