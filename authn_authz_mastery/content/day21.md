# Day 21 — Agent Identity Fundamentals

## Why this matters

A bank deploys an AI agent to process customer requests using `client_credentials` grant — the agent gets a service account token with no user context. A prompt injection attack tricks the agent into initiating an unauthorized transfer. The security team asks: "Which user authorized this? Which agent made the call?" They can't answer — every API call in the audit log shows only the service account. The bank cannot demonstrate regulatory compliance for the transaction.

## Core concepts

### 1. What makes agent auth different from human auth

A user authenticates once and acts directly; an agent acts on behalf of a user through an unattended delegation chain. Each hop in the chain (user → orchestrator → tool → API) needs a distinct, verifiable identity recorded in the token. 

- Human auth: proof of identity → scoped token
- Agent auth: proof of identity + proof of delegation chain → scoped token with `act` lineage

### 2. Principal hierarchy

The delegation chain defines four distinct principals:

- **User:** the human who initiated the session; identified by `sub` claim throughout the chain
- **Orchestrator agent:** the AI agent that receives the user's intent and decomposes it into tool calls
- **Tool agent:** a specialized sub-agent that executes one capability (e.g., "read account balance")
- **Backend API:** the resource server; validates the full delegation chain

### 3. Delegation chain vs. impersonation

- **Impersonation:** agent uses the user's token directly → agent inherits user's full scope, no agent identity in audit log, confused deputy risk
- **Delegation (RFC 8693 OBO):** agent exchanges user token for a narrowed token with `act` claim → audit trail shows user + agent at each hop, scope is minimized
- Key difference: delegation creates a verifiable chain; impersonation erases it

### 4. Confused deputy problem

An agent authorized to act for User A can be tricked via prompt injection into requesting resources for User B using its delegated authority. Prevention:
- The `sub` claim must always be the original user
- The `act` claim must identify the specific agent instance
- Scope narrowing limits blast radius

### 5. Audit trail requirements

Banking regulatory requirement: every API call must be traceable to:

- `sub`: original user (preserved at every hop)
- `act`: acting agent — `{"sub": "<agent_client_id>"}`, nesting grows at each hop
- `azp`: authorized party (the OAuth2 client that received the token)
- `jti`: unique token ID for trace correlation
- **Compliance** implies ability to answer: (a) the human user who authorized the session, (b) the agent(s) that made the call, (c) the scope of authority at each hop

### 6. Token lifetime strategy

Each hop's token should expire before the parent token could become stale:

- Human token: 1h (user session duration)
- Orchestrator exchange token: 15min (short-lived delegation; if stolen, expires quickly)
- Tool token: 5min (per-operation; minimal blast radius)
- Rationale: revoke the human token to cascade invalidation via introspection within the cache TTL (≤5min)

## WSO2 IS 7.3 / AgentCore mapping

### IS 7.3 principal hierarchy config

Enable token exchange grant (required for OBO) in `deployment.toml`:

```toml
[oauth]
allowed_grant_types = ["authorization_code", "refresh_token", "urn:ietf:params:oauth:grant-type:token-exchange"]
```

Per-application in Console:
- Grant types: include `urn:ietf:params:oauth:grant-type:token-exchange`
- Actor trust: specify which client_ids (agent_ids) can exchange for which subjects

### AgentCore per-agent IAM role pattern

```json
{
  "AgentRoleConfig": {
    "orchestratorRole": "arn:aws:iam::<PLACEHOLDER: account-id>:role/BankingOrchestratorRole",
    "toolRole": "arn:aws:iam::<PLACEHOLDER: account-id>:role/BankingToolRole",
    "sessionTags": {
      "agentId": "<runtime-provided>",
      "userId": "<runtime-provided from user session>",
      "sessionId": "<runtime-provided>"
    }
  }
}
```

## Anti-patterns

1. **`client_credentials` for agent identity** — issues a token with `sub`=client_id, no user context, no delegation chain; breaks regulatory auditability for any user-initiated action

2. **Passing the user's access token directly to the agent (impersonation)** — the agent inherits the user's full scope and appears as the user in all audit logs; a compromised agent becomes a full proxy for the user

3. **Sharing a single IAM role or OAuth2 client across multiple agent instances** — if one instance is compromised, all instances are compromised; no way to revoke individual agent authority

## Exercises

**Exercise 1:** A bank's AI agent uses `client_credentials` to call the payment API. An auditor asks "which user authorized transaction TX-001?" Can they answer? Why or why not?

**Hint:** `client_credentials` tokens have no user identity — only the service account (`sub`=client_id).

**Solution sketch:** No. `client_credentials` issues a token where `sub`=client_id. The payment API audit log records only the service account as the initiator. There is no record of which user authorized the session. To fix: use RFC 8693 token exchange — the agent exchanges the user's IS 7.3 token for a delegated token with `sub`=user + `act`=agent_id. The payment API then records both.

---

**Exercise 2:** An orchestrator agent passes the user's raw IS 7.3 access token to a tool agent to make an API call. What is the security risk and how does delegation (OBO) solve it?

**Hint:** what scope and identity does the tool agent inherit?

**Solution sketch:** The tool agent inherits the user's full scope — it can do anything the user can, not just the specific tool action. If the tool agent is compromised or prompt-injected, the attacker has full user access. With OBO (RFC 8693), the orchestrator exchanges the user token for a tool-specific token: `scope=accounts:read` (narrowed), `sub`=user (preserved), `act.sub`=tool_agent_id (recorded). The tool's blast radius is now limited to `accounts:read`.

---

**Exercise 3:** Design a token lifetime strategy for a 3-hop chain: user → orchestrator → tool → payment API. Justify each lifetime.

**Hint:** each hop's token should expire before the parent token could be used to re-exchange.

**Solution sketch:** Human token=1h (session duration); orchestrator exchange=15min (if orchestrator is compromised, stolen token is useless in 15min); tool token=5min (single-operation; minimal window for replay). Introspection-based APIs will detect revocation within their introspection cache TTL (recommend ≤5min cache). If the user revokes: next introspection call returns `active:false` for all derived tokens, effectively propagating revocation within the cache window.

## Lab

See `labs/day21/README.md` — design a principal hierarchy for a banking AI agent with correct token claims at each hop.
