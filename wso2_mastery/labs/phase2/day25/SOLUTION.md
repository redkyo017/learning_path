# Lab: Day 25 — Source Reading: WSO2 Throttle Handler (Reference Answers)

## Task 1: ThrottleHandler.java — Main Method Signature & Parameters

### Reference Findings

**Location:** `wso2am-universal-gw-4.7.0/repository/components/plugins/com.wso2.carbon.apimgt.gateway/org/wso2/carbon/apimgt/gateway/handlers/security/throttle/ThrottleHandler.java`

**Class Structure:**
```java
public class ThrottleHandler extends AbstractHandler {
    private static final Log logger = LogFactory.getLog(ThrottleHandler.class);
    
    // Token bucket for local rate limiting
    private TokenBucket tokenBucket;
    
    // Traffic Manager client for global coordination
    private GlobalThrottleEngineClient tmClient;
    
    @Override
    public boolean invoke(MessageContext messageContext) {
        // Main throttle decision logic
        return handleRequest(messageContext);
    }
}
```

### Key Method Signature

```java
public boolean invoke(MessageContext messageContext)
```

- **Parameter**: `MessageContext messageContext` — Contains request/response context, JWT claims, headers
- **Returns**: `boolean` — `true` to allow request, `false` to deny (HTTP 429)

### Parameters Accepted (Extracted from MessageContext)

From the `MessageContext`, the handler extracts:

1. **JWT Claims** (via `messageContext.getProperty("token_claims")`):
   - `applicationname` → Application ID
   - `http://wso2.org/claims/subscriber` → User ID
   - `tier` or derived from subscription store

2. **Request Metadata**:
   - API resource (from message context)
   - Subscription tier (from claims or subscription store)
   - Request timestamp

3. **Rate Limit Quota** (from tier configuration):
   - Gold: 5000 req/min
   - Silver: 2000 req/min
   - Bronze: 1000 req/min
   - Unlimited: no limit

### What It Returns

- **`true`**: Request is NOT throttled → allowed to proceed to backend
- **`false`**: Request IS throttled → denied with HTTP 429 Too Many Requests

---

## Task 2: GlobalThrottleEngineClient.java — TM Communication

### Reference Findings

**Location:** Similar package structure, typically adjacent to `ThrottleHandler.java`

### HTTP Endpoint Called

```
POST http://traffic-manager:9611/throttle/data
Content-Type: application/json
```

**Configuration Sources (priority order):**
1. Environment variable: `TM_URL` or `TRAFFIC_MANAGER_URL`
2. Configuration file: `repository/conf/api-manager.xml` or `throttle.properties`
3. Default: `http://localhost:9611`

In containerized (Docker/K8s) deployments:
- Set via environment: `TM_URL=http://tm:9611`
- Service name resolution: `http://traffic-manager:9611`

### Request Payload Structure

```json
POST http://tm:9611/throttle/data
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
```

**Field Meanings:**
- `applicationId`: Application name (from JWT claim `applicationname`)
- `tier`: Subscription tier (gold, silver, bronze, unlimited)
- `subscriptionId`: Unique subscription identifier (format: `appname::apiname`)
- `userId`: Subscriber identifier (from JWT claim `http://wso2.org/claims/subscriber`)
- `timestamp`: ISO 8601 or milliseconds since epoch
- `count`: Number of requests in this report (typically 1 in non-batched mode)
- `allowedCount`: Quota limit for this tier (5000 for gold, etc.)

### Response Structure

```json
HTTP 200 OK
Content-Type: application/json

{
  "throttled": false,
  "globalCount": 4804,
  "allowedCount": 5000,
  "resetTimestamp": 2026-09-03T10:31:00Z
}
```

**Field Meanings:**
- `throttled`: `false` = allow request, `true` = deny
- `globalCount`: Current global request count for this tier (across all GW replicas)
- `allowedCount`: Quota limit (echoed from request)
- `resetTimestamp`: When the quota window resets

### Methods in GlobalThrottleEngineClient

- `publishThrottleEvent(ThrottleEvent event)`: Sends throttle event to TM
- `handleResponse(HttpResponse response)`: Parses response and makes allow/deny decision
- `isThrottled()`: Returns boolean decision from TM response

---

## Task 3: Trace the Throttle Event Structure

### Throttle Event Class

**Class Name:** `ThrottleEvent` (or similar, e.g., `ThrottleMessage`, `EventData`)

**Fields:**

```java
public class ThrottleEvent {
    private String applicationId;        // App name from JWT
    private String subscriptionId;       // Unique subscription ID (app::api)
    private String tier;                 // gold, silver, bronze, unlimited
    private String userId;               // Subscriber name
    private long timestamp;              // Milliseconds since epoch or ISO 8601
    private int count;                   // Number of requests in batch
    private int allowedCount;            // Quota for this tier
    private String apiName;              // API being called
    private String apiVersion;           // API version
}
```

