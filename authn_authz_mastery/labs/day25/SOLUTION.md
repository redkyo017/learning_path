# Day 25 Lab — Solution

## Overview

This solution traces the complete AgentCore → IS 7.3 → Payment API flow. The key insight is that AgentCore bridges AWS IAM identity with OAuth2 identity via OIDC federation and RFC 8693 token exchange.

## The 8-Step Flow (Detailed Analysis)

### Steps 1–2: User Authentication and Session Setup

```http
Step 1: User Auth
GET https://is.bank.com:9443/oauth2/authorize?...

Response:
{
  "access_token": "eyJ...",
  "sub": "user-123",
  "scope": "payments:initiate",
  "exp": 3600
}
```

**Key points:**
- User gets IS 7.3 token with `sub=user-123`
- Scope includes `payments:initiate` (user authorized to initiate payments)
- Token TTL is 1 hour

```
Step 2: User Token → Agent
User's app: send user token to AgentCore session context (secure, not env var)
AgentCore: store token in secure session store for this agent instance
```

### Steps 3–4: AgentCore Gets OIDC Token and Calls IS 7.3

```
Step 3: AgentCore → AWS STS
AgentCore has temporary IAM credentials (from sts:AssumeRole)
AgentCore calls: sts:GetCallerIdentity + OIDC token request
AWS returns: OIDC identity token signed by AWS

Token payload:
{
  "iss": "https://oidc.eks.us-east-1.amazonaws.com/id/...",
  "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorAgentRole",
  "aud": "https://is.bank.com:9443/oauth2/token",
  "exp": 3600
}
```

The `aud` is critical — it identifies that this token was issued FOR IS 7.3's token endpoint.

### Step 5: IS 7.3 Validation (The Trust Federation)

When IS 7.3 receives the token exchange request:

```http
POST /oauth2/token
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<user-token>
&actor_token=<aws-oidc-token>
&scope=payments:initiate
```

IS 7.3 performs these checks (in order):

