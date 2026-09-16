# Day 36 — Solutions: The Validate Endpoint

## The Validate Endpoint Implementation

The `validateSub` method is the critical path for subscription verification:

```go
func (s *Store) validateSub(w http.ResponseWriter, req *http.Request) {
	q := req.URL.Query()
	consumerKey, apiContext, tier := q.Get("consumerKey"), q.Get("apiContext"), q.Get("tier")
	if consumerKey == "" || apiContext == "" {
		http.Error(w, "consumerKey and apiContext required", http.StatusBadRequest)
		return
	}
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	// Step 1: Look up application by consumerKey (O(1))
	app, ok := s.byKey[consumerKey]
	if !ok {
		writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "application_not_found"})
		return
	}
	
	// Step 2: Look up API ID by context (O(1))
	apiID := s.apiContextMap[apiContext]
	if apiID == "" {
		writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "api_not_found"})
		return
	}
	
	// Step 3: Find matching subscription (O(n_small) where n is subscriptions per app)
	for _, sub := range s.subIdx[app.ID] {
		if sub.APIID == apiID {
			// Step 4: Check status
			if sub.Status != SubUnblocked {
				writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_blocked"})
				return
			}
			// Step 5: Check tier (if provided)
			if tier != "" && sub.Tier != tier {
				writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "tier_mismatch"})
				return
			}
			// Step 6: All checks passed
			writeJSON(w, http.StatusOK, map[string]any{
				"valid":   true,
				"tier":    sub.Tier,
				"appName": app.Name,
				"appId":   app.ID,
			})
			return
		}
	}
	
	// Step 7: No matching subscription found
	writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_not_found"})
}
```

## Performance Analysis

### Step-by-Step Time Complexity

1. **`s.byKey[consumerKey]`** → O(1) hash map lookup
2. **`s.apiContextMap[apiContext]`** → O(1) hash map lookup
3. **`s.subIdx[app.ID]`** → O(1) hash map lookup, returns slice
4. **`for _, sub := range s.subIdx[app.ID]`** → O(n) where n = subscriptions per app
   - Typical case: 5-10 subscriptions per app
   - Worst case: All subscriptions belong to one app (unlikely in practice)

**Total:** O(1) + O(n_small) ≈ **O(1) in practice**

### Why Not O(1) Exactly?

You might ask: "Why is Step 4 O(n)? Can't we index subscriptions by (appID, apiID)?"

**Good question.** Yes, you could use a composite key:

```go
subIdx map[string]map[string]*Subscription  // appId → apiId → subscription
```

This would give O(1) for the subscription lookup. But:

1. **Memory overhead:** Two levels of maps instead of one
2. **Diminishing returns:** O(n) where n=5 is fast (even at 1000s/sec)
3. **Simplicity:** The current design is easier to understand and implement
4. **Typical usage:** Most apps subscribe to <10 APIs; scanning 10 subscriptions is negligible

In real WSO2, this optimization would be made. But for the learning path, the current design is a good balance between performance and clarity.

---

## Exercise 1: Why Always 200?

**The wrong way (return different HTTP statuses):**

```go
// Anti-pattern: Different status for different reasons
if !appFound {
    http.Error(w, "application not found", http.StatusNotFound)  // 404
    return
}
if !subFound {
    http.Error(w, "subscription not found", http.StatusNotFound)  // 404
    return
}
if blocked {
    http.Error(w, "subscription blocked", http.StatusForbidden)  // 403
    return
}
// Success
writeJSON(w, http.StatusOK, ...)
```

**Problem:** The GW's HTTP client handles different status codes differently:

```go
// GW code with the anti-pattern above
resp, err := http.Get("http://cp:8083/subscriptions/validate?...")
if err != nil || resp.StatusCode >= 400 {
    // Exception handling: GW treats all errors the same
    denyAccess()  // Can't distinguish between "app not found" and "blocked"
    return
}
// Assume success
allowAccess()
```

The GW can't distinguish between "this is an actual error" and "the subscription is invalid."

