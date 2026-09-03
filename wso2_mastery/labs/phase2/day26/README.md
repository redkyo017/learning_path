# Lab: Day 26 — Token-Bucket Throttle Middleware

## Objective

Integrate a token-bucket rate limiter into the gateway. This lab extends Day 24's gateway by adding
a throttle middleware that enforces per-application quota based on subscription tier.

## Prerequisites

- Phase 1 Go Key Manager running on port 8888 (token issuer)
- Docker and Docker Compose installed
- `golang.org/x/time/rate` package (`go get golang.org/x/time/rate`)

## Architecture

```
Client
  ↓
Gateway Port 9090
  ├─ /health (no auth required)
  ├─ /admin/subscriptions (POST to add, DELETE to remove)
  ├─ /api/info (JWT validation only)
  └─ /api/hello (JWT validation + subscription + THROTTLE)
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
6. Throttle Middleware: NEW!
   ├─ Get app's tier from claims
   ├─ Check token bucket for "appName::tier"
   ├─ If tokens available: consume 1 token, proceed
   ├─ If tokens exhausted: return 429
   ↓
7. Recovery Middleware: Defers panic recovery
   ↓
8. Reverse Proxy: Forwards to mock backend (port 8080)
   ↓
9. Mock Backend: Returns response
   ↓
10. Response to client
```

## Throttle Tier Rates

| Tier      | Rate          | Burst          |
|-----------|---------------|----------------|
| Gold      | 5000/min      | 5000 tokens    |
| Silver    | 2000/min      | 2000 tokens    |
| Bronze    | 1000/min      | 1000 tokens    |
| Unlimited | No limit      | Infinite       |

Burst capacity is set to 60 seconds worth of traffic (allowing normal spikes).

## Running the Lab

### Step 1: Start the Gateway and Backend

```bash
cd labs/phase2/day26
docker-compose up --build
```

You should see:
```
gateway_1  | mock backend starting on port 8080
gateway_1  | gateway starting on port 9090
```

### Step 2: Add a Gold-Tier Subscription

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

### Step 4: Make a Few Requests (Should Succeed)

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

Expected: Mock backend responses (all succeed)

### Step 5: Hammer the Endpoint (Should Hit Throttle)

```bash
for i in {1..100}; do
  RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello)
  HTTP_CODE=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | head -1)
  
  if [ "$HTTP_CODE" = "429" ]; then
    echo "Request $i: THROTTLED (429)"
    echo "$BODY"
    break
  else
    echo "Request $i: $HTTP_CODE"
  fi
done
```

Expected behavior:
- First ~83 requests: HTTP 200 (Gold tier: 5000/60 ≈ 83 tokens/sec)
- Request ~84+: HTTP 429 Throttled with error code "900801"

Response on throttle:
```json
{
  "code": "900801",
  "message": "Application level throttle limit exceeded"
}
```

### Step 6: Test Silver Tier (Lower Limit)

Add a Silver-tier subscription (2000/min = ~33 tokens/sec):

```bash
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app2",
    "apiname":"hello",
    "subscriptiontier":"silver",
    "keytype":"PRODUCTION"
  }'

TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

for i in {1..50}; do
  RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello)
  HTTP_CODE=$(echo "$RESP" | tail -1)
  
  if [ "$HTTP_CODE" = "429" ]; then
    echo "Request $i: THROTTLED (429)"
    break
  else
    echo "Request $i: $HTTP_CODE"
  fi
done
```

Expected: Silver tier throttles around request ~35

### Step 7: Test Unlimited Tier

```bash
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app3",
    "apiname":"hello",
    "subscriptiontier":"unlimited",
    "keytype":"PRODUCTION"
  }'

TOKEN3=$(curl -s http://localhost:8888/token?username=charlie&appname=app3 | jq -r .token)

for i in {1..1000}; do
  RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN3" http://localhost:9090/api/hello)
  HTTP_CODE=$(echo "$RESP" | tail -1)
  
  if [ "$HTTP_CODE" = "429" ]; then
    echo "Request $i: THROTTLED (429) - UNEXPECTED for Unlimited tier"
    break
  fi
done

echo "All 1000 requests succeeded for Unlimited tier"
```

Expected: All requests succeed (no throttle for unlimited)

### Step 8: Check Per-App Isolation

