# Lab Day 17: Go Reverse Proxy with Middleware Chain

**Prerequisites:** Go 1.21+ (for `log/slog`).

No Docker, no external dependencies. All packages are from the Go standard library.

---

## What This Lab Builds

A gateway process that:
- Accepts requests on `:9090`
- Chains `requestIDMiddleware` → `loggingMiddleware` → `httputil.ReverseProxy`
- Sets `X-Request-ID` on every request (generates one if the client didn't supply it)
- Forwards `activityid` header to the backend (WSO2 correlation pattern)
- Exposes `GET /health` outside the middleware chain

---

## Run

```bash
cd labs/phase2/day17

# Point the gateway at httpbin.org for a live backend you don't have to run yourself.
BACKEND_URL=https://httpbin.org go run main.go
```

Expected startup log:

```
2026/08/31 12:00:00 INFO gateway starting port=9090 backend=https://httpbin.org
```

---

## Test

Open a second terminal.

**Health check (not proxied):**
```bash
curl -s http://localhost:9090/health
# {"status":"UP"}
```

**Proxied request (httpbin echoes your headers back):**
```bash
curl -s http://localhost:9090/get | jq .headers
```

You should see `X-Request-Id` and `Activityid` in the echoed headers (httpbin capitalises
header names). The `Activityid` value should match `X-Request-Id`.

**Supply your own request ID:**
```bash
curl -s -H "X-Request-ID: my-trace-abc" http://localhost:9090/get | jq .headers
```

`Activityid` should equal `my-trace-abc`.

**Observe slog output in the gateway terminal:**
```
2026/08/31 12:00:05 INFO request method=GET path=/get duration_ms=312
```

---

## Exercises (from content/phase2/day17.md)

1. Explain in your own words why `Chain(proxy, m1, m2)` calls `m1` before `m2` even though
   the loop iterates from the end.
2. What happens if you reverse the order to `Chain(proxy, m2, m1)`? Try it.
3. Add a third middleware that adds a `X-Gateway: go-gateway/1.0` response header (hint:
   set it on `w` after calling `next.ServeHTTP`).

---

## Stop

Press `Ctrl+C` in the gateway terminal. You should see:

```
2026/08/31 12:00:10 INFO shutdown signal received
2026/08/31 12:00:10 INFO shutdown complete
```
