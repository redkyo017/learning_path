# Day 13 — Reading WSO2 IS Log4j2 Configuration

## Why This Matters

When a token flow breaks in production, logs are your first source of truth.
WSO2 IS ships with Log4j2 as its logging framework.  At the default INFO level
you will see only high-level lifecycle events.  To see the token validation
decision, client auth check, and scope resolution you must enable DEBUG on the
relevant loggers — without restarting the server.

This day builds the foundational skill of reading, understanding, and modifying
`log4j2.properties` so you can diagnose any OAuth2 issue within minutes.

---

## WSO2 IS Source Reading

### Where to find the config

Inside a WSO2 IS installation (or the Docker image):

```
wso2is-7.3.0/
└── repository/
    └── conf/
        └── log4j2.properties   ← the file you edit
```

In the Docker image (Tag: `wso2/wso2is:7.3.0`), the path maps to:

```
/home/wso2carbon/wso2is-7.3.0/repository/conf/log4j2.properties
```

To inspect it without entering the container:

```bash
docker exec <container-name> cat /home/wso2carbon/wso2is-7.3.0/repository/conf/log4j2.properties | head -80
```

---

## Core Concepts

### Logger name = Java package name

Log4j2 loggers mirror the Java package hierarchy.  The logger name:

```
org.wso2.carbon.identity.oauth2.OAuth2Service
```

…belongs to the `OAuth2Service` class inside the `org.wso2.carbon.identity.oauth2`
package.  When you set a level on a parent package, all child loggers inherit it.

| Logger name | Covers |
|---|---|
| `org.wso2.carbon.identity.oauth` | Core OAuth package + all children |
| `org.wso2.carbon.identity.oauth2` | OAuth2-specific token flows |
| `org.wso2.carbon.identity.oauth2.token` | Token issuance only |
| `org.wso2.carbon.identity.application.authentication` | App-level auth flows |

Setting `org.wso2.carbon.identity.oauth2` to DEBUG implicitly enables DEBUG for
every class inside that package.

### Level hierarchy

Log4j2 levels form a strict ordering:

```
TRACE < DEBUG < INFO < WARN < ERROR < FATAL
```

Setting a logger to DEBUG means: emit DEBUG, INFO, WARN, ERROR, and FATAL.
Setting it to WARN means: emit only WARN, ERROR, and FATAL — DEBUG and INFO
lines are suppressed.

WSO2 IS defaults to INFO for most packages.  This keeps log volume manageable
in production.  You temporarily raise a package to DEBUG when diagnosing an issue,
then restore it to INFO.

### The five loggers for OAuth2 debugging

To see the full token issuance and validation flow, add these lines to
`log4j2.properties`:

```properties
logger.org-wso2-carbon-identity-oauth.name=org.wso2.carbon.identity.oauth
logger.org-wso2-carbon-identity-oauth.level=DEBUG
logger.org-wso2-carbon-identity-oauth2.name=org.wso2.carbon.identity.oauth2
logger.org-wso2-carbon-identity-oauth2.level=DEBUG
logger.org-wso2-carbon-identity-application-authentication.name=org.wso2.carbon.identity.application.authentication
logger.org-wso2-carbon-identity-application-authentication.level=DEBUG
```

> **Note:** Log4j2 properties use a key naming convention of
> `logger.<unique-key>.name` and `logger.<unique-key>.level`.
> The unique key (e.g. `org-wso2-carbon-identity-oauth2`) is arbitrary —
> it just ties the `.name` and `.level` pair together.  Use hyphens, not dots,
> in the key portion to avoid Log4j2 parsing ambiguity.

You also need to register these loggers in the `loggers` list at the top of the
file.  Find the line that begins with `loggers =` and append the new logger keys
(comma-separated):

```properties
loggers = ..., org-wso2-carbon-identity-oauth, org-wso2-carbon-identity-oauth2, org-wso2-carbon-identity-application-authentication
```

### What each logger unlocks

| Logger | What you see at DEBUG |
|---|---|
| `oauth` (parent) | Client credential validation, grant type routing |
| `oauth2` | Token issuance, scope resolution, token storage |
| `oauth2.token` (child of oauth2) | Low-level token construction and signing |
| `application.authentication` | Application-level pre-auth checks, per-request auth context |