Verify that app1 and app2 have separate throttle buckets:

```bash
# Reset app1's bucket by waiting (buckets are per-app)
# Then verify app2 still has its own bucket

TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# app1: send a few requests
for i in {1..10}; do
  curl -s -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello > /dev/null
done

# app2: should have its own bucket (independent of app1)
for i in {1..40}; do
  RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello)
  HTTP_CODE=$(echo "$RESP" | tail -1)
  
  if [ "$HTTP_CODE" = "429" ]; then
    echo "app2 throttled at request $i (expected around 35)"
    break
  fi
done
```

Expected: app1 and app2 have separate buckets; app1's requests don't affect app2's limit.

---

## Error Responses Reference

| Scenario | Status Code | Response |
|----------|------------|----------|
| Missing token | 401 | `{"error":"missing_token"}` |
| Invalid token | 401 | `{"error":"invalid_token"}` |
| Subscription not found | 403 | `{"code":"900908","message":"Resource forbidden"}` |
| **Throttle limit exceeded** | **429** | **`{"code":"900801","message":"Application level throttle limit exceeded"}`** |
| Internal error | 500 | `{"error":"internal_server_error"}` |

---

## Code Walkthrough

### Throttle Middleware

```go
func throttleMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        claims, ok := r.Context().Value(claimsKey{}).(*WSO2Claims)
        if !ok {
            next.ServeHTTP(w, r)
            return
        }
        limiter := getOrCreateLimiter(claims.ApplicationName, claims.ApplicationTier)
        if !limiter.Allow() {
            w.Header().Set("Content-Type", "application/json")
            w.WriteHeader(http.StatusTooManyRequests)
            fmt.Fprint(w, `{"code":"900801","message":"Application level throttle limit exceeded"}`)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

**Key points:**
1. Get claims from context (set by JWT middleware)
2. Retrieve or create a limiter for the app::tier
3. Call `limiter.Allow()` (non-blocking, returns immediately)
4. If allowed: proceed; if denied: return 429

### Limiter Cache and Creation

```go
var throttleLimiters sync.Map  // appName::tier → *rate.Limiter

func getOrCreateLimiter(appName string, tier string) *rate.Limiter {
    key := appName + "::" + tier
    if l, ok := throttleLimiters.Load(key); ok {
        return l.(*rate.Limiter)
    }
    rps := map[string]rate.Limit{
        "Gold":      rate.Limit(5000.0 / 60),
        "Silver":    rate.Limit(2000.0 / 60),
        "Bronze":    rate.Limit(1000.0 / 60),
        "Unlimited": rate.Inf,
    }
    r, ok := rps[tier]
    if !ok {
        r = rate.Limit(10)
    }
    l := rate.NewLimiter(r, int(r*60))
    throttleLimiters.Store(key, l)
    return l
}
```

**Parameters:**
- `rate.Limit`: tokens/second (5000/60 ≈ 83.33 for Gold)
- `int(r*60)`: burst capacity (60 seconds worth)

### Middleware Chain Order

```go
apiMiddleware := Chain(proxy,
    requestIDMiddleware,
    loggingMiddleware,
    jwtValidationMiddleware(jwksURL),
    subscriptionMiddleware("hello"),
    throttleMiddleware,        // NEW: runs here
    recoveryMiddleware,
)
```

**Execution order (innermost first):**
1. Recovery middleware
2. Throttle middleware
3. Subscription middleware
4. JWT validation middleware
5. Logging middleware
6. Request ID middleware
7. Proxy to backend

---

## Exercises

### Exercise 1: Verify Per-App Bucket Isolation

Write a script that confirms app1 and app2 have separate throttle buckets:

**Hint:** Create subscriptions for both apps with different tiers, get tokens, and verify each
app's throttle limit is independent.

**Solution sketch:**

```bash
# App1: Gold (5000/min ≈ 83/sec)
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# App2: Silver (2000/min ≈ 33/sec)
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app2","apiname":"hello","subscriptiontier":"silver","keytype":"PRODUCTION"}'

TOKEN1=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Send 100 requests with app1 (should succeed, limit is 83)
app1_throttled=0
for i in {1..100}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN1" http://localhost:9090/api/hello)
  [ "$CODE" = "429" ] && app1_throttled=$i && break
