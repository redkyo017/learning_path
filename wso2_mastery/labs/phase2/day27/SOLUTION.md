# Solution: Day 27 — Traffic Manager Client and Global Throttling

## Overview

This solution extends Day 26 by adding a mock Traffic Manager (TM) server and integrating TM event
sending into the gateway's throttle middleware.

### Key Additions

1. **Mock TM Server**: Listens on port 9611, accepts throttle events at `/throttle/data`
2. **Event Sending**: Gateway sends throttle events to TM asynchronously
3. **TM Response Handling**: Logs TM responses (for future production use)

## Architecture

Three servers now run together:

```
Gateway (9090) ← HTTP requests
  ├─ Sends throttle events to TM (9611) asynchronously
  ├─ Calls backend (8080)
  └─ Returns response to client

TM (9611)
  └─ Receives POST /throttle/data
  └─ Logs events
  └─ Returns decision (throttled: bool)

Backend (8080)
  └─ Mock backend for testing
```

## Key Components

### 1. Mock Traffic Manager Handler

```go
func newMockTMHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var event struct {
			ApplicationID  string `json:"applicationId"`
			SubscriptionID string `json:"subscriptionId"`
			Tier           string `json:"tier"`
			UserID         string `json:"userId"`
			Timestamp      string `json:"timestamp"`
			Count          int    `json:"count"`
			AllowedCount   int    `json:"allowedCount"`
		}

		if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
			http.Error(w, `{"error":"invalid_json"}`, http.StatusBadRequest)
			return
		}

		slog.Info("throttle event received from GW",
			"app", event.ApplicationID,
			"tier", event.Tier,
			"count", event.Count,
			"allowedCount", event.AllowedCount,
		)

		// Mock TM: always return not throttled (permissive for testing)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"throttled":false,"globalCount":1000,"allowedCount":5000}`)
	}
}
```

**Key points:**
- Validates HTTP method (POST only)
- Parses throttle event JSON
- Logs event details for inspection
- Returns permissive decision (not throttled) — fine for mock/testing

### 2. Throttle Event Structure

The event sent from GW to TM:

```json
{
  "applicationId": "app1",
  "subscriptionId": "app1::gold",
  "tier": "gold",
  "userId": "unknown",
  "timestamp": "2026-09-03T10:30:00Z",
  "count": 1,
  "allowedCount": 5000
}
```

**Fields:**
- `applicationId`: App name from JWT
- `subscriptionId`: Composite key app::tier
- `tier`: Subscription tier (gold, silver, bronze, unlimited)
- `userId`: Subscriber from JWT (set to "unknown" for mock)
- `timestamp`: ISO 8601 timestamp when event occurred
- `count`: Number of requests in this batch (1 per request in mock)
- `allowedCount`: Quota for this tier

### 3. Sending Throttle Events from GW

In `throttleMiddleware`:

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

		// Send throttle event to TM (async, non-blocking)
		go sendThrottleEventToTM(claims.ApplicationName, claims.ApplicationTier)

		next.ServeHTTP(w, r)
	})
}
```

**Key points:**
- Event sending is **asynchronous** (`go sendThrottleEventToTM()`)
- Only allowed requests send events (throttled requests return 429 immediately)
- Event sending doesn't block the request handler

### 4. Throttle Event Sending Function

```go
func sendThrottleEventToTM(applicationName, tier string) {
	tmURL := os.Getenv("TM_URL")
	if tmURL == "" {
		tmURL = "http://localhost:9611"
	}

	event := map[string]interface{}{
		"applicationId":  applicationName,
		"subscriptionId": applicationName + "::" + tier,
		"tier":           tier,
		"userId":         "unknown",
		"timestamp":      time.Now().UTC().Format(time.RFC3339),
		"count":          1,
		"allowedCount":   5000,
	}

	body, _ := json.Marshal(event)
	resp, err := http.Post(tmURL+"/throttle/data", "application/json", bytes.NewReader(body))
	if err != nil {
		slog.Warn("failed to send throttle event to TM", "err", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		slog.Warn("TM returned error", "status", resp.StatusCode)
		return
	}

	slog.Debug("throttle event sent to TM", "app", applicationName, "tier", tier)
}
```

**Key points:**
- TM URL configurable via environment variable (allows dev/prod switching)
- Event is JSON-marshaled and sent via HTTP POST
- Errors are logged but don't crash the gateway
- Successful sends are logged at DEBUG level (verbose)

### 5. Mock TM Server in main()

```go
func main() {
	// ... existing setup ...

	tmPort := os.Getenv("TM_PORT")
	if tmPort == "" {
		tmPort = "9611"
	}

	// --- Mock Traffic Manager server (separate port) ---
	tmMux := http.NewServeMux()
	tmMux.HandleFunc("/throttle/data", newMockTMHandler())
	tmSrv := &http.Server{Addr: ":" + tmPort, Handler: tmMux}

	go func() {
		slog.Info("mock traffic manager starting", "port", tmPort)
		if err := tmSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("TM error", "err", err)
		}
	}()

	// ... existing backend and gateway setup ...

	// Graceful shutdown includes TM server
	if err := tmSrv.Shutdown(shutCtx); err != nil {
		slog.Error("TM shutdown error", "err", err)
	}
}
```

