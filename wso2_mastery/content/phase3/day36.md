# Day 36 — The Validate Endpoint: Gateway Integration at Scale

## Why This Matters

`GET /subscriptions/validate` is the endpoint the Gateway calls when it needs to verify a subscription at request time. This is where the CP and GW meet: the GW has a JWT; it needs to know if the subscription is valid and what tier applies. The performance and correctness of this endpoint directly determines whether the Gateway can serve requests fast and reliably. A slow validate endpoint means slow request latency; an incorrect response means incorrect access control.

## Core Concepts

### The Validate Endpoint Contract

The Gateway calls validate like this:

```
GET /subscriptions/validate?consumerKey=abc&apiContext=/petstore/v1&tier=Gold
```

**Query parameters:**
- `consumerKey` (required): The application's unique key
- `apiContext` (required): The API context/path (e.g., `/petstore/v1`)
- `tier` (optional): The requested subscription tier; if provided, the response must match this exact tier

**Response (always 200 OK):**

**Case 1: Valid subscription**
```json
{
  "valid": true,
  "tier": "Gold",
  "appName": "PetApp",
  "appId": "abc123de"
}
```

**Case 2: Subscription not found**
```json
{
  "valid": false,
  "reason": "subscription_not_found"
}
```

**Case 3: Subscription is BLOCKED**
```json
{
  "valid": false,
  "reason": "subscription_blocked"
}
```

**Case 4: Application not found**
```json
{
  "valid": false,
  "reason": "application_not_found"
}
```

**Case 5: Tier mismatch (requested tier is Gold, but subscription is Bronze)**
```json
{
  "valid": false,
  "reason": "tier_mismatch"
}
```

### Why Always 200, Never 404?

This is critical. The Gateway expects a structured JSON response, regardless of whether the subscription exists.

**If you return 404:**
- The GW's HTTP client raises an error before deserializing the body
- The GW can't read the `{"valid":false,...}` structure
- The GW treats it as a server error and may deny the request or retry

**If you return 200:**
- The GW deserializes the JSON body
- The GW reads `"valid": false` and applies the business logic
- The GW doesn't need special-case handling for different HTTP statuses

**HTTP semantics:**
- 404 means "the resource doesn't exist" (e.g., `GET /applications/missing`)
- 200 + `{"valid":false}` means "I processed your request; the answer is no"

The validate endpoint is answering a question ("is this subscription valid?"), not retrieving a resource. The answer can be "no," but the question was answered successfully.

### The Validation Algorithm

```
1. Receive consumerKey, apiContext, tier
2. Look up application by consumerKey (O(1) using byKey map)
   → If not found: return 200 {"valid":false,"reason":"application_not_found"}
3. Look up API ID using apiContext (O(1) using apiContextMap)
   → If not found: return 200 {"valid":false,"reason":"api_not_found"}
4. Scan subscriptions for this app (O(n) where n = subscriptions per app, typically small)
   → For each subscription:
     a. Check if APIID matches
     b. Check if Status == UNBLOCKED
     c. Check if Tier matches (or tier is empty, meaning "any tier is OK")
5. If match found: return 200 {"valid":true,...}
6. If no match: return 200 {"valid":false,"reason":"subscription_not_found"}
```

**Performance:**
- Steps 2 & 3: O(1) hash lookups (fast)
- Step 4: O(n) linear scan, but n is typically small (5-10 subscriptions per app)
- Total: O(1) + O(n_small) ≈ O(1) in practice

This is why you need the two-map design (by ID and by ConsumerKey): validation queries use the ConsumerKey path and must be O(1) to avoid catastrophic load.

### The /admin/apis Registration Endpoint

Before validation can work, the CP must register the API context → API ID mapping.

**Endpoint:** `POST /admin/apis`

**Request:**
```json
{
  "apiId": "petstore-abc123",
  "apiContext": "/petstore/v1"
}
```

**Response (201 Created):**
```json
{
  "apiId": "petstore-abc123",
  "apiContext": "/petstore/v1"
}
```

**What it does:**
- Stores the mapping in `apiContextMap[apiContext] = apiID`
- This allows the validate endpoint to resolve `/petstore/v1` → `petstore-abc123`

**Why separate endpoint?**
- The API already exists in the store (created on Days 31-33)
- We're not creating a new API; we're registering its context for the validation lookup
- This mirrors WSO2's design: the CP manages APIs, but the validation store needs context information

### Data Flow: From API Registration to Validation

1. **Day 31-33:** Create API (e.g., `/petstore/v1` → API ID `petstore-abc123`)
2. **Day 35:** Developers register applications and subscribe
3. **Day 36 (this step):** Register the API context so validate can look it up
   ```bash
   POST /admin/apis {"apiId":"petstore-abc123","apiContext":"/petstore/v1"}
   ```
4. **Runtime:** GW calls validate
   ```bash
   GET /subscriptions/validate?consumerKey=abc&apiContext=/petstore/v1&tier=Gold
   ```