done

# Send 50 requests with app2 (should throttle, limit is 33)
app2_throttled=0
for i in {1..50}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello)
  [ "$CODE" = "429" ] && app2_throttled=$i && break
done

echo "App1 throttled at: $app1_throttled (expected ~84)"
echo "App2 throttled at: $app2_throttled (expected ~34)"
```

---

### Exercise 2: Implement a Statistics Endpoint

Add a GET `/admin/stats` endpoint that returns the current state of all throttle limiters:

**Hint:** Iterate over `throttleLimiters` using `Range()` and collect limiter info.

**Solution sketch:**

```go
func statsHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "GET" {
        http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
        return
    }
    
    var stats []map[string]interface{}
    throttleLimiters.Range(func(key, value interface{}) bool {
        // Note: golang.org/x/time/rate doesn't expose current token count
        // So we can only report the key (appName::tier)
        stats = append(stats, map[string]interface{}{
            "limiter_key": key.(string),
        })
        return true
    })
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "limiters": stats,
        "count":    len(stats),
    })
}

// Add to main:
mux.HandleFunc("GET /admin/stats", statsHandler)
```

---

### Exercise 3: What Happens If a Tier String is Misspelled?

If an admin mistakenly adds a subscription with tier "GOLD" (uppercase) instead of "Gold",
what will happen when a request with that subscription comes in?

**Hint:** Look at the tier mapping in `getOrCreateLimiter()`. What is the default rate?

**Solution sketch:**

```
Scenario:
1. Subscription added: {"applicationname":"app1","apiname":"hello","subscriptiontier":"GOLD"}
2. JWT claims: applicationTier = "GOLD"
3. getOrCreateLimiter("app1", "GOLD") called
4. "GOLD" not in rps map (only "Gold", "Silver", "Bronze", "Unlimited")
5. Falls back to: r = rate.Limit(10)  // default conservative rate
6. Limiter created with 10 tokens/sec (very restrictive)
7. Result: app1 gets throttled very quickly (not the intended Gold tier)

Fix:
- Case-insensitive comparison: strings.ToLower(tier)
- Or enforce lowercase in subscription validation
- Or add both "Gold" and "GOLD" to the map

Better design:
```go
func getOrCreateLimiter(appName string, tier string) *rate.Limiter {
    key := appName + "::" + tier
    if l, ok := throttleLimiters.Load(key); ok {
        return l.(*rate.Limiter)
    }
    tier = strings.ToLower(tier)  // Normalize to lowercase
    rps := map[string]rate.Limit{
        "gold":      rate.Limit(5000.0 / 60),
        "silver":    rate.Limit(2000.0 / 60),
        "bronze":    rate.Limit(1000.0 / 60),
        "unlimited": rate.Inf,
    }
    // ... rest of function
}
```
```

---

## Testing Scenarios

### Scenario 1: Gold Tier Throttle Point

1. Add subscription with Gold tier (5000/min)
2. Hammer with 100 requests
3. Verify throttle occurs around request ~84

### Scenario 2: Silver Tier Throttle Point

1. Add subscription with Silver tier (2000/min)
2. Hammer with 50 requests
3. Verify throttle occurs around request ~34

### Scenario 3: Unlimited Tier Never Throttles

1. Add subscription with Unlimited tier
2. Hammer with 1000 requests
3. Verify no throttle (all succeed)

### Scenario 4: Per-App Isolation

1. Two apps with different tiers
2. Hammer both simultaneously
3. Verify each throttles independently at its tier's limit

---

## Common Mistakes

- **Wrong middleware order** — Throttle must run after subscription (which validates the tier).
- **Forgetting to set tier in subscription** — If tier is empty/null, limiter defaults to 10/sec (too conservative).
- **Blocking on limiter.Allow()** — It's non-blocking; use it safely in request handlers.
- **Creating new limiter per request** — Always cache in sync.Map; don't recreate.
- **Not handling missing claims** — Always check `ok` before using context values.

---

## Next Steps

- **Day 27:** Add a mock Traffic Manager client to coordinate throttle decisions across replicas.
- **Production considerations:** Add retry logic, circuit breaker, and event batching for TM communication.

---

## Teardown

Stop the gateway and remove containers:

```bash
Ctrl+C
docker-compose down -v
```
