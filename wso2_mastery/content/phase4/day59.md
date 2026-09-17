# Day 59 — Capstone: Personal Production Runbook

## Why This Matters

A runbook that doesn't exist when the incident starts is useless. Today you write yours, from memory, as the final act of this path. In production, your first 60 seconds determine whether the incident ends in minutes or hours. This runbook is your decision tree when the pager goes off.

## Core Concepts

### Runbook Structure

A production runbook is not a tutorial; it is an incident response checklist organized by:
1. **First 60 seconds:** Triage — what is broken?
2. **Per-service debug:** For each service, what to check and in what order
3. **Common failure flows:** Failure class → immediate action
4. **Recovery procedures:** How to restore service
5. **Escalation criteria:** When to page the expert

### The Triage Loop

When the pager goes off, follow this loop without deviation:

**a) Identify the failure class (next 30 seconds):**
- Check all four CloudWatch log groups for ERROR or FATAL lines in the last 5 minutes
- Look for patterns: 
  - `ERROR.*JWT.*invalid` → JWT validation failure
  - `ERROR.*subscription.*not found` → subscription deleted or revoked
  - `ERROR.*429` → throttle limit exceeded
  - `ERROR.*timeout` → backend timeout or dependency failure

**b) Run the classifier (next 30 seconds):**
- Download the error logs and run `bash debug.sh <log-file>`
- This maps raw error messages to one of 7 known failure classes (see Day 52)

**c) Check all four health endpoints (next 30 seconds):**
- Each service exposes a health endpoint that says "I am healthy and responsive"
- If a service is unhealthy, that narrows the scope dramatically

**d) If still unclear, narrow by request ID:**
- Ask the client for their request ID (usually in the response or browser console)
- This is the `X-Request-ID` header that GW added
- Use Day 48 log parser to find all lines with this ID across all services and trace the flow

### Triage Heuristic (3 Questions)

1. **Are any services down?** (Check health endpoints)
   - Yes → Restart the unhealthy service; verify it comes back online
   - No → Go to question 2

2. **Are the logs showing any ERROR lines?** (Check log groups)
   - Yes → Classify with Day 52 tool; follow the remediation for that class
   - No → Go to question 3

3. **Is the issue intermittent?** (Ask the client to reproduce)
   - Yes → Check TM throttle counters; check GW event sync lag
   - No → Service is likely healthy but client misconfigured (bad token, no subscription); verify credentials

## Exercises

### Exercise 1: CloudWatch Insights Query for Failed Requests

**Scenario:** You receive a page at 2:00 PM. Your first step is to find all requests that generated an ERROR line in the last 15 minutes.

**Task:** Write a CloudWatch Insights query that returns a sorted list of activityIds (from Day 46), grouped by how many errors each one generated.

**Hint:** The keyword is `group by activityId`. CloudWatch Insights supports `fields`, `filter`, `stats`, `sort`, and `limit` operations.

**Solution Sketch:**

```
fields @logStream, @message, @timestamp, activityId
| filter level = "ERROR" OR level = "FATAL"
| stats count(*) as error_count by activityId
| sort error_count desc
| limit 20
```

**Explanation:**
- `fields`: Select these columns so you can see which service logged it
- `filter level = "ERROR" OR level = "FATAL"`: Only error lines
- `stats count(*) as error_count by activityId`: Group by activityId, count errors per group
- `sort error_count desc`: Most errors first
- `limit 20`: Top 20 most-errored requests

This query tells you: "activityId abc123 generated 7 errors; activityId def456 generated 3 errors." You can then copy `abc123` and run the Day 48 parser to get the full trace.

---

### Exercise 2: IS Returning 503 on `/oauth2/token`

**Scenario:** Your monitoring alert says "IS health endpoint returning 503." GW cannot get tokens; all API calls fail with 401 (bad token).

**Task:** List the 3 most likely ECS Fargate causes (not WSO2-specific issues like misconfiguration).

**Hint:** Think about ECS task lifecycle (startup, resource limits, networking). What can cause a JVM process to be unresponsive?

**Solution Sketch:**

1. **IS container still in startup phase:**
   - ECS task definition specifies a `startPeriod` (e.g., 30 seconds)
   - IS JVM is loading (slow on first boot), still initializing the keystore
   - Health check is returning 503 during this window
   - **Immediate action:** Wait for startPeriod to elapse; if 503 persists after 60 seconds, move to #2

2. **IS JVM out of memory (OOM kill):**
   - Task memory was set too low (e.g., 512 MB for a heavy APIM IS instance)
   - JVM tried to allocate memory; OS killed the process
   - Container exited; ECS automatically restarts it
   - New container in startup, still serving 503
   - **Immediate action:** Check ECS task logs for "OutOfMemoryError" or task killed messages; increase task memory in the task definition; wait for new task to come up

3. **Security Group blocking inbound port 9443:**
   - IS listens on 9443 for HTTPS
   - GW's security group doesn't have a rule allowing traffic to IS SG on port 9443
   - GW connection attempt times out; appears as 503 from IS's perspective
   - **Immediate action:** Check SG rules in AWS console; add ingress rule: "IS SG: allow 9443 from GW SG"

