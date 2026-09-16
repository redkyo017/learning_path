# Day 33 — Lab: Tier and Policy Management

## Goal

Extend the CP API registry (Day 32) with subscription tier and policy management. Learn why the Control Plane and Gateway must coordinate tier information, and why you can't change tiers while an API is PUBLISHED.

## Prerequisites

- Go 1.19 or later
- `curl` (for testing)
- Familiarity with Day 32 lab

## Running the Lab

### Step 1: Start the Server

Navigate to this directory and run:

```bash
go run main.go
```

You should see:
```
WSO2 CP — API Registry with Policies listening on :8082
```

### Step 2: Test the New Endpoints

#### Test 1: Create an API with Tiers

```bash
curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"PaymentAPI",
    "context":"/payment/v1",
    "version":"1.0",
    "backendUrl":"http://payments:9000",
    "allowedTiers":["Bronze","Gold"]
  }' | jq .
```

Copy the `id` from the response. Let's call it `{id}`.

#### Test 2: Get Policies for an API

```bash
curl -s http://localhost:8082/apis/{id}/policies | jq .
```

**Expected output:**
```json
[
  {
    "name":"Bronze",
    "description":"1000 requests per minute"
  },
  {
    "name":"Gold",
    "description":"5000 requests per minute"
  }
]
```

The policies list mirrors the allowed tiers, with descriptions added.

#### Test 3: Update Tiers (Before Publishing)

```bash
curl -s -X PUT http://localhost:8082/apis/{id}/tiers \
  -H 'Content-Type: application/json' \
  -d '{"tiers":["Silver","Unlimited"]}' | jq .
```

**Expected output:**
```json
{
  "id":"...",
  "name":"PaymentAPI",
  "context":"/payment/v1",
  "version":"1.0",
  "backendUrl":"http://payments:9000",
  "status":"CREATED",
  "allowedTiers":["Silver","Unlimited"],
  "createdAt":"..."
}
```

The tiers have been updated to Silver and Unlimited.

#### Test 4: Get Updated Policies

```bash
curl -s http://localhost:8082/apis/{id}/policies | jq .
```

**Expected output:**
```json
[
  {
    "name":"Silver",
    "description":"2000 requests per minute"
  },
  {
    "name":"Unlimited",
    "description":"No rate limit"
  }
]
```

#### Test 5: Publish the API

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Publish"}' | jq .
```

**Expected output:**
```json
{
  "id":"...",
  "name":"PaymentAPI",
  ...
  "status":"PUBLISHED",
  "allowedTiers":["Silver","Unlimited"],
  ...
}
```

The API is now PUBLISHED.

#### Test 6: Try to Change Tiers While PUBLISHED

```bash
curl -s -X PUT http://localhost:8082/apis/{id}/tiers \
  -H 'Content-Type: application/json' \
  -d '{"tiers":["Gold"]}' | jq .
```

**Expected output (error):**
```json
{"error":"deprecate the API before changing tiers"}
```

Status code: `400 Bad Request`.

This is the critical business rule: you cannot change subscription tiers while an API is PUBLISHED.

#### Test 7: Deprecate the API

```bash
curl -s -X POST http://localhost:8082/apis/{id}/lifecycle \
  -H 'Content-Type: application/json' \
  -d '{"action":"Deprecate"}' | jq .
```

**Expected output:**
```json
{
  "id":"...",
  ...
  "status":"DEPRECATED",
  ...
}
```

#### Test 8: Now Change Tiers While DEPRECATED

```bash
curl -s -X PUT http://localhost:8082/apis/{id}/tiers \
  -H 'Content-Type: application/json' \
  -d '{"tiers":["Gold","Silver"]}' | jq .
```

**Expected output:**
```json
{
  "id":"...",
  ...
  "status":"DEPRECATED",
  "allowedTiers":["Gold","Silver"],
  ...
}
```

Success! Tier changes are allowed for DEPRECATED APIs.

#### Test 9: Verify Policies Updated

```bash
curl -s http://localhost:8082/apis/{id}/policies | jq .
```

**Expected output:**
```json
[
  {
    "name":"Gold",
    "description":"5000 requests per minute"
  },
  {
    "name":"Silver",
    "description":"2000 requests per minute"
  }
]
```

#### Test 10: Empty Tier List

Create a new API and try to get its policies with no allowed tiers:

```bash
curl -s -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{
    "name":"EmptyAPI",
    "context":"/empty/v1",
    "version":"1.0",
    "backendUrl":"http://empty:9000",
    "allowedTiers":[]
  }' | jq .
