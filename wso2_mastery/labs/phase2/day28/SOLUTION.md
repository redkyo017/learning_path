# Solution: Day 28 — GW Log4j2 Loggers

## The 5 GW-Specific Loggers

Based on the WSO2 API Manager Gateway 4.7.0 source distribution, here are the 5 critical loggers for GW debugging:

---

## Logger 1: Core Gateway Handler

**Logger Name:** `org.wso2.carbon.apimgt.gateway`

**Config Entry:**
```properties
logger.org-wso2-carbon-apimgt-gateway.name = org.wso2.carbon.apimgt.gateway
logger.org-wso2-carbon-apimgt-gateway.level = DEBUG
```

**Default Level:** INFO

**What It Logs:**
- General gateway operations
- Request routing
- Policy execution
- Response handling
- API invocation flow

**When to Enable:** When tracing the overall request flow through the gateway, or when a request disappears silently.

---

## Logger 2: Security Handler (JWT + Auth)

**Logger Name:** `org.wso2.carbon.apimgt.gateway.handlers.security`

**Config Entry:**
```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-security.name = org.wso2.carbon.apimgt.gateway.handlers.security
logger.org-wso2-carbon-apimgt-gateway-handlers-security.level = DEBUG
```

**Default Level:** INFO

**What It Logs:**
- JWT token extraction
- JWT signature verification
- Key ID (kid) lookup
- Token validation success/failure
- JWKS fetch operations
- Authorization header parsing

**When to Enable:** Client gets 401, you need to see if token is invalid, expired, improperly signed, or if JWKS key lookup failed.

**Common Patterns:**
```
DEBUG {JWTValidator} - Extracting token from Authorization header
DEBUG {JWTValidator} - Fetching public key for kid: e1a2b3c4
WARN {JWTValidator} - JWT token validation failed: Token expired
WARN {JWTValidator} - Public key not found for kid: e1a2b3c4
```

---

## Logger 3: Throttling Handler

**Logger Name:** `org.wso2.carbon.apimgt.gateway.handlers.throttling`

**Config Entry:**
```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.name = org.wso2.carbon.apimgt.gateway.handlers.throttling
logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.level = DEBUG
```

**Default Level:** INFO

**What It Logs:**
- Throttle policy execution
- Token bucket state (current count, capacity)
- Per-tier quota checks
- Throttle decision (allow/deny)
- TM communication (if using distributed throttling)
- Bucket refill events

**When to Enable:** Client gets 429 Too Many Requests, you need to see bucket state and tier limits.

**Common Patterns:**
```
DEBUG {ThrottleHandler} - Checking throttle: app=app1, tier=gold, bucket=4999
DEBUG {ThrottleHandler} - Bucket allows request, count=1
WARN {ThrottleHandler} - Request throttled for application: app1, tier: gold
```

---

## Logger 4: API Authentication Handler (Subscription Checks)

**Logger Name:** `org.wso2.carbon.apimgt.gateway.handlers.authentication`

**Config Entry:**
```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-authentication.name = org.wso2.carbon.apimgt.gateway.handlers.authentication
logger.org-wso2-carbon-apimgt-gateway-handlers-authentication.level = DEBUG
```

**Default Level:** INFO

**What It Logs:**
- Application subscription lookups
- Subscription validation (app must be bound to API)
- Key type validation (PRODUCTION vs SANDBOX)
- API binding checks
- Subscription tier matching

**When to Enable:** Client gets 403 Forbidden, you need to verify if subscription exists or if there's a key type mismatch.

**Common Patterns:**
```
DEBUG {APIAuthenticationHandler} - Checking subscription: app1::myapi
DEBUG {APIAuthenticationHandler} - Subscription found: tier=gold, keytype=PRODUCTION
WARN {APIAuthenticationHandler} - API subscription not found for application: app1
```

---

## Logger 5: JWT Validator (Detailed Token Analysis)

**Logger Name:** `org.wso2.carbon.apimgt.gateway.handlers.security.jwt`

**Config Entry:**
```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-security-jwt.name = org.wso2.carbon.apimgt.gateway.handlers.security.jwt
logger.org-wso2-carbon-apimgt-gateway-handlers-security-jwt.level = DEBUG
```

**Default Level:** INFO

