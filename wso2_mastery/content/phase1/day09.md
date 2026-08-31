# Day 9 — End-to-End Token Lifecycle & Structured Logging

## Learning Objectives

- Trace a complete token lifecycle across issue → validate → revoke → re-validate
- Enable WSO2 IS OAuth2 DEBUG logging and read lifecycle log lines
- Replace `log.Printf` with structured `log/slog` calls
- Add correlation ID middleware to link all log lines from a single request

---

## 1. End-to-End Token Lifecycle

The full lifecycle of a token in the lab server (and in WSO2 IS) involves four stages:

```
Client                          Server (lab / WSO2 IS)
  │                                       │
  │── POST /oauth2/token ────────────────→│
  │   Authorization: Basic ...            │  validateClient()
  │   grant_type=client_credentials       │  issueJWT()
  │                                       │  LOG: token_issued (client_id, exp)
  │←─ { access_token, expires_in } ───────│
  │                                       │
  │── POST /oauth2/introspect ───────────→│
  │   Authorization: Basic ...            │  validateJWT()
  │   token=<value>                       │  check revokedTokens → miss
  │                                       │  LOG: introspect_called (active=true)
  │←─ { active:true, sub, exp, ... } ─────│
  │                                       │
  │── POST /oauth2/revoke ───────────────→│
  │   Authorization: Basic ...            │  validateClient()
  │   token=<value>                       │  revokedTokens.Store(token, now)
  │                                       │  LOG: token_revoked (client_id, token_prefix)
  │←─ 200 OK ─────────────────────────────│
  │                                       │
  │── POST /oauth2/introspect ───────────→│
  │   Authorization: Basic ...            │  validateJWT() → ok
  │   token=<value>                       │  check revokedTokens → HIT
  │                                       │  LOG: introspect_called (active=false)
  │←─ { active:false } ───────────────────│
```

After revocation, the JWT signature is still valid and `exp` has not been reached — but the server-side `revokedTokens` map overrides the JWT's self-contained claims. This is how a gateway-mode introspection endpoint can bridge the JWT revocation gap for in-process checks (as opposed to remote gateways, which would still accept the JWT).

---

## 2. Enabling WSO2 IS OAuth2 DEBUG Logging

WSO2 IS uses log4j2. All configuration lives in:

```
<IS_HOME>/repository/conf/log4j2.properties
```

### Step 1: declare the logger names

Find the `loggers = ...` line (it lists comma-separated logger names already configured) and append your new names:

```properties
loggers = ...,org-wso2-carbon-identity-oauth,org-wso2-carbon-identity-oauth2,org-wso2-carbon-identity-oauth2-grant
```

### Step 2: add logger definitions

```properties
# Core OAuth2 package — covers token issuance, validation, revocation
logger.org-wso2-carbon-identity-oauth.name=org.wso2.carbon.identity.oauth
logger.org-wso2-carbon-identity-oauth.level=DEBUG
logger.org-wso2-carbon-identity-oauth.appenderRef.CARBON_LOGFILE.ref=CARBON_LOGFILE

# oauth2 sub-package — JWT validator, introspection data provider
logger.org-wso2-carbon-identity-oauth2.name=org.wso2.carbon.identity.oauth2
logger.org-wso2-carbon-identity-oauth2.level=DEBUG
logger.org-wso2-carbon-identity-oauth2.appenderRef.CARBON_LOGFILE.ref=CARBON_LOGFILE

# Grant handler classes — client_credentials, refresh_token, auth_code
logger.org-wso2-carbon-identity-oauth2-grant.name=org.wso2.carbon.identity.oauth2.token.handlers.grant
logger.org-wso2-carbon-identity-oauth2-grant.level=DEBUG
logger.org-wso2-carbon-identity-oauth2-grant.appenderRef.CARBON_LOGFILE.ref=CARBON_LOGFILE
```

Restart WSO2 IS (or use the JMX hot-reload endpoint at `https://<IS_HOST>:9443/carbon`) for changes to take effect.

---

## 3. Token Lifecycle Log Line Patterns

After enabling DEBUG, these patterns appear in `<IS_HOME>/repository/logs/wso2carbon.log`:

| Event | Log pattern | Key fields in log line |
|---|---|---|
| **Token issued** | `DEBUG ... AccessTokenIssuer ... Generating new access token for application: <app>` | `app`, `grantType`, `userId` |
| **Token validated (success)** | `DEBUG ... JWTValidator ... JWT token validated successfully for user: <sub>` | `sub`, `jti`, `exp` |
| **Token validation failed** | `WARN ... JWTValidator ... Error while validating JWT token. <reason>` | reason: `Expired JWT`, `Invalid Signature`, `Audience mismatch` |
| **Client auth failed** | `WARN ... OAuthClientAuthnService ... Client Authentication failed for client: <client_id>` | `client_id`, failure code |
| **Token revoked** | `DEBUG ... OAuthRevocationProcessor ... Revoking access token of user: <sub>` | `sub`, `tokenId`, `clientId` |

### Useful grep commands

```bash
# All revocations
grep "Revoking access token" <IS_HOME>/repository/logs/wso2carbon.log

# Validation failures only
grep "Error while validating JWT" <IS_HOME>/repository/logs/wso2carbon.log

# Client auth failures (compromised secret, wrong client)
grep "Client Authentication failed" <IS_HOME>/repository/logs/wso2carbon.log

# Full lifecycle for one application
grep "DefaultApp" <IS_HOME>/repository/logs/wso2carbon.log | grep -E "Generating|validated|Revoking"
```

