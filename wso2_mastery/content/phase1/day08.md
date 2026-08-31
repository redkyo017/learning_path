# Day 8 — Token Revocation (RFC 7009)

## Learning Objectives

- Understand the RFC 7009 revocation endpoint contract and its unusual "always 200" requirement
- Know WSO2 IS's `OAuthRevocationProcessor` and token state machine
- Understand the JWT revocation gap and why it is a fundamental consequence of self-contained tokens
- Preview JMS-based real-time revocation notification (Phase 2 topic)

---

## 1. Why Revocation?

Every access token has an expiry claim (`exp`). In many situations the token must be invalidated before it expires:

- A user explicitly logs out of an application
- A refresh token is compromised and must be cancelled along with all its access tokens
- An administrator revokes a specific application's access grants
- A security incident requires immediate cancellation of all tokens issued to a client

RFC 7009 defines a standard revocation endpoint that any OAuth 2.0 client can call to tell the authorisation server: "Forget this token."

---

## 2. Endpoint Contract

```
POST /oauth2/revoke
Authorization: Basic <base64(client_id:client_secret)>
Content-Type: application/x-www-form-urlencoded

token=<token_value>&token_type_hint=access_token
```

`token_type_hint` values: `access_token`, `refresh_token`. The server may ignore the hint and detect the token type itself.

### Success response

```
HTTP/1.1 200 OK
```

Empty body. RFC 7009 §2.2 is explicit: **return 200 whether or not the token was found**.

### Why "always 200"?

If the server returned `404 Not Found` for unknown tokens, an attacker who obtained a partial token string could iterate through the remaining characters and use the 404/200 difference to confirm which strings are valid tokens — a "token fishing" attack. A uniform 200 response discloses nothing about the server's token store.

### Error responses (client and server failures)

These are the only cases where a non-200 response is correct:

| Scenario | HTTP status | Error code |
|---|---|---|
| Missing or invalid client credentials | 401 Unauthorized | `invalid_client` |
| Token belongs to a different client | 401 Unauthorized | `invalid_client` |
| Malformed request (missing `token` param) | 400 Bad Request | `invalid_request` |
| Internal server fault | 503 Service Unavailable | `server_error` |

---

## 3. WSO2 IS: `OAuthRevocationProcessor`

When WSO2 IS receives a revocation request, the processing chain is:

1. **`OAuthRevocationRequestDTO`** — carries the token string and type hint from the HTTP request.
2. **Client authentication** — `OAuthClientAuthnService` validates the Basic Auth credentials. Only the client that owns the token may revoke it.
3. **`OAuthRevocationProcessor`** — resolves the token type, looks up the token record, updates its state to `REVOKED` in `IDN_OAUTH2_ACCESS_TOKEN`.
4. **Refresh token cascade** — if the submitted token is a refresh token, WSO2 also marks all associated access tokens as `REVOKED`.

Key class:
```
org.wso2.carbon.identity.oauth2.revoke.OAuthRevocationProcessor
```

After revocation, any subsequent introspection call for that token returns `{"active": false}`.

---

## 4. Token State Machine

```
             issue()
  ─────────────────────→  ACTIVE
                             │
                             │  revoke() via OAuthRevocationProcessor
                             │  (marks IDN_OAUTH2_ACCESS_TOKEN.TOKEN_STATE = 'REVOKED')
                             ▼
                           REVOKED  ──→  (cleanup job removes old rows)
                             │
                     (also: natural expiry)
                             ▼
                           INACTIVE  (exp reached, not explicitly revoked)
```

The `IDN_OAUTH2_ACCESS_TOKEN.TOKEN_STATE` column holds one of:
`ACTIVE`, `INACTIVE`, `REVOKED`, `EXPIRED`.

A token in `REVOKED` state will never transition back to `ACTIVE`. The only way to regain access is to issue a new token.

---

## 5. The JWT Revocation Gap

JWTs are **self-contained**: a gateway validates them by checking the signature and `exp` claim locally, without contacting the authorisation server. This is their performance advantage — zero network overhead.

The consequence: **revocation cannot propagate to gateways in real time**.

```
T+0:00  Token issued, exp = T+1:00
         AS state: ACTIVE   |  Gateway cache: valid
                            |
T+0:10  Token revoked on AS
         AS state: REVOKED  |  Gateway cache: still valid (JWT not expired)
                            |
T+0:10  Client calls API    |
         AS: would reject   |  Gateway: accepts — signature OK, exp not reached
                            |
...                         |
T+1:00  JWT expires         |
         AS: REVOKED        |  Gateway: rejects — exp reached
```

