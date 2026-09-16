# Day 33 — Tier and Policy Management: The Bridge Between Control Plane and Gateway

## Why This Matters

The tier/policy attachment bridges the Control Plane and the Gateway. The Gateway reads the allowed subscription tiers from the CP to decide which subscription tiers are valid for a given API context. When a developer tries to subscribe to an API, the API Gateway enforces the tier restrictions — but the CP is the source of truth for what those restrictions are. Understanding this boundary teaches you how distributed systems stay consistent: the CP and GW don't share memory; they communicate via events and reads.

## Core Concepts

### Policies and Tiers: Terminology

**Tier** (subscription tier): A quota/rate-limit package offered to subscribers. Examples:
- Bronze: 1000 requests per minute
- Silver: 2000 requests per minute
- Gold: 5000 requests per minute
- Unlimited: No rate limit

**Policy**: A policy object that wraps a tier with metadata (name, description, rate limits). When the CP returns `GET /apis/{id}/policies`, it returns a list of `Policy` objects, each with a name (tier name) and a description (e.g., "5000 requests/min").

**AllowedTiers**: The list of subscription tiers associated with a given API. An API can be subscribed to under any of its allowed tiers. If an API has `AllowedTiers = ["Bronze", "Gold"]`, subscribers cannot use the Silver tier for that API (even though Silver tier exists).

### Tier Descriptions

Each tier has a standard description that the CP stores (in the real WSO2, in the `AM_POLICY_SUBSCRIPTION` table). The lab defines them as a helper function:

```go
func tierDescription(tier string) string {
    switch tier {
    case "Bronze":
        return "1000 requests per minute"
    case "Silver":
        return "2000 requests per minute"
    case "Gold":
        return "5000 requests per minute"
    case "Unlimited":
        return "No rate limit"
    default:
        return "Unknown tier"
    }
}
```

### The Policies Endpoint: `GET /apis/{id}/policies`

This endpoint returns the policies (tiers with descriptions) that are allowed for a given API.

**Request:**
```
GET /apis/{abc12345}/policies
```

**Response:**
```json
[
  {
    "name": "Bronze",
    "description": "1000 requests per minute"
  },
  {
    "name": "Gold",
    "description": "5000 requests per minute"
  }
]
```

The list always matches the API's `AllowedTiers` field. If `AllowedTiers` is empty, the response is an empty array `[]` (never `null`).

### The Tiers Update Endpoint: `PUT /apis/{id}/tiers`

This endpoint updates which subscription tiers are allowed for an API.

**Request:**
```
PUT /apis/{abc12345}/tiers
Content-Type: application/json

{
  "tiers": ["Silver", "Gold", "Unlimited"]
}
```

**Response (success):**
```json
{
  "id": "abc12345",
  "name": "PetStore",
  "context": "/petstore/v1",
  "version": "1.0",
  "backendUrl": "http://backend:9000",
  "status": "CREATED",
  "allowedTiers": ["Silver", "Gold", "Unlimited"],
  "createdAt": "2026-09-16T10:30:00Z"
}
```

### The Business Rule: Cannot Change Tiers While PUBLISHED

Here's a critical rule that mirrors WSO2 production behavior:

**If the API status is PUBLISHED, you cannot change the tier list.**

**Reason:** If the GW has already activated the route with the old tier list, changing the tier list in the CP would cause inconsistency. Subscribers might be using the old tiers; invalidating them abruptly breaks the system.

**Solution:** The client must first deprecate the API (PUBLISHED → DEPRECATED), then change the tier list, then republish (DEPRECATED → PUBLISHED) if desired.

**Implementation:**

```go
if api.Status == StatusPublished {
    return 400 Bad Request with message: "deprecate the API before changing tiers"
}
```

### Populating Policies from the Database

In the real WSO2, the `AM_POLICY_SUBSCRIPTION` table stores all available tiers. The `AbstractAPIManager.getAPI()` method joins `AM_API` with `AM_POLICY_SUBSCRIPTION` to populate the `availableTiers` field. In the lab, we simulate this by looking up the tier descriptions dynamically.

## Exercises

### Exercise 1: Tier Update on Published API
**Q:** What HTTP status code should `PUT /apis/{id}/tiers` return if the API is PUBLISHED, and why?

**Hint:** Is this a "resource not found" error? A server error? Think about the HTTP status codes: 400 (bad request), 404 (not found), 409 (conflict), 500 (server error).

