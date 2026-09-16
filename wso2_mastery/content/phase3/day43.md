# Day 43: Docker Compose — Local Integration and Startup Order

## Why This Matters

You've built four independent services across three phases: an Identity Server (IS), a Control Plane (CP), a Universal Gateway (GW), and a Traffic Manager (TM). Today marks the moment they **work together as a system**. This is where theory becomes engineering.

Most production bugs in API management platforms are **integration bugs**: one service misconfigured to point at the wrong port, a race condition where the GW starts before the CP is ready, or a networking issue where containers can't resolve each other's hostnames. Docker Compose lets you simulate these problems locally before they hit production.

---

## Docker Compose as a Local ECS Analogue

### How Services Find Each Other: Service Names as DNS

In Docker Compose, each service gets its own IP address on a custom bridge network. Service names resolve to those IPs automatically via DNS.

```yaml
services:
  is:
    image: wso2-is-go:local
    ports:
      - "8080:8080"
  
  gw:
    image: wso2-gw-go:local
    ports:
      - "9090:9090"
    environment:
      JWKS_URL: "http://is:8080/oauth2/jwks"  # "is" resolves to the IS container
      CP_URL: "http://cp:8082"                 # "cp" resolves to the CP container
```

This mirrors **ECS Service Discovery**:
- In Fargate, services register with AWS Cloud Map.
- Cloud Map DNS names look like `cp.wso2.internal`, `gw.wso2.internal`.
- In Compose, service names (`cp`, `gw`, `is`) become hostnames on the bridge network.

**No `localhost` shortcuts:** Inside the `gw` container, `localhost:8082` refers to the GW itself, not the CP. You must use the service name: `http://cp:8082`.

---

## Service Startup Order: Who Depends on Whom?

### The Dependency Chain

WSO2 services have hard dependencies:

```
IS (no dependencies) ← Identity Server; others depend on it
  ↓
  ├→ CP (depends on IS) ← Control Plane; GW depends on CP
  │    ↓
  │    └→ GW (depends on CP and IS) ← Universal Gateway
  │
  └→ TM (depends on IS) ← Traffic Manager; can start in parallel with CP
```

### Why This Order?

1. **IS starts first:** GW and CP both need IS for JWT validation and token generation. If IS isn't ready, GW requests will fail on the `/oauth2/jwks` endpoint.
2. **CP starts after IS:** The CP connects to IS to fetch key manager configuration. Also, IS must be running to validate CP's own operational keys.
3. **GW starts after CP:** When GW starts, it makes an initial sync call to CP's `/admin/sync` endpoint to load all published APIs. It also subscribes to CP's `/events` SSE stream for real-time updates.
4. **TM can run in parallel with CP:** TM doesn't wait for CP (though in production, both may need shared state).

---

## Health Checks and `depends_on: condition`

### Health Check: How Do You Know a Service Is Ready?

A service being **up** (container running) is not the same as being **ready** (accepting requests).

```yaml
services:
  is:
    image: wso2-is-go:local
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s
```

- **test:** Command to run inside the container. Exit code 0 = healthy.
- **interval:** Check every 10 seconds.
- **timeout:** If the check takes > 5 seconds, mark it as failed.
- **retries:** Allow up to 5 consecutive failures before marking the service unhealthy.
- **start_period:** Don't start health checks for the first 5 seconds (gives the app time to boot).

### `depends_on` with Conditions

```yaml
gw:
  image: wso2-gw-go:local
  depends_on:
    cp:
      condition: service_healthy
    is:
      condition: service_healthy
```

This means: **Don't start the GW until both CP and IS have passed health checks.** Without the condition, `depends_on` only guarantees that the CP and IS containers are created, not that they're ready.

---

## Anti-Patterns and Common Mistakes

### Anti-Pattern 1: Starting GW Before CP Is Healthy

If the GW starts before the CP's health check passes:
- GW calls `/admin/sync` → CP not ready → connection refused.
- GW may enter a crash loop, exit, or start with an empty subscription cache.
- First requests hit the GW, find no APIs in cache, and get 404s.
- Eventually CP comes up, GW retries `/admin/sync`, APIs are loaded. But users saw errors.

**Fix:** Use `depends_on: { cp: { condition: service_healthy } }`.

### Anti-Pattern 2: Exposing the CP to the Internet

```yaml
# BAD
cp:
  ports:
    - "8082:8082"  # Exposed to the world
```

The CP is an **internal service**. It should never be exposed publicly. Developers upload APIs to the CP; unauthorized access allows attackers to publish malicious APIs.

**Fix:** Only expose the GW.

```yaml
# GOOD
cp:
  # No ports section; not exposed
  
gw:
  ports:
    - "9090:9090"  # Only GW is public
```

### Anti-Pattern 3: Using `restart: always` Without Health Checks

```yaml
# BAD
gw:
  restart: always  # Always restart on exit
```

