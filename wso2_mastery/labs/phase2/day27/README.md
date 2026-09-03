# Lab: Day 27 — Traffic Manager Client and Global Throttling

## Objective

Integrate a mock Traffic Manager into the gateway. The gateway now sends throttle events to the TM
and receives global throttle decisions (for testing, the mock TM is permissive).

This lab demonstrates the complete flow in a single-replica or multi-replica setup:
1. GW checks local token bucket
2. If request allowed, GW sends event to TM (async)
3. TM logs event and returns decision (for production use)
4. In multi-replica setups, TM coordinates global quota

## Architecture

```
Client
  ↓
Gateway Port 9090
  ├─ /health (no auth required)
  ├─ /admin/subscriptions (POST to add, DELETE to remove)
  ├─ /api/info (JWT validation only)
  └─ /api/hello (JWT validation + subscription + throttle + TM event)
      ↓ (async POST to TM)
Mock Traffic Manager Port 9611
  └─ /throttle/data (POST: receives events)
      ↓ (response)
  Gateway receives decision (logged)
      ↓
Mock Backend Port 8080
```

## Request Flow for Protected Route (/api/hello)

```
1. Client sends: GET /api/hello with Authorization: Bearer <JWT>
   ↓
2-6. Same as Day 26 (JWT, subscription, throttle middleware)
   ↓
7. Throttle middleware: NEW
   ├─ Check local bucket (same as Day 26)
   ├─ If allowed: proceed
   ├─ Send event to TM asynchronously (non-blocking):
   │  ├─ POST http://tm:9611/throttle/data
   │  ├─ Payload: {applicationId, tier, count, timestamp, allowedCount}
   │  ├─ TM logs event
   │  └─ TM returns: {throttled, globalCount}
   │
   ├─ GW logs TM response (for diagnostics)
   └─ Continue with request (TM response is for future decisions)
   ↓
8. Recovery → Proxy → Backend → Response
```

## Prerequisites

- Phase 1 Go Key Manager running on port 8888
- Docker and Docker Compose installed
- Day 26 lab completed and understood

## Running the Lab

### Step 1: Start the Gateway, Backend, and Mock TM

```bash
cd labs/phase2/day27
docker-compose up --build
```

You should see:
```
gateway_1  | mock backend starting on port 8080
gateway_1  | mock traffic manager starting on port 9611
gateway_1  | gateway starting on port 9090
```

Three servers are now running:
- **Gateway** on port 9090
- **Backend** on port 8080
- **Traffic Manager** on port 9611

### Step 2: Add a Subscription

```bash
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app1",
    "apiname":"hello",
    "subscriptiontier":"gold",
    "keytype":"PRODUCTION"
  }'
```

### Step 3: Get a Token

```bash
TOKEN=$(curl -s http://localhost:8888/token?username=alice&appname=app1 | jq -r .token)
echo $TOKEN
```

### Step 4: Make a Request

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello
```

Expected: Mock backend response

Check the logs:
```bash
docker-compose logs gateway
# You should see entries like:
# "throttle event sent to TM app=app1 tier=gold"
```

### Step 5: Check TM Logs

```bash
docker-compose logs tm
```

Expected logs:
```
tm_1 | throttle event received from GW app=app1 tier=gold count=1 allowedCount=5000
```

### Step 6: Verify TM Receives Events

Make multiple requests and check TM logs:

```bash
for i in {1..5}; do
  curl -s -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello > /dev/null
done

docker-compose logs tm | grep "throttle event received"
```

Expected: 5 events logged by TM

### Step 7: Test with Multiple Apps

```bash
# Add Silver tier subscription for app2
curl -X POST http://localhost:9090/admin/subscriptions \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname":"app2",
    "apiname":"hello",
    "subscriptiontier":"silver",
    "keytype":"PRODUCTION"
  }'

# Get token for app2
TOKEN2=$(curl -s http://localhost:8888/token?username=bob&appname=app2 | jq -r .token)

# Send requests from both apps
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello > /dev/null
curl -s -H "Authorization: Bearer $TOKEN2" http://localhost:9090/api/hello > /dev/null
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello > /dev/null

# Check TM logs
docker-compose logs tm | tail -10
```

Expected: Events from both app1 (Gold) and app2 (Silver) logged separately

### Step 8: Verify Throttle Still Works

The local throttle from Day 26 still applies:

```bash
# Hammer app1 (Gold: ~83 req/sec)
for i in {1..100}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" http://localhost:9090/api/hello)
  if [ "$CODE" = "429" ]; then
    echo "Throttled at request $i"
    break
  fi
done
```

Expected: Throttle still works at ~request 84 (local bucket exhausted)

### Step 9: Inspect TM Event Payload

The TM receives JSON events with structure:

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

Check the TM logs to see these events being parsed and logged.

---

## Error Responses Reference

| Scenario | Status Code | Response |
|----------|------------|----------|
| Missing token | 401 | `{"error":"missing_token"}` |
| Invalid token | 401 | `{"error":"invalid_token"}` |
| Subscription not found | 403 | `{"code":"900908","message":"Resource forbidden"}` |
| Throttle limit exceeded | 429 | `{"code":"900801","message":"Application level throttle limit exceeded"}` |
| Internal error | 500 | `{"error":"internal_server_error"}` |

---

## Code Walkthrough

### Mock TM Handler

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
		)

		// Mock TM: always return not throttled (permissive for testing)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"throttled":false,"globalCount":1000,"allowedCount":5000}`)
	}
}
```

The mock TM:
1. Accepts POST requests at `/throttle/data`
2. Parses the throttle event JSON
3. Logs the event (shows in docker-compose logs)
4. Returns a permissive decision (not throttled)

### Sending Throttle Events from GW

In the throttle middleware:

```go
if !limiter.Allow() {
    // Throttle locally
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusTooManyRequests)
    fmt.Fprint(w, `{"code":"900801","message":"Application level throttle limit exceeded"}`)
    return
}

