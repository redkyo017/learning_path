# Day 33 — Solution Guide

## Exercise 1 Solution: Why Tier Changes Are Blocked While PUBLISHED

**The Problem:**

When an API is PUBLISHED:
1. The Gateway has received the publish event
2. The Gateway has activated the route for that API context (e.g., `/payment/v1`)
3. The Gateway has cached the subscription tier restrictions in memory
4. The Gateway is routing live production traffic to this API

If the CP changes the tier list while PUBLISHED and the GW doesn't know:
- Subscribers using a removed tier would suddenly be invalid
- The GW would reject their requests with "unauthorized subscription tier"
- Existing subscriptions break

**The Solution:**

The business rule enforces a safe transition path:

```
PUBLISHED → DEPRECATED (safe; existing subs still work)
  ↓
(now tier changes are allowed)
  ↓
Modify tiers
  ↓
DEPRECATED → PUBLISHED (with new tiers, but only for new subs)
```

**Why This Works:**

- PUBLISHED: Active, routing traffic, no changes
- DEPRECATED: "No new subscriptions," but existing ones continue
  - This gives existing subscribers a grace period
  - The CP can safely change tiers
  - New subscribers see the updated tier list
- (Optionally) Re-publish with the new tiers

**Code Evidence:**

```go
if ok && api.Status == StatusPublished {
    reg.mu.Unlock()
    http.Error(w, `{"error":"deprecate the API before changing tiers"}`, http.StatusBadRequest)
    return
}
```

The check is explicit: "If PUBLISHED, reject the tier update."

## Exercise 2 Solution: Delete Single Tier Endpoint

Add this code to the `/apis/` mux handler, before the main method switch (after extracting `id` and the sub-resource checks):

```go
// Handle DELETE /apis/{id}/tiers/{tier}
if len(parts) == 4 && parts[2] == "tiers" && req.Method == http.MethodDelete {
	tier := parts[3]
	reg.mu.Lock()
	api, ok := reg.apis[id]
	if ok && api.Status == StatusPublished {
		reg.mu.Unlock()
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
	reg.mu.Unlock()
	if !ok {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	reg.mu.RLock()
	a := reg.apis[id]
	reg.mu.RUnlock()
	writeJSON(w, http.StatusOK, a)
	return
}
```

**Test it:**

```bash
# Create an API with tiers
curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"TestAPI",
    "context":"/test/v1",
    "version":"1.0",
    "backendUrl":"http://test:9000",
    "allowedTiers":["Bronze","Silver","Gold"]
  }' | jq .

# Copy the ID, then delete the "Silver" tier
curl -s -X DELETE http://localhost:8082/apis/{id}/tiers/Silver | jq .
```

**Expected output:**
```json
{
  "id":"...",
  ...
  "allowedTiers":["Bronze","Gold"],
  ...
}
```

The "Silver" tier has been removed, and "Bronze" and "Gold" remain.

**Test the PUBLISHED block:**

```bash
# Publish the API
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}' | jq .

# Try to delete a tier (should fail)
curl -s -X DELETE http://localhost:8082/apis/{id}/tiers/Bronze | jq .
```

**Expected output (error):**
```json
{"error":"deprecate the API before changing tiers"}
```

Status code: `400 Bad Request`.

## Exercise 3 Solution: Tier Description Sourcing

In production WSO2, tier descriptions come from the **`AM_POLICY_SUBSCRIPTION`** table:

### Database Schema

```sql
CREATE TABLE AM_POLICY_SUBSCRIPTION (
    POLICY_ID INT PRIMARY KEY,
    NAME VARCHAR(255) NOT NULL,          -- e.g., "Gold"
    DESCRIPTION VARCHAR(1024),           -- e.g., "5000 requests per minute"
    QUOTA_TYPE VARCHAR(50),              -- e.g., "RequestCountLimit"
    RATE_LIMIT INT,                      -- e.g., 5000 (requests/min)
    BURST_LIMIT INT,                     -- e.g., 10000 (burst capacity)
    BILLING_PLAN VARCHAR(50),            -- e.g., "COMMERCIAL", "FREE"
    CREATED_TIME TIMESTAMP,
    UPDATED_TIME TIMESTAMP
);

CREATE TABLE AM_API_TIER (
    API_ID INT,
    TIER_POLICY_ID INT,
    FOREIGN KEY (TIER_POLICY_ID) REFERENCES AM_POLICY_SUBSCRIPTION(POLICY_ID)
);
```

