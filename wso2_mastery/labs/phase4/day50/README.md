# Day 50 — Go APIHandler Chain Lab

## Goal
Build and test a pluggable handler chain that intercepts HTTP requests and responses. Understand request short-circuiting, property sharing across handlers, and reverse-order response processing.

## Setup
```bash
cd labs/phase4/day50
go run main.go
# Output: "Go APIHandler extension blueprint on :8090"
```

## Test 1: Valid API Key (200 OK)
```bash
curl -v -H 'X-API-Key: test-key-gold' http://localhost:8090/get
```

Expected output:
- HTTP 200
- RequestLogHandler logs: `method=GET path=/get`
- APIKeyCheckHandler passes, sets `tier=Gold` in context
- LatencyTrackerHandler logs: `ms=<ms> path=/get tier=Gold`
- Response body proxied from httpbin.org `/get` endpoint

## Test 2: Missing API Key (401 Unauthorized)
```bash
curl -v http://localhost:8090/get
```

Expected output:
- HTTP 401
- RequestLogHandler logs the request
- APIKeyCheckHandler rejects with JSON: `{"code":"900901","message":"Invalid Credentials"}`
- LatencyTrackerHandler does NOT run in response (chain short-circuited)

## Test 3: Invalid API Key (401 Unauthorized)
```bash
curl -v -H 'X-API-Key: invalid-key' http://localhost:8090/get
```

Expected output:
- HTTP 401 with same error as Test 2

## Test 4: Silver Tier Key (200 OK)
```bash
curl -v -H 'X-API-Key: test-key-silver' http://localhost:8090/get
```

Expected output:
- HTTP 200
- LatencyTrackerHandler logs: `tier=Silver`

## Chain Behavior
1. **Request flow (forward):** RequestLogHandler → APIKeyCheckHandler → LatencyTrackerHandler → backend
2. **Response flow (reverse):** LatencyTrackerHandler → APIKeyCheckHandler → RequestLogHandler → client
3. **Short-circuiting:** If APIKeyCheckHandler returns `false`, LatencyTrackerHandler and backend are skipped
4. **Properties:** Each handler can write to `ctx.Properties` (e.g., `tier`) and read from prior handlers

## Notes
- Handler chain order matters: validators first, observers last
- Each handler must implement `HandleRequest`, `HandleResponse`, and `Name()`
- LatencyTrackerHandler placed last ensures it captures the full backend latency (from before backend call to after response)
