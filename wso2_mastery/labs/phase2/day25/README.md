# Lab: Day 25 — Source Reading: WSO2 Throttle Handler

## Objective

This is a **source reading lab** — no code to write. Your task is to explore the WSO2 API Gateway
source code and understand how throttle events are generated and sent to the Traffic Manager.

## Tasks

### Task 1: Find ThrottleHandler.java

In the WSO2 universal gateway distribution, locate `ThrottleHandler.java`:

**Path:** `wso2am-universal-gw-4.7.0/components/throttle-handler/` or similar

**Questions to answer:**
1. What is the main method signature? (e.g., `handleThrottle(...)`)
2. What parameters does it accept? (e.g., request context, claims, tier)
3. What does it return? (e.g., allow/deny decision)

**Expected findings:**
```
File: wso2am-universal-gw-4.7.0/repository/components/plugins/
      com.wso2.carbon.apimgt.gateway/
      org/wso2/carbon/apimgt/gateway/handlers/security/
      throttle/ThrottleHandler.java

Main logic:
- Class: ThrottleHandler extends AbstractHandler
- Method: invoke(MessageContext messageContext)
- Performs:
  1. Extract tier from JWT claims
  2. Check local token bucket
  3. If breached: send event to TM
  4. Return allow/deny
```

---

### Task 2: Find GlobalThrottleEngineClient.java

This class handles communication with the Traffic Manager.

**Path:** `wso2am-universal-gw-4.7.0/components/traffic-manager-client/` or similar

**Questions to answer:**
1. What HTTP endpoint does it call? (Expected: `http://tm:9611/throttle/data`)
2. What is the request payload structure?
3. What is the response structure?

**Expected findings:**
```
File: ...org/wso2/carbon/apimgt/gateway/handlers/security/
      GlobalThrottleEngineClient.java

Methods:
- publishNonThrottledEvent(...) or similar
- Sends POST request to TM
- Payload: JSON with appId, tier, userId, count, timestamp, etc.

HTTP call:
POST http://tm-host:9611/throttle/data
Content-Type: application/json

{
  "applicationId": "myapp",
  "tier": "gold",
  "subscriptionId": "myapp::api1",
  "userId": "alice",
  "timestamp": "2026-09-03T10:30:00Z",
  "count": 1,
  "allowedCount": 5000
}

Response:
HTTP 200 OK
{
  "throttled": false,
  "globalCount": 4804,
  "allowedCount": 5000
}
```

---

### Task 3: Trace the Throttle Event Structure

In the source code, identify:
1. What data is included in a throttle event?
2. How is the subscription tier extracted?
3. How is the event serialized to JSON?

**Expected findings:**
```
Throttle Event Class: (name varies, might be ThrottleEvent, ThrottleMessage, etc.)

Fields:
- applicationId (String): app name from JWT
- subscriptionId (String): unique subscription ID
- tier (String): gold, silver, bronze, unlimited
- userId (String): subscriber name
- timestamp (long or String): milliseconds or ISO 8601
- count (int): number of requests in this batch
- allowedCount (int): quota for this tier

Tier mapping (hardcoded or config):
- Gold: 5000 req/min
- Silver: 2000 req/min
- Bronze: 1000 req/min
- Unlimited: no limit
```

---

### Task 4: Understand the Request Flow

In `ThrottleHandler.java`, trace the code path for:
1. A request that is NOT throttled (allowed)
2. A request that IS throttled (denied)

**Expected flow for allowed request:**
```
1. Receive request context
2. Extract JWT claims → get applicationname, tier
3. Check local bucket
4. Bucket has tokens: ALLOW
5. Send event to TM (async, non-blocking)
6. Return decision: ALLOW
7. Request proceeds to backend
```

**Expected flow for throttled request:**
```
1. Receive request context
2. Extract JWT claims → get applicationname, tier
3. Check local bucket
4. Bucket empty: DENY
5. Send throttle event to TM (sync or async, logged)
6. Return decision: DENY (429)
7. Request rejected, no backend call
```

---

## Guide to Exploration

### Finding the Source Tree

The distribution contains source as:
- Extracted JARs in `repository/components/plugins/`
- Or downloadable source archive from WSO2 website

Start here:
```bash
cd /Users/hunghan/Downloads/wso2am-universal-gw-4.7.0
find . -name "*ThrottleHandler*" -type f
find . -name "*GlobalThrottle*" -type f
find . -name "*throttle*" -type f | grep -i java
```

### Reading Java Code

Look for:
- **Class definitions**: `public class ThrottleHandler { ... }`
- **Method signatures**: `public MessageContext invoke(MessageContext ...) { ... }`
- **HTTP calls**: `HttpURLConnection`, `HttpClient`, `client.post()`, `RestTemplate`
- **JSON parsing**: `JSONObject`, `JsonParser`, `ObjectMapper`
- **Logging**: `logger.info()`, `logger.debug()` to understand flow

