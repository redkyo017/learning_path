# Day 15 — Phase 1 Capstone: Tracing a 401 in 5 Minutes

## What "Phase 1 Complete" Means

You can now:
- Deploy WSO2 IS and the Go Key Manager in Docker.
- Issue, introspect, and revoke JWT tokens using client_credentials.
- Read and modify `log4j2.properties` to enable DEBUG on any OAuth2 subsystem.
- Read WSO2 IS log lines and map them to specific failure classes.

Day 15 is the integration point: given a 401 in production, how do you trace it
from symptom to root cause in 5 minutes?  The answer is a decision tree, structured
logging, and the health endpoints that tell you whether IS is even up before you
dig into logs.

---

## The 401 Decision Tree

When a client receives a 401, work through this tree:

```
401 received
├── IS health check fails?
│   └── IS is DOWN → restart container; check ECS task health; check OOM kill
├── Token missing in request?
│   └── Client bug: Authorization header not set → fix the client
├── Token present but:
│   ├── "Invalid JWT" in IS logs (WARN {OAuth2TokenValidation})
│   │   ├── Signature mismatch → check JWKS kid rotation (did IS restart and generate a new key?)
│   │   └── Token expired → check clock skew; check if token_ttl is shorter than expected
│   ├── "Client Authentication failed" in IS logs (WARN {OAuthClientAuthn})
│   │   └── Wrong clientId or clientSecret → verify credentials in IS admin console
│   ├── "Invalid scope" in IS logs
│   │   └── Token scope doesn't cover the API → re-issue with correct scope; check API subscription
│   └── "Token revoked" in IS logs (INFO {OAuth2} - Revoking)
│       └── Token was explicitly revoked → check revocation event propagation to Gateway (Phase 2)
└── IS returns 200 on introspect but Gateway still 401?
    └── Gateway caching stale token state → flush Gateway cache (Phase 2/3 topic)
```

Five-minute clock:
- 0:00 — check IS is up (health endpoint)
- 0:30 — grep IS logs for WARN/ERROR around the timestamp
- 1:30 — identify the failure pattern from the five patterns table (Day 14)
- 2:30 — form a hypothesis (client creds? expired? scope?)
- 3:00 — confirm with a targeted grep on the correlation ID
- 4:00 — apply the fix (credentials / scope / restart)
- 5:00 — re-test

---

## WSO2 IS Health Endpoints

Before reading logs, confirm IS is accepting requests:

| Endpoint | Method | Expected response | Notes |
|---|---|---|---|
| `/healthz` | GET | `{"status":"UP"}` | Liveness — IS process is running |
| `/health` | GET | `{"status":"UP"}` | Alias; behavior depends on IS version |
| `/services/OAuth2TokenValidationService?wsdl` | GET | SOAP WSDL XML | SOAP endpoint check — note for Phase 2 |
| `/oauth2/token` | POST | `4xx` (not `5xx`) | Token endpoint is reachable |

Quick check:

```bash
curl -k https://<is-host>:9443/healthz
# {"status":"UP"}

curl -k https://<is-host>:9443/health
# {"status":"UP"}
```

If either returns a connection error or 5xx, IS is not healthy — logs may not
help until IS is running again.

---

## Adding Structured Logging to the Go Key Manager

The Day 12 KM already uses `log/slog` with correlation IDs.  Day 15 adds
**request logging at the start of every handler** — method, path, and
correlation ID — so every inbound request is visible in the log before any
business logic runs.

### The pattern

Each handler calls `slog.Info("request_received", ...)` as its first line:

```go
func tokenHandler(w http.ResponseWriter, r *http.Request) {
    corrID := correlationFromCtx(r.Context())
    slog.Info("request_received",
        "method", r.Method,
        "path", r.URL.Path,
        "correlation_id", corrID,
    )
    // ... rest of handler
}
```

This produces a JSON log line like:

```json
{
  "time": "2026-08-31T14:30:00Z",
  "level": "INFO",
  "msg": "request_received",
  "method": "POST",
  "path": "/api/am/keymanager/v1/oauth2/token",
  "correlation_id": "aB3xQ7mNpL_xyz123"
}
```

With this in every handler you can grep the KM logs by correlation ID and see
the full lifecycle of any request.

### Matching WSO2's MDC pattern

WSO2 IS uses the MDC key `Correlation-ID`.  The Go KM uses `correlation_id` in
JSON.  When the API Gateway forwards the `activityid` header, use that value as
the correlation ID in both systems:

