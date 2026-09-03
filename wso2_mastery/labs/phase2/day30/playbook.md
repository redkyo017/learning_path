# WSO2 GW Debug Playbook — Phase 2

## First-response checklist (401/403/429 from gateway)
- [ ] Check GW is UP: `curl https://<gw-host>:8243/health`
- [ ] Enable DEBUG logging: update GW log4j2.properties with security + throttling loggers
- [ ] Pull GW logs: `docker logs <container> 2>&1 | grep -E "(ERROR|WARN|DEBUG.*JWT|DEBUG.*throttl)"`
- [ ] Get correlation ID from the error response header: `activityid`
- [ ] Search GW logs: `grep <activityid> wso2carbon.log`
- [ ] If nothing in GW logs: check IS logs — token may have failed at issuance

## GW error decision tree
```
4xx from gateway
├── 401 Unauthorized
│   ├── "Token expired" in logs → token TTL exceeded (issue new token)
│   ├── "Signature verification failed" → JWKS kid mismatch (IS key rotated?)
│   ├── "Public key not found for kid" → GW JWKS cache stale → restart GW or clear cache
│   └── No GW logs at all → token never reached GW (check client, ALB, network)
├── 403 Forbidden
│   ├── "subscription not found" → app not subscribed to this API in CP
│   └── "keytype SANDBOX vs PRODUCTION" → using sandbox key against production endpoint
└── 429 Too Many Requests
    ├── "Application level throttle limit exceeded" → app tier breached
    └── "API level throttle limit exceeded" → API-wide limit breached (affects all apps)
```

## Key log patterns
| Pattern | Meaning | Action |
|---|---|---|
| `WARN {JWTValidator} - JWT token validation failed: Token expired` | Token TTL exceeded | Client must issue a new token |
| `WARN {JWTValidator} - Signature verification failed` | Key mismatch or tampered JWT | Check JWKS kid; check if IS restarted |
| `WARN {JWTValidator} - Public key not found for kid` | GW JWKS cache stale | Restart GW container or hit JWKS refresh endpoint |
| `WARN {APIAuthenticationHandler} - API subscription not found` | App not subscribed | Register subscription in CP admin UI |
| `WARN {ThrottleHandler} - Request throttled` | Tier limit hit | Wait for bucket refill; or upgrade subscription tier |

## IS vs GW log split
| Symptom | Check first | Secondary check |
|---|---|---|
| Token never issued | IS logs (`OAuthClientAuthn`, `OAuth2`) | N/A |
| Token issued but 401 at GW | GW logs (`JWTValidator`) | IS logs for key rotation |
| Token valid but 403 | GW logs (`APIAuthenticationHandler`) | CP subscription data |
| Intermittent 429 | GW logs (`ThrottleHandler`) | TM logs for global counter |

## ECS Fargate GW gotchas
- GW log4j2 changes require ECS task restart — no hot-reload in containerised deployments.
- `activityid` header: set by client or ALB; carried through all GW logs for that request.
- GW health path: `GET /services/Version` (legacy) or `GET /health` (custom endpoint).
- JWKS URL config: `[apim.jwt]` section in `deployment.toml` → `jwks_url`.