**Key points:**
- TM runs in a separate goroutine
- TM listens on its own port (9611)
- TM is included in graceful shutdown

## Testing the Implementation

### Verify TM Receives Events

```bash
# Start lab
cd labs/phase2/day27
docker-compose up --build

# In another terminal, add subscription
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold","keytype":"PRODUCTION"}'

# Get token
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

# Make request
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello

# Check TM logs
docker-compose logs tm
```

**Expected output:**
```
tm_1 | throttle event received from GW app=app1 tier=gold count=1 allowedCount=5000
```

### Verify Async Event Sending (Non-blocking)

Make a request and verify the response is immediate (not waiting for TM):

```bash
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)

time curl -s -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
# Should be <100ms (not waiting for TM response)
```

**Expected:** Response is fast (proves async, non-blocking)

### Verify Per-App Event Tracking

```bash
# Add two apps with different tiers
curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app1","apiname":"hello","subscriptiontier":"gold",...}'

curl -X POST http://localhost:9090/admin/subscriptions \
  -d '{"applicationname":"app2","apiname":"hello","subscriptiontier":"silver",...}'

# Get tokens
TOKEN1=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Send requests from both apps
for i in {1..3}; do
  curl -s -H "Authorization: Bearer $TOKEN1" http://localhost:9090/api/hello > /dev/null
  curl -s -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello > /dev/null
done

# Check TM logs
docker-compose logs tm | grep "throttle event received"
```

**Expected:** 6 events total (3 from app1, 3 from app2), each with correct tier:
```
tm_1 | throttle event received from GW app=app1 tier=gold count=1 ...
tm_1 | throttle event received from GW app=app2 tier=silver count=1 ...
tm_1 | throttle event received from GW app=app1 tier=gold count=1 ...
...
```

## Exercise Solutions

### Exercise 1: Track Global Counts in Mock TM

Enhanced mock TM that maintains real global counters:

```go
var globalCounters sync.Map  // "app::tier" → count

func newMockTMHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// ... parse event ...

		// Update global counter
		key := event.ApplicationID + "::" + event.Tier
		currentVal, _ := globalCounters.LoadOrStore(key, 0)
		current := currentVal.(int)
		newCount := current + event.Count
		globalCounters.Store(key, newCount)

		slog.Info("throttle event received",
			"app", event.ApplicationID,
			"globalCount", newCount,
			"allowedCount", event.AllowedCount,
		)

		// Return real global count and throttle decision
		throttled := newCount > event.AllowedCount
		w.Header().Set("Content-Type", "application/json")
		resp := map[string]interface{}{
			"throttled":    throttled,
			"globalCount":  newCount,
			"allowedCount": event.AllowedCount,
		}
		json.NewEncoder(w).Encode(resp)
	}
}
```

With this enhancement:
- TM tracks actual global counts for each app::tier
- Returns `throttled=true` when quota is exceeded
- Simulates real TM behavior

### Exercise 2: Periodic Counter Reset

Add a ticker to reset counters (simulates quota windows):

```go
func startCounterResetTicker() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		globalCounters.Range(func(key, value interface{}) bool {
			globalCounters.Store(key, 0)
			slog.Info("counter reset", "key", key)
			return true
		})
		slog.Info("all global counters reset")
	}
}

// In main():
go startCounterResetTicker()
```

This simulates real TM behavior where quotas reset periodically (minute, hour, day).

### Exercise 3: TM Diagnostics Endpoint

Add a GET endpoint to inspect current state:

```go
func newMockTMStatsHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, `{"error":"method_not_allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var stats []map[string]interface{}
		globalCounters.Range(func(key, value interface{}) bool {
			stats = append(stats, map[string]interface{}{
				"app_tier": key.(string),
				"count":    value.(int),
			})
			return true
		})

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"counters": stats,
		})
	}
}

// Add to TM mux in main():
tmMux.HandleFunc("GET /stats", newMockTMStatsHandler())
```

Usage:
```bash
curl http://localhost:9611/stats

# Response:
{
  "counters": [
    {"app_tier": "app1::gold", "count": 42},
    {"app_tier": "app2::silver", "count": 18}
  ]
}
```

## Summary

The Day 27 solution completes the throttle architecture with:

1. **Mock TM Server**: Accepts and logs throttle events at `/throttle/data`
2. **Event Sending**: Gateway sends events asynchronously (non-blocking)
3. **Per-App Tracking**: Each app::tier has independent event streams
4. **Error Resilience**: TM failures don't impact request handling

The local token bucket (Day 26) remains the primary mechanism for single-replica deployments.
The TM adds global coordination for multi-replica setups (see Day 27 content file).

The mock TM is suitable for development and testing. In production, replace with real WSO2 TM
by setting `TM_URL` environment variable to point to the real TM instance.
