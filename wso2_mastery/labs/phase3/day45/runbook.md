# WSO2 Control Plane + Event Sync — Phase 3 Runbook

## Topology Overview

### Docker Compose (Local)

```
                         ┌─────────────────────────────┐
                         │       Client (Bash/Curl)    │
                         └──────────────┬──────────────┘
                                        │
                ┌───────────────────────┼───────────────────────┐
                │                       │                       │
                ▼                       ▼                       ▼
            IS :8080              CP :8082              GW :9090
         (OAuth2/JWKS)      (API Registry)        (Request Router)
                │                   │                       │
                │ ◄─────────────────┤ (Config)             │
                │                   │                       │
                │ (JWKS)   ┌────────┴────────┐             │
                │ ◄────────┤                 ├─────────────┤
                │          │                 │ (Events)    │
                │     Events SSE /events     │ (Admin Sync)│
                └──────────────────────────────────────────┘

Backend :8000 (returns "hello from backend")
```

### Sequence Diagram: Single API Request

```
1. Create API in CP
   Client → POST /apis → CP stores (state: CREATED)

2. Publish API in CP
   Client → POST /apis/{id}/lifecycle → CP changes state to PUBLISHED
   CP → SSE broadcast API_PUBLISHED to all subscribers

3. GW receives API_PUBLISHED event
   GW ← SSE stream ← CP
   GW updates route cache: /smoke/v1 → backend

4. Create Application in CP
   Client → POST /applications → CP stores app with consumerKey

5. Subscribe Application to API
   Client → POST /subscriptions → CP stores subscription
   CP → SSE broadcast SUBSCRIPTION_CREATED

6. GW receives SUBSCRIPTION_CREATED event
   GW ← SSE stream ← CP
   GW updates subscription cache

7. Client requests JWT from IS
   Client → POST /oauth2/token with consumerKey
   IS → return JWT with claims (iss, sub, applicationname, exp, etc.)

8. Client calls GW with JWT
   Client → GET /smoke/v1/hello with Authorization: Bearer {JWT}
   GW:
     a. Validate JWT signature (fetch JWKS from IS :8080)
     b. Check subscription cache (does app have access to /smoke/v1?)
     c. Route to backend
   Backend → return "hello from backend"
   GW → return 200 with body
```

---

## CP API Quick Reference

All CP endpoints accept JSON. Authentication is not enforced in Phase 3 (flag for Phase 4).

| Endpoint | Method | Request Body | Response | Purpose |
|---|---|---|---|---|
| `/apis` | POST | `{"name":"API","context":"/path","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}` | `{"id":"api-001",...}` | Create API in CREATED state |
| `/apis/{id}/lifecycle` | POST | `{"action":"Publish"}` or `{"action":"Deprecate"}` | `{"id":"api-001","state":"PUBLISHED"}` | Transition API lifecycle; emits SSE event |
| `/apis/{id}/policies` | GET | — | `{"tiers":["Gold","Platinum"]}` | List allowed tiers for this API |
| `/apis/{id}/tiers` | PUT | `{"tiers":["Gold","Platinum"]}` | `{"id":"api-001"}` | Update tiers (only in CREATED/DEPRECATED states) |
| `/applications` | POST | `{"name":"App","owner":"developer"}` | `{"id":"app-001","consumerKey":"key-123"}` | Create consumer application |
| `/applications/{id}` | GET | — | `{"id":"app-001","name":"App",...}` | Retrieve app details |
| `/subscriptions` | POST | `{"appId":"app-001","apiId":"api-001","tier":"Gold"}` | `{"id":"sub-001",...}` | Subscribe app to API; emits SSE event |
| `/subscriptions/validate` | GET | `?consumerKey=key-123&apiContext=/smoke/v1&method=GET&path=/hello` | `{"valid":true,"tier":"Gold","status":"ACTIVE"}` | GW uses this to validate subscriptions on cache miss |
| `/admin/apis` | POST | `{"apiId":"api-001","apiContext":"/smoke/v1"}` | `{"registered":true}` | Register API context for /subscriptions/validate fallback |
| `/admin/sync` | GET | — | `{"apis":[...], "subscriptions":[...]}` | Full state dump; GW calls on startup |
| `/events` | GET (SSE) | — | `event: API_PUBLISHED`, `event: SUBSCRIPTION_CREATED`, etc. | Server-sent events stream |
| `/health` | GET | — | `{"status":"OK"}` | Health check |

