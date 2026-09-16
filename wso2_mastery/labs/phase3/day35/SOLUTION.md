# Day 35 — Solutions and Design Explanations

## Exercise 1: Soft Delete with Status

**Q:** Add a `DELETE /subscriptions/{id}` endpoint that sets `Status = BLOCKED` rather than deleting the record.

**Solution:**

Add this handler to the main function:

```go
mux.HandleFunc("/subscriptions/", func(w http.ResponseWriter, req *http.Request) {
    id := strings.TrimPrefix(req.URL.Path, "/subscriptions/")
    if req.Method == http.MethodDelete {
        s.mu.Lock()
        sub, ok := s.subs[id]
        if !ok {
            s.mu.Unlock()
            http.Error(w, "not found", http.StatusNotFound)
            return
        }
        sub.Status = SubBlocked  // Soft delete: mark as blocked, don't remove
        s.mu.Unlock()
        writeJSON(w, http.StatusOK, sub)
        return
    }
    http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
})
```

**Why soft deletion?**
- **Audit trail:** The subscription record remains in the store; you can see who unsubscribed and when.
- **Recovery:** An admin can unblock a subscription if it was blocked by mistake.
- **State consistency:** Blocked subscriptions still count for metrics and rate limiting.
- **Real-world:** This mirrors WSO2's actual behavior; subscriptions are never hard-deleted.

**Test it:**
```bash
# Create a subscription (save the sub ID)
curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"abc123de","apiId":"petstore-v1","tier":"Gold"}'
# Response: {"id":"sub12345",...}

# Delete it (soft-delete)
curl -s -X DELETE http://localhost:8083/subscriptions/sub12345

# Response: {"id":"sub12345",...,"status":"BLOCKED"}

# List subscriptions for the app
curl -s "http://localhost:8083/subscriptions?appId=abc123de"
# Response includes the subscription with status BLOCKED
```

---

## Exercise 2: Duplicate Subscription Prevention

**Q:** Two applications both try to subscribe to the same API. How does the store prevent duplicate subscriptions?

**Solution:**

Modify the `createSub` method to check for existing subscriptions:

```go
func (s *Store) createSub(w http.ResponseWriter, req *http.Request) {
	var body struct {
		AppID string `json:"appId"`
		APIID string `json:"apiId"`
		Tier  string `json:"tier"`
	}
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil || body.AppID == "" || body.APIID == "" || body.Tier == "" {
		http.Error(w, "appId, apiId, and tier are required", http.StatusBadRequest)
		return
	}
	
	s.mu.Lock()
	defer s.mu.Unlock()
	
	// Check for duplicate: same app + API with UNBLOCKED status
	existing := s.subIdx[body.AppID]
	for _, sub := range existing {
		if sub.APIID == body.APIID && sub.Status == SubUnblocked {
			http.Error(w, "subscription already exists for this app+api pair", http.StatusConflict)
			return
		}
	}
	
	// No duplicate; create the subscription
	sub := &Subscription{
		ID: newID(), AppID: body.AppID, APIID: body.APIID,
		Tier: body.Tier, Status: SubUnblocked, CreatedAt: time.Now().UTC(),
	}
	s.subs[sub.ID] = sub
	s.subIdx[sub.AppID] = append(s.subIdx[sub.AppID], sub)
	
	// Unlock before writing response (to avoid holding lock during I/O)
	// Actually, we already have defer unlock, so we return and the lock is released
	
	writeJSON(w, http.StatusCreated, sub)
}
```

**Why this check?**
- **Data integrity:** The same app should not have two UNBLOCKED subscriptions to the same API with different tiers. It would be ambiguous which tier applies.
- **Business rule:** The triple (app, API, tier) must be unique.
- **HTTP semantics:** 409 Conflict is the correct status code for constraint violations.

**Why check only UNBLOCKED?**
- If a subscription is BLOCKED (soft-deleted), the app can subscribe again.
- A new subscription might use a different tier (upgrade/downgrade pattern).

**Test it:**
```bash
# Create app and subscribe to petstore with Gold tier
curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"abc123de","apiId":"petstore-v1","tier":"Gold"}'
# Response: 201 Created

# Try to subscribe again with a different tier (should fail)
curl -s -X POST http://localhost:8083/subscriptions \
  -H 'Content-Type: application/json' \
  -d '{"appId":"abc123de","apiId":"petstore-v1","tier":"Silver"}'
# Response: 409 Conflict
```

