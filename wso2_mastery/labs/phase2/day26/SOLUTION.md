# Solution: Day 26 — Token-Bucket Throttle

## Overview

This solution adds the throttle middleware to the Day 24 gateway. The key addition is:

```go
// New: throttleMiddleware that checks per-application token buckets
func throttleMiddleware(next http.Handler) http.Handler { ... }

// New: limiter cache keyed by appName::tier
var throttleLimiters sync.Map
```

## Key Components

### 1. Throttle Middleware

The middleware executes after subscription check (which validates the tier):

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

**Flow:**
1. Extract claims from context
2. Get or create limiter for app::tier
3. Call `limiter.Allow()` (non-blocking)
4. If denied: return 429 with WSO2 error code
5. If allowed: proceed to next middleware

### 2. Limiter Cache and Creation

```go
var throttleLimiters sync.Map  // appName::tier → *rate.Limiter

func getOrCreateLimiter(appName string, tier string) *rate.Limiter {
	key := appName + "::" + tier
	if l, ok := throttleLimiters.Load(key); ok {
		return l.(*rate.Limiter)
	}
	// Map tier to requests/second
	rps := map[string]rate.Limit{
		"Gold":      rate.Limit(5000.0 / 60),      // 83.33 tokens/sec
		"Silver":    rate.Limit(2000.0 / 60),      // 33.33 tokens/sec
		"Bronze":    rate.Limit(1000.0 / 60),      // 16.67 tokens/sec
		"Unlimited": rate.Inf,                      // No limit
	}
	r, ok := rps[tier]
	if !ok {
		r = rate.Limit(10)  // default conservative (10 tokens/sec)
	}
	l := rate.NewLimiter(r, int(r*60))  // burst = 60 seconds worth
	throttleLimiters.Store(key, l)
	return l
}
```

**Details:**
- `key`: "appName::tier" (e.g., "app1::gold", "app2::silver")
- `rate.Limit`: tokens/second
- `int(r*60)`: burst capacity (allows 60 seconds of traffic at given rate)
- `rate.Inf`: special value meaning no limit (for Unlimited tier)

### 3. Middleware Chain Order

Updated chain (Day 26 adds throttle):

```go
apiMiddleware := Chain(proxy,
	requestIDMiddleware,
	loggingMiddleware,
	jwtValidationMiddleware(jwksURL),
	subscriptionMiddleware("hello"),
	throttleMiddleware,        // NEW: after subscription, before recovery
	recoveryMiddleware,
)
```

**Execution order (innermost to outermost when built):**
1. Recovery (catches panics)
2. Throttle (checks rate limit)
3. Subscription (validates app is subscribed)
4. JWT Validation (validates and extracts claims)
5. Logging (times request)
6. Request ID (assigns ID if missing)
7. Proxy (forwards to backend)

### 4. Import Addition

```go
import "golang.org/x/time/rate"
```

**Installation:**
```bash
go get golang.org/x/time/rate
```

## Testing the Implementation

### Verify Gold Tier Throttle

```bash
# Add Gold subscription (5000/min ≈ 83/sec)
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"hello",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'

# Get token
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# Hammer until throttled
for i in {1..100}; do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello)
  if [ "$HTTP" = "429" ]; then
    echo "Throttled at request $i"
    break
  fi
  echo "Request $i: $HTTP"
done
```

**Expected:**
- Requests 1-83: HTTP 200 (success)
- Request 84+: HTTP 429 (throttled)

Response on throttle:
```json
{
  "code": "900801",
  "message": "Application level throttle limit exceeded"
}
```

### Verify Per-App Isolation

Each app has independent buckets:

```bash
# Add two subscriptions with different tiers
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold",...}'

curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app2","apiname":"hello","subscriptiontier":"silver",...}'

# Get tokens
TOKEN1=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Test app1 (Gold): throttle around 84
for i in {1..100}; do
  curl -s -H "Authorization: Bearer $TOKEN1" http://localhost:9090/api/hello > /dev/null
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN1" http://localhost:9090/api/hello)
  [ "$HTTP" = "429" ] && echo "app1 throttled at $i" && break
done

# Test app2 (Silver): throttle around 34 (independent of app1)
for i in {1..50}; do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello)
  [ "$HTTP" = "429" ] && echo "app2 throttled at $i" && break
done
```

**Expected:**
- app1 throttles around request 84 (Gold rate)
- app2 throttles around request 34 (Silver rate)
- Separate buckets: app1's requests don't affect app2's bucket

### Verify Unlimited Tier Never Throttles

