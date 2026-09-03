# Day 28: GW Log4j2 Debug Loggers

## Why

You've built a working gateway (Days 24–27) with JWT validation, subscription checks, and throttling.
Now requests are flowing, but when a client complains about a 401 or 429, **where do you look?**

The answer: **GW logs**. But by default, the gateway logs at INFO level, which hides the debug details
you need to diagnose token validation failures, subscription mismatches, and throttle decisions.

Today you enable the **5 GW-specific log4j2 loggers** that reveal the internal mechanics of your gateway.

---

## The Problem: INFO vs DEBUG

### Default Behavior (INFO Level)

```
2026-09-03 10:30:00 INFO {org.wso2.carbon.apimgt.gateway.handlers.security.APIAuthenticationHandler} - Starting authentication
2026-09-03 10:30:01 WARN {org.wso2.carbon.apimgt.gateway.handlers.security.APIAuthenticationHandler} - Authentication failed
```

This tells you **authentication failed**, but not **why**. Was the token expired? Bad signature? Missing entirely?

### With DEBUG Enabled

```
2026-09-03 10:30:00 DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Extracting token from Authorization header
2026-09-03 10:30:00 DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Fetching public key for kid: e1a2b3c4
2026-09-03 10:30:00 DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Validating signature...
2026-09-03 10:30:01 WARN {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - JWT token validation failed: Token expired
```

Now you can see the **exact step** where validation failed: token extraction worked, key fetch worked, but
signature validation detected an expired token.

---

## The 5 GW-Specific Loggers

The gateway has many loggers, but these **5 are the critical ones for debugging**:

### Logger 1: Core Gateway Handler

```properties
logger.org-wso2-carbon-apimgt-gateway.name=org.wso2.carbon.apimgt.gateway
logger.org-wso2-carbon-apimgt-gateway.level=DEBUG
```

**What it logs:** General gateway operations (request routing, policy execution, response handling)

**When to enable:** Trace overall request flow through the gateway

---

### Logger 2: Security Handler (JWT + Auth)

```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-security.name=org.wso2.carbon.apimgt.gateway.handlers.security
logger.org-wso2-carbon-apimgt-gateway-handlers-security.level=DEBUG
```

**What it logs:** JWT validation, token extraction, signature verification, key lookups

**When to enable:** Client gets 401, need to see if token is invalid, expired, or improperly signed

---

### Logger 3: Throttling Handler

```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.name=org.wso2.carbon.apimgt.gateway.handlers.throttling
logger.org-wso2-carbon-apimgt-gateway-handlers-throttling.level=DEBUG
```

**What it logs:** Throttle decisions, bucket status, quota checks, per-tier limits

**When to enable:** Client gets 429 Too Many Requests, need to see bucket state and tier limits

---

### Logger 4: API Authentication Handler (Subscription Checks)

While this overlaps with Logger 2, it's specifically for subscription validation:

```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-authentication.name=org.wso2.carbon.apimgt.gateway.handlers.authentication
logger.org-wso2-carbon-apimgt-gateway-handlers-authentication.level=DEBUG
```

**What it logs:** Application subscription lookups, key type validation (PRODUCTION vs SANDBOX), API binding

**When to enable:** Client gets 403, need to verify if subscription exists

---

### Logger 5: JWT Validator (Detailed Token Analysis)

```properties
logger.org-wso2-carbon-apimgt-gateway-handlers-security-jwt.name=org.wso2.carbon.apimgt.gateway.handlers.security.jwt
logger.org-wso2-carbon-apimgt-gateway-handlers-security-jwt.level=DEBUG
```

**What it logs:** Token parsing, claim extraction, expiry checks, key ID (kid) resolution

**When to enable:** Deep dive into JWT internals (claim validation, token structure, key matching)

---

## How to Enable Debug Logging

### File Location

```
wso2am-universal-gw-4.7.0/repository/conf/log4j2.properties
```

### Add the Loggers

Edit `log4j2.properties` and add these lines (usually at the end before rootLogger):

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

### Update the Loggers List

At the top of log4j2.properties, find the `loggers =` line and add these logger names:

```properties
loggers = ..., org-wso2-carbon-apimgt-gateway, org-wso2-carbon-apimgt-gateway-handlers-security, org-wso2-carbon-apimgt-gateway-handlers-throttling, org-wso2-carbon-apimgt-gateway-handlers-authentication, org-wso2-carbon-apimgt-gateway-handlers-security-jwt
```

### Restart the Gateway

**In containerized deployments (ECS, Docker):** Restart the container

```bash
docker-compose restart gateway
# or in ECS
aws ecs update-service --cluster my-cluster --service my-gw-service --force-new-deployment
```

**In standalone deployments:** Restart the gateway process

```bash
./wso2am-universal-gw/bin/gateway.sh
```

---

## Log Output Locations

Once DEBUG is enabled, you'll see output in:

1. **Console:** `wso2am-universal-gw-4.7.0/repository/logs/wso2carbon.log` (main log file)
2. **Docker:** `docker logs <container>`
3. **ECS Fargate:** CloudWatch Logs (check the ECS task definition for log group)

### Sample Debug Output

```
[2026-09-03 10:30:00,123] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - JWT token received: eyJhbGc...
[2026-09-03 10:30:00,124] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Extracting claims from token
[2026-09-03 10:30:00,125] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Token expiry: 2026-09-03T11:30:00Z
[2026-09-03 10:30:00,126] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Current time: 2026-09-03T10:30:00Z (token valid)
[2026-09-03 10:30:00,127] DEBUG {org.wso2.carbon.apimgt.gateway.handlers.security.JWTValidator} - Signature valid for kid: e1a2b3c4
```