```

Copy the `id`, then:

```bash
curl -s http://localhost:8082/apis/{id}/policies | jq .
```

**Expected output:**
```json
[]
```

An empty array, not `null`. This is important for GW deserialization.

## Exercises (Answer in a File Called `answers.md`)

### Exercise 1: Tier Update Business Rule
**Q:** Why does the API return `400 Bad Request` when you try to change tiers while the API is PUBLISHED?

**Hint:** Think about what the Gateway is doing while the API is PUBLISHED. If the tiers changed in the CP, but the GW didn't know about it, what would happen?

**Solution sketch:**
```
When an API is PUBLISHED, the Gateway has activated the route and is routing traffic to it.
The GW has cached the allowed subscription tiers for that API in memory.

If the CP changes the tiers while PUBLISHED:
  1. New subscribers might try to use a tier that no longer exists
  2. Existing subscribers might be using a tier that was removed
  3. The GW and CP would be out of sync until the next event sync

The solution is to lock tier changes behind a deprecation:
  1. PUBLISHED → DEPRECATED (this is safe; existing subs still work)
  2. Change tiers (DEPRECATED APIs can have their tiers modified)
  3. Optionally re-publish with new tiers

This mirrors real-world API versioning: never break existing subscribers.
```

### Exercise 2: Delete Tier Endpoint
**Q:** Add a `DELETE /apis/{id}/tiers/{tier}` endpoint that removes a single tier from the allowed list. It should follow the same "no changes while PUBLISHED" rule as PUT.

**Hint:** Add a new condition before the method switch. Check for `len(parts) == 4` with `parts[2] == "tiers"` and `req.Method == http.MethodDelete`. Extract the tier name from `parts[3]`.

**Solution sketch:**
```go
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

### Exercise 3: Tier Description Sourcing
**Q:** In the code, `tierDescription()` returns hardcoded descriptions. In production WSO2, where does this come from, and how is it loaded?

**Hint:** Think about the WSO2 database schema. There's a table for subscription policies. Find the column that stores descriptions.

**Solution sketch:**
```
In production WSO2, subscription tiers are stored in the AM_POLICY_SUBSCRIPTION table.

Columns include:
  - POLICY_ID (unique key)
  - NAME (e.g., "Gold")
  - DESCRIPTION (e.g., "5000 requests per minute")
  - QUOTA_TYPE ("RequestCountLimit", "BandwidthLimit", etc.)
  - RATE_LIMIT (in requests per minute)
  - BURST_LIMIT
  - BILLING_PLAN

When the CP loads an API, it queries:
  SELECT api.id, api.name, api.context, policy.name, policy.description, ...
  FROM am_api api
  LEFT JOIN am_api_tier apitier ON api.id = apitier.api_id
  LEFT JOIN am_policy_subscription policy ON apitier.tier_policy_id = policy.policy_id

The CP caches the tier descriptions in memory or (for performance) in Redis.
When creating/updating an API, it validates that the requested tier names exist in AM_POLICY_SUBSCRIPTION.

In this lab, we simulate this by defining standard tier descriptions.
```

## What You Learned

- How the CP manages subscription tiers per API
- Why tier changes are blocked during PUBLISHED state
- How the GW and CP must coordinate policy information
- The importance of business rule enforcement across all endpoints
- How to structure complex HTTP handlers with multiple sub-resources

## The CP-to-GW Synchronization Pattern

By the end of this day, you've built the CP side of the tier/policy system:

**CP side (today):**
- Stores which tiers are allowed for each API
- Validates tier changes (no changes while PUBLISHED)
- Returns tier descriptions and policies

**GW side (not built today, but conceptually):**
- Receives policy updates from the CP (via events)
- Caches the allowed tiers for each API context
- Uses the tier list to validate subscription requests

**Sync protocol:**
```
When CP publishes an API:
  1. CP fires event: { api_id, context, status=PUBLISHED, allowed_tiers=[...] }
  2. GW receives event
  3. GW adds context to its route table with the tier restrictions
  4. Future requests to that context are routed with tier validation

When CP deprecates an API:
  1. CP fires event: { api_id, context, status=DEPRECATED, ... }
  2. GW receives event
  3. GW keeps the route active (existing subs still work)
  4. GW marks it as deprecated for new subscriptions

When CP changes tiers (after deprecation):
  1. CP updates AllowedTiers in the database
  2. CP fires event: { api_id, context, status=DEPRECATED, allowed_tiers=[...] }
  3. GW receives event
  4. GW updates its cached tier list for that context
```

## Next Steps

Day 34 will add event publishing, so the GW can receive real-time notifications of API changes.