### How Tier Is Extracted

**Source Priority:**

1. **JWT Claims** (primary):
   ```java
   String tier = (String) jwtClaims.get("tier");
   ```

2. **Subscription Store** (if not in JWT):
   ```java
   SubscriptionDTO sub = subscriptionStore.getSubscription(appId, apiName);
   String tier = sub.getTier(); // e.g., "gold"
   ```

3. **Hardcoded Default** (fallback):
   ```java
   if (tier == null) {
       tier = "silver"; // Default tier
   }
   ```

### Tier-to-Quota Mapping

```java
private static final Map<String, Integer> TIER_QUOTAS = 
    Map.of(
        "gold",      5000,      // 5000 req/min
        "silver",    2000,      // 2000 req/min
        "bronze",    1000,      // 1000 req/min
        "unlimited", Integer.MAX_VALUE
    );

int allowedCount = TIER_QUOTAS.getOrDefault(tier, 1000);
```

### Event Serialization to JSON

```java
public String toJson() {
    JSONObject json = new JSONObject();
    json.put("applicationId", this.applicationId);
    json.put("subscriptionId", this.subscriptionId);
    json.put("tier", this.tier);
    json.put("userId", this.userId);
    json.put("timestamp", this.timestamp);
    json.put("count", this.count);
    json.put("allowedCount", this.allowedCount);
    return json.toString();
}
```

Or using Jackson:
```java
ObjectMapper mapper = new ObjectMapper();
String json = mapper.writeValueAsString(throttleEvent);
```

---

## Task 4: Request Flow — Allowed vs. Throttled

### Flow for ALLOWED Request (Not Throttled)

```
1. Request arrives at ThrottleHandler.invoke(messageContext)
   ↓
2. Extract JWT claims
   - applicationname: "myapp"
   - subscriber: "alice"
   - tier: "gold"
   ↓
3. Check local token bucket for tier "gold"
   - Bucket state: 4500/5000 tokens available
   ↓
4. Local bucket has tokens → ALLOW
   - Consume 1 token: 4500 → 4499
   ↓
5. Send throttle event to TM (async, non-blocking)
   POST http://tm:9611/throttle/data
   {
     "applicationId": "myapp",
     "tier": "gold",
     "userId": "alice",
     "count": 1,
     ...
   }
   ↓
6. Return decision: true (ALLOW)
   ↓
7. Request proceeds to backend API
   ↓
8. TM responds: { "throttled": false, "globalCount": 4804 }
   - Update local bucket if needed (refill rate adjustment)
```

**Key Characteristics:**
- **Fast path**: No blocking wait for TM response
- **Asynchronous communication**: TM event sent in background thread
- **Local decision**: Based on local token bucket + JWT tier
- **Best effort**: If TM is unreachable, still allows request

### Flow for THROTTLED Request (Denied)

```
1. Request arrives at ThrottleHandler.invoke(messageContext)
   ↓
2. Extract JWT claims
   - applicationname: "myapp"
   - subscriber: "alice"
   - tier: "gold"
   ↓
3. Check local token bucket for tier "gold"
   - Bucket state: 0/5000 tokens available
   - Refill window not elapsed
   ↓
4. Local bucket empty → DENY
   - No tokens available for this window
   ↓
5. Send throttle event to TM (sync or logged)
   POST http://tm:9611/throttle/data
   {
     "applicationId": "myapp",
     "tier": "gold",
     "userId": "alice",
     "count": 1,
     ...
   }
   Log: "Request throttled for user alice, tier gold"
   ↓
6. Return decision: false (DENY)
   ↓
7. Request rejected with HTTP 429 Too Many Requests
   Response body:
   {
     "error": "Throttled",
     "message": "Rate limit exceeded",
     "retryAfter": 60
   }
   ↓
8. Request does NOT reach backend
```

**Key Characteristics:**
- **Local decision**: Based on empty token bucket
- **Synchronous rejection**: No backend call
- **Event logging**: Throttle event recorded for audit
- **HTTP 429 response**: Client knows to retry later

---

## Exercise 1: Event Field Mapping — Reference Answer

### JWT Claims to Throttle Event Mapping

| Source | JWT Claim / Context | Throttle Event Field | Example |
|--------|---------------------|----------------------|---------|
| JWT | `applicationname` | `applicationId` | `"myapp"` |
| JWT | `http://wso2.org/claims/subscriber` | `userId` | `"alice"` |
| Subscription Store | `subscriptionTier` | `tier` | `"gold"` |
| Derived | `appname::apiname` | `subscriptionId` | `"myapp::api1"` |
| MessageContext | Request timestamp | `timestamp` | `1693650600000` |
| Always 1 | Hardcoded | `count` | `1` |
| Tier config | `TIER_QUOTAS[tier]` | `allowedCount` | `5000` |