**What It Logs:**
- Token header parsing (alg, kid, type)
- Token payload parsing (claims: sub, exp, iat, etc.)
- Claim extraction and validation
- Expiry timestamp checks
- Signature algorithm validation
- Token structure analysis

**When to Enable:** Deep dive into JWT internals, when you need to see every claim being extracted or when debugging token format issues.

**Common Patterns:**
```
DEBUG {JWTValidator} - Parsing JWT header
DEBUG {JWTValidator} - Token algorithm: RS256
DEBUG {JWTValidator} - Claim expiry: 2026-09-03T11:30:00Z
DEBUG {JWTValidator} - Claim subscriber: alice
DEBUG {JWTValidator} - Claim applicationname: app1
```

---

## How to Add These to log4j2.properties

### Step 1: Update Loggers List

At the top of the file, find the `loggers =` line (around line 220) and add:

```properties
loggers = ..., org-wso2-carbon-apimgt-gateway, org-wso2-carbon-apimgt-gateway-handlers-security, org-wso2-carbon-apimgt-gateway-handlers-throttling, org-wso2-carbon-apimgt-gateway-handlers-authentication, org-wso2-carbon-apimgt-gateway-handlers-security-jwt
```

### Step 2: Add Logger Definitions

At the end of the file (before `rootLogger`), add:

```properties
# GW Debug Loggers
logger.org-wso2-carbon-apimgt-gateway.name = org.wso2.carbon.apimgt.gateway
logger.org-wso2-carbon-apimgt-gateway.level = DEBUG

logger.org-wso2-carbon-apimgt-gateway-handlers-security.name = org.wso2.carbon.apimgt.gateway.handlers.security
logger.org-wso2-carbon-apimgt-gateway-handlers-security.level = DEBUG

logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.name = org.wso2.carbon.apimgt.gateway.handlers.throttling
logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.level = DEBUG

logger.org-wso2-carbon-apimgt-gateway-handlers-authentication.name = org.wso2.carbon.apimgt.gateway.handlers.authentication
logger.org-wso2-carbon-apimgt-gateway-handlers-authentication.level = DEBUG

logger.org-wso2-carbon-apimgt-gateway-handlers-security-jwt.name = org.wso2.carbon.apimgt.gateway.handlers.security.jwt
logger.org-wso2-carbon-apimgt-gateway-handlers-security-jwt.level = DEBUG
```

### Step 3: Restart Gateway

In containerized deployment:
```bash
docker-compose restart gateway
```

---

## Answers to Questions

### Question 1: What is the fully qualified logger name for the core gateway handler?

**Answer:** `org.wso2.carbon.apimgt.gateway`

### Question 2: Which logger is responsible for JWT signature validation, and what level does it default to?

**Answer:** `org.wso2.carbon.apimgt.gateway.handlers.security` (specifically the JWTValidator class within it).
Default level: INFO

### Question 3: What does the throttling handler logger name contain?

**Answer:** `org.wso2.carbon.apimgt.gateway.handlers.throttling`

It indicates the handler is part of the gateway's request handlers, specifically the throttling component.

### Question 4: If you enable DEBUG on all 5 loggers, where would the logs appear?

**Answer:** 
- **In standalone deployments:** `wso2am-universal-gw-4.7.0/repository/logs/wso2carbon.log`
- **In Docker:** `docker logs <container>` and the configured log volume
- **In ECS Fargate:** CloudWatch Logs (log group specified in ECS task definition)

### Question 5: In a containerized deployment (Docker/ECS), how would you apply log4j2 config changes?

**Answer:**
1. Edit `log4j2.properties` inside the Docker image or mount it as a volume
2. Restart the container (log4j2 doesn't support hot-reload in containerized env)
3. In ECS Fargate: Update the task definition, then redeploy the service:
   ```bash
   aws ecs update-service --cluster my-cluster --service my-gw-service --force-new-deployment
   ```
4. New task will pull fresh log config at startup

---

## Key Takeaways

1. **Logger Hierarchy:** More specific loggers (e.g., `security.jwt`) override parent loggers (e.g., `security`)
2. **Default Levels:** Most GW loggers default to INFO; you must explicitly set to DEBUG for detailed output
3. **Performance Cost:** DEBUG logging is expensive (10–50 lines per request); only enable during troubleshooting
4. **Restart Required:** Log config changes require container restart; no hot-reload
5. **Correlation IDs:** Always use `activityid` or `Correlation-ID` to trace a single request across logs