---

## Event Types

CP emits events on the SSE stream (`/events`) when state changes. Clients (GW, monitoring tools) subscribe and react.

| Event Type | Fired When | Key Payload Fields | Example |
|---|---|---|---|
| `API_PUBLISHED` | API lifecycle transitions to PUBLISHED state | `id, name, context, version, tiers, backendUrl` | `{"id":"api-001","context":"/smoke/v1","version":"1.0","tiers":["Gold"],"backendUrl":"http://backend:8000"}` |
| `API_DEPRECATED` | API lifecycle transitions to DEPRECATED state | `id, context, version` | `{"id":"api-001","context":"/smoke/v1","version":"1.0"}` |
| `SUBSCRIPTION_CREATED` | New subscription created and status is not BLOCKED | `appId, apiId, tier, consumerKey, applicationname` | `{"appId":"app-001","apiId":"api-001","tier":"Gold","applicationname":"SmokeApp"}` |
| `SUBSCRIPTION_REMOVED` | Subscription blocked or deleted | `appId, apiId, reason` | `{"appId":"app-001","apiId":"api-001","reason":"rate_limit_exceeded"}` |

**Event Stream Format (SSE):**
```
:
event: API_PUBLISHED
data: {"id":"api-001","context":"/smoke/v1",...}

:
event: SUBSCRIPTION_CREATED
data: {"appId":"app-001","apiId":"api-001",...}
```

---

## Event Sync Failure Checklist

Use this checklist to diagnose event-related failures.

- [ ] **GW returns 403 for a published API**
  - Symptom: API was successfully published but GW still 404s.
  - Check: Watch the SSE stream before and after publishing.
    ```bash
    curl -N http://localhost:8082/events | grep API_PUBLISHED
    ```
  - If event appears: GW received it but didn't apply it to routing cache. Check GW code.
  - If event doesn't appear: CP EventBus not connected to lifecycle handler. Check CP code.

- [ ] **GW returns 403 for a valid subscription**
  - Symptom: Subscription created and API published, but GW returns 403.
  - Check: Watch SSE stream for `SUBSCRIPTION_CREATED` event.
    ```bash
    curl -N http://localhost:8082/events | grep SUBSCRIPTION_CREATED
    ```
  - If event appears: GW received but didn't update cache. Check GW event handler.
  - If event doesn't appear: CP didn't emit (status is BLOCKED). Check CP logs.
  - If 403 persists: GW cache miss; call `/subscriptions/validate` on CP.

- [ ] **Events not flowing**
  - Symptom: No events appear on SSE stream; curl -N hangs indefinitely.
  - Check: Is the SSE endpoint returning `Content-Type: text/event-stream`?
    ```bash
    curl -v http://localhost:8082/events 2>&1 | grep Content-Type
    # Expected: Content-Type: text/event-stream
    ```
  - Check: Network connectivity between GW and CP (if across containers or VPCs).
    ```bash
    docker compose exec gw curl http://cp:8082/events --max-time 5
    ```
  - Check: Is CP EventBus publishing events? Check CP logs: `grep -i "emit\|event" docker_compose_logs`

- [ ] **GW just restarted**
  - Symptom: GW comes back up with stale data (old APIs, missing subscriptions).
  - Check: GW calls `/admin/sync` on startup. Verify this in GW logs.
    ```bash
    docker compose logs gw | grep -i "admin\|sync"
    # Expected: [INFO] Calling /admin/sync on http://cp:8082
    #           [INFO] Loaded 5 APIs, 10 subscriptions
    ```
  - Check: CP's `/admin/sync` returns current state. Manually test:
    ```bash
    curl http://localhost:8082/admin/sync | jq '.apis | length'
    ```
  - If sync succeeds: GW should have fresh data. Wait a few seconds for subscriptions to appear.

