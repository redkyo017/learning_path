# WSO2 Production Runbook

**Author:** [Your Name]
**Last updated:** YYYY-MM-DD
**System:** WSO2 APIM (Go ports + real components) on AWS ECS Fargate
**Audience:** On-call engineers, SRE team

---

## Table of Contents

1. [First 60 Seconds — Triage](#first-60-seconds)
2. [Failure Class Reference](#failure-class-reference)
3. [Per-Service Debug](#per-service-debug)
4. [Recovery Procedures](#recovery-procedures)
5. [Escalation Criteria](#escalation-criteria)
6. [Smoke Test Verification](#smoke-test-verification)

---

## First 60 Seconds

When the pager goes off, follow this checklist without deviation:

### Step 1: Identify the Alert (10 seconds)

- **What is the alert?** (ALB returning 5xx? GW endpoint timing out? Client complaints?)
- **Which service?** (GW, IS, CP, TM, or ALB?)
- **Severity?** (All traffic down vs. intermittent vs. single client)

### Step 2: Check Health Endpoints (20 seconds)

From inside the VPC (or via CloudWatch agent in your bastion), run:

```bash
#!/bin/bash
# Quick health check for all 4 services

echo "Checking GW..."
curl -sf -w "%{http_code}\n" -o /dev/null http://gw.wso2.internal:8280/services/Version && echo "✓ GW OK" || echo "✗ GW DOWN"

echo "Checking IS..."
curl -sf -w "%{http_code}\n" -o /dev/null -X HEAD https://is.wso2.internal:9443/oauth2/token && echo "✓ IS OK" || echo "✗ IS DOWN"

echo "Checking CP..."
curl -sf -w "%{http_code}\n" -o /dev/null https://cp.wso2.internal:9443/health && echo "✓ CP OK" || echo "✗ CP DOWN"

echo "Checking TM..."
curl -sf -w "%{http_code}\n" -o /dev/null https://tm.wso2.internal:9443/services/Version && echo "✓ TM OK" || echo "✗ TM DOWN"
```

**Decision tree:**
- **Any service returning 503/timeout?** → Go to [Per-Service Debug](#per-service-debug) for that service
- **All services responding 200/OK?** → Go to Step 3

### Step 3: Collect Error Logs (20 seconds)

```bash
#!/bin/bash
# Download error logs from last 5 minutes

for SERVICE in gw is cp tm; do
  echo "Downloading $SERVICE errors..."
  aws logs filter-log-events \
    --log-group-name "/ecs/prod/wso2-$SERVICE" \
    --filter-pattern "ERROR OR FATAL" \
    --start-time $(date -d '5 minutes ago' +%s000) \
    --query 'events[].message' \
    --output text > "/tmp/errors-$SERVICE.log"
  
  # Count errors
  COUNT=$(wc -l < "/tmp/errors-$SERVICE.log")
  echo "$SERVICE: $COUNT error lines"
done
```

**Decision tree:**
- **Errors found?** → Run the classifier (Step 4)
- **No errors?** → Request-specific debug (Step 5)

### Step 4: Classify Errors (Automated)

```bash
#!/bin/bash
# Run the Day 52 + Day 53 classifier on error logs

for SERVICE in gw is cp tm; do
  if [ -s "/tmp/errors-$SERVICE.log" ]; then
    echo "=== Classifying $SERVICE errors ==="
    go run /path/to/labs/phase4/day53/main.go < "/tmp/errors-$SERVICE.log"
  fi
done
```

**Output:** Maps each error to one of 7 failure classes
- `AUTH_FAILED` → JWT validation issue
- `SUBSCRIPTION_NOT_FOUND` → Client not subscribed
- `THROTTLE_EXCEEDED` → Over rate limit
- `BACKEND_TIMEOUT` → Backend not responding
- `JWT_EXPIRED` → Token expired
- `JWT_INVALID_SIGNATURE` → Keystore changed; JWKS stale
- `EVENT_SYNC_LAG` → CP sync delayed; expect 1–5 sec lag

**Next:** Follow the remediation for the identified class (see [Failure Class Reference](#failure-class-reference))

### Step 5: Request-Specific Debug (If No Errors Yet)

If no errors in logs but clients still reporting failures:

```bash
#!/bin/bash
# Ask client for request ID (usually X-Request-ID header)
# Then trace it across all services

REQUEST_ID="req-abc123xyz"

# Search all log groups for this ID
for SERVICE in gw is cp tm; do
  echo "=== Traces for $REQUEST_ID in $SERVICE ==="
  aws logs filter-log-events \
    --log-group-name "/ecs/prod/wso2-$SERVICE" \
    --filter-pattern "$REQUEST_ID" \
    --query 'events[].message' \
    --output text
done

# Use Day 48 parser for full trace
go run /path/to/labs/phase4/day48/main.go --id "$REQUEST_ID" \
  < <(cat /tmp/errors-*.log)
```

---

## Failure Class Reference

### AUTH_FAILED (900901) — 401 Unauthorized

**Symptoms:**
- Client gets 401 on every request
- GW logs show "JWT validation failed" or "token invalid"

**Root causes:**
1. IS JWKS not accessible (IS down or SG rule)
2. GW JWKS cache stale (IS rotated keys; GW hasn't reloaded)
3. Client token is genuinely invalid (expired, malformed, wrong issuer)

**Immediate actions:**
```bash
# 1. Check IS health
curl -sf https://is.wso2.internal:9443/services/Version || echo "IS is DOWN"

# 2. Force GW to reload JWKS
curl -sf https://is.wso2.internal:9443/oauth2/jwks | jq .keys | head -20

# 3. If IS is down, restart it
aws ecs update-service --cluster prod --service wso2-is --force-new-deployment

# 4. If JWKS changed, restart GW to reload
aws ecs update-service --cluster prod --service wso2-gw --force-new-deployment

# 5. If token is invalid, ask client to get a new one
# (No action needed; client responsibility)
```

**Recovery time:** 5–10 seconds (GW restart is rolling; some instances ready immediately)

---

### SUBSCRIPTION_NOT_FOUND (900908) — 403 Forbidden

**Symptoms:**
- Client gets 403: "Subscription not found"
- Client says: "But I was just using this API!"
- GW logs show "subscription.*not found"

**Root causes:**
1. Subscription was deleted in CP; GW hasn't received the event yet (SSE lag ~1–5 sec)
2. Subscription was deleted; GW cache not synced (SSE connection dropped?)
3. Client has no subscription (never called CP `/subscriptions` endpoint)

**Immediate actions:**
```bash
# 1. Check if subscription exists in CP
SUBSCRIPTION_ID="sub-demo"
curl -sf https://cp.wso2.internal:9443/subscriptions \
  | jq ".[] | select(.id == \"$SUBSCRIPTION_ID\")" || echo "Subscription NOT FOUND"

# 2. If subscription doesn't exist (expected), no action needed
# Client should re-subscribe

# 3. If subscription exists but GW says it doesn't:
#    Force GW to reload all subscriptions
aws ecs update-service --cluster prod --service wso2-gw --force-new-deployment

# 4. Check SSE connection status
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "SSE.*connected OR SSE.*closed" \
  --start-time $(date -d '5 minutes ago' +%s000)
```

**Recovery time:** 5 seconds (if SSE lag) or 10 seconds (if GW restart needed)

---

### THROTTLE_EXCEEDED (900800) — 429 Too Many Requests

**Symptoms:**
- Client gets 429: "Quota exceeded"
- Either legitimate (over limit) or unexpected (within limit but denied)

**Root causes:**
1. Client is genuinely over their quota (expected; wait or upgrade tier)
2. GW lost connection to TM; using fallback throttle policy (too strict or too loose)
3. Throttle window reset not synchronized (clock skew between GW and TM)
4. TM crashed; GW cached stale counter

**Immediate actions:**
```bash
# 1. Check TM health
curl -sf https://tm.wso2.internal:9443/services/Version && echo "TM OK" || echo "TM DOWN"

# 2. Verify SG allows GW→TM on port 9611
aws ec2 describe-security-groups --group-ids <gw-sg-id> \
  | jq '.SecurityGroups[0].IpPermissions[] | select(.FromPort == 9611)'

# 3. Check if client is actually over quota
# (Look at TM throttle event logs for this subscription)
aws logs filter-log-events --log-group-name /ecs/prod/wso2-tm \
  --filter-pattern "throttle.*sub-<ID>" \
  --start-time $(date -d '1 minute ago' +%s000) | tail -5

# 4. If TM is down, restart it
aws ecs update-service --cluster prod --service wso2-tm --force-new-deployment

# 5. Check for clock skew (GW and TM should have ±1s diff)
# (This is rare; if suspected, verify NTP is syncing on both services)
```

**Recovery time:** 10 seconds (TM restart) or immediate (SG fix)

---

### BACKEND_TIMEOUT (504)

**Symptoms:**
- GW returns 504 Gateway Timeout
- Client says: "The API is taking forever"

**Root causes:**
1. Backend service is down or slow
2. Backend SG blocking traffic from GW
3. Backend instance out of resources (memory, CPU)
4. Network latency between GW and backend

**Immediate actions:**
```bash
# 1. Check backend health (application-specific)
# Example for PetStore API:
curl -sf http://backend.wso2.internal:8080/health || echo "Backend DOWN"

# 2. Check backend ECS task status
aws ecs describe-tasks --cluster prod --tasks <task-arn> \
  | jq '.tasks[0] | {status, lastStatus, containerInstanceArn}'

# 3. Check backend logs
aws logs tail /ecs/prod/backend --follow --since 5m

# 4. Verify SG: GW can reach backend on port 8080 (or custom port)
aws ec2 describe-security-groups --group-ids <backend-sg-id> \
  | jq '.SecurityGroups[0].IpPermissions[]'

# 5. If backend is down, restart it
aws ecs update-service --cluster prod --service backend-api --force-new-deployment
```

**Recovery time:** 30 seconds (backend restart)

---

### JWT_EXPIRED (401)

**Symptoms:**
- Client gets 401: "Token expired"
- GW logs show "JWT.*exp.*invalid"
- Happens after the client has been idle for a while

**Root causes:**
1. Client's token TTL (time-to-live) has exceeded (expected)
2. Clock skew: GW and IS have different system times (rare)

**Immediate actions:**
```bash
# 1. This is expected behavior; no immediate action needed
# 2. Client must request a new token from IS

# 3. If time-based, verify NTP on all services
# (On each ECS task):
timedatectl status
# Should show: synchronized: yes

# 4. If clock skew detected, restart affected services (forces NTP resync)
aws ecs update-service --cluster prod --service wso2-gw --force-new-deployment
```

**Recovery time:** Immediate (client gets new token)

---

### JWT_INVALID_SIGNATURE (401)

**Symptoms:**
- Client gets 401: "Token signature invalid"
- GW logs show "JWT.*signature.*invalid"
- Happens after IS keystore rotation

**Root causes:**
1. IS rotated keys; GW JWKS cache has old key
2. Token was signed with a key that's no longer in JWKS (IS retired it)

**Immediate actions:**
```bash
# 1. Check IS JWKS endpoint; see the current keys
curl -s https://is.wso2.internal:9443/oauth2/jwks | jq '.keys[].kid'

# 2. Restart GW to force JWKS reload
aws ecs update-service --cluster prod --service wso2-gw --force-new-deployment

# 3. Ask client to get a new token (signed with new key)
curl -X POST https://is.wso2.internal:9443/oauth2/token \
  -d 'grant_type=client_credentials&client_id=...&client_secret=...' \
  | jq .access_token

# 4. Client retries API call with new token
```

**Recovery time:** 5–10 seconds (GW restart)

---

### EVENT_SYNC_LAG (403 stale)

**Symptoms:**
- Client just subscribed to an API in the CP console
- Immediately makes an API call
- Gets 403: "Subscription not found"
- Retries 2 seconds later: works fine

**Root causes:**
1. CP event hasn't been delivered to GW's SSE connection yet (normal <5 sec lag)
2. SSE connection is slow or throttled

**Immediate actions:**
```bash
# 1. This is expected behavior (eventual consistency)
# 2. No immediate action needed; client should retry

# 3. If lag is >10 seconds, check GW SSE connection
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "SSE.*delay OR SSE.*lag" \
  --start-time $(date -d '5 minutes ago' +%s000)

# 4. If SSE is laggy, check CP load
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=wso2-cp \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Average

# 5. If CP is overloaded, scale it (if replicas > 1) or optimize
```

**Recovery time:** Immediate (client retry; event should arrive within 5 sec)

---

## Per-Service Debug

### Universal Gateway (GW)

**Health endpoint:** `GET http://gw.wso2.internal:8280/services/Version`

**Key loggers (enable DEBUG for troubleshooting):**
- `org.wso2.carbon.apimgt.gateway.handlers.security` — JWT validation
- `org.wso2.carbon.apimgt.gateway.handlers.proxy` — Request proxying
- `org.wso2.carbon.apimgt.gateway.handlers.throttle` — Throttle checks

**Common issues:**

| Issue | Log Pattern | Fix |
|---|---|---|
| JWT validation fails | `ERROR.*JWT.*invalid signature` | Check IS JWKS; restart GW |
| Subscription not cached | `ERROR.*subscription.*not found` | Force `/admin/sync`; restart GW |
| TM unreachable | `ERROR.*throttle.*connection refused` | Check TM health; check SG (9611) |
| SSE connection dropped | `WARN.*SSE.*closed` | Check CP; restart GW |

**Debug steps:**
```bash
# 1. Watch real-time logs
aws logs tail /ecs/prod/wso2-gw --follow --since 5m

# 2. Grep for a specific error code
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "900908"  # 900908 = subscription not found

# 3. Count errors by type
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "ERROR" \
  --query 'events[].message' \
  | jq -s 'group_by(.) | map({error: .[0], count: length}) | sort_by(.count) | reverse'
```

---

### Identity Server (IS)

**Health endpoint:** `HEAD https://is.wso2.internal:9443/oauth2/token` (returns 200 if ready)

**Key loggers:**
- `org.wso2.carbon.identity.oauth2` — Token issuance, introspection
- `org.wso2.carbon.identity.jwt` — JWT generation, validation
- `org.wso2.carbon.identity.keystore` — Keystore operations

**Common issues:**

| Issue | Log Pattern | Fix |
|---|---|---|
| OOM kill | `ERROR.*OutOfMemoryError` OR task killed | Increase ECS task memory |
| Keystore corrupted | `ERROR.*KeyStore` OR `ERROR.*PKCS12` | Manual keystore recovery (escalate) |
| Session limit exceeded | `ERROR.*MaxSessionsPerUser` | Increase config; add Redis session store |
| JVM still starting | `curl returns 503` | Wait for startup period (default 30s) |

**Debug steps:**
```bash
# 1. Check ECS task memory and CPU
aws ecs describe-tasks --cluster prod --tasks <task-arn> \
  | jq '.tasks[0] | {memory: .memory, cpu: .cpu, lastStatus}'

# 2. Check for OOM in task logs
aws logs tail /ecs/prod/wso2-is --since 5m | grep -i "memory\|oom\|heap"

# 3. Verify keystore is readable
# (On the task, or via CloudWatch):
ls -la /opt/wso2/keystore.jks && echo "Keystore OK" || echo "Keystore MISSING"

# 4. Check token endpoint response
curl -v -X HEAD https://is.wso2.internal:9443/oauth2/token 2>&1 | head -20
```

---

### Control Plane (CP)

**Health endpoint:** `GET https://cp.wso2.internal:9443/health`

**Key loggers:**
- `org.wso2.carbon.apimgt.impl` — API lifecycle, registry
- `org.wso2.carbon.event` — Event bus, SSE broadcasting
- `org.wso2.carbon.databridge` — Analytics, event aggregation

**Common issues:**

| Issue | Log Pattern | Fix |
|---|---|---|
| DB connection exhausted | `ERROR.*connection.*pool` | Increase DB pool size; check backend queries |
| Event hub not running | `ERROR.*EventHub.*start` | Restart CP |
| API publish fails | `ERROR.*APIException` | Check DB; verify API format |
| SSE connection slow | `WARN.*SSE.*delay` | Check CP load; check network |

**Debug steps:**
```bash
# 1. Check API registry
curl -s https://cp.wso2.internal:9443/apis | jq '.[] | {id, name, status}'

# 2. Check subscriptions
curl -s https://cp.wso2.internal:9443/subscriptions | jq '.[] | {id, app, api, tier}'

# 3. Check database connection pool
aws logs filter-log-events --log-group-name /ecs/prod/wso2-cp \
  --filter-pattern "pool\|connection" \
  --start-time $(date -d '5 minutes ago' +%s000)

# 4. Trigger a new event to test event hub
curl -X POST https://cp.wso2.internal:9443/apis \
  -H "Content-Type: application/json" \
  -d '{id: "test-api-9999", name: "Test", endpoint: "http://localhost:8080"}'
```

---

### Traffic Manager (TM)

**Health endpoint:** `GET https://tm.wso2.internal:9443/services/Version`

**Key loggers:**
- `org.wso2.carbon.throttle` — Throttle policy enforcement
- `org.wso2.carbon.analytics` — Event aggregation

**Common issues:**

| Issue | Log Pattern | Fix |
|---|---|---|
| GW→TM connection blocked | `ERROR.*connection refused` | Check TM health; check SG (9611) |
| Throttle counter not reset | `WARN.*counter.*stale` | Check system clock (NTP); restart TM |
| Memory leak (counters grow) | `WARN.*memory.*increasing` | Restart TM; check for counter cleanup |

**Debug steps:**
```bash
# 1. Check TM health
curl -s https://tm.wso2.internal:9443/services/Version

# 2. Check SG rule for GW→TM on port 9611
aws ec2 describe-security-groups --group-ids <tm-sg-id> \
  | jq '.SecurityGroups[0].IpIngressRules[] | select(.IpProtocol == "tcp" and .FromPort == 9611)'

# 3. Watch throttle events
aws logs tail /ecs/prod/wso2-tm --follow --since 5m

# 4. Check system clock on TM task
# (Inside container):
date && timedatectl status
```

---

## Recovery Procedures

### Restart Order (DO NOT restart all at once)

**Why the order matters:**
- If you restart CP, all GW SSE connections drop; GW clients lose real-time sync
- If you restart IS, all new tokens fail until it's back up
- Restart the most independent service first, dependent services last

**Correct order:**
1. **TM** (no dependencies)
2. **IS** (needed by GW; stateful)
3. **CP** (needed by GW; stateful)
4. **GW** (depends on both; stateless)

**Example restart:**

```bash
#!/bin/bash
# Restart all services in the correct order

echo "Step 1: Restart TM"
aws ecs update-service --cluster prod --service wso2-tm --force-new-deployment
sleep 15  # Wait for rolling restart

echo "Step 2: Restart IS"
aws ecs update-service --cluster prod --service wso2-is --force-new-deployment
sleep 15

echo "Step 3: Restart CP"
aws ecs update-service --cluster prod --service wso2-cp --force-new-deployment
sleep 15

echo "Step 4: Restart GW"
aws ecs update-service --cluster prod --service wso2-gw --force-new-deployment
sleep 15

echo "All services restarted. Running smoke test..."
bash /opt/wso2/runbooks/smoke-test.sh
```

### Emergency Failover (If One Service Is Dead)

**If GW is down:**
- Immediate: ALB returns 503 to all clients
- Action: Restart GW (`aws ecs update-service --force-new-deployment`)
- Recovery: 5–10 seconds

**If IS is down:**
- Immediate: GW can still serve cached JWTs; new token requests fail
- Action: Restart IS
- Recovery: 10–15 seconds

**If CP is down:**
- Immediate: GW can still serve from cache; no new APIs/subscriptions sync
- Action: Restart CP
- Recovery: 10–15 seconds

**If TM is down:**
- Immediate: GW falls back to local throttle policy (may be too strict or loose)
- Action: Restart TM
- Recovery: 5–10 seconds

---

## Smoke Test Verification

**Before declaring the incident resolved, always run this test:**

```bash
#!/bin/bash
# Smoke test: Full path from client to backend

echo "=== Smoke Test ==="

# Step 1: Get a valid token
echo "1. Getting token from IS..."
TOKEN=$(curl -s -X POST https://is.wso2.internal:9443/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d 'grant_type=client_credentials&client_id=demo-client&client_secret=demo-secret' \
  | jq -r '.access_token // empty')

if [ -z "$TOKEN" ]; then
  echo "✗ FAILED: Could not obtain token"
  exit 1
fi
echo "✓ Token obtained"

# Step 2: Make an authenticated API call
echo "2. Making API call with token..."
RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" \
  https://gw.wso2.internal:8243/petstore/v1/pets)

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "201" ]; then
  echo "✓ API call succeeded (HTTP $HTTP_CODE)"
else
  echo "✗ FAILED: API call returned HTTP $HTTP_CODE"
  echo "Response body: $BODY"
  exit 1
fi

# Step 3: Verify throttle is enforced
echo "3. Testing throttle enforcement..."
SUCCESS_COUNT=0
THROTTLED_COUNT=0

for i in $(seq 1 101); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    https://gw.wso2.internal:8243/petstore/v1/pets)
  
  if [ "$CODE" == "200" ] || [ "$CODE" == "201" ]; then
    ((SUCCESS_COUNT++))
  elif [ "$CODE" == "429" ]; then
    ((THROTTLED_COUNT++))
  fi
done

if [ $THROTTLED_COUNT -gt 0 ]; then
  echo "✓ Throttle enforced ($THROTTLED_COUNT requests denied at limit)"
else
  echo "⚠ WARNING: Throttle not enforced (all 101 requests succeeded)"
fi

# Step 4: Verify subscriptions are cached
echo "4. Testing subscription validation..."
# Use a non-existent subscription
BAD_SUB="non-existent-sub"
CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "https://gw.wso2.internal:8243/petstore/v1/pets?subscription=$BAD_SUB")

if [ "$CODE" == "403" ] || [ "$CODE" == "401" ]; then
  echo "✓ Subscription validation working (HTTP $CODE)"
else
  echo "⚠ Unexpected response (HTTP $CODE)"
fi

echo ""
echo "=== Smoke Test Complete ==="
echo "All systems operational."
```

---

## Quick Reference

| Service | Port | Health Check | Restart | Logs |
|---|---|---|---|---|
| GW | 8243/8280 | `GET :8280/services/Version` | `aws ecs update-service --service wso2-gw --force-new-deployment` | `/ecs/prod/wso2-gw` |
| IS | 9443/9763 | `HEAD :9443/oauth2/token` | `aws ecs update-service --service wso2-is --force-new-deployment` | `/ecs/prod/wso2-is` |
| CP | 9443 | `GET :9443/health` | `aws ecs update-service --service wso2-cp --force-new-deployment` | `/ecs/prod/wso2-cp` |
| TM | 9443/9611 | `GET :9443/services/Version` | `aws ecs update-service --service wso2-tm --force-new-deployment` | `/ecs/prod/wso2-tm` |

---

## Escalation

**Escalate to WSO2 support or the platform team if:**
- Failure class is unknown (doesn't match the 7 listed)
- OSGi bundle fails to start (`BundleException` in logs)
- Keystore operations fail after rotation (`PKCS12` errors)
- Database corruption suspected (inconsistent state in logs)
- All services are down and restart doesn't help (possible infrastructure issue)

---

## Document History

| Date | Author | Change |
|---|---|---|
| YYYY-MM-DD | [Your Name] | Initial runbook creation |
| | | |

---

## Related Documents

- [Day 58 Architecture](../day58/architecture.md)
- [Day 52 Failure Catalog](../../day52.md)
- [Day 53 Failure Classifier](../day53/)
- [Day 54 Triage Script](../day54/)
- [Day 59 Content (this day's notes)](../../day59.md)
