# Day 25 — AgentCore + OBO Patterns

## Why this matters

An AI agent (deployed via AgentCore) needs to call a WSO2-protected payment API on behalf of a user. AgentCore provides IAM credentials; WSO2 IS 7.3 requires an OAuth2 access token. Without the AgentCore ↔ IS 7.3 trust bridge, the agent either: (a) uses a static service account (no user context), or (b) cannot call WSO2 APIs at all. The bridge is RFC 8693 token exchange + AWS–IS 7.3 identity federation — unifying IAM and OAuth2 identity within a single delegation chain.

## Core concepts

### Trust federation: IS 7.3 registers AWS OIDC as external IdP

IS 7.3 must trust tokens issued by AgentCore's OIDC provider to accept them as `actor_token` values in token exchange requests. This is accomplished by:

1. **AWS OIDC provider endpoint** — AgentCore uses AWS STS or IAM Identity Center's OIDC endpoint to issue identity tokens to agents.
2. **IS 7.3 external IdP configuration** — IS 7.3 is told: "Trust tokens from this OIDC provider; fetch the JWKS from this discovery URL."
3. **JWKS validation** — When IS 7.3 receives a token exchange request with an `actor_token`, it fetches the JWKS from the registered discovery URL and validates the token's signature.

Without this federation setup, IS 7.3 has no way to verify that the `actor_token` is legitimate — it would reject the exchange.

### Full 8-step AgentCore → IS 7.3 → WSO2 API flow

This is the complete flow that binds AgentCore's IAM identity to IS 7.3's OAuth2 token exchange:

1. **User authenticates to IS 7.3** — via App-Native Auth (Day 11) or browser-based OIDC. IS 7.3 issues a user access token with scope `payments:initiate`. Token has `sub=user-123`.

2. **User token passed to AgentCore session context** — out-of-band, via app-level mechanism (e.g., user passes it to AgentCore via a secure API call or session context API, NOT via environment variable or logs).

3. **AgentCore agent assumes IAM role via STS** — AgentCore calls `sts:AssumeRole` with the agent's target role and session tags. STS vends temporary IAM credentials.

4. **Agent obtains OIDC identity token** — Using the IAM credentials, the agent fetches an OIDC identity token from AWS STS or IAM Identity Center OIDC endpoint. This token identifies the agent to external systems. It has `sub=<agent-identity>`, `aud=<oidc-endpoint>`, and is signed by AWS's private key.

5. **Agent calls IS 7.3 token exchange** — POST to `/oauth2/token` with:
   - `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`
   - `subject_token=<user-access-token>` — the user's IS 7.3 token
   - `actor_token=<oidc-identity-token>` — the AgentCore agent's AWS-signed OIDC token
   - `client_assertion_type` + `client_assertion` — agent's `private_key_jwt` credentials (Day 22)

6. **IS 7.3 validates `actor_token` against federated AWS OIDC IdP** — IS 7.3 looks up the registered AWS OIDC provider, fetches its JWKS, and validates the signature on the `actor_token`. Checks:
   - Token signature is valid (matches a public key in the JWKS)
   - `aud` claim matches the expected value (configured in IS 7.3)
   - `exp` has not passed
   - `sub` matches a configured actor trust policy (configured per-application in IS 7.3 Console)

7. **IS 7.3 issues exchange token** — If all checks pass, IS 7.3 issues a new access token:
   - `sub=user-123` — preserved from subject_token
   - `act.sub=agent-orchestrator-id` — the agent's identity from the actor_token
   - `scope=payments:initiate` — narrowed to what the agent requested
   - `aud=payment-api` — the target API
   - `exp=now+900` — typically 15 minutes for agent tokens

8. **Agent calls payment API with exchange token** — The agent includes `Authorization: Bearer <exchange-token>` in the request to the payment API. The API introspects the token at IS 7.3 to confirm `active:true`, `sub`, `act.sub`, and `scope`.