---

## Exercise 3: Why Two Maps?

**Q:** Why does the subscription store use two maps (`apps` by ID and `byKey` by consumerKey) instead of one?

**Solution:**

The store uses two separate maps to support two different lookup patterns with O(1) performance:

### Map 1: `apps map[string]*Application` (indexed by ID)

**Used for:**
- `POST /applications` → returns new app with ID
- `GET /applications/{id}` → retrieve by ID

**Access pattern:**
```go
app, ok := s.apps[id]  // O(1)
```

### Map 2: `byKey map[string]*Application` (indexed by ConsumerKey)

**Used for:**
- Validation: GW has JWT with app name; translates to ConsumerKey; looks up app
- `GET /subscriptions/validate?consumerKey=...` (Day 36)

**Access pattern:**
```go
app, ok := s.byKey[consumerKey]  // O(1)
```

### Why Not a Single Map?

**Scenario A: Only `apps` map (by ID)**

```go
apps map[string]*Application  // id → app

// Lookup by ID: O(1) ✓
app, ok := apps[id]

// Lookup by ConsumerKey: O(n) ✗
var app *Application
for _, a := range apps {
    if a.ConsumerKey == consumerKey {
        app = a
        break
    }
}
```

This forces a linear scan on the validation path. Under load (1000s of requests/sec), this is catastrophic.

**Scenario B: Only `byKey` map (by ConsumerKey)**

```go
apps map[string]*Application  // consumerKey → app

// Lookup by ConsumerKey: O(1) ✓
app, ok := apps[consumerKey]

// Lookup by ID: O(n) ✗
var app *Application
for _, a := range apps {
    if a.ID == id {
        app = a
        break
    }
}
```

This avoids the critical path (validation), but creates/retrieval become slow.

**Scenario C: Two maps (current design)**

```go
apps  map[string]*Application  // id → app
byKey map[string]*Application  // consumerKey → app

// Lookup by ID: O(1) ✓
app, ok := apps[id]

// Lookup by ConsumerKey: O(1) ✓
app, ok := byKey[consumerKey]
```

Both paths are fast.

### Real-World Database Analogy

In a relational database, you'd create two separate indexes on the `AM_APPLICATION` table:

```sql
CREATE INDEX idx_app_id ON AM_APPLICATION(APPLICATION_ID);
CREATE INDEX idx_consumer_key ON AM_APPLICATION(CONSUMER_KEY);

-- Query 1: Get by ID (uses idx_app_id)
SELECT * FROM AM_APPLICATION WHERE APPLICATION_ID = ?  -- O(log n) with B-tree

-- Query 2: Get by ConsumerKey (uses idx_consumer_key)
SELECT * FROM AM_APPLICATION WHERE CONSUMER_KEY = ?  -- O(log n) with B-tree
```

In-memory maps are faster (O(1) hash lookup vs. O(log n) B-tree), but the principle is the same: create a secondary index for each lookup pattern.

### Memory Cost

The two maps both store pointers to the same Application objects. Memory overhead is just two map entries per app, which is negligible.

```go
// Memory layout:
// apps["abc123de"] → pointer to Application
// byKey["xyzkey"] → pointer to the SAME Application object

// No duplication; the Application object itself is stored once in memory
```

---

## Design Pattern Summary

This implementation demonstrates the **Multi-Map Indexing** pattern, commonly used in high-performance systems:

1. **Primary storage:** `apps` map serves as the main store.
2. **Secondary index:** `byKey` map provides fast lookup by an alternative key.
3. **O(1) guarantees:** Both lookups are constant-time.
4. **Consistency:** Mutations update both maps atomically (under the same lock).

This is how databases work internally: B-tree indexes for different columns, all pointing to the same row data.

---

## What Happens on Day 36

Day 36 adds a third map to the Store:

```go
type Store struct {
    ...
    apiContextMap map[string]string  // apiContext → apiID
}
```

This map bridges the subscription store (which knows API IDs) with the Gateway (which knows API contexts like `/petstore/v1`). The three-map pattern supports even more lookup patterns while maintaining O(1) performance.
