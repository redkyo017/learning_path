# Day 27 Lab — WSO2 IS 7.3 as Agent IdP

## Objective

Configure IS 7.3's token exchange grant and agent policy enforcement to make AI agents first-class principals under the bank's identity governance. Success signal: you can explain how agent tokens are revoked when a user revokes their session, and you can design an actor trust policy that prevents privilege escalation.

## Scenario

A bank has deployed two agents: `payment_orchestrator` (orchestrates payment workflows) and `risk_scorer` (evaluates transaction risk). Both agents were registered as OAuth2 clients, but the security team has not yet configured agent policy enforcement.

**Current state:**
- `payment_orchestrator` client_id: `"payment_orchestrator"` (registered via DCR)
- `risk_scorer` client_id: `"risk_scorer"` (registered via DCR)
- User groups: `group:financial-users` (regular customers), `group:admins` (bank staff)
- Token exchange grant is enabled globally in IS 7.3

**Problem:** Any authenticated agent can exchange any user token. A compromised `risk_scorer` (which should have limited scope) can escalate by exchanging an admin's token.

## What you'll produce

1. **IS 7.3 `deployment.toml` additions** showing:
   - Global token exchange grant enablement
   - Token exchange actor trust configuration
   - Structured audit logging for agent call tracing

2. **Agent DCR registration requests** (form body, `private_key_jwt` auth):
   - `payment_orchestrator` registration
   - `risk_scorer` registration

3. **Actor trust policy definitions** (JSON):
   - Policy allowing `payment_orchestrator` to exchange for `group:financial-users`
   - Policy denying `risk_scorer` (initially) then allowing after security review
   - Policy blocking any agent from exchanging for `group:admins`

4. **Audit query example**:
   - Query IS 7.3 audit log to find all calls by `risk_scorer` agent on behalf of user `alice_001` in the past 24 hours

## Steps

### Step 1: Review the scenario

The bank's compliance requirement: agent tokens must be revocable at the user level (when user revokes, all derived agent tokens are revoked). Also, not all agents should be permitted to act for all users.

### Step 2: Study deployment.toml requirements

Open `config/agent_idp_deployment.toml`. This file shows what IS 7.3 sections need to be added or modified to support agent IdP functionality.

### Step 3: Design agent DCR requests

Write complete DCR requests for both agents. Each agent uses `private_key_jwt` client auth (Day 22). Remember:
- `token_assertion_type` and `client_assertion` are POST body parameters
- Assertion JWT must have `iss`, `sub`, `aud`, `jti`, `exp` claims
- No `Authorization: Bearer` header

### Step 4: Define actor trust policies

Specify which agents can exchange for which user groups. The bank's requirement: `payment_orchestrator` is approved for `group:financial-users`; `risk_scorer` is not yet approved (policy explicitly denies it or leaves it unspecified).

### Step 5: Check your work

- Does `deployment.toml` enable token exchange grant globally?
- Are DCR requests correctly formatted (form body, no Bearer auth)?
- Do actor trust policies restrict agents by user group (not just by agent)?
- Can you explain how revocation propagates when a user revokes their session?

## Success Criteria

- `deployment.toml` additions are syntactically correct TOML
- DCR requests are complete with all required JWT claims
- Actor trust policies restrict agents appropriately (at least 2 policies for demonstration)
- You can explain the audit log query pattern for agent call tracing
- You can describe the revocation chain: user revokes → IS 7.3 marks token → next introspection returns `active: false` → all derived tokens are rejected

## Time estimate

45–60 minutes

## Key concepts (reference Day 27 content)

- **Token exchange grant** — RFC 8693; must be enabled both globally and per-application
- **Agent client registration** — DCR with `private_key_jwt` auth; IS 7.3 assigns `client_id`
- **Actor trust policy** — restricts which agents can exchange for which user groups
- **Scope mapping** — distinguish agent scopes from user scopes (e.g., `agent:payments:initiate`)
- **Audit tagging** — IS 7.3 audit log must record `sub`, `act.sub`, `scope`, `jti` for agent call tracing