**The right way (always 200):**

```go
// Correct: Always 200
writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "application_not_found"})
writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_not_found"})
writeJSON(w, http.StatusOK, map[string]any{"valid": false, "reason": "subscription_blocked"})
writeJSON(w, http.StatusOK, map[string]any{"valid": true, ...})
```

**Benefit:** The GW has a unified response handler:

```go
// GW code with the correct approach
resp, err := http.Get("http://cp:8083/subscriptions/validate?...")
if err != nil {
    denyAccess()  // Network error (CP is down)
    return
}
var result map[string]any
json.NewDecoder(resp.Body).Decode(&result)
if result["valid"] == true {
    allowAccess()
} else {
    denyAccess()  // Reason is in result["reason"]
}
```

Single code path for all outcomes. The GW doesn't need special-case handling.

---

## Exercise 2: Cache Invalidation on Subscription Update

**Q:** A BLOCKED subscription is later unblocked. How does the GW know?

**Solution:**

The CP must emit an event when a subscription status changes.

**Without an event (what would happen):**

```
Timeline:
1. GW validates subscription → valid=false, reason="subscription_blocked"
   GW caches: "this app+api is invalid"
2. Admin unblocks the subscription (CP updates DB)
3. GW receives a request from this app
   GW checks cache: "still invalid" (cache not invalidated)
   GW denies the request (incorrectly)
4. GW and CP are out of sync
```

**With an event (correct behavior):**

```
Timeline:
1. GW validates subscription → valid=false, reason="subscription_blocked"
   GW caches: "this app+api is invalid" with a TTL (e.g., 1 hour)
2. Admin unblocks the subscription
   CP emits event: {
       "type": "SUBSCRIPTION_UPDATED",
       "appId": "abc123de",
       "apiId": "petstore-abc",
       "status": "UNBLOCKED"
   }
3. GW receives the event
   GW invalidates its cache for (app="abc123de", api="petstore-abc")
4. GW receives a request from this app
   GW checks cache: "cache miss"
   GW calls validate again → valid=true
   GW allows the request
```

**Implementation (Day 37):**

The CP would need an event bus (Redis, Kafka, or similar) and publish:

```go
// After updating subscription status
if sub.Status == SubBlocked {
    publishEvent("SUBSCRIPTION_UPDATED", map[string]string{
        "appId": sub.AppID,
        "apiId": sub.APIID,
        "status": string(sub.Status),
    })
}
```

The GW would subscribe to this topic and invalidate cache entries:

```go
// GW code
listener := bus.Subscribe("SUBSCRIPTION_UPDATED")
for event := range listener.Chan {
    appId := event.Data["appId"]
    apiId := event.Data["apiId"]
    cache.Delete(fmt.Sprintf("%s:%s", appId, apiId))
}
```

---

## Exercise 3: The Three-Map Design

**The three maps in the Store:**

```go
type Store struct {
    mu             sync.RWMutex
    apps           map[string]*Application        // id → app
    byKey          map[string]*Application        // consumerKey → app
    apiContextMap  map[string]string              // apiContext → apiID
    subs           map[string]*Subscription       // id → sub
    subIdx         map[string][]*Subscription     // appId → []sub
}
```

**Why three maps (instead of one)?**

Each map serves a different lookup pattern:

| Map | Key | Used for | O(n) alternative |
|-----|-----|----------|------------------|
| `apps` | ID | Create/retrieve by ID | N/A (primary) |
| `byKey` | ConsumerKey | Validation lookup | O(n) scan all apps |
| `apiContextMap` | API context | Context resolution | O(n) scan all APIs |

**Without `byKey` (single map on ID):**

```go
// Validation would have to scan all apps
for _, app := range s.apps {  // O(n)
    if app.ConsumerKey == consumerKey {
        // Found it
    }
}
```

This is catastrophic under load. Every validation request triggers O(n). If you have 10,000 apps, every validation does 10,000 comparisons.

**Without `apiContextMap` (single map on API ID):**

