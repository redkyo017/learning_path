# Lab Day 18: Complete Gateway Skeleton

**Prerequisites:** Go 1.21+. No external dependencies — stdlib only.

This lab runs two HTTP servers in the same process:
- **Gateway** on `:9090` — middleware chain + reverse proxy
- **Mock backend** on `:8080` — simple JSON responder for testing without an external server

---

## Run

```bash
cd labs/phase2/day18
go run main.go
```

Expected startup output:

```
2026/08/31 12:00:00 INFO mock backend starting port=8080
2026/08/31 12:00:00 INFO gateway starting port=9090 backend=http://localhost:8080
```

---

## Test: Health Check

The `/health` endpoint is outside the middleware chain. It should respond instantly
regardless of backend state.

```bash
curl -s http://localhost:9090/health
# {"status":"UP"}
```

---

## Test: Mock Backend via Gateway

The mock backend handles `/mock` and returns JSON. The gateway proxies everything except
`/health` through the middleware chain to the backend.

```bash
curl -s http://localhost:9090/mock | jq .
# {
#   "message": "mock backend response",
#   "path": "/mock"
# }

curl -s http://localhost:9090/mock/orders/42 | jq .
# {
#   "message": "mock backend response",
#   "path": "/mock/orders/42",
#   "method": "GET"
# }
```

Check the gateway terminal — you should see a structured slog line for each request:

```
INFO request method=GET path=/mock duration_ms=1
```

---

## Test: Request ID Correlation

Supply your own request ID and verify it appears as `activityid` on the backend side.
The mock backend echoes its response but doesn't reveal request headers directly; you
can hit the backend directly on :8080 to see what the gateway sent:

```bash
# Hit backend directly (bypasses gateway)
curl -s -H "activityid: manual-test-id" http://localhost:8080/mock

# Hit gateway — it should set activityid = X-Request-ID on the upstream request
curl -s -H "X-Request-ID: trace-abc-123" http://localhost:9090/mock
```

---

## Test: Graceful Shutdown

Press `Ctrl+C` in the gateway terminal. Observe:

```
INFO shutdown signal received
INFO shutdown complete
```

Both the gateway and the mock backend stop gracefully. In-flight requests are drained
within the 5-second timeout before the process exits.

---

## Test: Recovery Middleware (Optional)

To test the panic recovery path, temporarily add a panic to the mock backend handler
(modify `newMockBackend` in main.go to call `panic("simulated crash")`), then:

```bash
curl -s http://localhost:9090/mock
# {"error":"internal_server_error"}
```

The gateway returns 500 JSON instead of dropping the connection, and the process keeps
running. Check the gateway logs for:

```
ERROR panic recovered error=simulated crash path=/mock
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `9090` | Gateway listen port |
| `BACKEND_URL` | `http://localhost:8080` | Backend URL the proxy forwards to |
| `BACKEND_PORT` | `8080` | Mock backend listen port |

To use a real backend instead of the mock:

```bash
BACKEND_URL=https://httpbin.org go run main.go
```

---

## Exercises (from content/phase2/day18.md)

1. Why must `recoveryMiddleware` be the **last** argument to `Chain`, not the first?
2. Add a `X-Gateway-Version: 1.0` response header to all proxied responses using
   `proxy.ModifyResponse`.
3. Change the graceful shutdown timeout from 5s to 10s and explain when you would
   increase it in a production ECS Fargate deployment.