---

## When NOT to Enable DEBUG

**WARNING:** DEBUG logging is expensive. Each request will log 10–50 DEBUG lines. In production with
10k req/s, this can:
- Consume 100–500 MB/sec disk I/O
- Slow down request processing
- Increase ECS task CPU/memory usage

**Best practice:**
- Enable DEBUG **only during troubleshooting**
- Use correlation IDs to grep for specific request traces
- Disable after debugging to restore performance
- Use log aggregation (CloudWatch, ELK, Datadog) to centralize and filter

---

## Exercises

**Exercise 1:** You deploy a new IS (token issuer) and suddenly all JWTs fail with "Signature verification failed".
What GW logger would you enable first to diagnose, and what would you look for in the output?

**Hint:** Think about which handler validates JWT signatures, and what change at IS would break that validation
(e.g., IS restarted, key rotated, JWKS endpoint changed).

**Solution sketch:**

```
Enable: org.wso2.carbon.apimgt.gateway.handlers.security (JWT validation logger)

Look for these patterns in logs:
1. "Fetching public key for kid: <some-key-id>" — confirms GW is looking up the right key
2. "Public key not found for kid: <some-key-id>" — JWKS cache is stale or IS endpoint changed
3. "Signature verification failed" — key exists but signature doesn't match

Root causes to check:
- Did IS rotate signing keys? If yes, GW JWKS cache is outdated → restart GW to refresh cache
- Did JWKS endpoint URL change in deployment.toml? If yes, GW can't fetch new keys → update config
- Are IS and GW running in different time zones/clock skew? If yes, check system time sync

Remediation:
1. Check IS logs for key rotation events
2. Verify deployment.toml [apim.jwt] section has correct jwks_url
3. Restart GW to refresh JWKS cache
```

---

**Exercise 2:** In a containerized ECS deployment, you enable DEBUG logging but logs are not appearing in CloudWatch.
What could be wrong, and how do you verify the logs are being written?

**Hint:** Debug logging works locally (you see output in docker logs), but you need to ensure the
container's log driver is configured correctly.

**Solution sketch:**

```
Potential issues:
1. Log driver misconfigured in ECS task definition
2. CloudWatch log group doesn't exist
3. IAM role lacks permission to write to CloudWatch
4. Container logs aren't being flushed to stdout

Verification steps:
1. Check if logs appear in "docker logs <container>" locally — if yes, container is logging
2. Check ECS task definition logConfiguration → awslogs-logGroupName and awslogs-region
3. Verify log group exists in CloudWatch: aws logs describe-log-groups
4. Check IAM role: aws iam get-role-policy --role-name <ecsTaskRole> --policy-name cloudwatch-logs
   (should have logs:CreateLogStream and logs:PutLogEvents)

If logs are in docker but not CloudWatch:
- Redeploy task to apply log driver changes
- Check container health in ECS console → Logs tab

If logs are nowhere:
- SSH into container and check /opt/wso2am-universal-gw/repository/logs/ for local files
- Verify log4j2.properties appenders are correctly configured (appender paths should be writable)
```

---

**Exercise 3:** You have a production incident where a subset of users are getting 429 (Too Many Requests)
but your monitoring shows global traffic is within quota. Design a debugging strategy using GW logs
to isolate the issue.

**Hint:** With multiple GW replicas, a single app might be hitting a per-replica local bucket limit
before the global TM limit is reached.

**Solution sketch:**

```
Suspected issue: Per-replica bucket exhaustion (app is breaching local bucket on 1–2 replicas
but not hitting global TM quota).

Debugging strategy:
1. Enable org.wso2.carbon.apimgt.gateway.handlers.throttling DEBUG logger on all GW replicas
2. Generate a test request from the affected app → should see throttle decision in logs
3. Collect logs from all 3 replicas using correlation ID: grep <correlationID> wso2carbon.log
4. Compare bucket states:
   - GW-1: "Application tier: gold, localCount: 4500, bucket: 500 remaining"
   - GW-2: "Application tier: gold, localCount: 4600, bucket: 400 remaining"
   - GW-3: "Application tier: gold, localCount: 2900, bucket: 2100 remaining"
5. Notice GW-1 and GW-2 are near limits → requests routed to GW-1/GW-2 hit 429
6. Root cause: Load balancer is not evenly distributing traffic (sticky sessions or misconfiguration)

Remediation:
- Check ALB/LB health checks and target distribution
- Verify no sticky session affinity enabled
- Increase per-replica bucket size or adjust tier limits
- Implement TM-based throttling if it's not already active
```

---

## Anti-patterns

- **Leaving DEBUG on in production:** Performance killer. Always disable after troubleshooting.
- **Ignoring log4j2.properties changes in containerized setups:** Log config changes require container restart.
- **Not centralizing logs:** Collecting logs from each container is tedious. Use CloudWatch/ELK.
- **Enabling all loggers at DEBUG:** Too verbose. Enable only the 5 relevant GW loggers.

---

## Next Steps

- **Lab:** Find the 5 loggers in the WSO2 GW source checkout.
- **Day 29:** Memorize the 6 most common GW log line patterns.
- **Day 30:** Use these loggers in a capstone lab: run the gateway, generate errors, diagnose them.

