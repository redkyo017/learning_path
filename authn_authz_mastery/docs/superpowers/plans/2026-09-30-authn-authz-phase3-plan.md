# AuthN/AuthZ Mastery Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author all 10 day files (Days 21–30) and lab artifacts for the AI Agent Identity + Capstone phase of the AuthN/AuthZ Mastery path.

**Architecture:** Five tasks — one scaffold task extending the directory skeleton for days 21–30, then four content-authoring tasks (Days 21–23, 24–26, 27–29, 30). Tasks 1–3 are independent and can be dispatched in parallel; Task 4 (Day 30 Capstone) depends on Days 21–29 existing. Every day file MUST include a `## WSO2 IS 7.3 / AgentCore mapping` section — the defining feature of Phase 3. RFC 8693 (OBO / token exchange) is the master pattern — Day 23 is the pivot; every subsequent day extends or applies it.

**Tech Stack:** Markdown (day content), Mermaid diagrams, TOML (IS 7.3 deployment.toml), HTTP annotated requests, Java (Day 22 uses JWT; no implementation — annotated examples only), AWS IAM JSON (Day 24)

**Spec:** `authn_authz_mastery/docs/superpowers/specs/2026-09-30-authn-authz-mastery-design.md`

## Global Constraints

- Never write real secrets, keys, tokens, certificates, or AWS account IDs — use `<PLACEHOLDER>` + fill-in comments only, so the repo stays commit-safe
- Never run `git status`, `git diff`, `git log`, `terraform apply`, or any cloud CLI command (in subagents)
- Every Phase 3 day file (21–30) MUST include `## WSO2 IS 7.3 / AgentCore mapping` section (Phase 3 section name includes AgentCore — different from Phase 2's `## WSO2 IS 7.3 mapping`)
- Every exercise must ship with **Hint:** and **Solution sketch:** — no bare problems
- Every lab (days 21–29) needs README.md + diagram.md (with Mermaid) + config/ file + SOLUTION.md
- Day 30 lab lives in `labs/capstone/` (not `labs/day30/`) — spec-defined structure
- `private_key_jwt` always form body params (`client_assertion_type` + `client_assertion` as POST body), NEVER `Authorization: Bearer <client_assertion>`
- No Phase 2 content re-explanation (assume IS 7.3 basics from Phase 2 known)
- No Phase 1 re-explanation (assume FAPI/PAR/RAR/CIBA/DPoP/mTLS mechanics from Phase 1 known)
- Days 21–28: agent identity focus; Day 29: synthesis; Day 30: capstone deliverable
- Anti-patterns: 3 per day, agent-identity-specific (not generic OAuth2 mistakes)

## Review Focus

1. **`act` claim chain integrity** — does each day that builds on OBO correctly show `sub` preserved + `act` growing (not replaced) at each hop?
2. **`private_key_jwt` form body** — Day 22 and any day showing `client_assertion` must use `client_assertion_type` + `client_assertion` in POST body, never `Authorization: Bearer <jwt>`
3. **AgentCore vs. `client_credentials`** — Day 21 contrast table must clearly show why `client_credentials` breaks agent auditability
4. **Scope narrowing on token exchange** — every RFC 8693 exchange example must show the exchanged token's scope as a strict subset of the subject_token scope
5. **Day 30 capstone completeness** — `labs/capstone/` must contain all 4 files: `architecture.md` (5 diagrams), `configs/` directory, `decision_tree.md`, `ADR.md`

---

### Task 0: Scaffold Phase 3

**Files:**
- Create dirs: `authn_authz_mastery/labs/day21/config/` through `labs/day29/config/`, `labs/capstone/configs/`
- Modify: `authn_authz_mastery/README.md` (add Phase 3 day index, update Phase Map Phase 3 status → 🔄 IN PROGRESS)
- Modify: `authn_authz_mastery/content/GLOSSARY.md` (append Phase 3 agent identity terms)
- Modify: `authn_authz_mastery/PROGRESS.md` (Phase 3 status → 🔄 IN PROGRESS, add session log entry)

**Interfaces:**
- Produces: directory skeleton that Tasks 1–3 write into

- [ ] **Step 1: Create lab directories**

```bash
mkdir -p authn_authz_mastery/labs/day21/config
mkdir -p authn_authz_mastery/labs/day22/config
mkdir -p authn_authz_mastery/labs/day23/config
mkdir -p authn_authz_mastery/labs/day24/config
mkdir -p authn_authz_mastery/labs/day25/config
mkdir -p authn_authz_mastery/labs/day26/config
mkdir -p authn_authz_mastery/labs/day27/config
mkdir -p authn_authz_mastery/labs/day28/config
mkdir -p authn_authz_mastery/labs/day29/config
mkdir -p authn_authz_mastery/labs/capstone/configs
```

- [ ] **Step 2: Update README.md**

Add Phase 3 section to the day index:

```markdown
### Phase 3 — AI Agent Identity + Capstone
- [Day 21](content/day21.md) — Agent Identity Fundamentals
- [Day 22](content/day22.md) — JWT Bearer Assertion (RFC 7523)
- [Day 23](content/day23.md) — OBO — On-Behalf-Of (RFC 8693)
- [Day 24](content/day24.md) — AWS AgentCore Gateway Architecture
- [Day 25](content/day25.md) — AgentCore + OBO Patterns
- [Day 26](content/day26.md) — MCP Service Authentication
- [Day 27](content/day27.md) — WSO2 IS 7.3 as Agent IdP
- [Day 28](content/day28.md) — End-to-End Delegation Chain
- [Day 29](content/day29.md) — Architecture Synthesis
- [Day 30 Capstone](labs/capstone/) — Capstone Architect Deliverable
```

Update Phase Map Phase 3 row: `⬜` → `🔄 IN PROGRESS`

- [ ] **Step 3: Append Phase 3 GLOSSARY terms**

Append a new section `## Phase 3 — AI Agent Identity Terms` to `content/GLOSSARY.md`:

```markdown
---

## Phase 3 — AI Agent Identity Terms

**Act claim (`act`)** — RFC 8693 JWT claim identifying the acting agent. Structure: `{"sub": "<agent_client_id>"}`. Multi-hop: `act` nests inside itself — `{"sub": "tool_id", "act": {"sub": "orchestrator_id"}}`. The `sub` claim remains the original user throughout; `act` chain grows at each delegation hop.

**Actor token (`actor_token`)** — In RFC 8693 token exchange, the token identifying the agent (acting party) requesting the exchange. Typically a JWT signed by the agent's private key. IS 7.3 validates this token to ensure the agent is authorized to exchange on behalf of the subject.

**AgentCore Gateway** — AWS service that acts as an identity-aware proxy for AI agents. Provides per-agent IAM roles, SigV4 request signing, and credential vending. Each agent gets a scoped IAM role with session tags (`agentId`, `userId`, `sessionId`) rather than a shared service account.

**Confused deputy problem** — Security vulnerability where a less-privileged agent is tricked (e.g., via prompt injection) into using its authority to act on behalf of a different principal than intended. Prevented by binding tokens to specific principals via `sub` + `act` claims and scope narrowing.

**Credential vending** — AgentCore's mechanism for issuing short-lived AWS credentials (via `sts:AssumeRole`) to AI agents on a per-request or per-session basis. Credentials carry session tags that trace back to the originating user and agent instance.

**Delegation chain** — The ordered sequence of principals in a multi-hop agent auth flow: User → Orchestrator Agent → Tool Agent → Backend API. Each hop adds an `act` nesting level; `sub` is preserved throughout as the original user's identity.

**IAM trust policy** — AWS IAM document controlling which principals can assume a role. For AgentCore agents: restricts assumption to specific AgentCore service principals and adds required condition keys (`aws:SourceArn`, session tag conditions).

**`may_act` claim** — RFC 8693 optional claim pre-authorizing specific agents to exchange the token on behalf of the subject in future hops. Structure: `{"sub": "<pre-authorized_agent_client_id>"}`. Enables IS 7.3 to skip re-validation of expired parent tokens in deep chains.

**MCP (Model Context Protocol)** — Anthropic's open protocol for AI agents to discover and call tools. MCP tools are OAuth2 resource servers; the MCP client authenticates via Authorization Code flow or token exchange. IS 7.3 can act as the OAuth2 AS for MCP tool authentication.

**OBO (On-Behalf-Of)** — Common shorthand for RFC 8693 token exchange when an agent exchanges a user's token for a delegated token. The resulting token carries the user's identity (`sub`) plus the agent's identity (`act`). Not to be confused with Microsoft's non-standard "OBO flow" — here OBO always means RFC 8693.

**Principal hierarchy** — The identity stack in an AI-augmented system: the set of principals (user, orchestrator, tool, API) and the authority relationships between them. Each principal must have a distinct verifiable identity; authority flows downward via token exchange.

**RFC 7523** — "JSON Web Token (JWT) Profile for OAuth 2.0 Client Authentication and Authorization Grants." Defines two uses: (1) `private_key_jwt` client authentication (section 2.2) and (2) JWT bearer grant for service-to-user delegation (section 2.1). IS 7.3 supports both.

**RFC 8693** — "OAuth 2.0 Token Exchange." Defines `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`. The master pattern for AI agent identity: exchanges a `subject_token` (user's token) for a narrowed `act`-scoped token. IS 7.3 supports this grant type in the application config.

**Scoped tool token** — A short-lived OAuth2 access token issued to an MCP tool with a scope limited to a single tool capability (e.g., `mcp:payments:read`). Prevents a compromised tool from accessing unrelated capabilities.

**SigV4** — AWS Signature Version 4. The signing algorithm used to authenticate HTTP requests to AWS services. AgentCore agents sign API requests with temporary IAM credentials using SigV4; the signature includes request body hash, timestamp, and service scope, preventing replay.

**Subject token (`subject_token`)** — In RFC 8693, the token representing the user whose identity is being delegated. Typically the user's IS 7.3 access token. The exchange produces a new token that preserves the subject token's `sub` claim and adds the agent's `act` claim.

**Token exchange grant** — Shorthand for `grant_type=urn:ietf:params:oauth:grant-type:token-exchange` (RFC 8693). IS 7.3 must have this grant type enabled per-application in Console or via DCR.

**Trust federation (AWS ↔ IS 7.3)** — The mechanism by which IS 7.3 trusts AgentCore's identity claims. AgentCore's OIDC provider is registered as an external IdP in IS 7.3; IS 7.3 validates the `actor_token` against this IdP's JWKS before issuing exchange tokens.
```

- [ ] **Step 4: Update PROGRESS.md**

Change Phase 3 status row to: `🔄 IN PROGRESS — authoring Days 21–30`

Add session log entry:
```
| 2026-10-01 | Phase 3 authoring  | Phase 3 plan written. Tasks 0–4 defined. Ready to author. |
```

---

### Task 1: Days 21–23 — Agent Identity Fundamentals, JWT Bearer Assertion, OBO

**Files:**
- Create: `authn_authz_mastery/content/day21.md`
- Create: `authn_authz_mastery/content/day22.md`
- Create: `authn_authz_mastery/content/day23.md`
- Create: `authn_authz_mastery/labs/day21/README.md`, `diagram.md`, `config/agent_identity_comparison.md`, `SOLUTION.md`
- Create: `authn_authz_mastery/labs/day22/README.md`, `diagram.md`, `config/jwt_bearer_client_auth.http`, `SOLUTION.md`
- Create: `authn_authz_mastery/labs/day23/README.md`, `diagram.md`, `config/obo_token_exchange.http`, `SOLUTION.md`

**Interfaces:**
- Consumes: dirs day21–23/config/ (Task 0)
- Produces: foundational agent identity concepts + OBO master pattern; Tasks 2–3 build on these — Day 24+ can reference Day 23 OBO mechanics without re-explaining

**Day 21 — Agent Identity Fundamentals**

Write `content/day21.md`:

**Why this matters:** A bank deploys an AI agent to process customer requests using `client_credentials` grant — the agent gets a service account token with no user context. A prompt injection attack tricks the agent into initiating an unauthorized transfer. The security team asks: "Which user authorized this? Which agent made the call?" They can't answer — every API call in the audit log shows only the service account. The bank cannot demonstrate regulatory compliance for the transaction.

**Core concepts:**

1. What makes agent auth different from human auth
   - A user authenticates once and acts directly; an agent acts on behalf of a user through an unattended delegation chain
   - Each hop in the chain (user → orchestrator → tool → API) needs a distinct, verifiable identity recorded in the token
   - Human auth: proof of identity → scoped token. Agent auth: proof of identity + proof of delegation chain → scoped token with `act` lineage

2. Principal hierarchy
   - User: the human who initiated the session; identified by `sub` claim throughout the chain
   - Orchestrator agent: the AI agent that receives the user's intent and decomposes it into tool calls
   - Tool agent: a specialized sub-agent that executes one capability (e.g., "read account balance")
   - Backend API: the resource server; validates the full delegation chain
   
3. Delegation chain vs. impersonation
   - Impersonation: agent uses the user's token directly → agent inherits user's full scope, no agent identity in audit log, confused deputy risk
   - Delegation (RFC 8693 OBO): agent exchanges user token for a narrowed token with `act` claim → audit trail shows user + agent at each hop, scope is minimized
   - Key difference: delegation creates a verifiable chain; impersonation erases it

4. Confused deputy problem
   - An agent authorized to act for User A can be tricked via prompt injection into requesting resources for User B using its delegated authority
   - Prevention: the `sub` claim must always be the original user; the `act` claim must identify the specific agent instance; scope narrowing limits blast radius
   - IS 7.3 token exchange respects these constraints when the actor trust policy is correctly configured

5. Audit trail requirements
   - `sub`: original user (preserved at every hop)
   - `act`: acting agent — `{"sub": "<agent_client_id>"}`, nesting grows at each hop
   - `azp`: authorized party (the OAuth2 client that received the token)
   - `jti`: unique token ID for trace correlation
   - Banking regulatory requirement: every API call must be traceable to: (a) the human user who authorized the session, (b) the agent(s) that made the call, (c) the scope of authority at each hop

6. Token lifetime strategy
   - Human token: 1h (user session duration)
   - Orchestrator exchange token: 15min (short-lived delegation; if stolen, expires quickly)
   - Tool token: 5min (per-operation; minimal blast radius)
   - Rationale: each hop's token expires before the parent token could become stale; revoke the human token to cascade invalidation via introspection

**WSO2 IS 7.3 / AgentCore mapping:**

IS 7.3 principal hierarchy config:
```toml
# deployment.toml — enable token exchange grant (required for OBO)
[oauth]
allowed_grant_types = ["authorization_code", "refresh_token", "urn:ietf:params:oauth:grant-type:token-exchange"]

# Per-application in Console:
# Grant types: include "urn:ietf:params:oauth:grant-type:token-exchange"
# Actor trust: specify which client_ids (agent_ids) can exchange for which subjects
```

AgentCore per-agent IAM role pattern:
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

**Anti-patterns (3):**
1. `client_credentials` for agent identity — issues a token with `sub`=client_id, no user context, no delegation chain; breaks regulatory auditability for any user-initiated action
2. Passing the user's access token directly to the agent (impersonation) — the agent inherits the user's full scope and appears as the user in all audit logs; a compromised agent becomes a full proxy for the user
3. Sharing a single IAM role or OAuth2 client across multiple agent instances — if one instance is compromised, all instances are compromised; no way to revoke individual agent authority

**Exercises (3):**
1. A bank's AI agent uses `client_credentials` to call the payment API. An auditor asks "which user authorized transaction TX-001?" Can they answer? Why or why not?
   - **Hint:** `client_credentials` tokens have no user identity — only the service account (`sub`=client_id).
   - **Solution sketch:** No. `client_credentials` issues a token where `sub`=client_id. The payment API audit log records only the service account as the initiator. There is no record of which user authorized the session. To fix: use RFC 8693 token exchange — the agent exchanges the user's IS 7.3 token for a delegated token with `sub`=user + `act`=agent_id. The payment API then records both.

2. An orchestrator agent passes the user's raw IS 7.3 access token to a tool agent to make an API call. What is the security risk and how does delegation (OBO) solve it?
   - **Hint:** what scope and identity does the tool agent inherit?
   - **Solution sketch:** The tool agent inherits the user's full scope — it can do anything the user can, not just the specific tool action. If the tool agent is compromised or prompt-injected, the attacker has full user access. With OBO (RFC 8693), the orchestrator exchanges the user token for a tool-specific token: `scope=accounts:read` (narrowed), `sub`=user (preserved), `act.sub`=tool_agent_id (recorded). The tool's blast radius is now limited to `accounts:read`.

3. Design a token lifetime strategy for a 3-hop chain: user → orchestrator → tool → payment API. Justify each lifetime.
   - **Hint:** each hop's token should expire before the parent token could be used to re-exchange.
   - **Solution sketch:** Human token=1h (session duration); orchestrator exchange=15min (if orchestrator is compromised, stolen token is useless in 15min); tool token=5min (single-operation; minimal window for replay). Introspection-based APIs will detect revocation within their introspection cache TTL (recommend ≤5min cache). If the user revokes: next introspection call returns `active:false` for all derived tokens, effectively propagating revocation within the cache window.

**Lab — Day 21:**
- README: "Design a principal hierarchy for a banking AI agent. Success signal: you can draw the 3-tier delegation chain with correct token claims (`sub`, `act`, scope) at each hop."
- diagram.md: Mermaid sequence — user authenticates to IS 7.3 → orchestrator exchanges user token (OBO) → tool agent exchanges orchestrator token → payment API validates `sub`+`act` chain. Annotate each token with its `sub`, `act`, `scope`, `exp`.
- config/agent_identity_comparison.md: Markdown comparison table — columns: `client_credentials` vs. Impersonation vs. OBO/RFC 8693. Rows: audit trail (what `sub` records), scope control (min/max), revocation granularity, confused deputy risk, regulatory compliance.
- SOLUTION.md: annotated token payloads at each hop + completed comparison table filled in.

---

**Day 22 — JWT Bearer Assertion (RFC 7523)**

Write `content/day22.md`:

**Why this matters:** A fintech integrates their backend service with the bank's WSO2 IS 7.3 using a client secret stored in Kubernetes Secrets. During a routine SOC 2 audit: the secret was accidentally committed to the Git repository 18 months ago. The old commit is still in history. The bank is exposed. JWT Bearer Assertion (RFC 7523) eliminates the shared secret entirely — the client proves identity by signing a short-lived JWT with its private key. The private key never leaves the client.

**Core concepts:**

1. RFC 7523 client authentication (section 2.2)
   - Token request uses `client_assertion_type` and `client_assertion` as POST body parameters (NOT in the Authorization header)
   - `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`
   - `client_assertion=<signed JWT>` — the JWT proving the client's identity
   - The JWT is signed with the client's private key; IS 7.3 verifies with the registered public key (from JWKS)

2. Required JWT claims for `private_key_jwt` client authentication
   - `iss`: client_id (who signed this assertion)
   - `sub`: client_id (same as iss for client auth — the assertion is about this client)
   - `aud`: token endpoint URL (e.g., `https://is.bank.com/oauth2/token`) — prevents reuse at other endpoints
   - `jti`: UUIDv4 (replay prevention — IS 7.3 caches recent jtis; duplicate = rejected)
   - `exp`: ≤ 5 minutes from now (short-lived assertion; NOT the access token expiry)

3. IS 7.3 `private_key_jwt` client configuration
   - DCR field: `"token_endpoint_auth_method": "private_key_jwt"`
   - DCR field: `"jwks_uri": "https://<client-host>/jwks"` — IS 7.3 fetches public keys from here
   - Alternative: `"jwks": { ... }` — embed JWKS directly in DCR registration
   - IS 7.3 verifies: JWT signature (against JWKS), `aud` == token endpoint, `exp` not expired, `iss` == registered client_id, `jti` not seen before

4. Asymmetric advantage over `client_secret`
   - Private key never leaves the client (asymmetric — only public key is shared)
   - Rotating the key: update the JWKS endpoint (no secret distribution to IS 7.3)
   - Compromise scope: leaked private key → revoke/replace JWKS entry; no shared secret to rotate at IS 7.3
   - Audit: IS 7.3 logs which client authenticated; `jti` provides per-request trace

5. RFC 7523 section 2.1 — JWT bearer authorization grant
   - `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`
   - `assertion=<JWT with sub=user>` — a pre-authorized service presents a JWT about a user and gets an access token for that user
   - Used when there's a pre-established trust relationship (e.g., a service with pre-authorization to act for users without interactive consent)
   - Distinct from section 2.2 (client auth) — section 2.1 is an authorization grant, not client authentication

**WSO2 IS 7.3 / AgentCore mapping:**

IS 7.3 DCR registration for `private_key_jwt` client:
```http
POST /api/identity/oauth2/dcr/v1.1/register
Content-Type: application/json
Authorization: Basic <PLACEHOLDER: admin-base64>

{
  "client_name": "payment-orchestrator",
  "grant_types": ["authorization_code", "urn:ietf:params:oauth:grant-type:token-exchange"],
  "redirect_uris": ["https://<PLACEHOLDER: app-host>/callback"],
  "token_endpoint_auth_method": "private_key_jwt",
  "jwks_uri": "https://<PLACEHOLDER: client-host>/.well-known/jwks.json"
}
```

Token request with `private_key_jwt` (FORM BODY — NOT Authorization: Bearer):
```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=<PLACEHOLDER: auth-code>
&redirect_uri=https://<PLACEHOLDER: app-host>/callback
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=<PLACEHOLDER: signed-jwt>
```

JWT payload for `client_assertion`:
```json
{
  "iss": "<PLACEHOLDER: client_id>",
  "sub": "<PLACEHOLDER: client_id>",
  "aud": "https://<PLACEHOLDER: is-host>:9443/oauth2/token",
  "jti": "<PLACEHOLDER: UUIDv4>",
  "exp": "<PLACEHOLDER: now+300>",
  "iat": "<PLACEHOLDER: now>"
}
```

AgentCore mapping: AgentCore agents register with IS 7.3 as `private_key_jwt` clients. The agent's JWKS is derived from its IAM role's OIDC credentials or a dedicated JWT signing key. IS 7.3 fetches the JWKS on first authentication and caches it (TTL configurable).

**Anti-patterns (3):**
1. `exp` more than 5 minutes in the future — IS 7.3 may enforce a maximum assertion lifetime; large `exp` values create a wide replay window and may cause IS 7.3 to reject the assertion with `invalid_client`
2. Reusing the same `jti` across requests — IS 7.3 caches recent jtis to prevent replay; a duplicate `jti` returns `invalid_client`. Generate a fresh UUIDv4 per request
3. Using `Authorization: Bearer <client_assertion>` — the `Bearer` scheme signals resource access authorization, not client authentication. IS 7.3 treats this as an anonymous request with a malformed Authorization header, not a `private_key_jwt` client auth attempt

**Exercises (3):**
1. Write the complete token request form body for `private_key_jwt` client authentication to IS 7.3's token endpoint with `client_credentials` grant.
   - **Hint:** `client_assertion_type` and `client_assertion` go in the POST body — same place as `grant_type`.
   - **Solution sketch:** `POST /oauth2/token`, Content-Type: `application/x-www-form-urlencoded`. Body: `grant_type=client_credentials&scope=payments:read&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=<signed JWT>`. The JWT has `iss`=`sub`=client_id, `aud`=token endpoint URL, `jti`=fresh UUIDv4, `exp`=now+300, `iat`=now. No `Authorization` header.

2. An engineer generates a `client_assertion` JWT with `exp=now+7200` (2 hours) and reuses the same UUIDv4 `jti` for all requests in that window. Which IS 7.3 validation will fail, and why?
   - **Hint:** IS 7.3 caches `jti` values for replay prevention — how long?
   - **Solution sketch:** The second request with the same `jti` will be rejected with `invalid_client` — IS 7.3 has already seen this `jti`. The 2h `exp` compounds the problem: IS 7.3 must cache the `jti` for up to 2h, increasing memory pressure. Fix: UUIDv4 per request, `exp` ≤ 300s. Most IS 7.3 deployments enforce a configurable max assertion lifetime; exceeding it returns `invalid_client` before the replay check.

3. An AgentCore agent needs to authenticate to IS 7.3 using `private_key_jwt`. During testing, the engineer gets `invalid_client: JWKS validation failed`. What are the three most likely causes?
   - **Hint:** IS 7.3 fetches the JWKS and verifies: signature, `kid` match, key algorithm.
   - **Solution sketch:** (1) The JWKS URI registered in DCR is unreachable from IS 7.3's network — IS 7.3 can't fetch the public key. (2) The JWT uses `"alg": "RS256"` but the JWKS has only an `"alg": "ES256"` key — algorithm mismatch. (3) The JWT's `kid` doesn't match any key in the JWKS — IS 7.3 can't find the right public key to verify the signature. Check in order: network reachability → JWKS key algorithm → `kid` consistency.

**Lab — Day 22:**
- README: "Issue a `private_key_jwt` token request to IS 7.3. Success signal: understand all 5 JWT claims and why IS 7.3 requires each one."
- diagram.md: Mermaid sequence — client DCR registration → client generates JWT assertion → POST /oauth2/token (form body, no Bearer) → IS 7.3 fetches JWKS → verifies signature → issues access token. Annotate the JWT payload at the signing step.
- config/jwt_bearer_client_auth.http: annotated HTTP file — (1) DCR registration request/response, (2) token request with `client_assertion` in form body (not Authorization header), (3) token response. All `<PLACEHOLDER>` values with fill-in comments.
- SOLUTION.md: JWT claim breakdown (what each claim prevents), IS 7.3 verification steps in order, common error → root cause table.

---

**Day 23 — OBO — On-Behalf-Of (RFC 8693)**

Write `content/day23.md`:

**Why this matters:** A bank deploys an AI orchestrator that processes payment requests. The orchestrator calls a risk scoring service, which calls the payment initiation service. Each service must verify: "User X authorized this payment, routed through Agent Y." Without a proper delegation mechanism, teams pass the user's raw token through the chain (impersonation — full scope) or use `client_credentials` at each service (no user context). In a PSD2 compliance audit, the bank cannot prove that the specific user consented to the specific payment — every call looks like a service account action.

**Core concepts:**

1. RFC 8693 token exchange — the master pattern
   - `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`
   - `subject_token`: the token whose identity is being delegated (user's access token)
   - `subject_token_type=urn:ietf:params:oauth:token-type:access_token`
   - `actor_token`: the token identifying the agent requesting the delegation
   - `actor_token_type=urn:ietf:params:oauth:token-type:jwt`
   - `scope`: the scope requested for the result token — MUST be a subset of `subject_token`'s scope
   - `requested_token_type=urn:ietf:params:oauth:token-type:access_token`

2. Result token structure
   - `sub`: original user's subject claim — preserved unchanged
   - `act`: `{"sub": "<agent_client_id>"}` — the acting agent; added by IS 7.3 at exchange time
   - `scope`: narrowed to what the agent requested (MUST NOT exceed subject_token scope)
   - `exp`: independently set by IS 7.3 (typically shorter than the subject_token — recommended 15min for orchestrator exchange)
   - `jti`: new unique ID for this token (trace correlation)

3. Multi-hop delegation (`act` claim nesting)
   - Orchestrator exchanges user token → result: `act = {"sub": "orchestrator_id"}`
   - Tool agent exchanges orchestrator token → result: `act = {"sub": "tool_id", "act": {"sub": "orchestrator_id"}}`
   - Each hop prepends the current actor; the innermost `act` is the most recent agent
   - Resource server reads the outermost `act.sub` to know the immediate caller; traverses `act.act` for the full chain
   - Recommended max depth: 3 hops (user → orchestrator → tool → API)

4. `may_act` claim
   - Placed in the `subject_token` or exchange result by IS 7.3 to pre-authorize specific agents for further exchanges
   - Structure: `{"sub": "<pre-authorized_agent_client_id>"}`
   - Use case: IS 7.3 sets `may_act` in the orchestrator token to pre-authorize a known tool agent; downstream exchanges don't need to re-validate the full chain
   - Without `may_act`: IS 7.3 must re-verify the full chain on each downstream exchange — may fail if the subject_token has expired

5. IS 7.3 token exchange grant configuration
   - Enable in Console: Application → OAuth / OpenID Connect → Allowed Grant Types → check `token-exchange`
   - `deployment.toml` actor trust policy (controls which agents can exchange):
     ```toml
     [oauth.token_exchange]
     allow_refresh_token_grant = true
     # Per-app actor trust configured in Console or via DCR grant_types
     ```
   - DCR: `"grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange"]`

6. Scope narrowing constraint
   - IS 7.3 WILL NOT issue an exchange token with scope exceeding the `subject_token`'s scope
   - If agent requests `scope=payments:write` but subject_token has `scope=payments:read`, IS 7.3 returns `invalid_scope`
   - Design implication: the user must have been issued a token with the maximum scope needed by the entire agent chain

7. Revocation propagation
   - Revoking the human token (subject_token) propagates through the chain IF the API uses token introspection
   - IS 7.3 checks the exchange chain on introspection; a revoked parent token causes `active: false` for all derived tokens
   - APIs using local JWT validation will NOT see the revocation until the derived token expires
   - **Banking compliance requirement**: APIs in the delegation chain MUST use introspection (not local JWT validation) to honour user revocation within token lifetime

**WSO2 IS 7.3 / AgentCore mapping:**

First-hop exchange (user → orchestrator):
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

Second-hop exchange (orchestrator → tool):
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

AgentCore mapping: AgentCore uses RFC 8693 internally when a Bedrock agent needs to call a WSO2-protected API. The `subject_token` is the user's IS 7.3 access token (obtained via federated login). The `actor_token` is AgentCore's STS-vended OIDC token. IS 7.3 validates the `actor_token` against the registered AWS OIDC provider (configured as external IdP). Day 25 covers this federation in detail.

**Anti-patterns (3):**
1. Omitting `actor_token` from the exchange request — IS 7.3 may allow the exchange but issues a token with no `act` claim. The API cannot identify which agent made the call. Breaking for banking audit compliance.
2. Requesting the same scope as the `subject_token` without narrowing — the token exchange succeeds but violates least privilege. If the user has `scope=accounts:read payments:write`, a tool that only reads accounts should request `scope=accounts:read` only.
3. Not configuring the actor trust policy in IS 7.3 — without an explicit trust policy, IS 7.3 allows any authenticated client to exchange any user token for any agent. In a banking deployment, only known, registered agent client_ids should be permitted to exchange on behalf of users.

**Exercises (3):**
1. Write the complete token exchange request for an orchestrator agent to get a delegated token from IS 7.3, starting with a user's access token.
   - **Hint:** `grant_type`, `subject_token`, `subject_token_type`, `actor_token`, `actor_token_type`, and `scope` are all required POST body parameters.
   - **Solution sketch:** `POST /oauth2/token`, form body: `grant_type=urn:ietf:params:oauth:grant-type:token-exchange&subject_token=<user_token>&subject_token_type=urn:ietf:params:oauth:token-type:access_token&actor_token=<orchestrator_jwt>&actor_token_type=urn:ietf:params:oauth:token-type:jwt&scope=payments:initiate&requested_token_type=urn:ietf:params:oauth:token-type:access_token`. Add `client_assertion_type` + `client_assertion` if the orchestrator uses `private_key_jwt` client auth (recommended). Result token has `sub`=user, `act.sub`=orchestrator_client_id, `scope`=payments:initiate.

2. An orchestrator exchanges a user token for a delegated token. The tool agent then uses this orchestrator-scoped token directly to call the backend API (no further exchange). What is missing from the audit trail?
   - **Hint:** which principal in the chain is not recorded in the token?
   - **Solution sketch:** The tool agent's identity is not recorded — the API sees `act.sub`=orchestrator_id and assumes the orchestrator made the call. If the tool agent is compromised, all of its calls appear as orchestrator calls in the audit log. Fix: the tool agent must also exchange for its own delegated token, adding `act.act` nesting. The payment API then sees: `sub`=user, `act.sub`=tool_id, `act.act.sub`=orchestrator_id — the full chain is verifiable.

3. A user's access token expires after 1h. An orchestrator exchanged it 50 minutes ago and got a 15-minute agent token. At T+60min, the user calls `POST /oauth2/revoke` to revoke their session. The agent token is 5 minutes old (valid for 10 more minutes). Will the payment API reject the next request?
   - **Hint:** the answer depends on whether the API uses token introspection or local JWT validation.
   - **Solution sketch:** If the API introspects: IS 7.3 checks the exchange chain — the revoked parent token causes IS 7.3 to return `active: false` for the agent token. Next API call rejected. If the API validates JWTs locally: the agent token is still cryptographically valid (not expired) — the API does NOT see the revocation until the agent token's own `exp`. Banking compliance mandates introspection for APIs in delegation chains.

**Lab — Day 23:**
- README: "Trace a 2-hop OBO delegation chain through IS 7.3. Success signal: you can explain what `act` nesting means and why `sub` is preserved."
- diagram.md: Three Mermaid diagrams: (1) First exchange sequence (user → orchestrator, showing HTTP request + token payload evolution), (2) Second exchange sequence (orchestrator → tool, showing `act.act` nesting), (3) Revocation propagation flowchart (introspect vs. local JWT).
- config/obo_token_exchange.http: annotated HTTP file — (1) first exchange request/response with decoded JWT showing `sub`+`act`, (2) second exchange request/response with decoded JWT showing `sub`+`act`+`act.act`, (3) payment API call with token + IS 7.3 introspection call + response. All `<PLACEHOLDER>` values.
- SOLUTION.md: annotated token payloads at each hop showing `sub`, `act`, `scope`, `exp` — plus revocation propagation explanation.

---

### Task 2: Days 24–26 — AgentCore Gateway, AgentCore+OBO, MCP Service Auth

**Files:**
- Create: `authn_authz_mastery/content/day24.md`, `day25.md`, `day26.md`
- Create: `authn_authz_mastery/labs/day24/README.md`, `diagram.md`, `config/agentcore_iam_role.json`, `SOLUTION.md`
- Create: `authn_authz_mastery/labs/day25/README.md`, `diagram.md`, `config/agentcore_obo_token_exchange.http`, `SOLUTION.md`
- Create: `authn_authz_mastery/labs/day26/README.md`, `diagram.md`, `config/mcp_oauth2_server.toml`, `SOLUTION.md`

**Interfaces:**
- Consumes: dirs day24–26/config/ (Task 0), OBO mechanics from Day 23 (assumed known — do not re-explain RFC 8693 basics)
- Produces: AgentCore + MCP content; Task 3 Days 27–28 build on these

**Day 24 — AWS AgentCore Gateway Architecture**

Why it matters: A bank deploys an AI agent using Amazon Bedrock. Without AgentCore, the team gives the agent a static IAM access key stored in the deployment environment. The key is leaked via a misconfigured S3 bucket policy. With full IAM access, the attacker can read customer data from DynamoDB. AgentCore fixes this by vending per-request short-lived credentials tied to a scoped IAM role with session tags — a leaked credential is useless after seconds.

Core concepts:
- AgentCore Gateway identity model: each agent type (orchestrator, tool) gets a dedicated IAM role; no shared service accounts
- `sts:AssumeRole` with session tags: `agentId`, `userId`, `sessionId` — these become auditable metadata on every API call
- SigV4 signing: every request to an AgentCore-protected API is signed with temporary IAM credentials (SigV4 includes a timestamp — prevents replay beyond the credential TTL, typically 15 minutes)
- Credential vending lifecycle: Agent starts → AgentCore assumes role via STS → vends temporary credentials (AccessKeyId, SecretAccessKey, SessionToken) → agent signs requests with these → credentials expire → re-vend
- AgentCore's trust model: only requests from registered agents (by `agentId`) with valid SigV4 signatures are forwarded; others are rejected at the gateway
- `caller_identity` object: `{agentId, userId, sessionId}` — AgentCore adds this as an HTTP header to forwarded requests, so backend APIs know the agent's identity without re-validating IAM

WSO2 IS 7.3 / AgentCore mapping:
- IAM trust policy: restricts assumption to AgentCore's service principal
- IAM permission policy: grants only the permissions needed by that agent type
- Session tag condition: requires `userId` and `agentId` tags (enforced by Service Control Policy at the org level)
- AgentCore config: registers the IAM role ARN per agent type; maps `userId` to the user's IS 7.3 subject claim (Day 25 covers the token exchange bridge)

Lab config: `agentcore_iam_role.json` — IAM trust policy + permission policy for an orchestrator agent role, annotated with `<PLACEHOLDER>` for account IDs and ARNs.

Anti-patterns (3):
1. Shared IAM role for all agent instances — a compromised agent instance can impersonate any other agent of the same type; no per-instance revocation
2. Not including `userId` as a session tag — the audit log shows only `agentId`; impossible to trace which user's session triggered a specific API call
3. Long-lived IAM credentials for agents — credential TTL > 15min increases the blast radius of a leak; use short STS credentials (15min) re-vended at each AgentCore session

Exercises (3 with Hint + Solution sketch):
1. Why does AgentCore use `sts:AssumeRole` with session tags rather than a fixed IAM user for each agent?
   - **Hint:** think about credential rotation, per-session isolation, and audit trail.
   - **Solution sketch:** `sts:AssumeRole` vends temporary credentials (15min TTL) — a leaked credential expires automatically with no manual rotation. Session tags (`agentId`, `userId`, `sessionId`) make every CloudTrail entry traceable to the specific agent instance and user session. A fixed IAM user has long-lived credentials (risk of leak) and no per-session isolation (can't revoke one session without revoking the user).

2. An engineer wants to allow only the `payment-orchestrator` AgentCore agent to call the `PaymentService` API. Write the IAM condition that enforces this.
   - **Hint:** session tags are available as `aws:PrincipalTag/<tagKey>` in IAM conditions.
   - **Solution sketch:** In the permission policy for PaymentService: `"Condition": {"StringEquals": {"aws:PrincipalTag/agentId": "payment-orchestrator"}}`. This ensures that only STS sessions tagged with `agentId=payment-orchestrator` can call the API. Other agents using the same role but a different `agentId` tag are blocked.

3. A backend API receives an AgentCore-forwarded request with the `X-AgentCore-Caller-Identity` header. What information does this header contain, and how should the API use it?
   - **Hint:** the API doesn't need to re-validate IAM — AgentCore did that. The API uses the header for authz and audit.
   - **Solution sketch:** The header contains `{agentId, userId, sessionId}` (JSON, signed or otherwise attested by AgentCore). The API uses `userId` to scope data access to that user's records, `agentId` to enforce agent-specific authorization policies, and `sessionId` for audit log correlation. The API trusts this header because it's added by the AgentCore gateway — not by the agent itself — and the request already passed SigV4 validation at the gateway.

---

**Day 25 — AgentCore + OBO Patterns**

Why it matters: An AI agent (deployed via AgentCore) needs to call a WSO2-protected payment API on behalf of a user. AgentCore provides IAM credentials; WSO2 IS 7.3 requires an OAuth2 access token. Without the AgentCore ↔ IS 7.3 trust bridge, the agent either: (a) uses a static service account (no user context), or (b) cannot call WSO2 APIs at all. The bridge is RFC 8693 token exchange + AWS–IS 7.3 identity federation.

Core concepts:
- Trust federation: IS 7.3 registers AWS IAM Identity Center (or STS OIDC) as an external IdP — IS 7.3 trusts tokens issued by this IdP as `actor_token` values in token exchange requests
- Full AgentCore → IS 7.3 → WSO2 API flow:
  1. User authenticates to IS 7.3; IS 7.3 issues user access token
  2. User token passed to AgentCore session context (out-of-band; app-level)
  3. AgentCore agent assumes IAM role via STS; gets OIDC identity token
  4. Agent calls IS 7.3 token exchange: `subject_token`=user token, `actor_token`=OIDC identity token
  5. IS 7.3 validates `actor_token` against federated AWS OIDC IdP JWKS
  6. IS 7.3 issues exchange token: `sub`=user, `act.sub`=agentcore-agent-id, scope=narrowed
  7. Agent calls payment API with IS 7.3 exchange token (Bearer)
  8. Payment API introspects → IS 7.3 confirms `active:true` + `act` chain
- IS 7.3 external IdP config for AWS OIDC:
  - Identity Provider Type: `OpenID Connect`
  - Discovery URL: `https://oidc.eks.<PLACEHOLDER: region>.amazonaws.com/id/<PLACEHOLDER: cluster-id>/.well-known/openid-configuration` (or IAM Identity Center OIDC URL)
  - This tells IS 7.3 where to fetch the JWKS to validate `actor_token` signatures from AWS

WSO2 IS 7.3 / AgentCore mapping: annotated IS 7.3 external IdP configuration TOML + token exchange HTTP sequence showing the full 8-step flow.

Anti-patterns (3 — AgentCore-IS 7.3 integration specific):
1. Passing the user's IS 7.3 access token directly to the AgentCore agent via environment variable — the token appears in CloudTrail logs, container logs, and environment dumps; use a secure context passing mechanism (e.g., AWS Secrets Manager session, AgentCore context API)
2. Not validating the `aud` claim in the AgentCore `actor_token` — IS 7.3 must check that the OIDC token's `aud` matches the IS 7.3 token endpoint or a configured audience; without this, a token issued for a different IS 7.3 tenant or service can be used as an `actor_token`
3. Configuring IS 7.3 to trust all tokens from the AWS OIDC IdP without an actor trust policy — any AWS workload that can mint an OIDC token from this IdP can exchange any user's IS 7.3 token; restrict via IS 7.3 actor trust policy to specific `sub` values (agent client IDs)

Exercises (3 with Hint + Solution sketch): design questions about the federation trust model, actor token validation, and end-to-end flow.

Lab config: `agentcore_obo_token_exchange.http` — annotated HTTP sequence: IS 7.3 external IdP registration call + token exchange request (AgentCore OIDC as actor_token) + exchange result showing `act.sub`=agent-id + payment API call with introspection.

---

**Day 26 — MCP Service Authentication**

Why it matters: A team builds an MCP tool server for their AI agent and secures it with a static API key per tool. Three months later: a prompt injection attack causes the agent to leak the API key in a response. The attacker uses the key to call the tool directly with arbitrary inputs. API keys have no user context, no scope, no revocation per user, and no audit trail. OAuth2-scoped tokens for MCP tools fix all four problems.

Core concepts:
- MCP auth spec (2024): MCP tools are OAuth2 resource servers; the MCP client (AI agent) authenticates via Authorization Code flow or token exchange
- Tool discovery: MCP server publishes OAuth2 AS metadata at `/.well-known/oauth-authorization-server` — the agent reads this to discover the token endpoint, DCR endpoint, and supported scopes
- DCR for MCP clients: the agent registers as an OAuth2 client at IS 7.3's DCR endpoint (`/api/identity/oauth2/dcr/v1.1/register`) with `grant_types=["authorization_code"]` and MCP-specific redirect URIs
- Scoped tool tokens: each tool action maps to a scope: `mcp:payments:read`, `mcp:payments:write`, `mcp:accounts:read`; the agent requests only the scope for the specific tool call
- IS 7.3 as MCP OAuth2 AS: IS 7.3 is configured as the authorization server for the MCP tool server; the tool server registers with IS 7.3 as a resource server; IS 7.3 introspects tokens when the tool server receives a request
- Token lifetime: MCP tool tokens are short-lived (5min), tied to the current session's user context, and revocable per-user via IS 7.3 consent revocation (Day 18)

WSO2 IS 7.3 / AgentCore mapping: IS 7.3 `deployment.toml` section for MCP tool scope registration + MCP tool server resource server registration via API. DCR example for MCP client registration.

Anti-patterns (3):
1. One API key for all tool calls — no per-user revocation, no audit trail per user, no scope differentiation between read and write operations
2. Not using the MCP authorization code flow for user-context tools — a tool that accesses user data with a `client_credentials` token has no `sub` claim; the tool cannot enforce per-user access control
3. Tool tokens with scope `*` or overly broad scopes — an agent that requests `mcp:*` scope can call all tools regardless of the specific action; request only the scope for the specific tool call being made

Exercises (3 with Hint + Solution sketch): MCP tool discovery, scope design for a payment tool, revocation propagation from IS 7.3 consent to MCP tool token.

Lab config: `mcp_oauth2_server.toml` — IS 7.3 `deployment.toml` additions for MCP tool server registration + scope mapping for `mcp:payments:read` and `mcp:payments:write`.

---

### Task 3: Days 27–29 — IS 7.3 as Agent IdP, End-to-End Delegation Chain, Architecture Synthesis

**Files:**
- Create: `authn_authz_mastery/content/day27.md`, `day28.md`, `day29.md`
- Create: `authn_authz_mastery/labs/day27/README.md`, `diagram.md`, `config/agent_idp_deployment.toml`, `SOLUTION.md`
- Create: `authn_authz_mastery/labs/day28/README.md`, `diagram.md`, `config/delegation_chain_trace.md`, `SOLUTION.md`
- Create: `authn_authz_mastery/labs/day29/README.md`, `diagram.md`, `config/synthesis_flows.md`, `SOLUTION.md`

**Interfaces:**
- Consumes: dirs day27–29/config/ (Task 0), Days 23 (OBO), 24 (AgentCore), 25 (AgentCore+OBO), 26 (MCP) assumed known
- Produces: complete agent identity picture; Task 4 Day 30 capstone synthesises all phases

**Day 27 — WSO2 IS 7.3 as Agent IdP**

Why it matters: A bank's AI agent deployment passes all security reviews but fails the compliance audit. Reason: agent tokens are `client_credentials` grants — they have no user context and are excluded from the bank's consent and revocation framework. IS 7.3's token exchange grant + agent policy enforcement makes AI agents first-class principals under the bank's existing identity governance. Revoking a user's consent now revokes derived agent tokens automatically.

Core concepts:
- IS 7.3 token exchange grant: enable `urn:ietf:params:oauth:grant-type:token-exchange` per application in Console or via DCR
- Agent client registration: DCR with `grant_types` including token-exchange; IS 7.3 assigns a client_id to each agent type; this client_id appears as `act.sub` in exchange tokens
- Agent policy enforcement: IS 7.3 role-based policy allows specifying which agent client_ids can exchange tokens for which user groups — prevents a compromised agent from exchanging tokens for admin users
- Scope mapping for agent principals: define agent-specific scopes separate from human scopes (e.g., `agent:payments:initiate` vs. `payments:initiate`) to distinguish agent-originated calls in the APIM gateway
- Audit log tagging: IS 7.3 audit log records `sub`, `act`, `azp`, `jti` — enables: "show all API calls made by agent Y on behalf of user X in the last 24h"
- `deployment.toml` token exchange config: `[oauth.token_exchange]` section; per-app actor trust configured in Console

WSO2 IS 7.3 / AgentCore mapping: annotated `deployment.toml` for token exchange grant + agent client DCR request + agent policy configuration in Console (described via annotated JSON).

Anti-patterns (3):
1. No actor trust policy — IS 7.3 allows any authenticated agent to exchange any user token; a compromised low-privilege agent can escalate by exchanging a privileged user's token
2. Agent scopes overlapping with human scopes — if `payments:initiate` is used for both human and agent calls, the APIM gateway can't distinguish them; define `agent:payments:initiate` for agents to enable per-principal rate limiting and policy
3. Not tagging agent calls in IS 7.3 audit log — if `act` is not indexed in the audit log, the question "which agent made this call?" requires a full log scan; configure IS 7.3 log format to include `act.sub` as a structured field

Exercises (3 with Hint + Solution sketch): actor trust policy design, agent scope definition, audit log query for a specific agent's calls.

Lab config: `agent_idp_deployment.toml` — IS 7.3 `deployment.toml` additions for token exchange grant config + agent policy (described as annotated TOML + JSON for Console configuration).

---

**Day 28 — End-to-End Delegation Chain**

Why it matters: A payment operation is flagged for fraud review. The compliance officer needs to reconstruct: "User X clicked Pay → which AI agent chain processed this → which tool made the API call → what token authorized it → was it validly delegated?" Without designing the audit chain deliberately, teams discover after an incident that no single system has the complete picture.

Core concepts:
- Complete banking AI agent chain:
  1. User authenticates via IS 7.3 App-Native Auth (Day 11) → human access token (1h, `sub`=user)
  2. User intent sent to orchestrator → orchestrator calls IS 7.3 token exchange (RFC 8693, Day 23) → exchange token (15min, `sub`=user, `act.sub`=orchestrator_id)
  3. Orchestrator decomposes task → calls tool agent → tool exchanges orchestrator token → tool token (5min, `sub`=user, `act.sub`=tool_id, `act.act.sub`=orchestrator_id)
  4. Tool agent calls payment API via AgentCore (Day 24) → AgentCore validates SigV4, adds X-AgentCore-Caller-Identity
  5. Payment API receives token + AgentCore identity header → introspects IS 7.3 → confirms `active:true`, `sub`, full `act` chain, `scope`
  6. Payment API records: `sub`=user, `act_chain`=[tool_id, orchestrator_id], `jti`=trace_id in its own transaction log

- Token lifetimes at each hop: human=1h, orchestrator exchange=15min, tool=5min
- Revocation propagation (introspection-based):
  - User revokes session in IS 7.3 → human token revoked → next introspection returns `active:false` for all derived tokens
  - Propagation latency = introspection cache TTL (must be ≤5min for banking compliance)
  - Tokens with `exp` < cache_TTL will expire before revocation is detected — tool tokens (5min) may expire before revocation propagates

- Audit trail design:
  - Every token: `sub`=user, `act` chain, `jti` (correlation ID), `iat` (issuance time)
  - IS 7.3 audit log: token exchange events with `subject_client`, `actor_client`, `issued_scope`, `jti`
  - AgentCore: CloudTrail entries with session tags (`userId`, `agentId`, `sessionId`) per API call
  - Payment API: transaction log with `jti` (links to IS 7.3 audit) + AgentCore `sessionId` (links to CloudTrail)

- Chain depth limits:
  - RFC 8693 does not define a max depth; IS 7.3 allows configuration
  - Recommended: 3 hops (user → orchestrator → tool → API); 4+ hops add complexity without adding security
  - Enforced via IS 7.3 actor trust policy: configure which exchanges are permitted at each level

WSO2 IS 7.3 / AgentCore mapping: end-to-end HTTP trace showing all token requests and introspection calls with `<PLACEHOLDER>` values + audit log query patterns.

Anti-patterns (3):
1. Using local JWT validation at the payment API — revocation does not propagate within the token's lifetime; a user who revokes after a fraud alert still has active agent tokens for up to 15min
2. Not correlating `jti` across IS 7.3 audit, AgentCore CloudTrail, and payment API logs — each system has a piece of the chain; without a shared correlation ID, reconstructing the chain requires cross-system log correlation by timestamp (imprecise, slow)
3. Passing `sessionId` from AgentCore to IS 7.3 token exchange but not to the payment API — the payment API cannot correlate its transaction record with the CloudTrail entry; use `sessionId` as a claim in the IS 7.3 exchange token

Exercises (3 with Hint + Solution sketch): revocation propagation timing calculation, audit trail reconstruction from `jti`, chain depth limit enforcement.

Lab config: `delegation_chain_trace.md` — annotated token chain: for each hop, show the decoded JWT payload (all claims), the IS 7.3 introspection response, and the AgentCore CloudTrail entry format. `<PLACEHOLDER>` for all token values.

---

**Day 29 — Architecture Synthesis**

Why it matters: A bank's principal architect must present the identity architecture to the security board. They need to explain how the same IS 7.3 hub supports three radically different integration patterns — customer-facing banking app (FAPI 2.0 + SCA), B2B partner API (mTLS + org-scoped tokens), and AI agent integration (OBO + AgentCore + MCP) — without running three separate identity systems. This day produces the synthesis view that makes the architecture defensible.

Core concepts:
- Three flows through the same IS 7.3 hub:
  1. Customer-facing banking app: User → FAPI 2.0 + PAR → IS 7.3 authorization endpoint → SCA (FIDO2/passkey or TOTP) → JARM response → DPoP-bound JWT → APIM gateway → payment backend. Phase 1 + Phase 2 (Days 1–17).
  2. B2B partner API: Partner app (sub-org) → mTLS client auth → IS 7.3 (org-scoped token with `org_id`, `cnf.x5t#S256`) → APIM gateway validates `org_id` subscription → backend. Phase 1 Days 6 + Phase 2 Days 15–16, 20.
  3. AI agent integration: User authenticates (App-Native, Day 11) → user token → orchestrator OBO exchange (Day 23) → tool token → AgentCore gateway (Day 24) → MCP tool (Day 26) → IS 7.3 introspect → backend. Phase 3 Days 21–28.

- Shared IS 7.3 primitives (all three flows use these):
  - PAR (`/oauth2/par`) — all three flows use PAR for secure authorization request initiation
  - JWKS (`/oauth2/jwks`) — APIM gateway, resource servers, and external relying parties all verify JWTs here
  - Introspection (`/oauth2/introspect`) — APIM, tool servers, payment API all introspect tokens here
  - DCR (`/api/identity/oauth2/dcr/v1.1/register`) — FAPI clients, B2B apps, and MCP clients all register here

- Per-flow divergences:
  - Customer app: FAPI 2.0 compliance mode, JARM, SCA step-up, DPoP binding
  - B2B partner: mTLS client auth, org-scoped token, `org_id` subscription enforcement
  - AI agent: token exchange grant, `act` claim, AgentCore SigV4, MCP scoped tool tokens

WSO2 IS 7.3 / AgentCore mapping: IS 7.3 as the hub diagram — single IS 7.3 instance configured with all three paths; which `deployment.toml` sections enable each path.

Day 29 lab: Mermaid diagram showing all three flows converging on IS 7.3, a synthesis table comparing the three flows on 6 dimensions (auth method, token binding, audit claim, revocation mechanism, APIM enforcement, regulatory driver). No config stub — the synthesis IS the deliverable.

Anti-patterns (3): architecture-level mistakes — running separate IS instances per flow, not sharing JWKS across flows, treating AI agent auth as "out of scope for identity governance."

Exercises (3 with Hint + Solution sketch): multi-flow design questions.

Lab config: `synthesis_flows.md` — the comparison table + IS 7.3 hub diagram description (learner fills in the diagram from the table). SOLUTION.md: completed table + annotated Mermaid hub diagram.

---

### Task 4: Day 30 — Capstone Architect Deliverable + PROGRESS.md

**Files:**
- Create: `authn_authz_mastery/content/day30.md` (brief guide)
- Create: `authn_authz_mastery/labs/capstone/architecture.md` (5 Mermaid sequence diagrams)
- Create: `authn_authz_mastery/labs/capstone/configs/is73_hub_config.toml`
- Create: `authn_authz_mastery/labs/capstone/configs/agentcore_delegation_config.json`
- Create: `authn_authz_mastery/labs/capstone/decision_tree.md`
- Create: `authn_authz_mastery/labs/capstone/ADR.md`
- Modify: `authn_authz_mastery/PROGRESS.md` (mark Phase 3 complete, write "all phases complete" next steps)

**Interfaces:**
- Consumes: all Phase 3 days complete (Days 21–29 exist); builds on all Phase 1 + Phase 2 content
- Produces: team-shareable architect deliverable + PROGRESS.md final state

- [ ] **Step 1: Write content/day30.md**

Brief guide: explain what the capstone is, what the learner should produce, and how to self-assess.

Day 30 uses `## WSO2 IS 7.3 / AgentCore mapping` like all Phase 3 days.

The "Lab" section points to `labs/capstone/` (not the standard `labs/day30/`).

The capstone is the lab — `day30.md` is a 1-page guide explaining each deliverable and the success criteria.

Why it matters: An architect who can draw the diagrams, write the config stubs, build the decision tree, and draft the ADR from memory has internalised the full 30-day curriculum. The capstone produces artefacts teammates can act on immediately — it is the real-world output, not an exercise.

Success criteria:
- 5 Mermaid sequence diagrams (see `architecture.md`) drawn without looking at previous day files
- Config stubs in `configs/` annotated with the engineer's own comments (not copied from day files)
- Decision tree in `decision_tree.md` covers all three integration scenarios
- ADR captures the key design decisions and their rationale

- [ ] **Step 2: Write labs/capstone/architecture.md**

Five Mermaid sequence diagrams:

1. **Customer-facing banking app** — full FAPI 2.0 + PAR + RAR + DPoP + SCA flow (user → PAR → IS 7.3 → SCA → JARM → APIM → backend). Reference: Phase 1 Days 1–10, Phase 2 Day 13.

2. **B2B partner payment API** — mTLS client auth + org-scoped token flow (partner app → IS 7.3 mTLS → org-scoped JWT with `cnf.x5t#S256` + `org_id` → APIM → backend). Reference: Phase 1 Days 6, Phase 2 Days 15–16, 20.

3. **AI agent delegation chain** — full OBO chain (user → App-Native Auth → IS 7.3 → orchestrator exchange → tool exchange → AgentCore → MCP tool → IS 7.3 introspect → backend). Reference: Phase 3 Days 21–28.

4. **IS 7.3 hub — all three flows** — composite diagram showing three flows converging on IS 7.3; label which IS 7.3 endpoint each flow uses. Reference: Day 29.

5. **Token lifecycle** — shows a user token, its exchange chain, and revocation propagation with introspection. Annotate `sub`, `act`, `scope`, `exp` at each hop. Reference: Day 28.

All diagrams use Mermaid `sequenceDiagram` or `flowchart TD`. All values `<PLACEHOLDER>`.

- [ ] **Step 3: Write labs/capstone/configs/**

`is73_hub_config.toml` — annotated IS 7.3 `deployment.toml` sections for all three integration paths:
- FAPI 2.0 compliance mode (`[server.fapi]`)
- DPoP + mTLS token binding (`[oauth]`)
- CIBA backchannel (`[oauth.ciba]`)
- Token exchange grant (`[oauth.token_exchange]`)
- B2B org model (comment reference to Console config)
- APIM key manager URLs (`[apim.key_manager]`)

`agentcore_delegation_config.json` — AgentCore deployment config:
- IAM role ARNs per agent type (orchestrator, tool)
- Trust federation reference (IS 7.3 as external OIDC IdP)
- Session tag mappings (`userId` → IS 7.3 `sub`, `agentId` → agent client_id)
- Token exchange endpoint (`/oauth2/token`)

All `<PLACEHOLDER>` values.

- [ ] **Step 4: Write labs/capstone/decision_tree.md**

Protocol decision tree covering all 30 days. Format: flowchart (Mermaid `flowchart TD`).

Root question: "What kind of caller is making the API request?"

Branches:
- Human user (interactive) → "What regulatory profile?" → FAPI 2.0 (banking) → "SCA required?" → yes: FIDO2/passkey; no: standard OIDC
- Human user (interactive) → non-FAPI → standard OIDC + PKCE
- Machine/service (B2B partner) → "mTLS available?" → yes: mTLS + org-scoped token; no: `client_credentials` + DPoP (weaker — document risk)
- AI agent → "Acting on behalf of user?" → yes: RFC 8693 OBO → "Via AgentCore?" → yes: AgentCore + OIDC federation + OBO; no: direct OBO
- AI agent → not on behalf of user → RFC 7523 JWT bearer grant (pre-authorized trust)
- MCP tool call → "User-context required?" → yes: Authorization Code + IS 7.3 scope; no: `client_credentials` with scoped MCP token

Each leaf node references the relevant day file (e.g., "→ Day 23: OBO").

- [ ] **Step 5: Write labs/capstone/ADR.md**

Architecture Decision Record — adopting IS 7.3 + AgentCore as the identity hub for banking + AI agent integration.

Structure:
- **Title:** Adopt WSO2 IS 7.3 + AWS AgentCore as the unified identity hub for customer-facing, B2B, and AI agent integration
- **Status:** Proposed (learner fills in Accepted/Rejected after team review)
- **Context:** Three integration patterns (customer-facing FAPI, B2B partner, AI agent) converged on a single identity question: who is authorized to call this API, on whose behalf, with what scope? Running three separate auth systems creates: inconsistent consent models, no shared revocation, three audit log formats to correlate.
- **Decision:** IS 7.3 as the single OAuth2 authorization server; AgentCore as the credential vending layer for AI agents; RFC 8693 as the delegation primitive across all patterns.
- **Consequences (positive):** single consent model, revocation propagates to all derived tokens via introspection, one JWKS endpoint for all relying parties, PAR and DCR shared across flows.
- **Consequences (negative):** IS 7.3 becomes a single point of failure — requires HA deployment (active-active IS 7.3 cluster); all token validation latency concentrates at IS 7.3 introspection endpoint — requires aggressive caching (5min) with deliberate revocation propagation tradeoff.
- **Alternatives considered:** (1) Separate IdP per flow — rejected: no shared revocation, 3× governance overhead. (2) API-key-based agent identity — rejected: no user context, no revocation, no audit trail. (3) AWS IAM only for agents — rejected: no OAuth2 scope model, no IS 7.3 consent integration.
- **References:** Spec Days 1–30 day files; relevant RFCs (9126 PAR, 9396 RAR, 9449 DPoP, 8705 mTLS, 8693 OBO, 7523 JWT Bearer).

- [ ] **Step 6: Update PROGRESS.md**

Change Phase 3 status row to: `✅ COMPLETE — all content + capstone authored`

Add session log entry:
```
| 2026-10-01 | Phase 3 authoring  | All 10 days + capstone deliverable authored. Phase 3 complete. All 30 days done. |
```

Replace Next Session Instructions with:
```markdown
## Next Session Instructions

**All 3 phases complete (30 days).** The AuthN/AuthZ Mastery path is finished.

### What was built
- Phase 1 (Days 1–10): Hard Protocols — FAPI 2.0, PAR, RAR, CIBA, DPoP, mTLS, SCIM, Consent, SCA, Protocol Composition
- Phase 2 (Days 11–20): WSO2 IS 7.3 Deep-dive — App-Native Auth, Adaptive Auth, FAPI mode, CIBA, DPoP+mTLS, B2B Org, FIDO2, RAR+Consent, Extension Points, APIM integration
- Phase 3 (Days 21–30): AI Agent Identity + Capstone — Delegation chain, JWT Bearer Assertion, OBO, AgentCore, MCP, IS 7.3 as Agent IdP, End-to-End Chain, Synthesis, Capstone

### Next actions
1. Merge this branch to master (user handles VCS)
2. Start Day 1 — read `content/day01.md`, complete `labs/day01/`
3. The Capstone (`labs/capstone/`) is the real test — attempt it after Day 29 before reading the pre-written version
```

Update Phase Plans table row 3: `✅ Complete — days 21–30 + capstone authored`

- [ ] **Step 7: Verify Task 4**

```bash
# Day 30 has all required sections
for section in "Why this matters" "Core concepts" "WSO2 IS 7.3 / AgentCore mapping" "Anti-patterns" "Exercises" "Lab"; do
  grep -q "$section" authn_authz_mastery/content/day30.md || echo "FAIL: day30.md missing: $section"
done

# Capstone files exist
ls authn_authz_mastery/labs/capstone/architecture.md \
   authn_authz_mastery/labs/capstone/configs/is73_hub_config.toml \
   authn_authz_mastery/labs/capstone/configs/agentcore_delegation_config.json \
   authn_authz_mastery/labs/capstone/decision_tree.md \
   authn_authz_mastery/labs/capstone/ADR.md || echo "FAIL: capstone files missing"

# Decision tree has Mermaid
grep -q "flowchart\|graph\|sequenceDiagram" authn_authz_mastery/labs/capstone/decision_tree.md || echo "FAIL: decision_tree.md missing Mermaid"

# Architecture.md has 5 diagrams
COUNT=$(grep -c "^sequenceDiagram\|^flowchart\|^graph" authn_authz_mastery/labs/capstone/architecture.md 2>/dev/null || echo 0)
[ "$COUNT" -ge 5 ] || echo "FAIL: architecture.md has fewer than 5 diagrams (found: $COUNT)"

# All Phase 3 days have WSO2 IS 7.3 / AgentCore mapping section
for day in $(seq 21 30); do
  grep -q "WSO2 IS 7.3 / AgentCore mapping" authn_authz_mastery/content/day${day}.md \
    || echo "FAIL: day${day}.md missing WSO2 IS 7.3 / AgentCore mapping"
done

# No credentials
grep -rE "BEGIN PRIVATE|BEGIN CERT|AKIA[A-Z0-9]{16}" authn_authz_mastery/content/day2[1-9].md authn_authz_mastery/content/day30.md \
  && echo "FAIL: credentials" || echo "PASS: no credentials"

# PROGRESS.md shows all 3 phases complete
grep -c "COMPLETE" authn_authz_mastery/PROGRESS.md | grep -q "^3" && echo "PASS: all 3 phases" || echo "WARN: check PROGRESS"

echo "Task 4 verification done"
```
