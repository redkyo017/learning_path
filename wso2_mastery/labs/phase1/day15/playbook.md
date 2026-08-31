# WSO2 IS Debug Playbook — Phase 1

## First-response checklist (token 401)

- [ ] Check WSO2 IS is UP: `curl https://<is-host>:9443/healthz`
- [ ] Enable DEBUG logging: update `log4j2.properties` with OAuth2 loggers
- [ ] Pull IS logs: `docker logs <container> 2>&1 | grep -E "(ERROR|WARN|DEBUG.*token)"`
- [ ] Check for correlation ID in the 401 response header (`correlation-id`)
- [ ] Search logs for that correlation ID: `grep <correlation-id> wso2carbon.log`

---

## Token failure decision tree

```
401 received
├── Token missing → client bug (not sending Authorization header)
├── Token present but:
│   ├── "Invalid JWT" in logs → signature mismatch (check JWKS kid rotation)
│   ├── "Token expired" in logs → clock skew or long-lived token
│   ├── "Client Authentication failed" → wrong clientId/Secret
│   ├── "Invalid scope" → token scope doesn't cover the API
│   └── "Token revoked" → token was explicitly revoked (check revocation event propagation)
```

---

## Key log patterns

| Log pattern | Meaning | Action |
|---|---|---|
| `WARN {OAuthClientAuthn} - Client Authentication failed` | Wrong clientSecret | Check client registration in IS admin console |
| `WARN {OAuth2TokenValidation} - Invalid JWT` | Bad signature or tampered token | Check JWKS kid; check if IS restarted and key changed |
| `DEBUG {OAuth2} - Access token issued` | Healthy issue | Confirm token reaches the client |
| `INFO {OAuth2} - Revoking access token` | Explicit revocation | Check if revocation propagated to GW (Phase 2) |

---

## Common ECS Fargate gotchas

- IS log4j2 changes require either a restart or a hot-reload trigger — ECS task restart is clean.
- Correlation ID header: `correlation-id` in IS responses; check ALB logs for the same ID.
- IS health path: `GET /healthz` (not `/health`).

---

## Quick grep cheatsheet

```bash
# All WARN and ERROR in IS logs
docker logs <is-container> 2>&1 | grep -E "(WARN|ERROR)"

# All lines for a specific correlation ID
grep "<correlation-id>" /home/wso2carbon/wso2is-7.3.0/repository/logs/wso2carbon.log

# Token issuance lines only
docker logs <is-container> 2>&1 | grep "Access token issued"

# Client auth failures only
docker logs <is-container> 2>&1 | grep "Client Authentication failed"

# JWT validation failures only
docker logs <is-container> 2>&1 | grep "Invalid JWT"

# Go KM structured JSON — filter by correlation_id
grep "<correlation-id>" /tmp/km.log | jq .
```

---

## IS health endpoints reference

| Endpoint | Method | Expected | Notes |
|---|---|---|---|
| `/healthz` | GET | `{"status":"UP"}` | Primary liveness check |
| `/health` | GET | `{"status":"UP"}` | Alias; may vary by IS version |
| `/services/OAuth2TokenValidationService?wsdl` | GET | SOAP WSDL XML | SOAP validation endpoint (Phase 2) |

---

## Go KM structured log fields

Every log line emitted by `labs/phase1/day15/main.go` is JSON with these fields:

| Field | Example value | When it appears |
|---|---|---|
| `msg` | `"request_received"` | Entry of every handler |
| `method` | `"POST"` | Entry of every handler |
| `path` | `"/api/am/keymanager/v1/oauth2/token"` | Entry of every handler |
| `correlation_id` | `"aB3xQ7mNpL..."` | Entry of every handler |
| `client_id` | `"dGVzdC1jb..."` | token_issued, token_rejected, app_registered |
| `reason` | `"invalid_client_credentials"` | token_rejected |
| `active` | `true` / `false` | introspect_called |
| `sub` | `"test-client"` | introspect_called (active=true) |
| `exp` | `1756650000` | token_issued, introspect_called |