- [ ] **CP restarts and GW has stale data**
  - Symptom: After restarting CP, GW still routes to deleted APIs.
  - Root cause: CP lost in-memory state on restart; GW's local cache wasn't invalidated.
  - Fix: Restart GW to force re-sync: `docker compose restart gw`.
  - Phase 4 improvement: Make CP persistent (database-backed).

---

## Production ECS Fargate Checklist

When deploying to AWS ECS Fargate, use this checklist to ensure production readiness.

### Networking & Subnets
- [ ] All WSO2 tasks (IS, CP, GW, TM) in **private subnets** (no public IPs)
- [ ] ALB in **public subnets** with public IP / Elastic IP
- [ ] ALB routes public traffic to GW only (ports 8243, 8280)
- [ ] GW has route to CP and IS (via PrivateLink, peering, or same VPC)

### Security Groups
- [ ] **ALB SG:** Inbound HTTP/HTTPS from 0.0.0.0/0; outbound to GW SG on 8243/8280
- [ ] **GW SG:** Inbound from ALB SG on 8243/8280; outbound to CP SG (9443), IS SG (9443), backend SG, internet (443 for DNS)
- [ ] **CP SG:** Inbound from GW SG (9443), TM SG (9443); outbound to IS SG (9443), internet (443)
- [ ] **IS SG:** Inbound from GW SG (9443), CP SG (9443); outbound to internet (443)
- [ ] **TM SG:** Inbound from ALB SG (optional, if TM is public-facing); outbound to CP SG (9443), internet

### IAM Roles
- [ ] **Execution Role:** Permissions to pull ECR images, write CloudWatch logs, read Secrets Manager (only specific secrets)
- [ ] **Task Role:** Permissions for IS/CP/GW to call AWS APIs (e.g., Secrets Manager for keystores)
- [ ] Roles follow **least privilege:** no wildcard actions or resources

### Health Checks
- [ ] **GW health check path:** `/services/Version` (or equivalent)
  - Method: GET, Port: 8243 (TLS), Timeout: 5s, Interval: 10s, Healthy Threshold: 2, Unhealthy Threshold: 3
- [ ] **IS health check path:** `/oauth2/token` (or `/health`)
  - Method: HEAD, Port: 9443 (TLS)
- [ ] **CP health check path:** `/services/Version`
  - Method: GET, Port: 9443 (TLS)
- [ ] **TM health check path:** `/healthcheck`
  - Method: GET, Port: 9711 (TLS)
- [ ] All tasks have `start_period = 60` (allow 60s for dependency startup and health check warmup)

### Logging
- [ ] CloudWatch Log Groups created:
  - `/ecs/prod/wso2-gw`
  - `/ecs/prod/wso2-cp`
  - `/ecs/prod/wso2-is`
  - `/ecs/prod/wso2-tm`
- [ ] Log retention: 30–90 days (policy-dependent)
- [ ] Task definitions configured to log to these groups

### Monitoring & Alerting
- [ ] GW autoscaling policy: Target 60% CPU, min 1, max 4 replicas
  - Scale-out cooldown: 60s, Scale-in cooldown: 300s
- [ ] CloudWatch alarms for:
  - GW task unhealthy (alert if > 0 unhealthy tasks)
  - CP/IS task unhealthy (alert immediately; these are fixed 1 replica)
  - ALB target group unhealthy (alert if > 0)
  - High error rate (4xx, 5xx responses)

### Secrets & Configuration
- [ ] All secrets (API keys, keystores, passwords) in **AWS Secrets Manager**, not in environment variables
- [ ] Task role has permission to read only the secrets it needs
- [ ] Environment variables in task definition for non-secret config:
  - `JWKS_URL=https://is.wso2-internal:9443/oauth2/jwks`
  - `CP_URL=https://cp.wso2-internal:9443`
  - (No actual hostnames; use Cloud Map DNS names or internal ALB DNS)

### TLS/HTTPS
- [ ] All inter-service communication (GW ↔ CP, GW ↔ IS) over HTTPS/TLS
- [ ] ALB listener on 443 (HTTPS) with AWS Certificate Manager certificate
- [ ] Task definitions expose HTTPS ports (8243 for GW, 9443 for CP/IS)
- [ ] Self-signed certs okay for internal services; CA-signed for ALB (public-facing)