**Follow-up diagnostics:**
- `aws ecs describe-tasks --cluster prod --tasks <task-arn>` → check task status (RUNNING vs STOPPED)
- `aws logs tail /ecs/prod/wso2-is --follow` → watch for errors in real time
- `aws ec2 describe-security-groups --group-ids <sg-id>` → verify SG rules

---

### Exercise 3: GW Returns 200 to Request That Should Be Throttled

**Scenario:** Your monitoring shows that GW returned 200 OK to a request, but the client says they were supposed to hit their throttle limit (Gold tier = 100 req/min).

**Task:** List 2 causes and the diagnostic for each.

**Hint:** Throttle policy comes from CP; throttle state/counters live on TM. What can go wrong in that chain?

**Solution Sketch:**

1. **GW lost connection to TM; fell back to local throttle limit (or no limit):**
   - GW opens a connection to TM for throttle checks: `POST /throttle/check`
   - Connection drops (TM restarted, network blip, SG rule changed)
   - GW cannot reach TM to check quota
   - GW either: (a) allows the request (fail-open), or (b) checks a stale local counter
   - **Immediate action:** 
     - Check TM health: `curl -sf https://tm.wso2.internal:9443/services/Version`
     - Check GW → TM SG rule: must allow 9611/9711 from GW SG to TM SG
     - Check GW logs for "throttle connection error" or similar
     - Restart GW to force re-connection to TM

2. **Throttle policy was updated in CP but GW's event cache hasn't received it yet (lag):**
   - Admin updates throttle policy in CP: "Gold tier: 50 req/min" (was 100)
   - CP fires `POLICY_CHANGED` event
   - SSE connection to GW is slow or delayed
   - GW's cache still says "Gold tier: 100 req/min"
   - GW allows request 101 when it should deny it
   - **Immediate action:**
     - This is expected behavior (eventual consistency)
     - Check CP logs for the policy update timestamp
     - Check GW logs for when the event was received
     - Lag should be <1 second; if >5 seconds, check network or CP load
     - Restart GW to force full sync: `GET /admin/sync` will fetch latest policy

**Diagnostic command (both cases):**
```bash
# Check TM health
curl -sf https://tm.wso2.internal:9443/services/Version && echo "TM OK" || echo "TM DOWN"

# Check GW logs for throttle errors
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "throttle.*error OR throttle.*connection" \
  --start-time $(date -d '5 minutes ago' +%s000)

# Check when policy event was received
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "POLICY_CHANGED" \
  --start-time $(date -d '5 minutes ago' +%s000)
```

---

## Common Failure Classes & Immediate Actions

| Class | HTTP Code | Cause | Immediate Action |
|---|---|---|---|
| `AUTH_FAILED` (900901) | 401 | JWT invalid or missing | 1. Check IS health. 2. Run `GET /oauth2/jwks` to verify keys. 3. Client verify token is correct. |
| `SUBSCRIPTION_NOT_FOUND` (900908) | 403 | Subscription deleted; not cached yet | 1. Check CP health. 2. GW call `GET /admin/sync` to refresh. 3. Restart GW if lag persists. |
| `THROTTLE_EXCEEDED` (900800) | 429 | Over quota | 1. Check TM health. 2. Check GW→TM SG (9611/9711). 3. Wait for window reset (e.g., 1 minute) or upgrade subscription tier. |
| `BACKEND_TIMEOUT` | 504 | Backend not responding | 1. Check backend health in AWS console. 2. Check backend ECS task logs. 3. Check SG: GW can reach backend. 4. Restart backend if necessary. |
| `JWT_EXPIRED` | 401 | Token TTL exceeded | 1. Client requests new token from IS. 2. Client retries API call with new token. 3. Check IS health and NTP sync. |
| `JWT_INVALID_SIGNATURE` | 401 | JWKS changed; GW still using old key | 1. Reload GW's JWKS cache: check IS health, then restart GW. 2. Check IS keystore rotation logs. |
| `EVENT_SYNC_LAG` | 403 (stale) | CP event not delivered to GW yet | 1. This is transient. 2. Client retry; event should arrive within 5 seconds. 3. If persistent, restart GW to force `/admin/sync`. |

## Per-Service Checklist

### Universal Gateway (GW)

- **Log group:** `/ecs/{env}/wso2-gw`
- **Health check:** `GET http://gw.wso2.internal:8280/services/Version` (or via AWS ECS health endpoint)
- **Key loggers:** `org.wso2.carbon.apimgt.gateway.handlers.security` (JWT validation)
- **Common issues:**
  - JWT validation fails → check IS JWKS freshness
  - Subscription not found → check CP event sync and cache
  - Unable to reach TM → check SG rules for ports 9611/9711
- **Restart triggers:** IS keystore rotation, CP sync lost, TM unreachable

### Identity Server (IS)