### IS 7.3 external IdP config for AWS OIDC

To register AWS as an external IdP in IS 7.3, configure:

**Identity Provider Type:** `OpenID Connect`

**Discovery URL:** One of:
- EKS OIDC: `https://oidc.eks.<region>.amazonaws.com/id/<cluster-id>/.well-known/openid-configuration`
- IAM Identity Center: `https://oidc.eks.<region>.amazonaws.com/id/<account-id>-<org-id>/.well-known/openid-configuration`

This tells IS 7.3 where to fetch the JWKS and token validation metadata. The discovery document includes:
- `jwks_uri` — where to fetch the public keys
- `issuer` — the issuer claim that must match tokens from this provider
- `token_endpoint`, `authorization_endpoint` — (not used by IS 7.3 for actor validation, but present for standards compliance)

### `aud` claim validation

The `aud` claim in the OIDC token must match what IS 7.3 expects. Configure this in IS 7.3 as part of the external IdP setup:

```toml
[oauth]
actor_audience = "https://is.bank.com:9443/oauth2/token"
```

If the agent's OIDC token has `aud=https://payment-api.com`, the `aud` mismatch will cause IS 7.3 to reject the token exchange with `invalid_request: actor audience mismatch`.

### Actor trust policy

IS 7.3 can enforce which agents (identified by `sub` in the actor_token) are allowed to exchange tokens. Configure per-application in IS 7.3 Console under Application → OAuth → Advanced → Actor Trust Policy:

```json
{
  "version": "1",
  "allowedActors": [
    {
      "sub": "arn:aws:iam::<account>:role/PaymentOrchestratorRole",
      "audiences": ["payments:initiate"]
    },
    {
      "sub": "arn:aws:iam::<account>:role/FraudCheckerToolRole",
      "audiences": ["fraud:read"]
    }
  ]
}
```

Without an actor trust policy, IS 7.3 allows any authenticated actor to exchange any user token — creating a confused deputy risk.

## WSO2 IS 7.3 / AgentCore mapping

### IS 7.3 external IdP registration (annotated TOML)

```toml
# deployment.toml — register AWS OIDC as external IdP
[identity.provider.AWSOIDC]
type = "OpenIDConnect"
enabled = true

# Discovery URL — tells IS 7.3 where to fetch JWKS and token metadata
discovery_url = "https://oidc.eks.<PLACEHOLDER: region>.amazonaws.com/id/<PLACEHOLDER: cluster-id>/.well-known/openid-configuration"

# Client ID and secret (if needed for token endpoint communication)
# For actor_token validation, these are typically not needed
client_id = "<PLACEHOLDER: aws-oidc-client-id>"
client_secret = "<PLACEHOLDER: aws-oidc-client-secret>"

# Expected issuer — must match the iss claim in tokens from AWS OIDC
issuer = "https://oidc.eks.<PLACEHOLDER: region>.amazonaws.com/id/<PLACEHOLDER: cluster-id>"

# Audience claim validation — tokens from AWS OIDC must have this aud
audience = "https://is.bank.com:9443/oauth2/token"

# Token exchange configuration
[oauth.token_exchange]
enabled = true
allow_refresh_token_grant = true

# Per-application actor trust policy (set in Console)
# Example in deployment.toml (though Console is the primary config interface):
# [oauth.applications.BankingAgentApp]
# actor_trust_policy = {
#   "version": "1",
#   "allowedActors": [
#     {"sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorRole"}
#   ]
# }
```