---

## Known Limitations of Phase 3 Go CP (Carry Forward to Phase 4)

### 1. In-Memory State Loss on Restart
**Limitation:** All APIs and subscriptions stored in RAM. On CP restart, data is lost.

**Impact:** Production downtime if CP crashes; need to re-upload all APIs and resubscribe.

**Workaround:** Don't restart CP. Run it as immutable (container never stops).

**Phase 4 Fix:** Implement persistence:
- PostgreSQL or DynamoDB for API/subscription store.
- CP reads from store on startup.
- State recovered within seconds.

### 2. No Authentication on CP Endpoints
**Limitation:** Anyone can POST to `/apis`, `/applications`, `/subscriptions`.

**Impact:** Unauthorized users can create APIs, publish malicious content, or delete subscriptions.

**Workaround:** Place CP behind an ALB with API authentication (AWS API Gateway, OAuth2, TLS mutual auth).

**Phase 4 Fix:** Add middleware:
- JWT validation on all CP endpoints.
- Role-based access control (admin can create APIs; developers can only create apps).

### 3. SSE Connection Without Automatic Reconnection
**Limitation:** If the GW-to-CP SSE connection drops, GW loses the event stream and doesn't automatically reconnect.

**Impact:** If the network hiccups for a few seconds, GW misses events and has stale cache.

**Workaround:** Restart GW to force re-sync.

**Phase 4 Fix:** Implement in GW:
- Automatic reconnection with exponential backoff.
- On reconnect, call `/admin/sync` to catch up on missed events.
- Emit metrics for connection health.

### 4. No Request Rate Limiting on CP
**Limitation:** CP accepts unlimited requests.

**Impact:** A misbehaving GW (polling CP in a tight loop) can overwhelm CP.

**Workaround:** Monitor CP CPU/memory. Manually investigate if high.

**Phase 4 Fix:** Add rate limiting middleware to CP:
- Per-IP rate limits (e.g., 1000 req/sec per GW).
- Global rate limit (e.g., 5000 req/sec total).
- Graceful degradation (429 Too Many Requests).

### 5. Event Ordering Not Guaranteed
**Limitation:** SSE events are emitted as they occur but not explicitly ordered or numbered.

**Impact:** GW may process `SUBSCRIPTION_CREATED` before `API_PUBLISHED` (out-of-order).

**Workaround:** GW should handle out-of-order events gracefully. Validate subscription and API exist before using.

**Phase 4 Fix:** Add event sequencing:
- Each event has a `sequence_number`.
- GW tracks `last_sequence_seen` and re-requests any gaps.

---

## Debugging in Production

### How to Access Logs

```bash
# From local machine
aws logs tail /ecs/prod/wso2-gw --follow

# Or grep for a specific request
aws logs filter-log-events \
  --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "SmokeAPI" \
  --query 'events[*].[logStreamName,message]' \
  --output text
```

### How to Find a Request Across All Services

Each request should have a **correlation ID** (not implemented in Phase 3; Phase 4 feature). Until then:

1. Get the timestamp of the failure from the ALB/GW logs.
2. Look for that timestamp in CP logs.
3. Look for that timestamp in IS logs.

Example:
```bash
# Terminal 1: Follow GW logs
aws logs tail /ecs/prod/wso2-gw --follow --since 1m

# Terminal 2: Make a request
curl https://api.prod.example.com/smoke/v1/hello \
  -H "Authorization: Bearer $TOKEN" \
  -v

# Terminal 1: Look for your request (grep by authorization header or response code)
aws logs filter-log-events --log-group-name /ecs/prod/wso2-gw \
  --filter-pattern "Smoke" --query 'events[*].message'
```

---

## Summary

**Phase 3 gives you:**
- Event-driven architecture with SSE for low-latency sync.
- Local caching in GW for sub-millisecond validation.
- Health checks with startup ordering to prevent race conditions.

**Phase 4 will add:**
- Distributed tracing for end-to-end request flow visibility.
- Persistence for CP (no data loss on restart).
- Automatic reconnection logic for SSE streams.
- Rate limiting and authentication on internal APIs.