**Solution sketch:**
```
Return 400 Bad Request.

This is a client error because the client is trying to violate a business rule.
The API does exist (not a 404). The server is not broken (not a 500).
The client is asking for an invalid operation: changing tiers on a published API.

Response body:
  {"error":"deprecate the API before changing tiers"}

(409 Conflict is also defensible, but 400 is more direct and aligns with
WSO2's actual behavior.)
```

### Exercise 2: Implement a Tier Removal Endpoint
**Q:** Add a `DELETE /apis/{id}/tiers/{tier}` endpoint that removes a specific tier from the allowed tier list.

**Hint:** Filter the `AllowedTiers` slice to exclude the specified tier. Same business rule as the PUT endpoint: reject if PUBLISHED.

**Solution sketch:**
```go
if len(parts) == 4 && parts[2] == "tiers" && req.Method == http.MethodDelete {
    tier := parts[3]
    r.mu.Lock()
    api, ok := r.apis[id]
    if ok && api.Status == StatusPublished {
        r.mu.Unlock()
        http.Error(w, `{"error":"deprecate the API before changing tiers"}`, http.StatusBadRequest)
        return
    }
    if ok {
        newTiers := []string{}
        for _, t := range api.AllowedTiers {
            if t != tier {
                newTiers = append(newTiers, t)
            }
        }
        api.AllowedTiers = newTiers
    }
    r.mu.Unlock()
    if !ok {
        http.Error(w, "not found", http.StatusNotFound)
        return
    }
    r.mu.RLock()
    a := r.apis[id]
    r.mu.RUnlock()
    writeJSON(w, http.StatusOK, a)
    return
}
```

### Exercise 3: Tier Description Sourcing
**Q:** `GET /apis/{id}/policies` returns `Policy` objects with a `description` field. In production WSO2, where does the tier description come from?

**Hint:** Search for `AM_POLICY_SUBSCRIPTION` in the WSO2 codebase. What columns does that table have?

**Solution sketch:**
```
The AM_POLICY_SUBSCRIPTION table has columns:
  - POLICY_ID
  - NAME (tier name, e.g., "Gold")
  - DESCRIPTION (e.g., "5000 requests per minute")
  - RATE_LIMIT (in requests per minute)
  - BURST_LIMIT
  - QUOTA_TYPE

When the CP returns policy information for an API, it queries:
  SELECT p.NAME, p.DESCRIPTION, ...
  FROM AM_POLICY_SUBSCRIPTION p
  WHERE p.POLICY_ID IN (
    SELECT tier_policy_id FROM AM_API_TIER WHERE api_id = ?
  )

The default tiers are seeded at installation time. You can add custom tiers via the admin API.
```

## Anti-Patterns to Avoid

1. **Allowing tier list changes while PUBLISHED without locking** — If the GW is reading the tier list while the CP is updating it, the GW might see a partial or inconsistent list. The solution is to lock during the update (which the lab does with `sync.RWMutex`) and to sync the full API object (including tiers) on every publish event.

2. **Returning `null` for an empty tier list instead of `[]`** — In JSON, `null` and `[]` are different. If the CP returns `"allowedTiers": null`, the GW might deserialize it as a nil slice, then panic when it tries to iterate. Always return `[]` (empty array) when there are no tiers.

3. **Allowing a published API to have zero tiers** — If an API loses all its tiers and stays PUBLISHED, subscribers with those tiers suddenly become invalid. The lab prevents this with the "cannot publish without tiers" rule.

4. **Confusing "tier name" and "tier ID"** — In WSO2, the tier name (e.g., "Gold") is human-readable and used for display. The tier ID is an internal database key. Always be clear about which one you're using.

5. **Not syncing tier changes to the GW** — If the CP updates the tier list but doesn't fire an event, the GW keeps the old tier list in memory. Always emit a notification after a tier update, or the GW will be out of sync.

## What You'll Build

Your lab will extend the Day 32 registry with:

- `GET /apis/{id}/policies` endpoint: Returns the policies (tiers with descriptions) for an API
- `PUT /apis/{id}/tiers` endpoint: Updates the allowed tier list; rejects if PUBLISHED
- Tier descriptions: A helper function that returns standard descriptions for each tier
- Business rule enforcement: Prevent tier updates on published APIs

## The CP-to-GW Communication Pattern

By the end of this day, you'll have built a CP that can:
1. Create APIs
2. Manage their lifecycle (CREATED → PUBLISHED → DEPRECATED → RETIRED)
3. Manage subscription tiers for each API
4. Enforce business rules (no publishing without tiers, no tier changes while published)

Tomorrow (Day 34), you'll add event publishing, so the GW can receive these changes in real-time and keep its route table in sync.
