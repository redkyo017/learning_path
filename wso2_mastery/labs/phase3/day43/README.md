# Day 43 Lab: Docker Compose Integration

## Objective

Build and run all four WSO2 Go services (IS, CP, GW, backend) using Docker Compose. Observe them start in the correct order with health checks, and validate that they can communicate.

## Prerequisites

- Docker and Docker Compose installed locally.
- Go 1.22+ available (for local builds, if needed).
- `curl` installed (for manual testing).

## Files in This Lab

- `docker-compose.yml` — Defines all four services with dependencies and health checks.
- `README.md` — This file; setup and run instructions.
- `teardown.md` — How to stop and clean up.

## Step 1: Add Dockerfiles (Prerequisite)

Before running `docker compose up`, each Go service needs a `Dockerfile` in its lab directory. The Dockerfiles are not provided here; you must add them yourself.

**Add to `labs/phase1/day15/Dockerfile` (IS):**
```dockerfile
FROM golang:1.22-alpine
WORKDIR /app
COPY main.go .
RUN go mod init is && go mod tidy
CMD ["go", "run", "main.go"]
```

**Add to `labs/phase3/day39/Dockerfile` (CP):**
```dockerfile
FROM golang:1.22-alpine
WORKDIR /app
COPY main.go .
RUN go mod init cp && go mod tidy
CMD ["go", "run", "main.go"]
```

**Add to `labs/phase2/day27/Dockerfile` (GW):**
```dockerfile
FROM golang:1.22-alpine
WORKDIR /app
COPY main.go .
RUN go mod init gw && go mod tidy
CMD ["go", "run", "main.go"]
```

**Why Alpine?** Smaller image, faster startup, suitable for local development.

## Step 2: Build and Start Services

From `labs/phase3/day43/`, run:

```bash
docker compose up --build
```

This command:
1. Builds images for IS, CP, GW using the Dockerfiles from step 1.
2. Starts the backend container (pre-built).
3. Starts IS, waits for health check to pass.
4. Starts CP (depends on IS), waits for health check.
5. Starts GW (depends on CP and IS), waits for health checks.

**Expected output (last 10 lines):**
```
is           | [INFO] Starting IS on :8080
is           | [INFO] /health endpoint ready
cp           | [INFO] Starting CP on :8082
cp           | [INFO] /health endpoint ready
cp           | [INFO] Subscribed to IS event hub
gw           | [INFO] Starting GW on :9090
gw           | [INFO] Loaded from CP: 0 APIs, 0 subscriptions
gw           | [INFO] /health endpoint ready
backend      | [ECHO] Listening on :8000
```

If you see this, **all services are healthy and ready**.

## Step 3: Verify Services Are Running

In another terminal, check the status:

```bash
docker compose ps
```

Expected output:
```
NAME                COMMAND                  SERVICE      STATUS      PORTS
day43-is-1          "go run main.go"         is           Up 10s      0.0.0.0:8080->8080/tcp
day43-cp-1          "go run main.go"         cp           Up 5s       0.0.0.0:8082->8082/tcp
day43-gw-1          "go run main.go"         gw           Up 2s       0.0.0.0:9090->9090/tcp
day43-backend-1     "-text=hello from backend" backend    Up 15s      0.0.0.0:8000->8000/tcp
```

All statuses should be `Up`. If any is `Exited`, check the logs:

```bash
docker compose logs <service_name>  # e.g., docker compose logs gw
```

## Step 4: Manual Smoke Test (Optional)

Test the integration manually:

```bash
# Check each service individually
curl http://localhost:8080/health
curl http://localhost:8082/health
curl http://localhost:9090/health

# Create an API in CP
curl -X POST http://localhost:8082/apis \
  -H 'Content-Type: application/json' \
  -d '{"name":"TestAPI","context":"/test/v1","version":"1.0","backendUrl":"http://backend:8000","allowedTiers":["Gold"]}'

# You should see a response with an API ID.
```

## Step 5: Run the Automated Smoke Test

For a full end-to-end test, use the smoke test from day44:

```bash
cd ../day44
chmod +x smoke_test.sh
bash smoke_test.sh
```

Expected output: `=== ALL STEPS PASSED ===`

## Troubleshooting

### Issue: "docker compose: command not found"
**Solution:** Install Docker Desktop (includes Docker Compose).

### Issue: "could not resolve service name \"is\""
**Error in GW logs:** Connection errors when trying to reach `http://is:8080`.
**Cause:** Network not properly set up or service not running.
**Solution:** Check `docker compose ps` to confirm IS is up. Verify the service name in `docker-compose.yml` matches the environment variable (`JWKS_URL: "http://is:8080/..."`).

### Issue: GW starts but returns 404 for all APIs
**Cause:** GW may not have received the CP's initial state or lost connection to the SSE stream.
**Solution:** Check logs: `docker compose logs gw | grep -i "error\|sync\|events"`. Verify GW has `CP_URL` set correctly.

### Issue: Health checks repeatedly failing
**Cause:** Service isn't starting (Go compilation error, bad import, etc.).
**Solution:** Check logs: `docker compose logs <service>`. Look for `ERROR`, `panic`, or compilation errors.

## What Each Step Does

1. **IS starts:** Provides JWT endpoints (`/oauth2/token`, `/oauth2/jwks`).
2. **CP starts after IS:** Initializes API registry, subscribes to IS key events.
3. **GW starts after CP:** Calls `/admin/sync` to load initial APIs, subscribes to `/events` for updates.
4. **Backend** (stateless, starts anytime): Mock HTTP echo service.

## Network Topology (inside Docker Compose)

```
Client (your terminal)
  │
  ├── curl http://localhost:8080 ──→ IS (exposed on host)
  ├── curl http://localhost:8082 ──→ CP (exposed on host)
  ├── curl http://localhost:9090 ──→ GW (exposed on host)
  └── curl http://localhost:8000 ──→ Backend (exposed on host)

Inside Compose Network:
  IS (is:8080)
  CP (cp:8082) ─── http://is:8080 ──→ IS (for key config)
  GW (gw:9090) ─── http://cp:8082 ──→ CP (for /admin/sync + /events)
                ─── http://is:8080 ──→ IS (for JWKS)
  Backend (backend:8000)
```

Service names (`is`, `cp`, `gw`, `backend`) are DNS hostnames on the internal bridge network. They resolve automatically.

## Next Steps

- Day 44: Run the automated smoke test (`bash ../day44/smoke_test.sh`).
- Day 45: Review the runbook and answer reflection questions.