```go
func correlationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := r.Header.Get("activityid")
        if id == "" {
            id = generateID()
        }
        ctx := context.WithValue(r.Context(), correlationKey{}, id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

Now `grep <activityid-value>` finds the request in both IS logs and KM logs.

---

## Phase 1 Completion Reflection

Over the last 15 days you built:

| Day | Topic | Artifact |
|---|---|---|
| 1–2 | OAuth2 + OIDC foundations | Knowledge |
| 3–4 | WSO2 IS + APIM architecture | Knowledge |
| 5–6 | Docker environment | Running IS + APIM stack |
| 7 | client_credentials flow | Working token issuance |
| 8 | JWKS + token validation | JWT verified end-to-end |
| 9 | Correlation IDs | Traceable requests |
| 10 | Token revocation | Revoke + introspect |
| 11 | Full KM endpoints | All 7 endpoints |
| 12 | Docker packaging + APIM registration | Container-ready KM |
| 13 | log4j2 configuration | Debug logging on demand |
| 14 | Log line reading | Pattern recognition |
| 15 | 401 decision tree + structured logging | Runbook + final KM |

**Phase 2 preview:**
- Replace the in-memory JWT store with a database.
- Connect the KM to WSO2 APIM's Control Plane via the Key Manager connector API.
- Trace token flows across IS → KM → Gateway using distributed tracing.

---

## Lab (Day 15)

See `labs/phase1/day15/` — add request logging to every handler in the Go KM,
observe structured JSON output, and grep by correlation_id.

---

## Exercises

**Exercise 1 — Add request logging to all handlers**

Open `labs/phase1/day15/main.go`.  Every handler already has a `corrID` line.
Add `slog.Info("request_received", ...)` before any other logic in each handler.

**Hint:** The handlers are: `tokenHandler` / `handleClientCredentials`,
`introspectHandler`, `revokeHandler`, `registerApplicationHandler`,
`deleteApplicationHandler`, `jwksHandler`, `healthHandler`.

**Solution sketch:**
```go
slog.Info("request_received",
    "method", r.Method,
    "path", r.URL.Path,
    "correlation_id", corrID,
)
```
Add this as the second statement in each handler (right after `corrID := correlationFromCtx(...)`).

**Exercise 2 — Grep by correlation ID**

Run `go run main.go` in `labs/phase1/day15/`.  Make a token request.  Find the
correlation ID in the `token_issued` log line.  Grep all log lines for that ID.

**Hint:** The output is JSON.  Use `jq` to pretty-print and filter:
`go run main.go | tee /tmp/km.log &` then after making requests:
`grep <correlation_id_value> /tmp/km.log | jq .`

**Solution sketch:**
```bash
# In terminal 1:
go run main.go 2>&1 | tee /tmp/km.log

# In terminal 2:
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "test-client:test-secret" -d "grant_type=client_credentials")

# The correlation_id appears in the km.log:
grep "token_issued" /tmp/km.log | jq .correlation_id
CORR_ID=$(grep "token_issued" /tmp/km.log | jq -r .correlation_id | head -1)
grep "$CORR_ID" /tmp/km.log | jq .
```

**Exercise 3 — Apply the 401 decision tree**

Simulate a 401 scenario: call the token endpoint with wrong credentials.  Then
trace it using the decision tree.

**Hint:** Use `curl -u "wrong-client:wrong-secret"`.  The log will show `token_rejected`
with `reason: invalid_client_credentials`.  Map this to the decision tree node.

**Solution sketch:**
```bash
curl -v -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "wrong-client:wrong-secret" -d "grant_type=client_credentials"
# Returns: 401 {"error":"invalid_client"}
# In km.log: {"msg":"token_rejected","reason":"invalid_client_credentials","client_id":"wrong-client"}
# Decision tree: "Client Authentication failed" → Wrong clientId/Secret → verify credentials
```

---

## Anti-Patterns

- **Skipping the health check** — if IS is down, logs show nothing useful.  Always
  check `/healthz` first.
- **Reading logs from the wrong container** — in a Docker Compose stack with both
  IS and the Go KM, `docker logs` requires specifying the container name.  Mixing
  up the two is a common time-waster.
- **Not echoing the correlation ID in 401 responses** — clients cannot self-diagnose
  without the correlation ID.  Add it to error responses:
  ```go
  w.Header().Set("X-Correlation-ID", corrID)
  ```

---

## Key Takeaways

1. The 401 decision tree: IS up? → token present? → invalid JWT / client auth failed / scope / revoked.
2. Check `/healthz` before reading logs.
3. Every handler should log `method + path + correlation_id` at request start.
4. Match the Go KM `correlation_id` to IS's `Correlation-ID` MDC by forwarding the `activityid` header.
5. Phase 1 is complete.  Phase 2 adds the database layer, Control Plane integration, and distributed tracing.