**Note:** Some fields come from JWT, others from the subscription store or derived from request context.

---

## Exercise 2: TM Endpoint URL — Reference Answer

### Where Does the Gateway Get the TM Endpoint URL?

**Configuration Sources (Priority Order):**

1. **Environment Variable** (highest priority):
   ```bash
   export TM_URL=http://traffic-manager:9611
   # or
   export TRAFFIC_MANAGER_URL=http://tm.example.com:9611
   ```

2. **Configuration File** (`repository/conf/throttle.properties` or `api-manager.xml`):
   ```xml
   <!-- api-manager.xml -->
   <ThrottleManager>
       <Url>http://traffic-manager:9611</Url>
   </ThrottleManager>
   ```

3. **Hardcoded Default** (lowest priority):
   ```java
   String tmUrl = System.getProperty("TM_URL", "http://localhost:9611");
   ```

### Containerized Deployment (Docker/K8s)

In modern containerized environments:
- GW and TM run as separate services
- Use service name for discovery
- Example Compose override or K8s ConfigMap:
  ```yaml
  env:
    - name: TM_URL
      value: "http://tm:9611"
  ```

---

## Exercise 3: What Happens on TM Failure — Reference Answer

### Fallback Behavior When TM Is Unreachable

**Typical Implementation:**

```java
public ThrottleDecision sendEventToTM(ThrottleEvent event) {
    try {
        HttpResponse response = httpClient.post(TM_URL + "/throttle/data", event.toJson());
        return parseResponse(response);
    } catch (ConnectException | TimeoutException e) {
        logger.warn("TM unavailable: " + e.getMessage());
        // Fallback: use local bucket decision (best effort)
        return decideLocally(event);
    } catch (Exception e) {
        logger.error("TM communication error", e);
        // Mark TM as unhealthy (optional circuit breaker)
        markTMUnhealthy();
        // Still allow request based on local quota
        return decideLocally(event);
    }
}

private ThrottleDecision decideLocally(ThrottleEvent event) {
    // Use local token bucket state
    // Conservative: if we don't have TM data, we trust the local bucket
    return localBucket.hasCapacity() ? ALLOW : DENY;
}
```

### Trade-offs

**Pros (Fail-Open Philosophy):**
- **High Availability**: Requests don't fail due to TM outages
- **Graceful Degradation**: System continues to operate
- **Resilience**: Short TM outages don't cascade to API consumers

**Cons:**
- **Risk of Quota Overages**: If TM stays down and traffic increases, actual usage may exceed quota
- **Accuracy Loss**: Global quotas not enforced, only local
- **Requires Monitoring**: Need alerts on TM health to catch issues early

### Mitigation Strategies

1. **Conservative Local Quotas**:
   - Set local bucket rate slightly below tier limit
   - Buffer for TM outage period

2. **Circuit Breaker**:
   - Track TM failures
   - If failure rate > threshold, temporarily disable TM communication
   - Resume after recovery window

3. **Health Checks**:
   - Periodic `/health` ping to TM
   - Update health status in logs
   - Alert on degradation

4. **Retry Logic**:
   - Exponential backoff: retry TM connection in next 10s, 30s, 60s windows
   - Resume full communication when TM recovers

---

## Summary — Key Takeaways

### The Throttle Flow Has Three Components

1. **ThrottleHandler** (in Gateway):
   - Checks local token bucket
   - Extracts tier from JWT
   - Makes allow/deny decision
   - Fast, local decision

2. **GlobalThrottleEngineClient** (in Gateway):
   - Sends HTTP POST to TM at `/throttle/data`
   - Payload: appId, tier, userId, timestamp, count, allowedCount
   - Response: throttled decision + global count
   - Async communication (non-blocking)

3. **Traffic Manager** (separate service):
   - Receives throttle events from all Gateway replicas
   - Aggregates counts across all instances
   - Maintains global quota per tier
   - Returns throttle decision to each gateway

### Fallback Strategy

If TM is unreachable:
- Gateway continues with local bucket (best effort)
- Logs warning/error
- Allows requests to proceed (availability over accuracy)
- Retries TM connection in next window
- Risk: quota overages if TM stays down

This is the **fail-open philosophy**: prefer availability and graceful degradation over strict accuracy.

---

## Key Concepts Identified

- **Local Token Bucket**: Tracks tokens (capacity, refill rate) per tier
  - On each request: consume 1 token
  - Periodically: refill tokens based on elapsed time and rate

- **TM Communication**: Synchronous for decisions (when needed), asynchronous for event logging

- **Event Structure**: JSON with app/tier/count/timestamp/quota

- **Error Handling**: Fallback to local bucket if TM unavailable
