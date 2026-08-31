# Day 14 — WSO2 IS Log Line Anatomy & Pattern Recognition

## Why This Matters

Knowing the exact format of WSO2 IS log lines lets you read a 1,000-line log file
in 30 seconds by pattern-matching on the parts that matter.  More importantly, it
lets you write precise `grep` commands that pull the signal from the noise during
an outage.

Day 13 covered how to enable DEBUG logging.  Day 14 teaches you what to look for
once the logs are flowing.

---

## WSO2 IS Log Line Anatomy

Every line written by WSO2 IS to `wso2carbon.log` follows this format:

```
[timestamp] [thread] LEVEL {logger-short-name} - message
```

Concrete example:

```
[2026-08-31 14:23:01,234] [http-nio-9443-exec-5] INFO {org.wso2.carbon.identity.oauth2.OAuth2Service} - Access token issued to [api-consumer-1] for scope [read:items]
```

Breaking it apart:

| Field | Value | Notes |
|---|---|---|
| `[2026-08-31 14:23:01,234]` | Timestamp | `yyyy-MM-dd HH:mm:ss,SSS` local time |
| `[http-nio-9443-exec-5]` | Thread name | `http-nio-<port>-exec-<N>` for HTTPS request threads |
| `INFO` | Log level | TRACE / DEBUG / INFO / WARN / ERROR |
| `{org.wso2.carbon.identity.oauth2.OAuth2Service}` | Logger (full class name) | Often abbreviated in grep patterns |
| `Access token issued to [api-consumer-1] for scope [read:items]` | Message | Human-readable; may include structured values in `[brackets]` |

### Thread naming convention

The thread name `http-nio-9443-exec-5` means:
- `http-nio` — Tomcat NIO HTTP connector
- `9443` — HTTPS port
- `exec-5` — the 5th thread in the worker pool for this request

All log lines from a single HTTP request share the same thread name (unless the
request spawns async tasks), so you can use the thread name as a rough correlation
key when no correlation ID is present.

---

## Five Log Patterns to Memorize

These five patterns cover the vast majority of OAuth2 debugging scenarios in WSO2 IS.

| Pattern | Typical level | Meaning | What to do next |
|---|---|---|---|
| `Access token issued to \[.*\] for scope` | DEBUG / INFO | Token issued successfully | Confirm the token reaches the client; check the client_id and scope match expectations |
| `Token validation for access_token.*\[VALID\]` | DEBUG | Token passed introspection | The token is fine; check the downstream system rejecting it |
| `Invalid JWT token\. failed:` | WARN | Token signature invalid or expired | Check JWKS `kid` rotation; check clock skew between issuer and validator |
| `Client Authentication failed for client_id:` | WARN | Wrong client_id or client_secret | Verify the credentials in IS admin console; check for Base64-encoding issues |
| `Revoking access token issued to \[.*\]` | INFO | Token explicitly revoked | Check whether revocation propagated to the API Gateway (Phase 2 concern) |

### How to grep for them

```bash
# All five patterns in one pass:
docker logs <is-container> 2>&1 \
  | grep -E "(Access token issued|Token validation.*VALID|Invalid JWT|Client Authentication failed|Revoking access token)"
```

To focus on failures only:

```bash
docker logs <is-container> 2>&1 | grep -E "(WARN|ERROR)"
```

---

## Log Correlation with MDC

WSO2 IS adds a **correlation ID** to the Mapped Diagnostic Context (MDC) for
every inbound HTTP request.  All log lines produced within that request's
thread automatically include the same ID.

### What MDC is

MDC is a thread-local map that Log4j2 reads when formatting each log line.
The key `Correlation-ID` is set at request entry and cleared at request exit.
When the `%X{Correlation-ID}` pattern token is in the appender layout, every line
in the request's thread carries the correlation ID.

### Default IS layout (excerpt from log4j2.properties)

```properties
appender.CARBON_LOGFILE.layout.pattern = [%d] [%t] %5p {%c} - %m%n
```

The `%X{Correlation-ID}` token may not appear in the default layout in older IS
versions.  To enable it, update the pattern:

```properties
appender.CARBON_LOGFILE.layout.pattern = [%d] [%t] %5p {%c} [%X{Correlation-ID}] - %m%n
```

### Enabling CorrelationLogFilter

WSO2 IS ships with `CorrelationLogFilter`, a Servlet filter that:
1. Reads the `activityid` request header (set by WSO2 APIM Gateway when it forwards requests).
2. Falls back to generating a new UUID if the header is absent.
3. Stores the ID in MDC under `Correlation-ID`.

To enable it, add the following to
`repository/conf/deployment.toml`:

```toml
[correlation]
enable = true
```

After the next restart (or hot-reload for deployment.toml if IS supports it),
every log line gains the correlation ID.

### Searching by correlation ID

Once enabled:

```bash
grep "aB3xQ7mNpL" /home/wso2carbon/wso2is-7.3.0/repository/logs/wso2carbon.log
```

…returns every log line for that single HTTP request across all loggers.

---

## Reading a Log Snippet (Exercise Scenario)

Below is a condensed log snippet from a token validation failure:

```
[2026-08-31 15:01:00,100] [http-nio-9443-exec-3] WARN {org.wso2.carbon.identity.oauth2.token.handlers.clientauth.BasicAuthClientAuthHandler} - Client Authentication failed for client_id: bad-app
[2026-08-31 15:01:00,102] [http-nio-9443-exec-3] WARN {org.wso2.carbon.identity.oauth.OAuthClientAuthn} - Client Authentication failed for client_id: bad-app. Reason: Invalid client credentials
[2026-08-31 15:01:05,210] [http-nio-9443-exec-7] DEBUG {org.wso2.carbon.identity.oauth2.OAuth2Service} - Access token issued to [valid-app] for scope [read:products]
[2026-08-31 15:01:10,500] [http-nio-9443-exec-9] WARN {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - Invalid JWT token. failed: JWT verification failed: Signature validation failed
```

Reading exercise: see the lab in `labs/phase1/day14/`.

---

## Lab (Day 14)

See `labs/phase1/day14/` — log analysis: given a realistic log file, identify
the failure class, the affected client, and the next diagnostic step.

---

## Exercises

**Exercise 1 — Parse a log line**

Given this line:

```
[2026-08-31 09:10:02,555] [http-nio-9443-exec-2] WARN {org.wso2.carbon.identity.oauth.OAuthClientAuthn} - Client Authentication failed for client_id: mobile-app-1
```

Answer: (a) What level is this? (b) Which subsystem logged it? (c) What does this mean for the token flow?

**Hint:** The level is the all-caps word between the thread name and the `{`.
The subsystem is the short name inside `{}`.

**Solution sketch:**
- (a) WARN — the request did not produce a fatal error, but something unexpected happened.
- (b) `OAuthClientAuthn` — the client authentication layer.  This is distinct from token validation.
- (c) The client presented credentials (client_id + client_secret) but they did not match any registered client.
  The token endpoint returned `401 invalid_client`.  Next step: verify the credentials in the IS admin console
  under Service Providers → OAuth/OpenID Connect Configuration.

**Exercise 2 — Write a targeted grep**

You want to find all lines for a specific correlation ID `X7aP3Q` and extract only
the level and message.

**Hint:** Use `grep` to filter by the ID, then pipe to `awk` to extract fields.

**Solution sketch:**
```bash
grep "X7aP3Q" wso2carbon.log | awk '{print $4, substr($0, index($0,$6))}'
```

Or more simply:

```bash
grep "X7aP3Q" wso2carbon.log | grep -oP '(DEBUG|INFO|WARN|ERROR).*'
```

**Exercise 3 — Distinguish client auth failure from token validation failure**

Explain the difference between:
- `Client Authentication failed for client_id: foo`
- `Invalid JWT token. failed: Signature validation failed`

Which occurs earlier in the token flow?  What does each indicate about the caller?

**Hint:** Client auth happens at the token endpoint (issuing).  JWT validation
happens at the introspection endpoint or gateway (using the token).

**Solution sketch:**
- `Client Authentication failed` happens when the caller tries to *obtain* a token.
  The server rejected the client_id/secret before issuing anything.
  This is the caller's credentials, not the token itself.
- `Invalid JWT` happens when someone presents a *token* that fails signature
  verification.  The token was issued (possibly by a different key), but the
  validator cannot trust it.
- Client auth failure is earlier in the flow.  If you see `Client Authentication failed`,
  no token was ever issued to that caller in this request.

---

## Anti-Patterns

- **Grepping only for `ERROR`** — most OAuth2 failures log at `WARN`, not `ERROR`.
  `grep -E "(ERROR|WARN)"` is the minimum.
- **Confusing thread name with correlation ID** — thread names repeat across requests.
  If CorrelationLogFilter is not enabled, use the timestamp range to correlate,
  not the thread name alone.
- **Reading truncated logs from `docker logs --tail 100`** — client auth failures
  and token issues often appear as pairs (two lines: the handler and the outer
  service).  Use a wide enough tail, or `grep` the full log.

---

## Teardown

No running services.  This is a log analysis day.

---

## Key Takeaways

1. Log line format: `[timestamp] [thread] LEVEL {logger} - message`.
2. The five patterns: token issued, token valid, invalid JWT, client auth failed, revoked.
3. MDC correlation ID links all lines for one request — enable `CorrelationLogFilter` + `%X{Correlation-ID}` in the layout.
4. Most OAuth2 failures are at WARN, not ERROR.
5. Client auth failure occurs at issuance; JWT invalid occurs at validation — they indicate different callers/stages.