// Send throttle event to TM (async, non-blocking)
go sendThrottleEventToTM(claims.ApplicationName, claims.ApplicationTier)
```

The event is sent asynchronously (in a goroutine) so it doesn't block the request handler.

### TM URL Configuration

```go
func sendThrottleEventToTM(applicationName, tier string) {
	tmURL := os.Getenv("TM_URL")
	if tmURL == "" {
		tmURL = "http://localhost:9611"
	}
	// ... send POST to tmURL + "/throttle/data"
}
```

The TM URL can be set via environment variable `TM_URL`. This allows:
- **Dev**: `TM_URL=http://localhost:9611` (local mock)
- **Production**: `TM_URL=http://traffic-manager.corp.com:9611` (real TM)

---

## Exercises

### Exercise 1: Modify the Mock TM to Track Global Counts

Enhance the mock TM to maintain a global counter for each app::tier:

**Hint:** Add a `sync.Map` to store global counts, and update the response to return real global counts.

**Solution sketch:**

```go
var globalCounters sync.Map  // key: "app::tier" → count

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
		)
		
		// Return real global count
		throttled := newCount > event.AllowedCount
		w.Header().Set("Content-Type", "application/json")
		resp := map[string]interface{}{
			"throttled":   throttled,
			"globalCount": newCount,
			"allowedCount": event.AllowedCount,
		}
		json.NewEncoder(w).Encode(resp)
	}
}
```

This simulates a real TM that tracks global counts and returns throttle decisions.

---

### Exercise 2: Add Periodic Reset of Global Counters

Real TMs reset counters periodically (e.g., every minute or hour). Add a reset mechanism to the mock TM:

**Hint:** Use a `time.Ticker` to reset all counters every minute.

**Solution sketch:**

```go
func startCounterResetTicker() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	
	for range ticker.C {
		globalCounters.Range(func(key, value interface{}) bool {
			globalCounters.Store(key, 0)  // Reset to 0
			return true
		})
		slog.Info("global counters reset")
	}
}

// Call in main():
go startCounterResetTicker()
```

This simulates real TM behavior where quotas reset periodically.

---

### Exercise 3: Add a Diagnostics Endpoint to the Mock TM

Create a GET endpoint at the mock TM that returns all global counters and their current state:

**Hint:** Add a GET handler that iterates over `globalCounters` and returns JSON.

**Solution sketch:**

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
				"limiter_key": key.(string),
				"count":       value.(int),
			})
			return true
		})
		
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"counters": stats,
		})
	}
}

// In main(), add to TM mux:
tmMux.HandleFunc("GET /stats", newMockTMStatsHandler())
```

Usage:
```bash
curl http://localhost:9611/stats
```

---

## Testing Scenarios

### Scenario 1: Single App, Multiple Requests

1. Add subscription for app1 (Gold tier)
2. Send 10 requests
3. Verify TM receives 10 events (check logs)

### Scenario 2: Multiple Apps with Different Tiers

1. Add subscriptions for app1 (Gold) and app2 (Silver)
2. Send 5 requests from app1, 5 from app2
3. Verify TM logs show both app1 and app2 events

### Scenario 3: Throttle Local Before TM

1. Add subscription for app1 (Gold: ~83 req/sec)
2. Hammer with 100 requests
3. Verify: first ~83 are 200 (sent to TM), rest are 429 (throttled locally)
4. TM logs should show ~83 events (only allowed requests send events)

### Scenario 4: TM Diagnostics Endpoint

1. Make requests from multiple apps
2. Call TM stats endpoint (if implemented)
3. Verify global counts are accurate

---

## Common Mistakes

- **Blocking on TM response** — Event sending should be async. Always use `go sendThrottleEvent(...)`.
- **Not handling TM failures** — If TM is down, requests should still proceed (local bucket is sufficient). Failures are logged but not fatal.
- **Sending events for throttled requests** — Only allowed requests (local bucket still has tokens) should send events to TM.
- **Hardcoding TM URL** — Always use an environment variable for easy testing and production deployment.

---

## Next Steps

- **Production deployment:** Replace mock TM with real WSO2 Traffic Manager.
- **Multi-replica testing:** Spin up multiple GW instances and verify global throttling coordination.
- **Resilience patterns:** Add retry logic, circuit breaker, and fallback behavior for TM failures.
- **Task 5:** Add gateway debug patterns (detailed logging, metrics, distributed tracing).

---

## Teardown

Stop the gateway, backend, and mock TM:

```bash
Ctrl+C
docker-compose down -v
```

All three servers (gateway, backend, TM) will be stopped and containers removed.