### Token exchange request with AgentCore OIDC

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded
Host: is.bank.com:9443

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<PLACEHOLDER: user-access-token>
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&actor_token=<PLACEHOLDER: agentcore-oidc-token>
&actor_token_type=urn:ietf:params:oauth:token-type:jwt
&scope=payments:initiate
&requested_token_type=urn:ietf:params:oauth:token-type:access_token
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: agent-client-assertion>
```

The `subject_token` is the user's IS 7.3 access token (obtained via App-Native Auth or browser login). The `actor_token` is the AgentCore agent's OIDC token signed by AWS.

### Exchange result with `act.sub`

```json
{
  "access_token": "<PLACEHOLDER: exchange-token>",
  "token_type": "Bearer",
  "expires_in": 900,
  "scope": "payments:initiate"
}
```

**Decoded JWT payload:**
```json
{
  "iss": "https://is.bank.com:9443/oauth2/token",
  "sub": "user-123",
  "act": {
    "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorRole"
  },
  "aud": "payment-api",
  "scope": "payments:initiate",
  "exp": "<PLACEHOLDER: now+900>",
  "jti": "<PLACEHOLDER: UUIDv4>"
}
```

Key claims:
- `sub` — the original user (preserved)
- `act.sub` — the agent's identity from the OIDC token
- `scope` — narrowed to `payments:initiate`
- `exp` — 15 minutes from issuance

### Payment API introspection

The agent calls the payment API with the exchange token:

```http
POST /payments/initiate
Authorization: Bearer <PLACEHOLDER: exchange-token>
Content-Type: application/json

{
  "amount": 100,
  "currency": "USD"
}
```

The payment API introspects to validate the token:

```http
POST /oauth2/introspect
Content-Type: application/x-www-form-urlencoded

token=<PLACEHOLDER: exchange-token>
&token_type_hint=access_token
```

**IS 7.3 introspection response:**
```json
{
  "active": true,
  "scope": "payments:initiate",
  "client_id": "<PLACEHOLDER: agent-client-id>",
  "username": "user-123",
  "sub": "user-123",
  "act": {
    "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorRole"
  },
  "aud": "payment-api",
  "iss": "https://is.bank.com:9443/oauth2/token",
  "exp": "<PLACEHOLDER: timestamp>",
  "iat": "<PLACEHOLDER: timestamp>",
  "jti": "<PLACEHOLDER: UUIDv4>"
}
```

The payment API can now verify:
- `active=true` — token is valid
- `sub=user-123` — payment is on behalf of the user
- `act.sub` — the agent that initiated this
- `scope=payments:initiate` — agent has permission to initiate
- `aud=payment-api` — token was issued for this API

## Anti-patterns

### 1. Passing user token via environment variable

**Problem:** The token appears in CloudTrail logs, container logs, environment dumps, and could be exfiltrated by prompt injection.

**Anti-pattern:**
```bash
# DO NOT DO THIS
export IS73_USER_TOKEN="eyJ..."  # In pod environment
export AGENT_CONTEXT='{"user_token": "eyJ..."}'  # In logs
```

**Fix:** Use a secure context passing mechanism:
- AWS Secrets Manager session (agent reads from Secrets Manager at runtime)
- AgentCore context API (agent requests the user token via authenticated API call)
- Session store (user token stored in transient session store, agent retrieves via session ID)

Never store tokens in environment variables or pod startup scripts.

### 2. Not validating the `aud` claim in actor_token

**Problem:** Without `aud` validation, a token issued for a different IS 7.3 tenant or service can be used as an `actor_token`.

**Scenario:** An attacker controls a different SaaS system that also uses AWS OIDC. The attacker tricks an agent to exchange a bank user's token using the attacker's OIDC token. The `actor_token` has `aud=https://attacker-saas.com` instead of the bank's IS 7.3 token endpoint.

Without `aud` validation in IS 7.3, this attack succeeds — IS 7.3 would issue a token for the attacker's purposes.

**Fix:** Configure IS 7.3 to validate `aud`:
```toml
[identity.provider.AWSOIDC]
audience = "https://is.bank.com:9443/oauth2/token"
```

IS 7.3 will reject tokens with `aud` that doesn't match this value.

### 3. Trusting all AWS OIDC tokens without actor trust policy

