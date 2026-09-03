# Solution: Day 23 — Subscription Store and Middleware

## Complete Working Code

The `main.go` file in this directory is a complete, working implementation of a gateway with:
1. JWT validation middleware (from Day 21)
2. Subscription data store (`sync.Map`)
3. Subscription middleware that checks subscriptions
4. Admin endpoint to manage subscriptions

## Key Components

### SubscriptionRecord Type

```go
type SubscriptionRecord struct {
	ApplicationName string `json:"applicationname"`
	APIName         string `json:"apiname"`
	SubscriptionTier string `json:"subscriptiontier"`
	KeyType         string `json:"keytype"`
}
```

The JSON tags use lowercase to match the admin API request format.

### Subscription Store

```go
var subscriptionStore sync.Map  // key: "appName::apiName"
```

`sync.Map` is used because:
- **Read-heavy workload**: Every request queries it; subscriptions are rarely updated.
- **No locking on reads**: Concurrent requests can check subscriptions simultaneously without contention.
- **Thread-safe**: Simultaneous reads and writes are safe (unlike a bare `map[string]interface{}`).

### Subscription Middleware

```go
func subscriptionMiddleware(apiName string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Step 1: Retrieve claims from context (set by JWT middleware)
			claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
			if !ok || claims == nil {
				// No claims means JWT validation didn't run or failed
				http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
					http.StatusForbidden)
				return
			}
			// Step 2: Construct the subscription key
			key := claims.ApplicationName + "::" + apiName
			// Step 3: Check if the subscription exists
			if _, found := subscriptionStore.Load(key); !found {
				http.Error(w, `{"code":"900908","message":"Resource forbidden"}`,
					http.StatusForbidden)
				return
			}
			// Step 4: Subscription found; proceed to next handler
			next.ServeHTTP(w, r)
		})
	}
}
```

**Key points:**
- Takes `apiName` as a parameter, allowing reuse on different routes.
- Checks that claims exist (fails closed if JWT middleware wasn't called).
- Constructs the key as "appName::apiName" to match the store.
- Returns the WSO2-standard 403 error if subscription is not found.

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

This simulates the CP pushing subscription data to the gateway.

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

**Execution order (innermost first):**
1. Recovery middleware — catches panics in the proxy layer
2. Subscription middleware — checks if app is subscribed to "hello"
3. JWT validation middleware — validates token, stores claims in context
4. Logging middleware — records request timing
5. Request ID middleware — assigns X-Request-ID if missing
6. Handler / Proxy — forwards to backend

---

## Testing Walkthrough

### Test 1: Successful Request

**Setup:** Add subscription, get token for subscribed app.

```bash
# Add subscription
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# Get token
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# Call API
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

**Expected flow:**
1. JWT validation middleware: token is valid, claims extracted, stored in context.
2. Subscription middleware: checks for key "app1::hello", finds it in the store.
3. Request forwarded to backend.
4. Mock backend returns a response.

**Response:** Mock backend JSON (success)

### Test 2: No Subscription

**Setup:** Get token for app that has no subscription.

```bash
# Get token for app2 (no subscription added)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Call API
curl -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello
```

**Expected flow:**
1. JWT validation middleware: token is valid, claims extracted.
2. Subscription middleware: checks for key "app2::hello", does not find it in the store.
3. Returns 403 immediately; backend is never called.

**Response:** `HTTP 403 Forbidden` with `{"code":"900908","message":"Resource forbidden"}`

### Test 3: Invalid Token

```bash
curl -H "Authorization: Bearer invalid" http://localhost:9090/api/hello
```

**Expected flow:**
1. JWT validation middleware: token is invalid, returns 401 immediately.
2. Subscription middleware is never reached.

**Response:** `HTTP 401 Unauthorized` with `{"error":"invalid_token"}`

### Test 4: No Token

```bash
curl http://localhost:9090/api/hello
```

**Expected flow:**
1. JWT validation middleware: no Authorization header, returns 401 immediately.

**Response:** `HTTP 401 Unauthorized` with `{"error":"missing_token"}`

---

## Exercise Solutions

### Exercise 1: DELETE /admin/subscriptions

```go
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

// In main, handle both POST and DELETE:
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

**Test:**
```bash
curl -X DELETE "http://localhost:9090/admin/subscriptions?appname=app1&apiname=hello"
```

### Exercise 2: GET /admin/subscriptions (List)

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
		return true  // continue iteration
	})
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"subscriptions": subs,
		"count":         len(subs),
	})
}
```

**Test:**
```bash
curl http://localhost:9090/admin/subscriptions
```

**Response:**
```json
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

### Exercise 3: Multiple APIs

Create separate middleware instances for each API:

```go
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

Each route checks for subscriptions to its own API:
- `/api/hello` checks for "appName::hello"
- `/api/users` checks for "appName::users"

An application must be subscribed to each API separately via `/admin/subscriptions`.

---

## Key Takeaways

1. **`sync.Map` for read-heavy stores** — Subscriptions are read on every request but updated rarely.
2. **Middleware order matters** — JWT validation must run before subscription checks to have claims.
3. **Middleware factories** — Pass parameters (apiName) to middleware factories to reuse on different routes.
4. **Admin endpoints for runtime management** — Simulate CP→GW event sync by exposing management endpoints.
5. **Fail-closed on missing subscriptions** — Return 403 immediately if subscription is not found.
6. **WSO2-standard error codes** — Use error code `900908` for "Resource forbidden" (subscription missing).

---

## Common Mistakes

- **Forgetting to check if claims exist** — Always verify `claims != nil` before using claims.
- **Hardcoding API name** — Pass it as a parameter to the middleware factory for reusability.
- **Storing subscriptions in an unsafe map** — Use `sync.Map` or `map` with `sync.RWMutex`.
- **Placing subscription middleware before JWT** — Claims won't be in context yet; JWT must run first.
- **Using `sync.Map.Range()` within a hot path** — It's slower than direct lookups; only use for diagnostics.

---

## Next Steps

Day 24 combines JWT validation + subscription enforcement into an end-to-end gateway test.
Task 4 will add throttle middleware, using the `subscriptionTier` from the subscription record.