If the GW crashes due to a bad configuration, it will restart infinitely without diagnostics. Docker won't tell you why it's crashing.

**Fix:** Use health checks. If a container is unhealthy, look at the logs to understand why:

```bash
docker compose logs gw --tail 50
docker compose ps  # Shows health status
```

---

## How ECS Handles Startup Order (Production Context)

Docker Compose has `depends_on: { condition: service_healthy }`. ECS Fargate doesn't. How does production handle this?

**Answer: Retry loops inside each service.**

Each WSO2 component has startup retry logic:
- **GW on startup:** Tries to call `/admin/sync` up to N times with exponential backoff. If CP is slow, GW waits.
- **CP on startup:** Tries to connect to IS, retrying if the connection fails.

In ECS, you also configure **task definition health checks** with a `startPeriod`:

```hcl
health_check {
  command     = ["CMD-SHELL", "curl -sf http://localhost:9090/health || exit 1"]
  interval    = 10
  timeout     = 5
  retries     = 5
  start_period = 60  # Allow 60s for the task to boot and retry dependencies
}
```

The ECS Service marks the task as healthy only after the `start_period` and successful health checks. ALB only routes traffic to healthy tasks.

---

## Today's Lab: Docker Compose Integration

Your task: Build and run four Docker containers (IS, CP, GW, backend) using Docker Compose. See them start in the correct order, pass health checks, and validate that they can communicate.

**Key files to modify first:**
1. Add `Dockerfile` to `labs/phase1/day15/` (IS)
2. Add `Dockerfile` to `labs/phase2/day27/` (GW)
3. Add `Dockerfile` to `labs/phase3/day39/` (CP)
4. Add `Dockerfile` to `labs/phase3/day43/` (integrate all four)

---

## Exercises

### Exercise 1: What Happens If GW Starts Before CP?
**Question:** You remove the `depends_on` condition from GW so it starts immediately. What error do you expect to see in the GW logs?

**Hint:** Think about what the GW does on startup and what happens if the CP isn't listening.

**Solution sketch:**
- **GW startup sequence:** Calls `/admin/sync` to the CP to fetch all published APIs.
- **If CP isn't healthy yet:** Connection refused (ECONNREFUSED) or timeout (ETIMEDOUT).
- **GW log messages:**
  ```
  ERROR: Failed to sync CP state: connection refused (address http://cp:8082)
  ERROR: Retrying in 5s...
  ```
- **If GW's retry logic gives up:** GW exits or logs warnings and starts with an empty API cache.
- **Consequence:** All API requests return 404 until CP is up and GW reconnects.

---

### Exercise 2: Write the `depends_on` Block
**Question:** Write the YAML for the GW service that ensures it waits for both CP and IS to pass their health checks.

**Hint:** Use `condition: service_healthy` for each dependency.

**Solution sketch:**
```yaml
gw:
  image: wso2-gw-go:local
  depends_on:
    cp:
      condition: service_healthy
    is:
      condition: service_healthy
  # ... rest of config
```

---

### Exercise 3: How Does ECS Handle This in Production?
**Question:** In ECS Fargate, there's no `depends_on: { condition: service_healthy }`. How does WSO2 ensure the GW doesn't start processing traffic until CP and IS are ready?

**Hint:** Two mechanisms: application retry logic + task definition health checks.

**Solution sketch:**
1. **Application Retry Logic:** Each WSO2 component has built-in retry loops on startup. GW retries `/admin/sync` with exponential backoff until CP responds.
2. **Task Definition Health Check with `start_period`:** The Fargate health check has a `start_period` (e.g., 60 seconds) during which failed checks don't count as unhealthy. This gives the container time to boot and retry its dependencies.
3. **ECS Service Logic:** The ECS Service only marks a task as healthy after the start period expires and health checks pass. The ALB only routes traffic to healthy tasks. So even if the GW task starts, no traffic reaches it until its health checks pass.
4. **Sequence:**
   ```
   T=0:   GW task starts, retries CP/IS connections
   T=30:  GW fails health check, but start_period=60, so ignored
   T=45:  GW succeeds in connecting to CP/IS, loads state
   T=60:  start_period ends; health checks now matter
   T=70:  Health check passes; task marked RUNNING; ALB routes traffic
   ```

---

## Key Takeaways

1. **Service names as DNS:** Inside `gw`, `http://cp:8082` resolves to the CP container.
2. **Health checks validate readiness:** Not just running, but ready to accept requests.
3. **`depends_on: { condition: service_healthy }`:** Enforces startup order locally.
4. **ECS equivalent:** Retry logic + health check start period.
5. **Anti-patterns:** Exposing internal services, ignoring health checks, assuming `running` = `ready`.

---

## Next Steps

Day 44 will take Docker Compose one step further: a **smoke test** that validates end-to-end flow. Day 45 brings a production runbook.