- **Log group:** `/ecs/{env}/wso2-is`
- **Health check:** `HEAD https://is.wso2.internal:9443/oauth2/token`
- **Key loggers:** `org.wso2.carbon.identity.oauth2`, `org.wso2.carbon.identity.jwt`
- **Common issues:**
  - Token generation fails → check keystore, check JVM heap
  - Introspection timeout → check IS load, database connection pool
  - Session limit exceeded → increase `MaxSessionsPerUser` in config; or add Redis session store
- **Restart triggers:** Keystore rotation, OOM kill detected, config change, bundle init error

### Control Plane (CP)

- **Log group:** `/ecs/{env}/wso2-cp`
- **Health check:** `GET https://cp.wso2.internal:9443/health`
- **Key loggers:** `org.wso2.carbon.apimgt.impl`, `org.wso2.carbon.event`
- **Common issues:**
  - API publish fails → check database connection
  - Event hub not running → check JMS broker logs (if external) or in-process event queue
  - Slow SSE delivery → check CP CPU load; check network between CP and GW
- **Restart triggers:** Database failover, event hub broker restart, high memory usage

### Traffic Manager (TM)

- **Log group:** `/ecs/{env}/wso2-tm`
- **Health check:** `GET https://tm.wso2.internal:9443/services/Version`
- **Key loggers:** `org.wso2.carbon.throttle`, `org.wso2.carbon.analytics`
- **Common issues:**
  - Throttle check always returns allow → SG blocking GW→TM, or TM not running
  - Counters not resetting → check system clock (NTP), check if TM restarted mid-window
  - Memory leak → throttle counters growing indefinitely; restart TM
- **Restart triggers:** Config change, SG rule fixed, clock skew resolved, memory cleanup

## Recovery Procedures

### Service Restart (One at a Time)

**DO NOT restart all four services simultaneously.** CP restart drops the event bus; all GWs lose real-time sync.

**Order:** Always start with the lowest-dependency service first.

1. **Restart TM first** (no other service depends on it for startup)
   ```bash
   # Trigger rolling restart in ECS
   aws ecs update-service --cluster prod --service wso2-tm --force-new-deployment
   
   # Monitor until stable
   aws ecs describe-services --cluster prod --services wso2-tm
   ```

2. **Restart GW next** (depends on IS + CP, but is stateless)
   ```bash
   aws ecs update-service --cluster prod --service wso2-gw --force-new-deployment
   # GW will call /admin/sync on CP automatically
   ```

3. **Restart CP** (many services depend on it, but restart is usually fast)
   ```bash
   aws ecs update-service --cluster prod --service wso2-cp --force-new-deployment
   ```

4. **Restart IS last** (stateful; most expensive to restart)
   ```bash
   aws ecs update-service --cluster prod --service wso2-is --force-new-deployment
   ```

### Smoke Test (Before Declaring Resolved)

**Always run this before closing the incident:**

```bash
# 1. Get a valid token
TOKEN=$(curl -s -X POST https://is.wso2.internal:9443/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'grant_type=client_credentials&client_id=demo-client&client_secret=demo-secret' \
  | jq -r .access_token)

if [ -z "$TOKEN" ]; then
  echo "FAILED: Could not obtain token from IS"
  exit 1
fi

# 2. Make an API call
RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/response.body \
  -H "Authorization: Bearer $TOKEN" \
  https://gw.wso2.internal:8243/petstore/v1/pets)

if [ "$RESPONSE" != "200" ]; then
  echo "FAILED: API call returned $RESPONSE"
  cat /tmp/response.body
  exit 1
fi

# 3. Verify throttle (Gold tier should allow 100 req/min)
SUCCESS=0
for i in $(seq 1 101); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    https://gw.wso2.internal:8243/petstore/v1/pets)
  if [ "$CODE" == "429" ]; then
    SUCCESS=1
    break
  fi
done

if [ $SUCCESS -eq 1 ]; then
  echo "✓ All systems operational"
  exit 0
else
  echo "WARNING: Throttle not enforced (101+ requests allowed)"
  exit 1
fi
```

## Escalation Criteria

Escalate to WSO2 support (or the platform team) if:

- **Unknown failure class:** Error message doesn't match any of the 7 classes; likely a new bug
- **OSGi bundle failure:** Logs show `ERROR.*BundleException` or `ERROR.*ActivationException` in IS or CP; indicates a plugin conflict
- **Keystore corruption:** IS fails with `ERROR.*KeyStore` or `ERROR.*PKCS12`; may require manual keystore recovery
- **Database corruption:** CP logs show `ERROR.*constraint violation` or `ERROR.*deadlock`; may need DBA intervention
- **Cascading failures:** Multiple services failing with interconnected errors; may indicate network partition or cascading timeout

---

## Notes

- **Fail-safe design:** If GW cannot reach TM or CP, it should fail **open** (allow the request) rather than fail **closed** (deny all). This prevents thundering herd of 503s during a CP outage.
- **Observability first:** The Day 46 activity ID is your lifeline. Every log line should include it. If you see logs without activityId, logging is misconfigured.
- **Triage before deep-dive:** Spend 60 seconds identifying the failure class before diving into code. Wrong hypothesis wastes 30 minutes.
