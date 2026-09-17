# WSO2 Production Failure Catalog

Use this as a quick-reference during incidents. Read the error code from the response body, find the class below, run the action.

## Quick Reference Table

| Class | Error Code | Log Signature | Root Cause | Immediate Action |
|---|---|---|---|---|
| AUTH_FAILED | 900901 | `Invalid Credentials` | Wrong API key / expired token / missing subscription | Check subscription in CP; verify IS /oauth2/token health |
| SUBSCRIPTION_NOT_FOUND | 900908 | `no valid subscription` | GW event cache stale | Restart GW → triggers /admin/sync re-fetch |
| THROTTLE_EXCEEDED | 900800 | `Throttle limit exceeded` | Rate limit hit; or TM connection lost | Check TM health; check GW→TM SG (9611/9711) |
| BACKEND_TIMEOUT | — | `connection timed out` | Backend unreachable or slow | Check backend ECS task; check SG rules |
| JWT_EXPIRED | — | `JWT expired` / `exp claim` | Token TTL elapsed; clock skew | Client re-auths; check NTP on GW/IS containers |
| JWT_INVALID_SIGNATURE | — | `Signature verification failed` | JWKS unreachable; IS keystore rotated | `curl https://is.wso2.internal:9443/oauth2/jwks`; restart GW |
| EVENT_SYNC_LAG | — | `eventHub.*error` | CP→GW event connection broken | Restart GW; check CP /admin/sync; check CP logs |

---

## Log Patterns (for grep / CloudWatch Metrics Filter)

| Class | grep pattern |
|---|---|
| AUTH_FAILED | `Invalid Credentials\|900901` |
| SUBSCRIPTION_NOT_FOUND | `no valid subscription\|900908` |
| THROTTLE_EXCEEDED | `Throttle limit exceeded\|900800` |
| BACKEND_TIMEOUT | `connection timed out\|read timeout` |
| JWT_EXPIRED | `JWT expired\|token expired\|\bexp\b claim` |
| JWT_INVALID_SIGNATURE | `Signature verification failed\|invalid JWT` |
| EVENT_SYNC_LAG | `eventHub.*error\|sync lag\|event sync.*fail` |

---

## HTTP Status Code → Failure Class Mapping

| HTTP Status | Likely Failure Classes |
|---|---|
| 401 Unauthorized | AUTH_FAILED, JWT_EXPIRED, JWT_INVALID_SIGNATURE |
| 403 Forbidden | SUBSCRIPTION_NOT_FOUND, AUTH_FAILED |
| 429 Too Many Requests | THROTTLE_EXCEEDED |
| 502 Bad Gateway | BACKEND_TIMEOUT, EVENT_SYNC_LAG |
| 504 Gateway Timeout | BACKEND_TIMEOUT |

---

## CloudWatch Insights Cross-Log-Group Query Template

```
fields @logStream, @message
| filter @message like /900901|900908|900800|timed out|JWT expired|Signature verification|eventHub/
| sort @timestamp desc
| limit 50
```

---

## Incident Triage Workflow

1. **Get the error code from the response body.**
   - Examples: 900901, 900908, 900800, or text like "JWT expired", "connection timed out"

2. **Find it in the table above.**
   - Quick scan by error code, then read the root cause and immediate action.

3. **Run the immediate action.**
   - If it's "restart GW", restart GW. If it's "check TM health", check TM health.

4. **If the issue persists:**
   - Check the GW/IS/CP/TM logs for the failure class (use grep patterns).
   - Correlate timestamps and activity IDs across logs.
   - Check network and security groups.

---

## Notes

- **No single restart cures all:** Different failures need different actions. Read the error code.
- **Clock skew affects JWT checks:** NTP is not optional. Sync all containers to the same time source.
- **Event sync lag is cascading:** If the GW loses touch with the CP, it falls back to stale data. Restart the GW to re-sync.
- **TM connection loss is silent:** The GW will not error; it just falls back to local throttle limits, which may be wrong. Monitor the GW→TM SG and TM health proactively.