### How It Works in Production

**Step 1: Tier Definition**

When WSO2 is installed, it seeds default tiers:

```sql
INSERT INTO AM_POLICY_SUBSCRIPTION VALUES
  (1, 'Bronze', '1000 requests per minute', 'RequestCountLimit', 1000, 2000, 'FREE', NOW(), NOW()),
  (2, 'Silver', '2000 requests per minute', 'RequestCountLimit', 2000, 4000, 'COMMERCIAL', NOW(), NOW()),
  (3, 'Gold', '5000 requests per minute', 'RequestCountLimit', 5000, 10000, 'COMMERCIAL', NOW(), NOW()),
  (4, 'Unlimited', 'No rate limit', 'NONE', NULL, NULL, 'COMMERCIAL', NOW(), NOW());
```

**Step 2: API-Tier Association**

When an API is created with allowed tiers:

```sql
INSERT INTO AM_API_TIER (API_ID, TIER_POLICY_ID)
VALUES (123, 1), (123, 3);  -- API 123 is allowed on Bronze (tier 1) and Gold (tier 3)
```

**Step 3: Query for Policies**

When the CP needs to return `GET /apis/{id}/policies`, it queries:

```sql
SELECT 
  p.NAME,
  p.DESCRIPTION,
  p.RATE_LIMIT,
  p.QUOTA_TYPE
FROM AM_POLICY_SUBSCRIPTION p
INNER JOIN AM_API_TIER at ON p.POLICY_ID = at.TIER_POLICY_ID
WHERE at.API_ID = ?
ORDER BY p.RATE_LIMIT DESC;
```

**Step 4: Caching in the CP**

For performance, the CP caches tier descriptions in memory or in Redis:

```go
// In the CP boot-up:
var tierCache = map[string]TierInfo{
    "Bronze":    {Description: "1000 requests per minute", RateLimit: 1000},
    "Silver":    {Description: "2000 requests per minute", RateLimit: 2000},
    "Gold":      {Description: "5000 requests per minute", RateLimit: 5000},
    "Unlimited": {Description: "No rate limit", RateLimit: 0},
}
```

### In This Lab

We hardcoded the tier descriptions in the `tierDescription()` function:

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

This simulates what the CP does when it loads tier metadata from the database.

### Production Considerations

1. **Tier Validation** — When a client tries to set `allowedTiers: ["Gold", "InvalidTier"]`, the CP should reject "InvalidTier" as it's not in `AM_POLICY_SUBSCRIPTION`.

2. **Rate Limit Enforcement** — The GW reads the tier descriptions and enforces the rate limits on incoming requests.

3. **Custom Tiers** — Admins can add custom tiers via the WSO2 admin API. The CP dynamically reads them from the database.

4. **Tier Updates** — If an admin changes a tier description (e.g., "Gold now has 10000 requests/min"), the CP needs to invalidate its cache and reload from the database.

## Key Patterns Demonstrated

### 1. Business Rule Enforcement

The tier update is blocked based on the API's current state:

```go
if api.Status == StatusPublished {
    return 400 Bad Request
}
```

This is a common pattern: "You cannot perform this action in the current state." It prevents inconsistency between the CP and GW.

### 2. Atomic Updates with Locks

The tier update happens atomically under a write lock:

```go
reg.mu.Lock()
defer reg.mu.Unlock()
// Read, check, update in one atomic block
```

If the lock is released between reading the status and updating the tiers, another goroutine might publish the API, violating the invariant.

### 3. Sub-Resource Routing

The `/apis/{id}/tiers` endpoint is a sub-resource under `/apis/{id}`. We route it by parsing the URL path:

```go
if len(parts) == 3 && parts[2] == "tiers" && req.Method == http.MethodPut {
    // Handle tier update
}
```

This is a RESTful pattern: related data lives under the parent resource.

## What's Next

In Day 34 (not built in this task), we'll add event publishing:

- When an API is published, the CP fires an event: `APIPublishedEvent { id, context, tiers, ... }`
- When tiers are updated, the CP fires: `APITiersUpdatedEvent { id, newTiers, ... }`
- The Gateway subscribes to these events and syncs its local state
- This keeps the CP and GW in sync without polling

This completes the CP-to-GW synchronization story.