**Maximum gap = token TTL at the time of revocation.** For a 3600-second TTL token revoked immediately after issue, an attacker can continue using it for up to 3600 seconds via a gateway that does local JWT validation.

### Mitigation strategies

| Strategy | How it works | Trade-off |
|---|---|---|
| **Short-lived JWTs** (e.g. 300 s) | Shrinks the worst-case gap to 5 minutes | Higher token refresh frequency; more load on the AS |
| **Opaque reference tokens** | Gateway introspects every request; AS can reject revoked tokens immediately | Network latency on every API call |
| **JMS revocation events** | AS publishes a revocation event; gateway receives it and purges its token cache | Requires a JMS broker; small asynchronous lag |
| **Per-path introspection policy** | Gateway calls introspect only on sensitive routes even for JWTs | Configuration complexity; partial coverage |

WSO2 API Manager's default Phase 2 configuration uses JMS event notification (via WSO2 Message Broker or ActiveMQ) to tell the gateway to purge specific tokens from its local cache within milliseconds of revocation. Phase 2 of this learning path covers that integration.

---

## 6. `token_type_hint` — Optimisation, Not Validation

The hint tells the server which token type to look up first in the database. If the hint is wrong (you pass `access_token` but submit a refresh token), the server must still try the other type. WSO2 IS follows this requirement.

For the lab server, all tokens are JWTs and are tracked in the `revokedTokens` map regardless of type hint.

---

## Exercises

### Exercise 1 — Full round-trip: issue → introspect → revoke → introspect

Run the day08 lab server. Execute the complete lifecycle in a shell script. Confirm the status transitions.

**Hint:** Use `jq -r .access_token` to capture the token. Use `curl -o /dev/null -w "%{http_code}"` to capture only the HTTP status code without a body. The revoke call returns an empty body.

**Solution sketch:**
```bash
# Issue
TOKEN=$(curl -s -X POST http://localhost:9443/oauth2/token \
  -u test-client:test-secret \
  -d grant_type=client_credentials | jq -r .access_token)
echo "Token: ${TOKEN:0:40}..."

# Introspect — expect active:true
echo "Before revocation:"
curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret -d "token=$TOKEN" | jq .active

# Revoke — expect HTTP 200, empty body
echo "Revoke HTTP status:"
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:9443/oauth2/revoke \
  -u test-client:test-secret -d "token=$TOKEN"
echo ""

# Introspect again — expect active:false
echo "After revocation:"
curl -s -X POST http://localhost:9443/oauth2/introspect \
  -u test-client:test-secret -d "token=$TOKEN" | jq .active
```

---

### Exercise 2 — Revoke an unknown token

Call `/oauth2/revoke` with a string that was never issued as a token. Confirm the HTTP response is 200 and the body is empty. Explain why this is correct per RFC 7009.

**Hint:** No special setup needed — just submit a fabricated token value.

**Solution sketch:**
```bash
curl -v -X POST http://localhost:9443/oauth2/revoke \
  -u test-client:test-secret \
  -d "token=this-was-never-a-real-token"
```
Expected: `HTTP/1.1 200 OK` with no body. The lab server's `revokeHandler` stores the string in `revokedTokens` anyway (harmless — it was never a valid JWT) and returns 200. This behaviour is correct by RFC 7009 §2.2: uniform 200 prevents token enumeration.

---

### Exercise 3 — Revocation gap analysis

Given a token with `expires_in=3600` that is revoked 60 seconds after issue, calculate:
1. The maximum remaining gap window on a gateway using local JWT validation.
2. What `expires_in` value would you set to guarantee the gap is no larger than 60 seconds?
3. What is the cost of that shorter TTL on token issuance rate?

**Hint:** Gap = `exp - revoke_time`. The gap shrinks as the token ages. For a gateway to "catch up," the token must expire. Draw a timeline.

**Solution sketch:**
1. Revoked at T+60, expires at T+3600 → gap = 3600 - 60 = **3540 seconds** (≈59 minutes).
2. To guarantee gap ≤ 60 s: set `expires_in = 60`. Even if revoked immediately after issue, the token expires within 60 seconds.
3. Cost: every client must refresh every 60 seconds. For N clients, that is N token requests per minute instead of N per hour — a 60× increase in AS load. In practice, 300 seconds (5 minutes) is a common balance point.