---

## 4. Structured Logging with `log/slog`

Go 1.21 introduced `log/slog` in the standard library. Unlike `log.Printf` (unstructured text), `slog` emits key-value pairs that log aggregators (Datadog, Splunk, CloudWatch Logs Insights) can index and query by field.

### Basic usage

```go
import "log/slog"

slog.Info("token_issued", "client_id", clientID, "exp", exp)
slog.Warn("token_invalid", "reason", "expired", "client_id", clientID)
slog.Error("server_error", "err", err)
```

### Enable JSON output (required for log aggregators)

Call this once in `main()` before starting the HTTP server:

```go
slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
```

Each log line is then a self-contained JSON object:

```json
{"time":"2026-08-31T10:00:05Z","level":"INFO","msg":"token_issued","client_id":"test-client","exp":1725004000}
```

---

## 5. Correlation ID Middleware

In any system handling concurrent requests, multiple log lines are emitted per request. Without a shared identifier, it is impossible to reconstruct the sequence of events for a single transaction.

A **correlation ID** is a randomly generated string attached to every log line emitted while processing one HTTP request.

### Implementation pattern

```go
// Use an unexported struct type as the context key.
// A bare string key ("correlation_id") would collide if any imported package
// used the same string. A private struct type is globally unique.
type correlationKey struct{}

func correlationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        id := generateID()  // 16 bytes of crypto/rand, base64url-encoded
        ctx := context.WithValue(r.Context(), correlationKey{}, id)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func correlationFromCtx(ctx context.Context) string {
    v, _ := ctx.Value(correlationKey{}).(string)
    return v
}
```

Then in every handler:

```go
corrID := correlationFromCtx(r.Context())
slog.Info("introspect_called",
    "correlation_id", corrID,
    "active", active,
    "client_id", clientID,
)
```

### Log events and fields (day09 lab)

| Event `msg` | Level | Key fields |
|---|---|---|
| `token_issued` | INFO | `correlation_id`, `client_id`, `exp` |
| `token_validated` | INFO | `correlation_id`, `client_id`, `sub` |
| `token_invalid` | WARN | `correlation_id`, `reason` |
| `token_revoked` | INFO | `correlation_id`, `client_id`, `token_prefix` |
| `introspect_called` | INFO | `correlation_id`, `client_id`, `active` |
| `revoke_called` | INFO | `correlation_id`, `client_id` |

---

## Exercises

### Exercise 1 — Enable JSON slog output

Modify the day09 lab server to output structured JSON logs. Run it and perform one token issuance. Pipe stdout through `jq` to view the structured log line. Identify which fields appear in the `token_issued` event.

**Hint:** Add `slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))` at the start of `main()`. The server logs go to stdout; pipe with `go run main.go 2>&1 | jq .` or redirect to a file.

**Solution sketch:**
```bash
go run main.go > logs.json &
curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret -d grant_type=client_credentials > /dev/null
cat logs.json | jq .
```
Expected output includes a line like:
```json
{"time":"...","level":"INFO","msg":"token_issued","correlation_id":"abc123","client_id":"test-client","exp":1725007600}
```

---

### Exercise 2 — Trace a full lifecycle by correlation ID

Run the day09 server with JSON logging. Perform the complete lifecycle (issue → introspect → revoke → introspect). Stop the server. Find all log lines that share the correlation ID from the `token_revoked` event.

**Hint:** Each HTTP request has its own correlation ID. The four operations are four separate requests — each has a different correlation ID. To trace across all requests, use the `token_prefix` field (first 8 characters of the token) which appears in multiple events and identifies the same token.

**Solution sketch:**
```bash
# Run server, capture logs
go run main.go > logs.json &

TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret -d grant_type=client_credentials | jq -r .access_token)

curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret -d "token=$TOKEN" > /dev/null

curl -s -X POST http://localhost:9443/oauth2/revoke \
  -u test-client:test-secret -d "token=$TOKEN" > /dev/null

curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret -d "token=$TOKEN" > /dev/null

kill %1

PREFIX=${TOKEN:0:8}
jq -r "select(.token_prefix == \"$PREFIX\") | [.time, .msg, .active] | @tsv" logs.json
```

---

### Exercise 3 — Add a custom log field

Extend `introspectHandler` to include the introspecting client's ID in the log line. Currently the client authenticates via Basic Auth but their ID may not appear in all log events. Add `"caller_client_id"` as a structured field.

**Hint:** The client ID is available from `clientID, _, _ := r.BasicAuth()` (already called for auth). Pass it to the slog call as `"caller_client_id", clientID`.

**Solution sketch:**
```go
clientID, _, ok := r.BasicAuth()
if !ok {
    // ... 401 response ...
}
// ... validation ...
corrID := correlationFromCtx(r.Context())
slog.Info("introspect_called",
    "correlation_id", corrID,
    "caller_client_id", clientID,
    "active", active,
)
```
This makes the log line queryable by caller in a log aggregator:
```
filter msg = "introspect_called" and caller_client_id = "gateway-client"
```