**Problem:** Without an actor trust policy, any AWS workload that can mint an OIDC token from the configured AWS OIDC IdP can exchange any user's IS 7.3 token.

**Scenario:** A junior engineer deploys a debug script on an EC2 instance. The script can assume an IAM role and get an OIDC token. It then exchanges a privileged admin user's IS 7.3 token without authorization.

**Fix:** Configure an actor trust policy in IS 7.3 per-application to restrict exchanges:

```toml
# Per-application in Console:
# Application → OAuth → Advanced → Actor Trust Policy
actor_trust_policy = {
  "version": "1",
  "allowedActors": [
    {
      "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorRole"
    },
    {
      "sub": "arn:aws:iam::123456789012:role/FraudCheckerToolRole"
    }
  ]
}
```

Only agents with these exact IAM role ARNs can exchange tokens. Any other agent is denied.

## Exercises

### Exercise 1: Trust federation setup

**Hint:** Think about which system validates which token.

**Question:** IS 7.3 receives an RFC 8693 token exchange request with an `actor_token` from AgentCore. Describe the trust federation chain that allows IS 7.3 to accept this token.

**Solution sketch:**

1. IS 7.3 is configured with the AWS OIDC provider's discovery URL.
2. IS 7.3 fetches the JWKS from the discovery URL (cached).
3. The `actor_token` is a JWT signed by AWS.
4. IS 7.3 looks up the key in the JWKS that matches the `kid` in the token header.
5. IS 7.3 verifies the signature using the public key.
6. IS 7.3 checks that `aud` matches the configured audience.
7. IS 7.3 checks that `sub` (the agent's role ARN) matches the actor trust policy.
8. If all checks pass, IS 7.3 trusts the actor's identity and issues an exchange token.

The chain is: AWS issues OIDC token → Agent sends to IS 7.3 → IS 7.3 validates against AWS JWKS → IS 7.3 trusts the agent.

### Exercise 2: `aud` claim validation

**Hint:** Think about reusing tokens across different systems.

**Question:** An `actor_token` is issued with `aud=https://attacker-saas.com`. IS 7.3 is configured with `audience=https://is.bank.com:9443/oauth2/token`. Should IS 7.3 accept this token in a token exchange request? Why or why not?

**Solution sketch:**

No. IS 7.3 must reject this token. The `aud` mismatch indicates the token was issued for a different system. Accepting it would violate the "audience restriction" principle — the token was not intended for IS 7.3's token endpoint.

This prevents token reuse attacks. An attacker could trick an agent to exchange a user's token using a token issued for a different service, potentially gaining unauthorized access to that service.

IS 7.3 returns `invalid_request: actor_audience_mismatch`.

### Exercise 3: Actor trust policy enforcement

**Hint:** Consider which agents are allowed to exchange tokens on behalf of which users.

**Question:** A bank deploys three agent types: `PaymentOrchestratorRole`, `FraudCheckerToolRole`, and `AdminProvisioningRole`. The admin provisioning agent should NOT be allowed to exchange user tokens (it only provisions new agents). Write an actor trust policy that permits only the first two agents.

**Solution sketch:**

```json
{
  "version": "1",
  "allowedActors": [
    {
      "sub": "arn:aws:iam::123456789012:role/PaymentOrchestratorRole",
      "audiences": ["payments:initiate", "payments:check"]
    },
    {
      "sub": "arn:aws:iam::123456789012:role/FraudCheckerToolRole",
      "audiences": ["fraud:read", "accounts:read"]
    }
  ]
}
```

The `AdminProvisioningRole` is not listed. If it attempts to exchange a user token, IS 7.3 returns `invalid_grant: actor not trusted for this operation`.

## Lab

See `labs/day25/README.md` — trace a complete AgentCore → IS 7.3 → payment API flow. Success signal: understand the 8-step flow and how AWS OIDC federation bridges AgentCore's IAM identity with IS 7.3's OAuth2 token exchange.
