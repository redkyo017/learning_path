# Day 35 — Building the Subscription Store: Applications and Subscriptions

## Why This Matters

Day 34 taught you the **what** (subscription data model). Day 35 teaches you the **how** (building the store in Go). The subscription store is the service that the Gateway queries when it needs to validate access. Getting the data structure right is critical: a slow lookup means slow request latency; an incorrect business rule means incorrect access control.

## Core Concepts

### Cryptographic Key Generation

Applications need strong, unique ConsumerKey and ConsumerSecret values. WSO2 uses `crypto/rand` (not `math/rand`), which is cryptographically secure.

```go
func newKey() string {
    b := make([]byte, 16)
    rand.Read(b)  // crypto/rand.Read (from "crypto/rand" import)
    return hex.EncodeToString(b)  // Returns 32-char hex string
}
```

**Why not `math/rand`?**
- `math/rand` is seeded with the current time, so it's predictable
- An attacker can guess the ConsumerKey after observing a few values
- `crypto/rand` uses OS entropy (e.g., `/dev/urandom` on Linux)

**Why hex-encode?**
- The raw bytes are binary; hex encoding makes them human-readable and safe for JSON/URLs
- 16 bytes → 32 hex characters (each byte = 2 hex digits)

### The Two-Index Design

The subscription store uses two separate maps for different access patterns:

```go
type Store struct {
    mu     sync.RWMutex
    apps   map[string]*Application   // id → app (for create/retrieve)
    byKey  map[string]*Application   // consumerKey → app (for validation)
    subs   map[string]*Subscription  // id → sub
    subIdx map[string][]*Subscription // appId → []sub (for listing by app)
}
```

**Why two maps?**

1. **`apps` (by ID)**: Used when registering/retrieving applications by ID
   - Lookup: `POST /applications` returns new app with ID
   - Lookup: `GET /applications/{id}` retrieves by ID
   - Pattern: O(1) by ID

2. **`byKey` (by ConsumerKey)**: Used for validation at request time
   - Lookup: GW has JWT with app name; translates to ConsumerKey; looks up app
   - Lookup: Validation query `GET /subscriptions/validate?consumerKey=...`
   - Pattern: O(1) by ConsumerKey

Using a single map would force O(n) scans on the validation path, which is catastrophic under load. Most requests go through validation; it must be fast.

### The Subscription Index

The `subIdx` map is a secondary index for fast listing:

```go
subIdx map[string][]*Subscription  // appId → []*Subscription
```

When you call `GET /subscriptions?appId={id}`, you don't iterate through all subscriptions; you directly access `subIdx[appId]`.

### Application Model

```go
type Application struct {
    ID             string    `json:"id"`
    Name           string    `json:"name"`
    ConsumerKey    string    `json:"consumerKey"`
    ConsumerSecret string    `json:"consumerSecret"`
    Owner          string    `json:"owner"`
    CallbackURL    string    `json:"callbackUrl"`
    CreatedAt      time.Time `json:"createdAt"`
}
```

**Key rule:** ConsumerSecret is exposed in the creation response only. On all subsequent GETs, return `"consumerSecret": "***"` to prevent leakage.

### Subscription Model

```go
type Subscription struct {
    ID        string             `json:"id"`
    AppID     string             `json:"appId"`
    APIID     string             `json:"apiId"`
    Tier      string             `json:"tier"`
    Status    SubscriptionStatus `json:"status"`
    CreatedAt time.Time          `json:"createdAt"`
}

type SubscriptionStatus string
const (
    SubUnblocked SubscriptionStatus = "UNBLOCKED"
    SubBlocked   SubscriptionStatus = "BLOCKED"
)
```

### POST /applications — Creating an App

**Request:**
```json
{
  "name": "PetApp",
  "owner": "alice",
  "callbackUrl": "https://petapp.example.com/callback"
}
```

