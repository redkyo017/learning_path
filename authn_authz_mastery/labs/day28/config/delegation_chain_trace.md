# Day 28 Lab — Annotated End-to-End Delegation Chain Trace

## Complete HTTP Trace with Decoded JWTs

This file shows the complete HTTP trace for the PAY-001 transaction with all token payloads decoded.

---

## Step 1: User authentication → human_token

```http
POST /oauth2/authorize
Content-Type: application/x-www-form-urlencoded

client_id=mobilebank
&response_type=code
&scope=payments:read%20payments:write%20accounts:read
&state=<PLACEHOLDER: random-state>
&nonce=<PLACEHOLDER: random-nonce>
&redirect_uri=https%3A%2F%2F<PLACEHOLDER: app-host>%2Fcallback
```

Response (JARM-encoded):
```http
HTTP/1.1 302 Found
Location: https://<PLACEHOLDER: app-host>/callback?response=<PLACEHOLDER: jarm-response-jwt>
```

Decoded JARM response:
```json
{
  "code": "<PLACEHOLDER: authorization-code>",
  "state": "<PLACEHOLDER: random-state>"
}
```

Token request (private_key_jwt):
```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=<PLACEHOLDER: authorization-code>
&redirect_uri=https%3A%2F%2F<PLACEHOLDER: app-host>%2Fcallback
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: mobile-bank-client-assertion>
```

Token response:
```json
{
  "access_token": "<PLACEHOLDER: human-token-jwt>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "payments:read payments:write accounts:read"
}
```

**Decoded human_token JWT:**
```json
{
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "sub": "alice_001",
  "aud": "mobilebank",
  "scope": "payments:read payments:write accounts:read",
  "exp": 1696108129,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440000",
  "alg": "RS256",
  "kid": "<PLACEHOLDER: key-id>"
}
```

**Key observations:**
- `sub = "alice_001"` — user is identified
- `scope` is broad (read+write for payments and accounts)
- `exp = 3600s` (1 hour from issuance)
- `jti = "550e8400-e29b-41d4-a716-446655440000"` — unique token ID for tracing

---

## Step 2: First-hop exchange (user → orchestrator)

**Orchestrator calls IS 7.3 token exchange endpoint:**

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&subject_token=<PLACEHOLDER: human-token-jwt>
&subject_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aaccess_token
&actor_token=<PLACEHOLDER: orchestrator-actor-jwt>
&actor_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Ajwt
&scope=agent%3Apayments%3Ainitiate
&requested_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aaccess_token
&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=<PLACEHOLDER: orchestrator-client-assertion>
```

**Where:**
- `subject_token` = human_token from step 1
- `actor_token` = JWT signed by orchestrator's private key (identifies the orchestrator)
- `scope = agent:payments:initiate` (narrowed from human's full scope)

**IS 7.3 processing:**
1. Validates `human_token` (signature, exp, active status)
2. Validates `actor_token` (signature against orchestrator's JWKS, exp, `aud`)
3. Checks actor trust policy: actor=payment_orchestrator, subject=alice_001 ∈ group:financial-users? → Allow
4. Issues new token with `act` claim added

**Token response:**
```json
{
  "access_token": "<PLACEHOLDER: orchestrator-token-jwt>",
  "token_type": "Bearer",
  "expires_in": 900,
  "scope": "agent:payments:initiate"
}
```

**Decoded orchestrator_token JWT:**
```json
{
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "sub": "alice_001",
  "act": {
    "sub": "payment_orchestrator"
  },
  "aud": "payment-api",
  "scope": "agent:payments:initiate",
  "exp": 1696104729,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440001",
  "alg": "RS256",
  "kid": "<PLACEHOLDER: key-id>"
}
```

**Key observations:**
- `sub = "alice_001"` — preserved from human_token
- `act = {"sub": "payment_orchestrator"}` — agent identity added
- `scope = "agent:payments:initiate"` — narrowed from human's full scope
- `exp = 900s` (15 minutes, shorter than human token)
- `jti = "550e8400-e29b-41d4-a716-446655440001"` — new unique ID

---

## Step 3: Second-hop exchange (orchestrator → tool)

**Tool agent calls IS 7.3 token exchange endpoint:**

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&subject_token=<PLACEHOLDER: orchestrator-token-jwt>
&subject_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aaccess_token
&actor_token=<PLACEHOLDER: risk-scorer-actor-jwt>
&actor_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Ajwt
&scope=agent%3Apayments%3Ainitiate
&requested_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Aaccess_token
&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer
&client_assertion=<PLACEHOLDER: risk-scorer-client-assertion>
```

