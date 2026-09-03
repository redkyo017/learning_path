# Day 26: Implementing Token-Bucket Throttle in Go

## Why

Today you build a **local throttle middleware** using the token-bucket algorithm from Day 25.
This is the fast path: before contacting the TM, the gateway checks a per-application bucket
keyed by subscription tier. If the bucket is empty, reject with 429.

By the end of today, your gateway will:
1. Extract the subscription tier from JWT claims (set by Day 24's subscription middleware)
2. Maintain a per-app token bucket using `golang.org/x/time/rate`
3. Reject requests with WSO2's standard 429 response when throttled

---

## Core Concepts

### Per-Application Token Buckets

Each application (from the JWT claim `applicationname`) gets its own bucket, keyed by tier:

```go
// Key format: "appName::tier"
// Example: "app1::gold", "app2::silver"
throttleLimiters sync.Map  // key: string → value: *rate.Limiter
```

Why per-app? Because one app's quota shouldn't affect another's.
Why keyed by tier? Because different tiers have different rates (Gold: 5000/min, Silver: 2000/min).

### The `golang.org/x/time/rate` Package

Go's standard `rate` package (not in stdlib, must `go get`) provides `rate.Limiter`:

```go
import "golang.org/x/time/rate"

// Create a limiter: 83.33 tokens/sec, capacity 5000 (60 seconds worth)
limiter := rate.NewLimiter(83.33, 5000)

// Check if 1 token available; does NOT block
if limiter.Allow() {
    // Token consumed, request allowed
} else {
    // No tokens, request throttled
}
```

**Key parameters:**
- First arg: `rate.Limit` (tokens per second)
- Second arg: `int` (burst capacity, in tokens)

For Gold tier (5000/min):
```go
rate.Limit(5000.0 / 60)  // ≈ 83.33 tokens/second
int(5000.0 / 60 * 60)    // = 5000 token capacity (60 seconds)
```

### Mapping Tiers to Rates

```go
rps := map[string]rate.Limit{
    "Gold":      rate.Limit(5000.0 / 60),   // 83.33 tokens/sec
    "Silver":    rate.Limit(2000.0 / 60),   // 33.33 tokens/sec
    "Bronze":    rate.Limit(1000.0 / 60),   // 16.67 tokens/sec
    "Unlimited": rate.Inf,                   // No limit
}
```

### The Throttle Middleware

After subscription middleware (Day 24) passes, the throttle middleware:
1. Extracts `claims.ApplicationName` and `claims.ApplicationTier` from context
2. Looks up or creates a limiter for `"appName::tier"`
3. Calls `limiter.Allow()`
4. If false, return 429 with WSO2 error code

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

### WSO2 429 Response

When a request is throttled, return:

```
HTTP 429 Too Many Requests
Content-Type: application/json

{
  "code": "900801",
  "message": "Application level throttle limit exceeded"
}
```

The error code `900801` is standardized by WSO2 for application-level throttle.

---

## Lab

See `labs/phase2/day26/` — full gateway with throttle middleware.

### Features

- JWT validation + subscription check (from Day 24)
- **NEW:** Per-application token-bucket throttle
- Token bucket keyed by `applicationName::applicationTier`
- Returns 429 with WSO2 error code when throttled

### Running the Lab

```bash
cd labs/phase2/day26
docker-compose up --build

# In another terminal:

# 1. Add a subscription for app1 with Gold tier
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"hello",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'

# 2. Get a token for app1
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# 3. Make requests until throttled
# Gold tier: 5000/min = ~83 req/sec
for i in {1..100}; do
  curl -s -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello | jq .code
done

# Around request 85, you should see "900801" (throttled)

# 4. Try with Silver tier (lower limit)
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app2",
    "apiname":"hello",
    "subscriptiontier":"silver",
    "keytype":"PRODUCTION"
  }'

TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Silver: 2000/min = ~33 req/sec, should throttle much sooner
for i in {1..50}; do
  curl -s -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello | jq .code
done

# Should see "900801" around request 35
```

---

## Middleware Chain Order

The throttle middleware runs **after** subscription check:

```
Request ID → Logging → JWT Validation → Subscription Check → Throttle → Recovery → Proxy
                                                                ↑
                                                           NEW TODAY
```

**Why after subscription?** Because we check `claims.ApplicationTier` from the subscription record,
and subscription middleware already validated that the app is subscribed.

---

## Exercises

**Exercise 1:** Why is the throttle middleware placed after the subscription middleware, not before?

**Hint:** What data does the throttle middleware need? Where does it come from? Is it set before
or after the subscription check?

**Solution sketch:**

```
Throttle middleware needs:
- claims.ApplicationName (set by JWT validation)
- claims.ApplicationTier (set by subscription middleware, derived from subscription record)

If throttle ran before subscription:
- Would have applicationName but not applicationTier
- Would have to look up the subscription record again (inefficient)
- Violates separation of concerns

Order:
1. JWT Validation → claims available, no tier yet
2. Subscription → tier confirmed, subscription valid
3. Throttle → both applicationName and tier available, apply rate limit

Placement ensures efficiency and clarity: each middleware does one job in dependency order.
```

---

**Exercise 2:** What happens when an application has a tier of "Unlimited"?

**Hint:** Look at the tier mapping in `getOrCreateLimiter()`. What is `rate.Inf`?

**Solution sketch:**

```go
rps := map[string]rate.Limit{
    "Unlimited": rate.Inf,  // Special value
}

limiter := rate.NewLimiter(rate.Inf, 1)
limiter.Allow()  // Always returns true, no matter how often called

When tier == "Unlimited":
- Limiter is created with infinite rate and small burst
- limiter.Allow() will always return true
- No requests are rejected for throttle
- Useful for internal APIs or premium tiers with no quota

Design note: rate.Inf is a special case in the rate package meaning "no limit".
```

---

**Exercise 3:** If an app with tier "Bronze" makes 1000 requests, then the app's tier is upgraded
to "Gold" while requests are still in-flight, what happens?

**Hint:** The limiter is keyed by `"appName::tier"`. When the tier changes, what key does a new
request use? Are they separate limiters or the same?

**Solution sketch:**

```
Scenario:
- App1 starts with "Bronze" tier: key = "app1::bronze"
  Limiter created: 16.67 tokens/sec
- App1's tier upgraded to "Gold": key = "app1::gold"
  NEW limiter created: 83.33 tokens/sec

Old limiter (app1::bronze): 10/16 tokens used, in sync.Map storage
New limiter (app1::gold):   0/5000 tokens, in sync.Map storage

What happens:
- Requests using old JWT claim (Bronze): matched against "app1::bronze" limiter (throttled)
- Requests using new JWT claim (Gold): matched against "app1::gold" limiter (not throttled)
- Both limiters coexist in the sync.Map; old one eventually pruned by GC

Design consideration: To truly enforce the tier change across ALL in-flight requests,
you'd need to either:
1. Invalidate all old JWTs (extreme, not practical)
2. Accept that tier changes are eventual (current design)
3. Clear the old limiter on tier upgrade (loses state)

WSO2 usually chooses option 2: tier changes are eventual. A client's cached JWT will
reflect the old tier until the token refreshes.
```

---

## Anti-patterns

- **Creating a new limiter per request** — Expensive and breaks accounting. Always store limiters
  in a cache (sync.Map) keyed by appName::tier.

- **Checking `Unlimited` tier after calling `Allow()`** — The `rate.Inf` limiter handles it.
  Don't add a special case.

- **Throttle before JWT validation** — You need the applicationName from the JWT. Throttle
  must run after JWT validation.

- **Not considering burst capacity** — A bucket with 0 burst will reject every other request.
  Use at least 60 seconds worth of capacity to absorb normal traffic patterns.

---

## Teardown

Stop docker-compose with `Ctrl+C`.

---

## Next Steps

- **Day 27:** Add a mock Traffic Manager client to the gateway. The TM will receive throttle events
  and make global decisions.
