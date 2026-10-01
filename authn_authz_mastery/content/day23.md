# Day 23 — OBO — On-Behalf-Of (RFC 8693)

## Why this matters

A bank deploys an AI orchestrator that processes payment requests. The orchestrator calls a risk scoring service, which calls the payment initiation service. Each service must verify: "User X authorized this payment, routed through Agent Y." Without a proper delegation mechanism, teams pass the user's raw token through the chain (impersonation — full scope) or use `client_credentials` at each service (no user context). In a PSD2 compliance audit, the bank cannot prove that the specific user consented to the specific payment — every call looks like a service account action.

## Core concepts

### 1. RFC 8693 token exchange — the master pattern

The token exchange request includes:

- `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`
- `subject_token`: the token whose identity is being delegated (user's access token)
- `subject_token_type=urn:ietf:params:oauth:token-type:access_token`
- `actor_token`: the token identifying the agent requesting the delegation
- `actor_token_type=urn:ietf:params:oauth:token-type:jwt`
- `scope`: the scope requested for the result token — MUST be a subset of `subject_token`'s scope
- `requested_token_type=urn:ietf:params:oauth:token-type:access_token`

### 2. Result token structure

The exchanged token carries:

- `sub`: original user's subject claim — **preserved unchanged**
- `act`: `{"sub": "<agent_client_id>"}` — the acting agent; added by IS 7.3 at exchange time
- `scope`: narrowed to what the agent requested (MUST NOT exceed subject_token scope)
- `exp`: independently set by IS 7.3 (typically shorter than the subject_token — recommended 15min for orchestrator exchange)
- `jti`: new unique ID for this token (trace correlation)

### 3. Multi-hop delegation (`act` claim nesting)

The `act` claim nests at each hop:

- Orchestrator exchanges user token → result: `act = {"sub": "orchestrator_id"}`
- Tool agent exchanges orchestrator token → result: `act = {"sub": "tool_id", "act": {"sub": "orchestrator_id"}}`
- Each hop prepends the current actor; the innermost `act` is the most recent agent
- Resource server reads the outermost `act.sub` to know the immediate caller; traverses `act.act` for the full chain
- Recommended max depth: 3 hops (user → orchestrator → tool → API)

### 4. `may_act` claim

Placed in the `subject_token` or exchange result by IS 7.3 to pre-authorize specific agents for further exchanges:

- Structure: `{"sub": "<pre-authorized_agent_client_id>"}`
- Use case: IS 7.3 sets `may_act` in the orchestrator token to pre-authorize a known tool agent; downstream exchanges don't need to re-validate the full chain
- Without `may_act`: IS 7.3 must re-verify the full chain on each downstream exchange — may fail if the subject_token has expired

### 5. IS 7.3 token exchange grant configuration

Enable in Console:
- Application → OAuth / OpenID Connect → Allowed Grant Types → check `token-exchange`

Configure in `deployment.toml`:
```toml
[oauth.token_exchange]
allow_refresh_token_grant = true
# Per-app actor trust configured in Console or via DCR grant_types
```

DCR: `"grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"]`

### 6. Scope narrowing constraint

IS 7.3 **will NOT** issue an exchange token with scope exceeding the `subject_token`'s scope:
- If agent requests `scope=payments:write` but subject_token has `scope=payments:read`, IS 7.3 returns `invalid_scope`
- Design implication: the user must have been issued a token with the maximum scope needed by the entire agent chain

### 7. Revocation propagation

Revoking the human token (subject_token) propagates through the chain **IF** the API uses token introspection:
- IS 7.3 checks the exchange chain on introspection; a revoked parent token causes `active: false` for all derived tokens
- APIs using local JWT validation will NOT see the revocation until the derived token expires
- **Banking compliance requirement**: APIs in the delegation chain MUST use introspection (not local JWT validation) to honour user revocation within token lifetime

## WSO2 IS 7.3 / AgentCore mapping

### First-hop exchange (user → orchestrator)

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<PLACEHOLDER: user-access-token>
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&actor_token=<PLACEHOLDER: orchestrator-jwt>
&actor_token_type=urn:ietf:params:oauth:token-type:jwt
&scope=payments:initiate
&requested_token_type=urn:ietf:params:oauth:token-type:access_token
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: orchestrator-client-assertion>
```

Result token payload (decoded):

```json
{
  "sub": "<user-subject>",
  "act": {"sub": "orchestrator_client_id"},
  "scope": "payments:initiate",
  "iss": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "aud": "payment-api",
  "exp": "<PLACEHOLDER: now+900>",
  "jti": "<PLACEHOLDER: UUIDv4>"
}
```

### Second-hop exchange (orchestrator → tool)

```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&subject_token=<PLACEHOLDER: orchestrator-exchange-token>
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&actor_token=<PLACEHOLDER: tool-jwt>
&actor_token_type=urn:ietf:params:oauth:token-type:jwt
&scope=payments:initiate
&requested_token_type=urn:ietf:params:oauth:token-type:access_token
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: tool-client-assertion>
```

Result token payload (decoded, 2-hop):

```json
{
  "sub": "<user-subject>",
  "act": {
    "sub": "tool_client_id",
    "act": {"sub": "orchestrator_client_id"}
  },
  "scope": "payments:initiate",
  "exp": "<PLACEHOLDER: now+300>",
  "jti": "<PLACEHOLDER: UUIDv4>"
}
```

### AgentCore mapping

AgentCore uses RFC 8693 internally when a Bedrock agent needs to call a WSO2-protected API:
- The `subject_token` is the user's IS 7.3 access token (obtained via federated login)
- The `actor_token` is AgentCore's STS-vended OIDC token
- IS 7.3 validates the `actor_token` against the registered AWS OIDC provider (configured as external IdP)
- Day 25 covers this federation in detail

## Anti-patterns

1. **Omitting `actor_token` from the exchange request** — IS 7.3 may allow the exchange but issues a token with no `act` claim. The API cannot identify which agent made the call. Breaking for banking audit compliance.

2. **Requesting the same scope as the `subject_token` without narrowing** — the token exchange succeeds but violates least privilege. If the user has `scope=accounts:read payments:write`, a tool that only reads accounts should request `scope=accounts:read` only.

3. **Not configuring the actor trust policy in IS 7.3** — without an explicit trust policy, IS 7.3 allows any authenticated client to exchange any user token for any agent. In a banking deployment, only known, registered agent client_ids should be permitted to exchange on behalf of users.

## Exercises

**Exercise 1:** Write the complete token exchange request for an orchestrator agent to get a delegated token from IS 7.3, starting with a user's access token.

**Hint:** `grant_type`, `subject_token`, `subject_token_type`, `actor_token`, `actor_token_type`, and `scope` are all required POST body parameters.

**Solution sketch:** `POST /oauth2/token`, form body: `grant_type=urn:ietf:params:oauth:grant-type:token-exchange&subject_token=<user_token>&subject_token_type=urn:ietf:params:oauth:token-type:access_token&actor_token=<orchestrator_jwt>&actor_token_type=urn:ietf:params:oauth:token-type:jwt&scope=payments:initiate&requested_token_type=urn:ietf:params:oauth:token-type:access_token`. Add `client_assertion_type` + `client_assertion` if the orchestrator uses `private_key_jwt` client auth (recommended). Result token has `sub`=user, `act.sub`=orchestrator_client_id, `scope`=payments:initiate.

---

**Exercise 2:** An orchestrator exchanges a user token for a delegated token. The tool agent then uses this orchestrator-scoped token directly to call the backend API (no further exchange). What is missing from the audit trail?

**Hint:** which principal in the chain is not recorded in the token?

**Solution sketch:** The tool agent's identity is not recorded — the API sees `act.sub`=orchestrator_id and assumes the orchestrator made the call. If the tool agent is compromised, all of its calls appear as orchestrator calls in the audit log. Fix: the tool agent must also exchange for its own delegated token, adding `act.act` nesting. The payment API then sees: `sub`=user, `act.sub`=tool_id, `act.act.sub`=orchestrator_id — the full chain is verifiable.

---

**Exercise 3:** A user's access token expires after 1h. An orchestrator exchanged it 50 minutes ago and got a 15-minute agent token. At T+60min, the user calls `POST /oauth2/revoke` to revoke their session. The agent token is 5 minutes old (valid for 10 more minutes). Will the payment API reject the next request?

**Hint:** the answer depends on whether the API uses token introspection or local JWT validation.

**Solution sketch:** If the API introspects: IS 7.3 checks the exchange chain — the revoked parent token causes IS 7.3 to return `active: false` for the agent token. Next API call rejected. If the API validates JWTs locally: the agent token is still cryptographically valid (not expired) — the API does NOT see the revocation until the agent token's own `exp`. Banking compliance mandates introspection for APIs in delegation chains.

## Lab

See `labs/day23/README.md` — trace a 2-hop OBO delegation chain through IS 7.3 with correct `act` nesting.