**Where:**
- `subject_token` = orchestrator_token from step 2
- `actor_token` = JWT signed by risk scorer's private key

**IS 7.3 processing:**
1. Validates `orchestrator_token` (signature, exp, active status)
2. Validates `actor_token` (signature against risk_scorer's JWKS)
3. Checks actor trust policy: actor=risk_scorer, subject=alice_001 ∈ group:financial-users? → Allow
4. **Extracts parent chain:** orchestrator_token has `act = {"sub": "payment_orchestrator"}`
5. Issues new token with risk_scorer added to `act` chain (nesting grows)

**Token response:**
```json
{
  "access_token": "<PLACEHOLDER: tool-token-jwt>",
  "token_type": "Bearer",
  "expires_in": 300,
  "scope": "agent:payments:initiate"
}
```

**Decoded risk_scorer_token JWT (nested `act`):**
```json
{
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "sub": "alice_001",
  "act": {
    "sub": "risk_scorer",
    "act": {
      "sub": "payment_orchestrator"
    }
  },
  "aud": "payment-api",
  "scope": "agent:payments:initiate",
  "exp": 1696104829,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "alg": "RS256",
  "kid": "<PLACEHOLDER: key-id>"
}
```

**Key observations:**
- `sub = "alice_001"` — preserved through two hops
- `act` is nested: risk_scorer is the immediate caller, payment_orchestrator is the parent
- `exp = 300s` (5 minutes, shortest lifetime for minimal blast radius)
- `jti = "550e8400-e29b-41d4-a716-446655440002"` — new unique ID
- **Full chain is visible:** `sub` (user) + `act.sub` (tool) + `act.act.sub` (orchestrator)

---

## Step 4–5: Tool calls Payment API via AgentCore

```http
POST /v1/payments/initiate
Authorization: Bearer <PLACEHOLDER: risk-scorer-token-jwt>
X-AgentCore-Caller-Identity: {"userId": "alice_001", "agentId": "risk_scorer", "sessionId": "550e8400-e29b-41d4-a716-446655440003"}
Content-Type: application/json

{
  "amount": 1000.00,
  "currency": "USD",
  "destination_account": "<PLACEHOLDER: dest-account>"
}
```

**AgentCore processing:**
1. Receives request with Bearer token
2. Validates SigV4 signature (if routed through AgentCore; otherwise, direct call)
3. Adds `X-AgentCore-Caller-Identity` header with session tags
4. Forwards to Payment API

---

## Step 6a: Payment API introspects token

```http
POST /oauth2/introspect
Content-Type: application/x-www-form-urlencoded

token=<PLACEHOLDER: risk-scorer-token-jwt>
&client_id=payment-api
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: payment-api-client-assertion>
```

**IS 7.3 processing:**
1. Validates the token (signature, exp)
2. **Traces the delegation chain:**
   - risk_scorer_token.sub = alice_001 ✓
   - risk_scorer_token.act.sub = risk_scorer ✓
   - risk_scorer_token.act.act.sub = payment_orchestrator ✓
   - No revocation on any member of the chain ✓
3. Returns full introspection response

**IS 7.3 response:**
```json
{
  "active": true,
  "sub": "alice_001",
  "act": {
    "sub": "risk_scorer",
    "act": {
      "sub": "payment_orchestrator"
    }
  },
  "aud": "payment-api",
  "scope": "agent:payments:initiate",
  "exp": 1696104829,
  "iat": 1696104529,
  "jti": "550e8400-e29b-41d4-a716-446655440002",
  "client_id": "risk_scorer",
  "token_type": "Bearer"
}
```

**Payment API validation:**
- `active: true` ✓ — token is valid
- `sub: alice_001` ✓ — user is authenticated
- `act` chain ✓ — full delegation chain is recorded
- `scope: agent:payments:initiate` ✓ — agent scope allows payment initiation
- `jti` ✓ — unique ID for audit correlation

---

## Step 6b: Payment API processes and logs transaction

```json
{
  "timestamp": "2026-10-01T10:15:30Z",
  "txn_id": "PAY-001",
  "user_sub": "alice_001",
  "agent_chain": ["risk_scorer", "payment_orchestrator"],
  "token_jti": "550e8400-e29b-41d4-a716-446655440002",
  "agentcore_session_id": "550e8400-e29b-41d4-a716-446655440003",
  "amount": 1000.00,
  "currency": "USD",
  "status": "approved"
}
```

---

## Step 7: Revocation scenario (if user revokes at T+60min)

**User clicks "Sign out everywhere" at T=60min:**

```http
POST /oauth2/revoke
Content-Type: application/x-www-form-urlencoded

token=<PLACEHOLDER: human-token-jwt>
&client_id=mobilebank
```

**IS 7.3 marks human_token as revoked:**
- Token state updated in IS 7.3 cache/database
- IS 7.3 audit log entry: `event_type=token_revoke`, `jti=550e8400-e29b-41d4-a716-446655440000`

**At T+62min, if tool tries to exchange orchestrator_token:**

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange
&subject_token=<PLACEHOLDER: orchestrator-token-jwt>
...
```

**IS 7.3 processing:**
1. Validates orchestrator_token: `exp > 62min`? Yes, token not expired
2. **BUT:** IS 7.3 checks the chain:
   - orchestrator_token.sub = alice_001
   - orchestrator_token's parent (subject_token) = human_token (jti=550e8400-e29b-41d4-a716-446655440000)
   - Is human_token revoked? **YES** (revoked at T=60min)
3. **IS 7.3 denies the exchange:**

```json
{
  "error": "invalid_request",
  "error_description": "Subject token has been revoked"
}
```

**Result:** Tool cannot get a new token; existing tool tokens are still valid until their own `exp`, but further exchanges fail.

**If Payment API calls introspect on existing tool_token after T+60min:**

```json
{
  "active": false,
  "error": "invalid_token",
  "error_description": "Token chain revoked (parent token revoked)"
}
```

**Revocation propagates:** All derived tokens become inactive within the introspection cache TTL (300s = 5min).

---

## Audit Trail Reconstruction

**Given:** Transaction PAY-001 with `jti = 550e8400-e29b-41d4-a716-446655440002`

**Query 1: Find IS 7.3 token exchanges with this jti**

```sql
SELECT timestamp, event_type, actor_client, issued_scope
FROM is73_audit
WHERE jti = "550e8400-e29b-41d4-a716-446655440002"
  AND event_type = "token_exchange"
```

**Result:**
- One row: Second-hop exchange (orchestrator → tool)
- Timestamps and actors recorded

**Query 2: Trace parent tokens**

The second-hop entry will reference the first-hop exchange (via subject_token's jti):

```sql
SELECT timestamp, event_type, actor_client, issued_scope
FROM is73_audit
WHERE jti = "550e8400-e29b-41d4-a716-446655440001"
  AND event_type = "token_exchange"
```

**Result:**
- One row: First-hop exchange (user → orchestrator)
- Full chain reconstructed

**Query 3: Find AgentCore CloudTrail entries**

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --filter-criteria '[{"attributeKey": "SessionId", "attributeValue": "550e8400-e29b-41d4-a716-446655440003"}]'
```

**Query 4: Verify user consent**

Check if alice_001 gave consent for `agent:payments:initiate` scope:

```sql
SELECT timestamp, consent_scope, consent_status
FROM is73_consent_log
WHERE subject = "alice_001"
  AND scope LIKE "%agent:payments%"
```

---

## Summary: Complete Audit Trail

| System | Record | Correlation ID | Info |
|--------|--------|-----------------|------|
| IS 7.3 audit | Token exchange #1 | `jti=uuid-1` | user → orchestrator |
| IS 7.3 audit | Token exchange #2 | `jti=uuid-2` | orchestrator → tool |
| IS 7.3 audit | Introspection | `jti=uuid-2` | payment API verified token |
| Payment API | Transaction PAY-001 | `jti=uuid-2` + `agentcore_session_id=uuid-3` | $1000 approved |
| AgentCore CloudTrail | AssumeRole | `sessionId=uuid-3` | Tool called API |

All records linked via `jti` (or `agentcore_session_id` derivative). Compliance officer can reconstruct the entire chain in minutes using structured audit queries.