### Hot-reload — no restart needed

WSO2 IS monitors `log4j2.properties` for changes at a configurable interval
(default: 30 seconds).  This is configured by the `monitorInterval` attribute
in the file header:

```properties
# Reload configuration every 30 seconds
appender.CARBON_CONSOLE.type = Console
...
```

After you save `log4j2.properties` with the new DEBUG lines, wait up to
30 seconds.  The next request will produce DEBUG output — no container restart
required.  This is critical in production: you can enable verbose logging,
diagnose the issue, and restore INFO-level logging without any downtime.

To verify hot-reload has taken effect:

```bash
# Trigger a token request
curl -X POST https://localhost:9443/oauth2/token \
  -k -u "<clientId>:<clientSecret>" \
  -d "grant_type=client_credentials"

# In another terminal, watch IS logs
docker logs -f <is-container> 2>&1 | grep DEBUG
```

If DEBUG lines appear, hot-reload succeeded.

---

## Lab (Day 13)

See `labs/phase1/day13/` — a source-reading exercise: locate the config file,
identify which loggers are active, and explain the effect of switching INFO to DEBUG.

---

## Exercises

**Exercise 1 — Identify the logger name**

Given the Java class `org.wso2.carbon.identity.oauth2.validators.TokenValidationHandler`,
write the minimal Log4j2 properties block to set it to DEBUG without affecting
other packages.

**Hint:** You need a `.name` line and a `.level` line, plus a unique key of your
choice.  The key just needs to appear in the `loggers =` list.

**Solution sketch:**
```properties
logger.km-token-validation.name=org.wso2.carbon.identity.oauth2.validators.TokenValidationHandler
logger.km-token-validation.level=DEBUG
```
And in the `loggers =` list, add `km-token-validation`.

To set the whole validators sub-package:
```properties
logger.km-oauth2-validators.name=org.wso2.carbon.identity.oauth2.validators
logger.km-oauth2-validators.level=DEBUG
```

**Exercise 2 — Package vs class scope**

You want to see every log line from the `oauth2` package but nothing extra from
`application.authentication`.  Which logger entries do you add?

**Hint:** You only need the `oauth2` logger from the five-logger block above.
The `application.authentication` logger is separate — omit it.

**Solution sketch:**
```properties
logger.oauth2-debug.name=org.wso2.carbon.identity.oauth2
logger.oauth2-debug.level=DEBUG
```
Add `oauth2-debug` to the `loggers =` list.  The `application.authentication`
package stays at its default INFO.

**Exercise 3 — Restore production logging**

After diagnosing an issue, you want to restore INFO level without deleting the
logger entries (so you can re-enable DEBUG quickly later).

**Hint:** Change `.level=DEBUG` to `.level=INFO` — that's it.  The logger entry
stays registered; it just no longer emits DEBUG.

**Solution sketch:**
```properties
logger.org-wso2-carbon-identity-oauth2.name=org.wso2.carbon.identity.oauth2
logger.org-wso2-carbon-identity-oauth2.level=INFO
```
Save the file and wait up to 30 seconds for hot-reload.

---

## Anti-Patterns

- **Setting the root logger to DEBUG** — the root logger covers every library in
  IS.  At DEBUG the log volume is enormous and important lines drown in noise.
  Always target the specific package.
- **Forgetting to add to the `loggers =` list** — a logger block without its key
  in the list is silently ignored.  This is the most common "why isn't DEBUG
  working?" trap.
- **Restarting the container to apply log changes** — unnecessary; hot-reload
  handles it.  Restarting also loses any in-memory session state if IS is not
  clustered.

---

## Teardown

No running services.  This is a source-reading day.

---

## Key Takeaways

1. Logger name = Java package or class name.  Set a parent package to affect all children.
2. Level hierarchy: TRACE < DEBUG < INFO < WARN < ERROR.  Setting DEBUG means all above it also emit.
3. The five OAuth2 debug loggers: `oauth`, `oauth2`, and `application.authentication` are the most useful.
4. WSO2 IS hot-reloads `log4j2.properties` every 30 seconds — no restart needed.
5. Always add new logger keys to the `loggers =` list, or they are silently ignored.