**Response (201 Created):**
```json
{
  "id": "abc123de",
  "name": "PetApp",
  "consumerKey": "abcd1234ef567890...",
  "consumerSecret": "secret1234567890...",
  "owner": "alice",
  "callbackUrl": "https://petapp.example.com/callback",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

**Important:** The response includes the ConsumerSecret. The developer must save it immediately; it's never shown again.

### GET /applications/{id} — Retrieving an App

**Request:**
```
GET /applications/abc123de
```

**Response (200 OK):**
```json
{
  "id": "abc123de",
  "name": "PetApp",
  "consumerKey": "abcd1234ef567890...",
  "consumerSecret": "***",
  "owner": "alice",
  "callbackUrl": "https://petapp.example.com/callback",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

**Important:** The ConsumerSecret is masked as `"***"`. This prevents accidental leakage when sharing logs or screenshots.

### POST /subscriptions — Creating a Subscription

**Request:**
```json
{
  "appId": "abc123de",
  "apiId": "petstore-abc",
  "tier": "Gold"
}
```

**Response (201 Created):**
```json
{
  "id": "sub12345",
  "appId": "abc123de",
  "apiId": "petstore-abc",
  "tier": "Gold",
  "status": "UNBLOCKED",
  "createdAt": "2026-09-16T12:00:00Z"
}
```

### GET /subscriptions?appId={id} — Listing Subscriptions

**Request:**
```
GET /subscriptions?appId=abc123de
```

**Response (200 OK):**
```json
[
  {
    "id": "sub12345",
    "appId": "abc123de",
    "apiId": "petstore-abc",
    "tier": "Gold",
    "status": "UNBLOCKED",
    "createdAt": "2026-09-16T12:00:00Z"
  },
  {
    "id": "sub67890",
    "appId": "abc123de",
    "apiId": "users-xyz",
    "tier": "Bronze",
    "status": "UNBLOCKED",
    "createdAt": "2026-09-16T11:55:00Z"
  }
]
```

If no subscriptions exist, return `[]` (never `null`).

## Exercises

### Exercise 1: Soft Delete with Status
**Q:** Add a `DELETE /subscriptions/{id}` endpoint that sets `Status = BLOCKED` rather than deleting the record.

**Hint:** WSO2 soft-deletes subscriptions. Find the subscription, set its `Status` field to `SubBlocked`, and return the updated subscription. Don't remove it from any maps.

**Solution sketch:**
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
    // ... other methods
})
```

### Exercise 2: Duplicate Subscription Prevention
**Q:** Two applications both try to subscribe to the same API. How does the store prevent duplicate subscriptions?

**Hint:** Before inserting a new subscription, check `subIdx[appID]` to see if a subscription with the same `APIID` already exists. Return a 409 Conflict if it does.

**Solution sketch:**
```go
// In createSub method, after decoding the body:
s.mu.Lock()
defer s.mu.Unlock()

// Check for duplicate subscription
existing := s.subIdx[body.AppID]
for _, sub := range existing {
    if sub.APIID == body.APIID && sub.Status == SubUnblocked {
        http.Error(w, "subscription already exists", http.StatusConflict)
        return
    }
}

// If no duplicate, insert
sub := &Subscription{
    ID: newID(), AppID: body.AppID, APIID: body.APIID,
    Tier: body.Tier, Status: SubUnblocked, CreatedAt: time.Now().UTC(),
}
s.subs[sub.ID] = sub
s.subIdx[sub.AppID] = append(s.subIdx[sub.AppID], sub)
writeJSON(w, http.StatusCreated, sub)
```

### Exercise 3: Why Two Maps?
**Q:** Why does the subscription store use two maps (`apps` by ID and `byKey` by consumerKey) instead of one?

**Hint:** Consider the two different lookup patterns. One is used when creating/retrieving; the other is used during validation at request time. What would happen if you used only one map?

**Solution sketch:**
```
With two maps (current design):
  - byID lookup: apps[id] → O(1)
  - byKey lookup: byKey[consumerKey] → O(1)

With one map (ID-only):
  - byID lookup: apps[id] → O(1)
  - byKey lookup: iterate all apps, check each consumerKey → O(n)
    This is catastrophic under load. Validation happens on every request.

With one map (Key-only):
  - byKey lookup: byKey[consumerKey] → O(1)
  - byID lookup: iterate all apps, find the one with matching ID → O(n)
    This is less critical (create/retrieve is less frequent), but still bad.

Conclusion: Two maps are necessary to maintain O(1) for both patterns.
This is a classic database indexing problem: you create secondary indexes
for different access patterns.
```

## Anti-Patterns to Avoid

1. **Using a single map** — Forces O(n) scan on validation. Under high load, the system fails.

2. **Not generating cryptographically random keys** — Using `math/rand` or a simple counter makes ConsumerKeys predictable. Use `crypto/rand` exclusively.

3. **Returning `ConsumerSecret` in GET responses** — If the secret is exposed in a log, screenshot, or API response, attackers can impersonate the app. Expose it only at creation time.

4. **Hard-deleting subscriptions instead of soft-deleting** — Hard deletion removes audit trails and prevents recovery. Always use soft deletion (set Status = BLOCKED).

5. **Not checking for duplicate subscriptions** — If you allow the same app to subscribe to the same API twice with different tiers, the validation logic breaks. Always check for duplicates.

6. **Using a nil slice instead of an empty array** — If `GET /subscriptions?appId=missing` returns `null`, the GW might panic. Always return `[]` (empty array).

## What You'll Build

Your lab will implement:

- **Application store** with ConsumerKey/ConsumerSecret generation
- **Subscription store** with two indexes (by ID and by ConsumerKey)
- **Endpoints:**
  - `POST /applications` → Create app with generated keys
  - `GET /applications/{id}` → Retrieve app (ConsumerSecret masked)
  - `POST /subscriptions` → Create subscription
  - `GET /subscriptions?appId={id}` → List subscriptions by app
- **Validation for duplicate subscriptions**
- **Soft-delete semantics** (mark BLOCKED, don't remove)

## The CP-to-GW Communication Pattern

The subscription store is the **data service** layer. Day 36 will add the **validation endpoint** that the GW calls. By separating concerns (store logic vs. validation logic), you can:
- Reuse the store for multiple endpoints
- Test the store independently of HTTP concerns
- Add new endpoints without duplicating store logic