```bash
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app3","apiname":"hello","subscriptiontier":"unlimited",...}'

TOKEN3=$(curl -s http://localhost:8888/token?username=charlie&appname=app3 | jq -r .token)

for i in {1..10000}; do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN3" http://localhost:9090/api/hello)
  [ "$HTTP" = "429" ] && echo "Unexpected throttle at $i" && exit 1
done

echo "All 10000 requests succeeded for Unlimited tier"
```

**Expected:** All requests succeed (rate.Inf never throttles)

## Exercise Solutions

### Exercise 1: Per-App Bucket Isolation Script

```bash
#!/bin/bash

# Setup: add two subscriptions
curl -s -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}' > /dev/null

curl -s -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{"applicationname":"app2","apiname":"hello","subscriptiontier":"silver","keytype":"PRODUCTION"}' > /dev/null

# Get tokens
TOKEN1=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Test app1 (Gold: 83/sec)
echo "Testing app1 (Gold tier)..."
app1_throttle=0
for i in {1..100}; do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN1" http://localhost:9090/api/hello)
  if [ "$HTTP" = "429" ]; then
    app1_throttle=$i
    break
  fi
done

# Test app2 (Silver: 33/sec)
echo "Testing app2 (Silver tier)..."
app2_throttle=0
for i in {1..50}; do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello)
  if [ "$HTTP" = "429" ]; then
    app2_throttle=$i
    break
  fi
done

echo "Results:"
echo "  app1 (Gold) throttled at request: $app1_throttle (expected ~84)"
echo "  app2 (Silver) throttled at request: $app2_throttle (expected ~34)"

if [ "$app1_throttle" -gt 80 ] && [ "$app1_throttle" -lt 90 ] && \
   [ "$app2_throttle" -gt 30 ] && [ "$app2_throttle" -lt 40 ]; then
  echo "✓ Test PASSED: Per-app isolation verified"
else
  echo "✗ Test FAILED: Throttle points outside expected ranges"
fi
```

### Exercise 2: Statistics Endpoint

Add to `main.go`:

```go
func statsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var limiters []string
	throttleLimiters.Range(func(key, value interface{}) bool {
		limiters = append(limiters, key.(string))
		return true
	})

	w.Header().Set("Content-Type", "application/json")
	resp := map[string]interface{}{
		"limiters": limiters,
		"count":    len(limiters),
	}
	json.NewEncoder(w).Encode(resp)
}

// In main(), add to mux:
mux.HandleFunc("GET /admin/stats", statsHandler)
```

Usage:
```bash
curl http://localhost:9090/admin/stats

# Response:
{
  "count": 2,
  "limiters": [
    "app1::gold",
    "app2::silver"
  ]
}
```

### Exercise 3: Handling Misspelled Tier

**Problem:** If tier is "GOLD" instead of "Gold", it falls back to conservative rate (10/sec).

**Solution:** Normalize tier to lowercase:

```go
func getOrCreateLimiter(appName string, tier string) *rate.Limiter {
	key := appName + "::" + tier
	if l, ok := throttleLimiters.Load(key); ok {
		return l.(*rate.Limiter)
	}
	
	// Normalize tier to lowercase for comparison
	tierLower := strings.ToLower(tier)
	key = appName + "::" + tierLower  // Update key to use normalized tier
	
	// Check cache again with normalized key
	if l, ok := throttleLimiters.Load(key); ok {
		return l.(*rate.Limiter)
	}
	
	rps := map[string]rate.Limit{
		"gold":      rate.Limit(5000.0 / 60),
		"silver":    rate.Limit(2000.0 / 60),
		"bronze":    rate.Limit(1000.0 / 60),
		"unlimited": rate.Inf,
	}
	
	r, ok := rps[tierLower]
	if !ok {
		r = rate.Limit(10)  // default if still not found
	}
	
	l := rate.NewLimiter(r, int(r*60))
	throttleLimiters.Store(key, l)
	return l
}
```

This ensures both "Gold", "GOLD", "gold" map to the same limiter.

## Summary

The Day 26 solution integrates token-bucket rate limiting into the gateway:

1. **Throttle Middleware**: Checks `limiter.Allow()` after subscription validation
2. **Limiter Cache**: Per-app::tier limiters stored in `sync.Map`
3. **Tier Mapping**: Gold/Silver/Bronze/Unlimited with specific rates
4. **429 Response**: WSO2-standard error code "900801" on throttle
5. **Per-App Isolation**: Each app has independent buckets; one app's traffic doesn't affect others

The implementation is complete and functional for single-replica deployments. Day 27 adds
a mock Traffic Manager to coordinate throttle decisions across multiple replicas.
