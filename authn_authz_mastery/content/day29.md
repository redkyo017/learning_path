# Day 29 — Architecture Synthesis

## Why this matters

A bank's principal architect must present the identity architecture to the security board. They need to explain how the same IS 7.3 hub supports three radically different integration patterns — customer-facing banking app (FAPI 2.0 + SCA), B2B partner API (mTLS + org-scoped tokens), and AI agent integration (OBO + AgentCore + MCP) — without running three separate identity systems. Each pattern has different compliance drivers, threat models, and technical requirements. But all three share the same IS 7.3 OAuth2 server, the same JWKS endpoint, the same introspection API. This day produces the synthesis view that makes the architecture defensible: showing how a single hub can serve divergent needs without creating a monolithic or fragile system.

## Core concepts

### 1. Three flows through the same IS 7.3 hub

#### Flow 1: Customer-facing banking app (FAPI 2.0 + SCA)

- **Auth method**: Authorization Code flow with PAR (Day 4) + RAR (Day 8) for consent granularity
- **User identity**: Verified via App-Native Auth (Day 11) + out-of-band authentication (SMS/email/FIDO2)
- **Strong customer authentication (SCA)**: One-time passcode or FIDO2 passkey (Day 17)
- **Token binding**: DPoP (Demonstration of Possession, Day 16) — token is bound to client's public key; prevents token theft/replay
- **Token response**: JARM (JWT-encoded response, Day 9) — response is signed and optionally encrypted
- **Scope**: `payments:read payments:write accounts:read accounts:write` (broad, user-driven granular consent)
- **Token lifetime**: 1h (user session; user typically active)
- **Revocation**: User can revoke via mobile app; propagates via introspection within 5min
- **Regulatory driver**: PSD2 (Revised Payment Services Directive) — EU regulation mandating SCA for payments
- **Implementation**: Days 1–17 (Phase 1 + Phase 2)

#### Flow 2: B2B partner API (mTLS + org-scoped tokens)