```go
// Validation would have to compare contexts
apiID := ""
for _, storedCtx := range s.apiContexts {  // O(n)
    if storedCtx == apiContext {
        apiID = storedCtx
        break
    }
}
```

Again, O(n) instead of O(1).

**With all three maps (current design):**

```go
app, _ := s.byKey[consumerKey]           // O(1)
apiID := s.apiContextMap[apiContext]     // O(1)
for _, sub := range s.subIdx[app.ID] {   // O(n_small) but n is typically 5-10
    // ...
}
```

Both critical lookups are O(1).

---

## The Registration Endpoint: POST /admin/apis

The `/admin/apis` endpoint registers API contexts:

```go
func (s *Store) registerAPI(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var body struct {
		APIID      string `json:"apiId"`
		APIContext string `json:"apiContext"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.APIID == "" || body.APIContext == "" {
		http.Error(w, "apiId and apiContext are required", http.StatusBadRequest)
		return
	}
	s.mu.Lock()
	s.apiContextMap[body.APIContext] = body.APIID
	s.mu.Unlock()
	writeJSON(w, http.StatusCreated, map[string]string{
		"apiId":      body.APIID,
		"apiContext": body.APIContext,
	})
}
```

**What it does:**

1. Receives `{apiId, apiContext}` pair
2. Stores the mapping: `apiContextMap[apiContext] = apiID`
3. Returns 201 Created

**Why separate endpoint?**

- The API already exists (created on Days 31-33)
- We're not creating a new API; we're registering its context for validation
- The subscription store doesn't manage APIs directly; it just maps contexts to IDs
- This separation allows multiple contexts per API (versioning)

**Example:**

```bash
POST /admin/apis
{
  "apiId": "petstore-v1-id",
  "apiContext": "/petstore/v1"
}

# Later, maybe register a v2
POST /admin/apis
{
  "apiId": "petstore-v2-id",
  "apiContext": "/petstore/v2"
}

# Now validate can resolve both contexts to different API IDs
```

---

## Test Execution Example

**Setup:**

```bash
# Terminal 1: Start server
go run main.go
# Output: WSO2 CP — Subscription Manager listening on :8083
```

**Terminal 2: Run tests**

```bash
# 1. Create app
curl -s -X POST http://localhost:8083/applications \
  -H 'Content-Type: application/json' \
  -d '{"name":"PetApp","owner":"alice"}' | jq .

# Output:
# {
#   "id": "abc123de",
#   "name": "PetApp",
#   "consumerKey": "abcd1234ef567890...",
#   "consumerSecret": "secret...",
#   ...
# }

# 2. Register API
curl -s -X POST http://localhost:8083/admin/apis \
  -H 'Content-Type: application/json' \
  -d '{"apiId":"petstore-abc","apiContext":"/petstore/v1"}' | jq .

# Output:
# {
#   "apiId": "petstore-abc",
#   "apiContext": "/petstore/v1"
# }

# 3. Subscribe
curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"abc123de","apiId":"petstore-abc","tier":"Gold"}' | jq .

# Output:
# {
#   "id": "sub12345",
#   "appId": "abc123de",
#   "apiId": "petstore-abc",
#   "tier": "Gold",
#   "status": "UNBLOCKED",
#   ...
# }

# 4. Validate (success)
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/petstore/v1&tier=Gold" | jq .

# Output:
# {
#   "valid": true,
#   "tier": "Gold",
#   "appName": "PetApp",
#   "appId": "abc123de"
# }

# 5. Validate (missing app)
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=missing&apiContext=/petstore/v1" | jq .

# Output:
# {
#   "valid": false,
#   "reason": "application_not_found"
# }

# 6. Validate (tier mismatch)
curl -s "http://localhost:8083/subscriptions/validate?consumerKey=abcd1234ef567890...&apiContext=/petstore/v1&tier=Silver" | jq .

# Output:
# {
#   "valid": false,
#   "reason": "tier_mismatch"
# }
```

All responses are 200 OK, never 404. The endpoint answers a question; the answer can be "no," but the question was answered successfully.