### Key Concepts to Identify

- **Local Token Bucket**: How is it implemented? (e.g., `TokenBucket` class, `AtomicInteger` counter)
- **TM Communication**: Synchronous or asynchronous?
- **Event Structure**: JSON field names and types
- **Error Handling**: What happens if TM is unreachable?

---

## Expected Findings Summary

You should understand:

1. **ThrottleHandler**: Coordinates between local bucket and TM
   - Fast path: check local bucket
   - Slow path: contact TM for global decision

2. **Token Bucket Algorithm**: Tracks tokens (capacity, refill rate)
   - On each request: consume 1 token
   - Periodically: refill tokens based on elapsed time and rate

3. **TM API**: Receives events, returns throttle decision
   - POST `/throttle/data`
   - JSON payload with app/tier/count/timestamp
   - Response: `throttled` boolean + global count

4. **Error Handling**: Fallback to local bucket if TM unavailable
   - Logged at ERROR or WARN level
   - Allows requests to proceed (best effort)
   - TM recovery triggers re-sync

---

## Documentation References

- WSO2 API Manager 4.7.0 Official Documentation:
  https://apim.docs.wso2.com/en/4.7.0/

- Throttle Policy Documentation:
  https://apim.docs.wso2.com/en/4.7.0/learn/rate-limiting/

- Gateway Architecture Diagram:
  Usually found in `repository/docs/` or the above link

---

## Exercises

### Exercise 1: Event Field Mapping

Write down the mapping from JWT claims to throttle event fields:

| JWT Claim | Throttle Event Field | Example |
|-----------|---------------------|---------|
| `applicationname` | `applicationId` | `"app1"` |
| `http://wso2.org/claims/subscriber` | `userId` | `"alice"` |
| ??? | `subscriptionId` | `"app1::api1"` |
| ??? | `tier` | `"gold"` |

**Hint:** Some fields come from the JWT, others from the subscription store or request context.

**Solution sketch:**
```
JWT Claim | Throttle Event Field
- applicationname → applicationId
- subscriber → userId

Subscription Store:
- subscriptionTier → tier
- applicationname + "::" + apiname → subscriptionId

Request Context:
- request timestamp → timestamp
- always 1 → count (in non-batched mode)
- tier-derived → allowedCount (5000 for gold, etc.)
```

---

### Exercise 2: TM Endpoint URL

Where does the gateway get the TM endpoint URL?

**Hint:** Is it hardcoded, read from config file, or an environment variable?

**Solution sketch:**
```
WSO2 Configuration Sources (priority order):
1. Environment variable: TM_URL or TRAFFIC_MANAGER_URL
2. Configuration file: repository/conf/gateway-config.xml or api-manager.xml
3. Default: http://localhost:9611 or http://traffic-manager:9611

In modern containerized setups (Docker, K8s):
- Use environment variable
- Set to TM service name or host
- Example: TM_URL=http://tm:9611
```

---

### Exercise 3: What Happens on TM Failure?

The code should handle TM unavailability gracefully. What is the fallback behavior?

**Hint:** Does it retry, timeout, log, or proceed?

**Solution sketch:**
```
Typical Fallback Strategy:

if (sendEventToTM fails):
    - Log WARN or ERROR
    - Catch exception (connection timeout, HTTP error, etc.)
    - Proceed with local bucket decision
    - Mark TM as "unhealthy" (optional circuit breaker)
    - Retry connection in next window

Trade-offs:
- Pro: High availability, requests don't fail due to TM issues
- Con: Risk of quota overages if TM stays down and traffic increases
- Mitigation: Alert on TM health, use conservative local rates

This is the "fail-open" philosophy: availability over strict accuracy.
```

---

## Submission

After exploring the source code, write a brief summary (100-200 words) answering:

1. What are the key components in the throttle flow?
2. How does the gateway communicate with the TM?
3. What is the fallback if TM is unavailable?

**Example summary:**
```
The throttle flow consists of three components:

1. ThrottleHandler (in GW): Checks local token bucket, extracts tier from JWT, 
   decides allow/deny for the request.

2. GlobalThrottleEngineClient (in GW): Sends HTTP POST with throttle event to TM at 
   /throttle/data endpoint. Payload includes appId, tier, userId, timestamp, count.

3. Traffic Manager: Receives events from all GW replicas, aggregates counts, 
   maintains global quota, returns throttle decision.

Fallback: If TM is unreachable, GW continues with local bucket (best effort), 
logs error, and retries later. This ensures availability but may allow quota overages.
```

---

## Teardown

No resources to clean up (reading lab only).

---

## Next Steps

- **Day 26:** Implement the token-bucket algorithm in Go and integrate throttle middleware.
- Compare your findings with the Go implementation to verify understanding.