- **Auth method**: mTLS (mutual TLS, Day 6) + client certificate auth
- **Client certificate**: Issued by bank's PKI; identifies the partner organization
- **Token structure**: OAuth2 token with `org_id` claim (partner's organization identifier) + certificate hash (`cnf.x5t#S256`) binding token to the cert
- **Scope**: `partner-api:read partner-api:write` (partner-specific scope, not user-scoped)
- **Token lifetime**: 24h (machine-to-machine; long-lived because no user session)
- **Rate limiting**: Per-organization (org_id), not per-user
- **Revocation**: Partner can revoke via admin API; typically scheduled (daily or weekly refresh)
- **Regulatory driver**: B2B compliance (data protection, audit trail per partner)
- **Implementation**: Days 6 (Phase 1) + Days 15–16, 20 (Phase 2)

#### Flow 3: AI agent integration (OBO + AgentCore + MCP)

- **Auth method**: Token exchange (RFC 8693, Day 23) + `private_key_jwt` client auth (Day 22)
- **User identity**: Flows from user's initial login (App-Native Auth or Authorization Code) → preserved through agent chain via `sub` claim
- **Agent identity**: Each agent is a distinct OAuth2 client; identity recorded via `act` claim (Day 23)
- **Token structure**: `sub=user`, `act={"sub": agent_client_id}` (single-hop) or nested `act` for multi-hop chains
- **Scope narrowing**: User token may have broad scope; each exchange narrows to agent-specific scope (Day 27)
- **Token lifetimes**: human=1h, orchestrator=15min, tool=5min (each hop shorter to minimize blast radius)
- **Tool auth**: MCP tool calls IS 7.3 token exchange to get scoped token for specific operation (Day 26)
- **Revocation**: User revokes via mobile app; propagates to all agent tokens via introspection (Day 28)
- **Regulatory driver**: Agent auditability — compliance must trace every action to the user who initiated it + all agents involved
- **Implementation**: Days 21–28 (Phase 3)

### 2. Shared IS 7.3 primitives (used by all three flows)

#### PAR — Pushed Authorization Request

All three flows use PAR (`/oauth2/par`) for secure authorization request initiation:

- **Customer app**: PAR + RAR (Day 8) for granular consent (which accounts can be accessed, which payment limit)
- **B2B partner**: PAR for secure request initiation (prevent parameter tampering in transit)
- **AI agent**: PAR used when an agent needs to re-authenticate (rare, but supported)

#### JWKS — JSON Web Key Set

All three flows verify JWTs against `/oauth2/jwks`:

- **Customer app**: Mobile app verifies JARM response JWT (response is signed by IS 7.3)
- **B2B partner**: Partner app verifies access token JWT locally (optional; some use introspection instead)
- **AI agent**: IS 7.3 verifies `actor_token` JWT (agent's signed assertion) + payment API optionally verifies token JWT

#### Introspection — Token introspection endpoint

All three flows use `/oauth2/introspect` to verify token status (with different caching strategies):

- **Customer app**: APIM gateway introspects on every user API call (cache TTL = 5min for compliance)
- **B2B partner**: APIM gateway introspects at connection time (cache TTL = 1h; partner tokens are long-lived)
- **AI agent**: Payment API introspects on every delegated token (cache TTL = 5min for compliance + revocation propagation)

#### DCR — Dynamic Client Registration

All three flows register clients via `/api/identity/oauth2/dcr/v1.1/register`:

- **Customer app**: Mobile app registers with `response_types=["code"]`, `token_endpoint_auth_method=private_key_jwt`, `response_mode=jwt` (JARM)
- **B2B partner**: Partner app registers with `token_endpoint_auth_method=mtls_client_auth`, no `response_types` (DCR returns `client_id` + cert info)
- **AI agent**: Agent registers with `grant_types=["token-exchange"]`, `token_endpoint_auth_method=private_key_jwt`

### 3. Per-flow divergences

| Dimension | Customer App (FAPI 2.0) | B2B Partner (mTLS) | AI Agent (OBO) |
|-----------|------------------------|--------------------|----------------|
| **User identity** | Named user (`sub`); verified via SCA | Organization (`org_id`); no named user | Named user (`sub`); agent identity in `act` |
| **Client auth** | PKCE + DPoP | mTLS certificate | `private_key_jwt` |
| **Token binding** | DPoP-bound; token tied to client's public key | Certificate hash (`cnf.x5t#S256`); token tied to cert | No binding (stateless); scope narrowing is control |
| **Audit claim** | `sub`, `aud`, `scope` | `sub` (org_id), `cnf.x5t#S256` | `sub`, `act` (single or nested), `scope` |
| **Revocation mechanism** | User-initiated; propagates via introspection | Scheduled (admin-initiated) | User-initiated; propagates via introspection |
| **Regulatory driver** | PSD2 (SCA, consent, revocation) | B2B audit trail (org-level) | Agent auditability (per-agent tracing) |

### 4. IS 7.3 hub configuration

**Single IS 7.3 instance serves all three flows:**

1. **Global OAuth2 config** (deployment.toml):
   - `allowed_grant_types = ["authorization_code", "refresh_token", "client_credentials", "urn:ietf:params:oauth:grant-type:token-exchange"]`
   - All grant types are enabled globally; per-application enablement decides which grants each client uses

2. **Three separate applications (Console)**:

   **App 1: MobileBank (customer-facing)**
   - Grant types: `authorization_code`, `refresh_token`
   - Token endpoint auth: `private_key_jwt` + PKCE
   - Response type: `code` + response_mode: `jwt` (JARM)
   - Audience: `mobilebank`
   - Scopes: `payments:read payments:write accounts:read accounts:write openid profile`

   **App 2: PartnerAPI (B2B)**
   - Grant types: `client_credentials`
   - Token endpoint auth: `mtls_client_auth`
   - Audience: `partner-api`
   - Scopes: `partner-api:read partner-api:write`
   - Additional claim: `org_id` (added via claim mapping)

   **App 3: AgentOrchestrator (AI agent)**
   - Grant types: `urn:ietf:params:oauth:grant-type:token-exchange`
   - Token endpoint auth: `private_key_jwt`
   - Audience: `payment-api`
   - Scopes: `payments:initiate agent:payments:initiate accounts:read`
   - Actor trust policy: restrict which agents can exchange for which users

3. **Shared infrastructure**:
   - Single JWKS endpoint (`/oauth2/jwks`) — all three apps' public keys are here
   - Single introspection endpoint (`/oauth2/introspect`) — APIM and resource servers call here
   - Single PAR endpoint (`/oauth2/par`) — all flows can use it
   - Single audit log (structured JSON) — all three flows recorded with distinct claim patterns

## WSO2 IS 7.3 / AgentCore mapping

### IS 7.3 as the identity hub diagram

See `labs/day29/config/synthesis_flows.md` for a Mermaid diagram showing:
1. All three flows converging on IS 7.3
2. Shared endpoints (PAR, JWKS, introspection, DCR)
3. Per-flow endpoints (authorization endpoint for customer app, mTLS auth for partner, token exchange for agent)
4. Resource servers (APIM gateway, partner API, payment API) all trust IS 7.3 JWKS

### deployment.toml sections enabling each flow

**Customer app (FAPI 2.0):**
```toml
[oauth]
allowed_grant_types = ["authorization_code", "refresh_token"]

[oauth.jwt]
enable_mtls = false

# App 1 config in Console:
# - PKCE mandatory
# - DPoP binding enabled
# - Response mode: JARM
```

**B2B partner (mTLS):**
```toml
[oauth]
allowed_grant_types = ["client_credentials"]

[oauth.mtls]
enable_client_auth = true

# App 2 config in Console:
# - Token auth method: mtls_client_auth
# - Client certificate path mapping to org_id
```

**AI agent (OBO):**
```toml
[oauth]
allowed_grant_types = ["urn:ietf:params:oauth:grant-type:token-exchange"]

[oauth.token_exchange]
# Actor trust policies configured per-app in Console (not in TOML)

# App 3 config in Console:
# - Grant type: token-exchange
# - Token auth method: private_key_jwt
# - Actor trust policy: restrict agents
```

## Anti-patterns

1. **Running separate IS instances per flow** — each flow (FAPI, B2B, Agent) has its own IS 7.3 instance. Operational cost increases 3×. JWKS is not shared; customers and partners must maintain three separate key lists. Audit is fragmented; compliance officers cannot trace transactions across flows. Single hub architecture (this day's lesson) is more defensible: one IS 7.3 to operate, one JWKS to maintain, unified audit trail.

2. **Not sharing JWKS across flows** — each flow has a separate key set. Customer app verifies tokens from MobileBank app's keys; agent app verifies tokens from AgentOrchestrator app's keys; no cross-verification. If a customer app and agent app need to interoperate (e.g., an agent needs to verify a customer's token), they can't. Single JWKS (all apps' keys) allows any resource server to verify any token from any app. Trade-off: slightly larger JWKS (more keys), but much better interoperability. Mitigate by rotating keys regularly and using key versioning (`kid` claim).

3. **Treating AI agent auth as "out of scope for identity governance"** — agent tokens are issued via `client_credentials` (service account), not integrated into IS 7.3 identity governance. Agent calls are not auditable at the user level. If a user's account is compromised and an agent is acting on their behalf, there's no revocation mechanism (tokens are long-lived service account tokens). Fix: integrate agent auth into IS 7.3 identity governance via token exchange + actor trust policies. Agent calls inherit user revocation and consent models — "out of scope" is not defensible in a regulated industry.

## Exercises

**Exercise 1:** A bank's CISO reviews the three-flow architecture. They ask: "What happens if IS 7.3 goes down? Do all three flows fail?" Discuss the blast radius and suggest a mitigation strategy.

**Hint:** Consider token lifetime and validation strategy (local vs. introspection).

**Solution sketch:** If IS 7.3 goes down:
- **Customer app**: APIM gateway caches customer tokens (TTL=5min for compliance). Requests with cached tokens are accepted for 5min; requests outside the cache miss are rejected. Most customer sessions recover when IS 7.3 returns (within SLA window).
- **B2B partner**: Partner tokens are long-lived (24h) and often validated locally (JWT signature check). Partner app can continue operating for up to 24h without IS 7.3. This is by design: B2B integrations prioritize uptime.
- **AI agent**: Agent tokens are short-lived (5min) and introspection is required (payment API cannot validate locally). Agent requests fail immediately when IS 7.3 is down. Blast radius: AI-augmented features are unavailable; core banking (human-initiated payments) continues.

**Mitigation**: Deploy IS 7.3 in active-active cluster (multiple nodes); use load balancer with health checks. Cache introspection results with TTL matching token lifetime (5min). For extreme HA: run IS 7.3 replicas in multiple regions with database replication; agents automatically fail over to nearest replica.

---

**Exercise 2:** Design an API gateway (APIM) policy that handles all three flows. The policy must: (1) validate token type (FAPI vs. B2B vs. Agent), (2) apply appropriate rate limiting, (3) enforce scope. Write pseudocode.

**Hint:** Token claims differ: FAPI has `sub` (user), B2B has `org_id`, Agent has `act` (agent). Use claim-based routing.

**Solution sketch:**
```yaml
Policy: TokenValidationAndRouting
  1. Parse JWT token (or call introspection)
  2. if token has "act" claim:
       route to "Agent Flow"
       rate_limit(agent_flow: 5000/hour per agent_id)
       enforce_scope(agent:payments:initiate | agent:payments:read)
  3. else if token has "org_id" claim:
       route to "B2B Flow"
       rate_limit(b2b_flow: 10000/hour per org_id)
       enforce_scope(partner-api:read | partner-api:write)
  4. else if token has "sub" claim (no "act", no "org_id"):
       route to "Customer Flow"
       rate_limit(customer_flow: 1000/hour per sub)
       enforce_scope(payments:read | payments:write | accounts:read | accounts:write)
  5. else:
       return 401 Unauthorized
```

This policy routes requests to three different backends (or three different rule sets within one backend) based on token type, applies flow-specific rate limits, and validates scope.

---

**Exercise 3:** The bank wants to add a fourth flow: internal employee access (same banking APIs, but employee accounts authenticated via Windows AD + 2FA). Should this be a fourth application in the same IS 7.3 hub or a separate instance? Justify your choice.

**Hint:** Consider: JWKS sharing, audit trail consolidation, operational complexity.

**Solution sketch:** Add as a fourth application to the same IS 7.3 hub. Reasons: (1) JWKS is already shared with three flows; adding a fourth doesn't increase complexity. (2) All four flows can share the same JWKS endpoint; employee tokens are verifiable by the same APIM gateway. (3) Unified audit trail: compliance can query a single audit log to correlate customer, partner, agent, and employee actions (e.g., if an employee initiates a payment on behalf of a customer, both `sub` claims are visible in the transaction record). (4) Operational simplicity: one IS 7.3 to operate and monitor. Configuration in Console:

**App 4: EmployeePortal**
- Grant types: `authorization_code`, `refresh_token`
- Token endpoint auth: `private_key_jwt` (Windows AD federation via SAML or OIDC bridge)
- Audience: `employee-portal`
- Scopes: `admin:read admin:write` (employee-specific scopes, different from customer scopes)
- MFA enforcement: policy in IS 7.3 to require 2FA for sensitive operations

Cost of separate instance: duplicated JWKS management, separate audit trail, fragmented compliance picture. Not justified.

## Lab

See `labs/day29/README.md` — design and compare the three-flow architecture using an IS 7.3 hub synthesis model.