**1. Validate client_assertion (agent's private_key_jwt)**
```
Check: Is this client (agent) registered?
Check: Is the JWT signature valid (using agent's JWKS)?
Check: Is aud correct (is.bank.com token endpoint)?
Check: Is jti unique (replay prevention)?
Check: Is exp not exceeded?
Result: ✅ Agent is authenticated
```

**2. Validate subject_token (user's IS 7.3 token)**
```
Check: Is the JWT signed by IS 7.3?
Check: Is exp not exceeded?
Check: Is scope valid (payments:initiate)?
Extract: sub=user-123
Result: ✅ User token is valid
```

**3. Validate actor_token (AWS OIDC token) — THE TRUST FEDERATION**
```
Step A: Lookup AWS OIDC provider (registered in Step 4)
Step B: Fetch AWS OIDC JWKS from discovery URL
        GET https://oidc.eks.us-east-1.amazonaws.com/id/<cluster-id>/keys
Step C: Extract kid from actor_token JWT header
Step D: Lookup key with matching kid in JWKS
Step E: Verify JWT signature using AWS public key
Result: ✅ Token is signed by AWS

Step F: Check aud claim
        actor_token.aud == "https://is.bank.com:9443/oauth2/token"?
        Result: ✅ Token was issued for IS 7.3

Step G: Check actor trust policy (configured per-app in IS 7.3 Console)
        actor_token.sub == "arn:aws:iam::123456789012:role/PaymentOrchestratorAgentRole"?
        Is this role in the allowed_actors list for this app?
        Result: ✅ Agent is trusted
```

### Step 6: IS 7.3 Issues Exchange Token

```json
{
  "sub": "user-123",
  "act": {
    "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorAgentRole"
  },
  "scope": "payments:initiate",
  "aud": "payment-api",
  "exp": 900,
  "jti": "uuid-token"
}
```

**Key claims:**
- `sub` — PRESERVED from subject_token (original user)
- `act` — ADDED from actor_token (agent's identity)
- `scope` — same as requested (payments:initiate)
- `exp` — shorter TTL (15 minutes) than subject_token (1 hour)
- `jti` — unique ID for audit trail correlation

### Steps 7–8: Payment API Call and Introspection

```http
POST /payments/initiate
Authorization: Bearer <exchange-token>

{
  "amount": 100.00,
  "recipient": "account-456"
}
```

Payment API introspects:

```http
POST /oauth2/introspect
token=<exchange-token>

Response:
{
  "active": true,
  "sub": "user-123",
  "act": {
    "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorAgentRole"
  },
  "scope": "payments:initiate"
}
```

Payment API decision:
```
✅ active=true → Token is valid and not revoked
✅ scope contains "payments:initiate" → Authorized for this operation
✅ sub=user-123 → Scope access to user-123's records
✅ act.sub=agent-role → Log this action as orchestrator
→ ALLOW payment
```

## Trust Federation: The Key Innovation

Without trust federation, the flow breaks:

```
❌ BROKEN (no federation):
   Agent: "Here's an AWS OIDC token"
   IS 7.3: "How do I know AWS issued this? I don't have AWS JWKS"
   IS 7.3: "REJECT — I can't validate actor_token"

✅ WORKING (with federation):
   Agent: "Here's an AWS OIDC token"
   IS 7.3: (configured with AWS OIDC discovery URL)
   IS 7.3: GET https://oidc.eks.us-east-1.amazonaws.com/id/.../.well-known/openid-configuration
   IS 7.3: Caches JWKS from that endpoint
   IS 7.3: Validates token signature using AWS public key
   IS 7.3: ACCEPT — actor_token is valid
```

## Revocation Propagation Scenario

**Setup:**
- T0: User gets IS 7.3 token (1h TTL)
- T0: User passes token to orchestrator agent
- T0: Agent exchanges for 15-min token
- T0: Agent gets exchange token
- T5min: Agent calls payment API (still has valid exchange token)
- T10min: User revokes session in IS 7.3 Console

**What happens at T12min when agent calls payment API again?**

```
Agent: POST /payments/initiate with exchange token
PaymentAPI: Introspect token at IS 7.3

IS 7.3 processing:
  1. Lookup token by jti
  2. Check parent (subject_token) status
  3. Parent is REVOKED (user revoked)
  4. Return: active=false

PaymentAPI:
  Receive: active=false
  Decision: REJECT — Token is revoked
  Response: 401 Unauthorized
```

**Why is this important for banking?**

If user revokes their session after discovering fraud, the agent's token is **immediately invalid**. No grace period. Revocation propagates in near-real-time via introspection.

If the payment API used **local JWT validation** (no introspection), the token would remain valid for the full 15-minute TTL — violating compliance requirements.

## Actor Trust Policy: Design Decisions

**Configuration (in IS 7.3 Console, per-application):**

```json
{
  "version": "1",
  "allowedActors": [
    {
      "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorRole",
      "audiences": ["payments:initiate", "payments:check"],
      "canActFor": ["user-group:employees", "user-group:contractors"]
    },
    {
      "sub": "arn:aws:iam::123456789012:role/FraudCheckerToolRole",
      "audiences": ["fraud:read", "accounts:read"],
      "canActFor": ["user-group:internal"]
    }
  ]
}
```

**Scenario 1: Authorized agent**

```
Actor: PaymentOrchestratorRole
Actor trust policy check: ✅ In allowedActors list
User: user-123 in employees group
User check: ✅ In canActFor list
Result: ✅ ALLOW exchange
```

**Scenario 2: Unauthorized agent**

```
Actor: AdminProvisioningRole
Actor trust policy check: ❌ NOT in allowedActors list
Result: ❌ DENY exchange
Response: HTTP 400 {
  "error": "invalid_grant",
  "error_description": "actor_not_trusted_for_exchange"
}
```

**Scenario 3: Agent not allowed for this user group**

```
Actor: FraudCheckerToolRole
Actor trust policy check: ✅ In allowedActors list
User: user-123 in contractors group
User check: ❌ NOT in canActFor list
Result: ❌ DENY exchange
Response: HTTP 400 {
  "error": "invalid_grant",
  "error_description": "actor_not_authorized_for_subject"
}
```

## Scope Narrowing Verification

**Setup:**
- Subject token: `scope=accounts:read payments:read payments:write`
- Exchange request: `scope=payments:write`

**IS 7.3 validation:**
```
Check: Is requested scope a subset of subject_token scope?
  payments:write ⊆ {accounts:read, payments:read, payments:write}?
  ✅ Yes

Issue exchange token with:
  scope=payments:write (narrowed)
```

**Attempt to exceed scope:**
- Subject token: `scope=payments:read` (read-only)
- Exchange request: `scope=payments:write` (write)

**IS 7.3 validation:**
```
Check: Is requested scope a subset of subject_token scope?
  payments:write ⊆ {payments:read}?
  ❌ No

Response: HTTP 400 {
  "error": "invalid_scope",
  "error_description": "requested_scope_exceeds_subject_scope"
}
```

## Assessment: Answer Key

**Q1: Why must IS 7.3 validate the `aud` claim?**

A: The `aud` claim identifies who the token is intended for. If an OIDC token has `aud=https://attacker-service.com`, it was issued for the attacker's service, not IS 7.3. Using it as an `actor_token` would violate token semantics and enable token-reuse attacks. IS 7.3 must verify `aud=https://is.bank.com:9443/oauth2/token` (its own token endpoint).

**Q2: What happens if actor trust policy is not configured?**

A: Without an actor trust policy, IS 7.3 allows ANY agent to exchange ANY user's token. This violates the principle of least privilege. A compromised low-privilege agent or even a debug script on an EC2 instance could escalate by exchanging a privileged user's token.

**Q3: Why 15-min vs 1-hour token lifetimes?**

A: User token (1h) represents the user's session duration. Orchestrator token (15min) is shorter for two reasons:
- If orchestrator is compromised, blast radius is limited to 15 minutes
- User's revocation propagates via introspection within the cache TTL (~5min)
- Tool tokens (5min) are even shorter (single operation)

**Q4: How does introspection validate the delegation chain?**

A: IS 7.3 introspection checks:
1. Token `jti` exists and is not revoked
2. Token's parent (subject_token) is active
3. User's consent for this agent is not revoked
4. Token's `exp` has not passed

If any check fails, `active=false` is returned.

**Q5: Revocation scenario design**

A: User revokes → IS 7.3 marks user's consent as WITHDRAWN → Introspection checks parent status → Returns `active=false` → API rejects token. This works because APIs use introspection (not local JWT validation). If they used local validation, revocation would not be seen until the token's own TTL expires.

## Files to Review

- `config/agentcore_obo_token_exchange.http` — Complete HTTP trace of the 8-step flow
- `diagram.md` — Visual representation of each step and trust federation validation
- Day 25 content: `content/day25.md` — Full technical deep-dive on AgentCore + OBO
