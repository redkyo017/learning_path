# Day 12 — Complete Key Manager: Docker Packaging & APIM Registration

## What "Complete" Means

A production-ready Key Manager service must:

1. Implement all seven Key Manager endpoints.
2. Log every request with a correlation ID (structured JSON).
3. Accept configuration via environment variables (port, future: DB URL, signing key path).
4. Run as a stateless container so Kubernetes or Docker Compose can scale it.
5. Be registered in the APIM admin console so the Control Plane can call it.

Day 12 wires all of this together.

---

## Structured Logging + Correlation ID

Copy the correlation ID middleware pattern from Day 9 into your Key Manager.
Every handler extracts the ID from context and passes it to `slog`:

```go
slog.Info("token_issued",
    "correlation_id", correlationFromCtx(r.Context()),
    "client_id", clientID,
)
```

The JSON log line that comes out:

```json
{
  "time": "2026-08-31T10:00:00Z",
  "level": "INFO",
  "msg": "token_issued",
  "correlation_id": "aB3xQ7...",
  "client_id": "dGVzdC1jbGllbnQ"
}
```

Structured logs let you grep, filter in Datadog/CloudWatch, and trace a
single request across multiple services by its `correlation_id`.

---

## Configurable Port via Environment Variable

```go
func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "9444"
    }
    addr := ":" + port
    // ...
    log.Fatal(http.ListenAndServe(addr, handler))
}
```

`os.Getenv` returns an empty string when the variable is not set.  The
fallback `"9444"` means the binary works without any configuration in
development.

---

## Docker Multi-Stage Build

A multi-stage build produces a minimal final image:

```dockerfile
# Stage 1 — compile
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o keymanager .

# Stage 2 — minimal runtime
FROM alpine:3.19
WORKDIR /app
COPY --from=build /app/keymanager .
EXPOSE 9444
CMD ["./keymanager"]
```

**Why two stages?**

The `golang:1.22-alpine` image is ~230 MB (with toolchain).  The
`alpine:3.19` image is ~7 MB.  The final image contains only the compiled
binary — no Go source, no compiler, no module cache.  The result is
typically 12–18 MB.

### docker-compose.yml

```yaml
services:
  keymanager:
    build: .
    ports:
      - "9444:9444"
    environment:
      - PORT=9444
```

Run with:

```bash
docker compose up --build
```

---

## Registering the Go Key Manager in WSO2 APIM

Log into the APIM admin console: `https://<apim-host>:9443/admin`

### Step 1 — Open Key Manager configuration

Navigate to: **Key Managers** → **Add Key Manager**

### Step 2 — Fill in the form

| Field | Value |
|-------|-------|
| Name | `GoKeyManager` |
| Display Name | `Go Key Manager (Phase 1)` |
| Description | `Learning path custom KM` |
| Type | `Custom` |
| Well-known URL | *(leave blank — we provide endpoints manually)* |

### Step 3 — Configure endpoints

Under **Key Manager Endpoints**, enter:

| Endpoint | Value |
|----------|-------|
| Token Endpoint | `http://keymanager:9444/api/am/keymanager/v1/oauth2/token` |
| Revoke Endpoint | `http://keymanager:9444/api/am/keymanager/v1/oauth2/revoke` |
| Introspection Endpoint | `http://keymanager:9444/api/am/keymanager/v1/oauth2/introspect` |
| JWKS Endpoint | `http://keymanager:9444/api/am/keymanager/v1/jwks` |
| Register Endpoint | `http://keymanager:9444/api/am/keymanager/v1/keymanager/application` |

> Replace `keymanager` with your container name or IP.  If running both
> containers on the same Docker network, use the service name.

### Step 4 — Grant types

Enable: `client_credentials`

### Step 5 — Save

Click **Add**.  APIM will immediately:

1. Call `GET /health` — if your container is not running you will see a
   connection error here.
2. Call `GET /api/am/keymanager/v1/jwks` — caches your public key.
3. Call `POST /api/am/keymanager/v1/keymanager/application` once for
   each of APIM's internal service accounts.

If all three succeed, the Key Manager status shows **Active**.

---

## What APIM Does After Registration

Once the KM is active, every developer subscription through the portal triggers:

```
POST /api/am/keymanager/v1/keymanager/application
Body: {"applicationName":"<dev-app-name>","grantTypes":["client_credentials"],"callbackUrl":""}
```

Your service creates the OAuth client and returns `clientId`/`clientSecret`.
APIM stores them in `AM_APPLICATION_KEY_MAPPING`.

When the developer calls the Gateway with their token, the Gateway calls:

```
POST /api/am/keymanager/v1/oauth2/introspect
Body: token=<access_token>
```

Your service validates the JWT and returns the `active` flag plus claims.

---

## Practical Checkpoint

1. Why is the final Docker image much smaller than the build image?
2. What three calls does APIM make immediately after you save the Key
   Manager in the admin console?
3. What field in `docker-compose.yml` controls the port the service listens on?

---

## Lab (Day 12)

See `labs/phase1/day12/keymanager/` — Dockerfile, docker-compose.yml,
and the complete Go Key Manager server.

---

## Exercises

**Exercise 1 — Build and run**

Build the Docker image and verify the health endpoint responds before
connecting APIM.

**Hint:** `docker compose up --build -d` starts it in detached mode; then
`curl http://localhost:9444/health`.

**Solution sketch:**
```bash
cd labs/phase1/day12/keymanager
docker compose up --build -d
curl http://localhost:9444/health
# {"status":"UP"}
docker compose down
```

**Exercise 2 — PORT override**

Run the container on port 8080 instead of 9444 without changing the
Dockerfile or docker-compose.yml.

**Hint:** Pass an environment variable override on the command line.

**Solution sketch:**
```bash
docker run --rm -e PORT=8080 -p 8080:8080 keymanager-keymanager
curl http://localhost:8080/health
```

Or in docker-compose.yml change `PORT=8080` and the port mapping to `"8080:8080"`.

**Exercise 3 — Full registration smoke test**

With the container running, simulate what APIM does on registration:

1. GET /health
2. GET /api/am/keymanager/v1/jwks
3. POST /api/am/keymanager/v1/keymanager/application with body
   `{"applicationName":"apim_publisher","grantTypes":["client_credentials"],"callbackUrl":""}`
4. Use the returned `clientId`/`clientSecret` to obtain a token.
5. Introspect that token.

**Hint:** Each step uses the output of the previous one.

**Solution sketch:**
```bash
curl http://localhost:9444/health
curl http://localhost:9444/api/am/keymanager/v1/jwks
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/keymanager/application \
  -H "Content-Type: application/json" \
  -d '{"applicationName":"apim_publisher","grantTypes":["client_credentials"],"callbackUrl":""}' \
  | tee /tmp/km_app.json

CLIENT_ID=$(jq -r .clientId /tmp/km_app.json)
CLIENT_SECRET=$(jq -r .clientSecret /tmp/km_app.json)

TOKEN=$(curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" | jq -r .access_token)

curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/introspect \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "token=${TOKEN}" | jq .active
# true
```
