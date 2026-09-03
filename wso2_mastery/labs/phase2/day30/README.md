# Lab: Day 30 — GW Capstone (Use the Playbook)

## Overview

This is the Phase 2 capstone lab. You'll run the Day 27 gateway (which you built in previous labs),
generate real error scenarios (401, 403, 429), and use the GW Debug Playbook to diagnose them in < 3 minutes.

This simulates a production incident response exercise.

## Objective

1. Start the Day 27 gateway (includes JWT validation, subscriptions, throttling, mock TM)
2. Generate test errors (401, 403, 429)
3. Enable DEBUG logging
4. Use the playbook to diagnose each error
5. Document the root cause and remediation

## Files

```
labs/phase2/day27/          ← Full gateway (use this to generate errors)
playbook.md                 ← Debug runbook (reference this)
labs/phase2/day30/          ← This capstone lab
```

## Prerequisites

- Docker and Docker Compose installed
- Day 27 lab files available (main.go, docker-compose.yml, etc.)
- jq installed (for JSON parsing): `brew install jq`

## Instructions

### Step 1: Start the Day 27 Gateway

Navigate to the Day 27 lab and start the services:

```bash
cd labs/phase2/day27
docker-compose up --build
```

Wait for output showing:
```
gateway    | [... ] INFO ... Gateway started on port 8243
issuers    | [... ] INFO ... Token issuer running on port 8888
tm         | [... ] INFO ... Mock TM listening on port 9611
admin      | [... ] INFO ... Admin API on port 9090
```

### Step 2: Set Up Test Environment

In a new terminal:

```bash
# Set env vars for easy API calls
export GW_HOST="https://localhost:8243"
export GW_ADMIN="http://localhost:9090"
export ISSUER="http://localhost:8888"

# Disable SSL verification for dev (localhost only!)
export INSECURE="-k"
```

### Step 3: Prepare Test Subscriptions

Register two test apps and subscriptions:

```bash
# App 1: subscribed to hello API (gold tier)
curl -s -X POST $GW_ADMIN/admin/subscriptions $INSECURE \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname": "app1",
    "apiname": "hello",
    "subscriptiontier": "gold",
    "keytype": "PRODUCTION"
  }' | jq .

# App 2: subscribed to hello API (silver tier)
curl -s -X POST $GW_ADMIN/admin/subscriptions $INSECURE \
  -H "Content-Type: application/json" \
  -d '{
    "applicationname": "app2",
    "apiname": "hello",
    "subscriptiontier": "silver",
    "keytype": "PRODUCTION"
  }' | jq .

# App 3: NOT subscribed to orders (we'll test 403)
# (Don't register this one)
```

### Step 4: Generate Test Errors

#### Scenario A: Generate 401 Expired Token

```bash
# Get a token (valid for 30 seconds in dev)
TOKEN=$(curl -s "$ISSUER/token?username=alice&appname=app1" | jq -r .token)

# Verify it works first
curl -s $GW_HOST/api/hello -H "Authorization: Bearer $TOKEN" $INSECURE
# Expected: 200 OK or 502 (backend error, not auth error)

# Wait 31 seconds for token to expire
sleep 31

# Try again with expired token
curl -s $GW_HOST/api/hello -H "Authorization: Bearer $TOKEN" $INSECURE
# Expected: 401 Unauthorized
```

#### Scenario B: Generate 403 Subscription Not Found

```bash
# Get a token for app3 (which has NO subscription to any API)
TOKEN3=$(curl -s "$ISSUER/token?username=charlie&appname=app3" | jq -r .token)

# Try to call hello API (app3 is not subscribed)
curl -s $GW_HOST/api/hello -H "Authorization: Bearer $TOKEN3" $INSECURE
# Expected: 403 Forbidden
```

#### Scenario C: Generate 429 Throttle

```bash
# Get a fresh token for app2 (silver tier, 2000 req/min quota)
TOKEN2=$(curl -s "$ISSUER/token?username=bob&appname=app2" | jq -r .token)

# Send 2001 requests in rapid succession to exceed quota
for i in {1..2001}; do
  curl -s $GW_HOST/api/hello -H "Authorization: Bearer $TOKEN2" $INSECURE > /dev/null
done

# Last request should get 429
curl -s $GW_HOST/api/hello -H "Authorization: Bearer $TOKEN2" $INSECURE
# Expected: 429 Too Many Requests
```

### Step 5: Enable DEBUG Logging

Edit the gateway's log4j2.properties to enable the 5 GW-specific loggers (from Day 28):

**Option A: Docker Volume**

```bash
# Copy log config to local directory
docker cp <gateway-container>:/opt/wso2am-universal-gw/repository/conf/log4j2.properties /tmp/log4j2.properties

# Edit it (add 5 loggers from Day 28 SOLUTION)
vim /tmp/log4j2.properties

# Copy back
docker cp /tmp/log4j2.properties <gateway-container>:/opt/wso2am-universal-gw/repository/conf/log4j2.properties

# Restart gateway
docker-compose restart gateway
```

**Option B: Modify Dockerfile**

Add to docker-compose.yml gateway service:

```yaml
environment:
  - LOG_LEVEL=DEBUG
```

Then restart:
```bash
docker-compose up --build -d gateway
```

### Step 6: Use the Playbook to Diagnose

For each error scenario, follow the playbook (playbook.md):

```bash
# Get logs from the last error
docker logs gateway 2>&1 | tail -100 > /tmp/gw.log

# Use the playbook's decision tree to identify:
# 1. Error type (401/403/429)
# 2. Root cause (from log patterns)
# 3. Remediation

# Example: 401 error
grep "Token expired" /tmp/gw.log
grep "Signature verification failed" /tmp/gw.log
grep "Public key not found" /tmp/gw.log
# Based on which pattern matches, recommend fix
```

### Step 7: Document Your Findings

For each error scenario (A, B, C), document:

1. **Error Scenario:** What was the test case?
2. **HTTP Status:** What status code was returned?
3. **Log Pattern:** Which WARN/ERROR log matched?
4. **Root Cause:** What went wrong?
5. **Remediation:** How would you fix it?

Example documentation:

```
## Scenario A: 401 Expired Token

**Test Case:** Wait 31 seconds after token issuance, then retry API call

**HTTP Status:** 401 Unauthorized

**Log Pattern:** 
  WARN {JWTValidator} - JWT token validation failed: Token expired

**Root Cause:** 
  Token TTL was 30 seconds; request arrived at 31 seconds after issuance

**Remediation:**
  Client must request a new token from the Identity Server
  Token TTL in production is usually 1 hour; test setup uses 30 seconds for demo
```

## Questions to Answer

1. **For each error scenario (401/403/429), what log pattern confirmed the diagnosis?**

2. **If you had 3 GW replicas and got intermittent 429 errors with low global traffic, what would you check first?**

3. **How would you use correlation IDs (activityid) to trace a single request across multiple replicas?**

4. **What's the difference between "GW logs show subscription not found" vs "app is subscribed but key type mismatch"?**

5. **If DEBUG logs are disabled, how would you diagnose a 401 error?**

## Expected Duration

Completing all error scenarios and playbook steps: **< 30 minutes**

## Hints

- Enable DEBUG logging before generating errors so you capture the full request trace
- Use `grep -E "(WARN|ERROR|DEBUG.*JWT|DEBUG.*throttl)"` to filter out noise
- Correlation IDs make it easy to trace a single request; log them with each request
- In production, use CloudWatch log filtering (AWS) or ELK to search logs

## Teardown

Stop the gateway when done:

```bash
cd labs/phase2/day27
docker-compose down -v
```