5. **Validate resolves:** `/petstore/v1` → `petstore-abc123` → finds subscription → returns 200 `{"valid":true}`

### The Three-Map Store

Day 35 used two maps:
```go
apps   map[string]*Application      // id → app
byKey  map[string]*Application      // consumerKey → app
```

Day 36 adds a third:
```go
apiContextMap map[string]string     // apiContext → apiID
```

This allows the validate endpoint to handle queries that arrive with `apiContext` instead of `apiID`.

## Exercises

### Exercise 1: Blocked Subscription Response
**Q:** The GW calls validate with a `consumerKey` that belongs to a BLOCKED subscription. What should the response be?

**Hint:** The subscription exists, but its status is BLOCKED. This is not an "application not found" error; it's a specific subscription status. The response should be 200 (not an error).

**Solution sketch:**
```
In the validate algorithm:
  if sub.Status == SubBlocked {
      return 200 OK {
          "valid": false,
          "reason": "subscription_blocked"
      }
  }

The reason field tells the GW why validation failed. The GW might log this
as a different event (e.g., for monitoring when subscriptions are blocked).
```

### Exercise 2: Cache Invalidation on Subscription Update
**Q:** A BLOCKED subscription is later unblocked by an admin. What extra step ensures the GW picks up the change?

**Hint:** The GW caches subscription data locally. Simply updating the subscription in the CP is not enough. What event must the CP emit?

**Solution sketch:**
```
The CP must emit a SUBSCRIPTION_UPDATED event that includes:
  - appId
  - apiContext
  - newStatus (or full subscription object)

The GW's subscription middleware listens for this event and:
  1. Invalidates its cache entry for this (app, api) pair
  2. On the next request, calls validate again to get the new status

Without the event, the GW keeps the old (BLOCKED) subscription data
and continues to deny requests.

Day 37 will implement this event bus integration.
```

### Exercise 3: Why Always 200?
**Q:** Why does the validate endpoint return 200 even when the subscription is not found, instead of 404?

**Hint:** Think about how the GW deserializes the response. What would happen if validate returned 404?

**Solution sketch:**
```
If validate returned 404:
  GW's HTTP client receives 404
  → Raises an error (or treats as "not found")
  → GW exception handler kicks in
  → GW needs special logic to distinguish between:
    a) "subscription not found" (should deny request with 403)
    b) "validate endpoint crashed" (should deny request with 502)
    c) "subscription is blocked" (should deny request with 403)

With three different HTTP statuses, the GW needs complex error handling.

If validate always returns 200:
  GW's HTTP client receives 200
  → Deserializes JSON body successfully
  → Reads "valid": false
  → GW treats all failures uniformly
  → Single code path: "if valid, allow; else deny"

The validate endpoint's job is to ANSWER a question, not to REPORT an error.
The answer can be "no" (valid=false), but the question was answered successfully (200).
```

## Anti-Patterns to Avoid

1. **Returning HTTP 404 for a missing subscription** — Breaks GW deserialisation. Always return 200.

2. **Not indexing by ConsumerKey** — O(n) scans during validation will fail under load. Use the byKey map.

3. **Allowing a tier mismatch to silently return `valid:true`** — If the GW requests tier=Gold and the subscription is tier=Bronze, return `valid:false` with a reason, not `valid:true`.

4. **Not registering API contexts** — If the validate endpoint can't resolve `/petstore/v1` to an API ID, it can't find subscriptions. Always call `POST /admin/apis` for new API deployments.

5. **Forgetting to check subscription status (UNBLOCKED vs. BLOCKED)** — A BLOCKED subscription is not valid. Always check the status field.

6. **Returning `null` instead of `[]` for empty subscription lists** — In the internal list endpoint, always return `[]`, not `null`.

## What You'll Build

Your lab will extend the Day 35 store with:

- **The validate endpoint:** `GET /subscriptions/validate` with O(1) lookups
- **API context registration:** `POST /admin/apis` to register contexts
- **The apiContextMap:** For context → ID resolution
- **Comprehensive validation logic:**
  - Look up app by ConsumerKey
  - Look up API by context
  - Find matching subscription with correct tier and status
  - Return 200 in all cases (never 404)
- **Proper error reasons:** "application_not_found", "subscription_not_found", "subscription_blocked", "tier_mismatch"

## The CP-to-GW Communication Pattern

By the end of Day 36, you'll have built:

1. **Application and Subscription stores** (Days 34-35)
2. **A fast validate endpoint** (Day 36) that the GW calls for cache misses
3. **API context registration** so validation can resolve contexts to IDs

Day 37 will complete the loop by adding event publishing, so the GW can receive real-time updates when subscriptions change.

The full cycle:
- Developer registers app → CP generates ConsumerKey
- Developer subscribes app to API → CP stores subscription
- GW receives request with JWT → Reads JWT, gets ConsumerKey
- GW calls `GET /subscriptions/validate?consumerKey=...&apiContext=...` → CP responds 200 with validity
- If subscription changes → CP emits event → GW invalidates cache → Next request calls validate again
