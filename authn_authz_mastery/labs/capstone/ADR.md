# Architecture Decision Record (ADR)

## Title

Adopt WSO2 IS 7.3 + AWS AgentCore as the unified identity hub for customer-facing, B2B, and AI agent integration

## Status

**Proposed** (learner to fill in: Accepted / Rejected / Superseded after team review and security board sign-off)

## Date

2026-10-01

## Context

### The Problem

A bank processes three distinct types of API requests:

1. **Customer-facing banking application** (mobile app, web browser)
   - User authenticates via mobile device
   - Requests PSD2 compliance: SCA, PAR, RAR, DPoP token binding
   - Regulatory driver: EU Payment Services Directive

2. **B2B partner integration** (payment networks, corporate customers)
   - Service-to-service authentication via mTLS certificate
   - No named user; organization-scoped tokens
   - Regulatory driver: B2B audit trail, partner subscription management

3. **AI agent integration** (Bedrock, internal orchestration)
   - Agent acts on behalf of a user (e.g., "process this transfer")
   - Requires auditability: which user initiated → which agent executed → what action
   - Regulatory driver: Agent accountability in transaction audit trail

### The Challenge

Without a unified hub, the bank runs three separate identity systems:

| Dimension | Separate Systems (Anti-Pattern) | Unified Hub (Proposed) |
|-----------|------|---|
| **Endpoints** | 3 OAuth2 servers (3 distinct JWKS) | 1 IS 7.3 JWKS |
| **Consent model** | 3 different consent frameworks | Single consent model; revocation propagates to all token types |
| **Revocation** | User revokes in System A; systems B and C don't know | User revokes once; IS 7.3 propagates to all derived tokens |
| **Audit trail** | 3 separate logs; compliance must correlate manually | Single audit log; all transactions linked by `jti` and `sub` |
| **Token validation** | APIM gateway maintains 3 key lists | APIM gateway fetches single JWKS endpoint |
| **Operational complexity** | Patch 3 systems, scale 3 systems, troubleshoot 3 systems | Single platform to operate |
| **Cost** | 3 licenses, 3 DBA teams, 3 security reviews | 1 license, 1 team, 1 security model |

### Key Requirements

1. All three flows must use the same OAuth2 authorization server (no separate identity systems).
2. User revocation must propagate to AI agent tokens within 5 minutes (compliance requirement).
3. Each integration pattern must be independently auditable at the transaction level.
4. PSD2 compliance must be met for customer-facing flows.
5. AI agents must have distinct identity in the audit trail (not appear as service accounts).

## Decision

**We will adopt WSO2 IS 7.3 + AWS AgentCore as the unified identity hub.**

### Implementation Strategy

#### 1. IS 7.3 as the Single OAuth2 Authorization Server

**IS 7.3 is configured with:**

- **FAPI 2.0 compliance mode** — enables PAR, RAR, DPoP, JARM for customer-facing flows
- **mTLS client authentication** — enables B2B partner integration with certificate-based identity
- **RFC 8693 token exchange grant** — enables AI agent delegation chains (user → orchestrator → tool → API)
- **External OIDC federation** — trusts AWS IAM OIDC tokens from AgentCore as `actor_token` in exchange requests
- **Unified audit log** — all token requests, exchanges, and revocations recorded with full context (`sub`, `act`, `scope`, `jti`)
- **Single JWKS endpoint** — all flows' public keys published at `/oauth2/jwks`
- **Single introspection endpoint** — all resource servers call `/oauth2/introspect` for token validation

**Three applications registered in IS 7.3:**

1. **MobileBank** (customer app)
   - Grant types: `authorization_code`, `refresh_token`
   - Auth method: `private_key_jwt` + PKCE
   - Response mode: `jwt` (JARM)
   - Scopes: `payments:read`, `payments:write`, `accounts:read`, `accounts:write`

2. **PartnerAPI** (B2B service)
   - Grant types: `client_credentials`
   - Auth method: `mtls_client_auth`
   - Scopes: `partner-api:read`, `partner-api:write`
   - Token claim: `org_id` (extracted from certificate subject)

3. **AgentOrchestrator** + **AgentTool** (AI agents)
   - Grant types: `urn:ietf:params:oauth:grant-type:token-exchange`
   - Auth method: `private_key_jwt`
   - Scopes: `agent:payments:initiate`, `agent:accounts:read` (narrower than human scopes)
   - Actor trust policy: restrict which agents can exchange for which users
   - External IdP trust: AWS OIDC federation

#### 2. AWS AgentCore as the Credential Vending Layer

**AgentCore is configured with:**

- **Per-agent IAM role** — each agent type (orchestrator, tool) has a dedicated role; no shared service account
- **Session tags** — `userId` (from user's IS 7.3 token), `agentId` (agent client_id), `sessionId` (correlation ID)
- **SigV4 request signing** — every API call to AgentCore-protected backends is signed with temporary credentials
- **Trust federation with IS 7.3** — AgentCore's OIDC token is the `actor_token` in RFC 8693 exchanges
- **Credential lifetime** — 15 minutes (temporary credentials expire automatically; reduces leak blast radius)

#### 3. RFC 8693 Token Exchange as the Delegation Primitive

**All three flows converge on token exchange logic:**

- **Customer app** — does not use token exchange directly; uses standard authorization code + FAPI SCA
- **B2B partner** — does not use token exchange (certificate-bound tokens are sufficient)
- **AI agent** — uses token exchange for each hop: user → orchestrator (exchange 1) → tool (exchange 2) → backend

**Token exchange ensures:**

- Original user identity (`sub`) is preserved across the delegation chain
- Agent identity is recorded (`act` claim) at each hop
- Scope is narrowed at each hop (least privilege)
- Revocation propagates through introspection (user revokes → next introspection returns `active:false`)

## Consequences

### Positive

1. **Single consent model** — Users grant consent once; IS 7.3 enforces it consistently across all three flows. No separate consent frameworks per integration pattern.

2. **Unified revocation** — User revokes their session; IS 7.3 propagates revocation to all derived tokens (customer tokens, agent tokens) within the introspection cache TTL (5 minutes). No manual revocation per system.

3. **Single JWKS endpoint** — All flows' public keys are published at one endpoint. APIM gateway fetches a single JWKS; resource servers verify tokens from any flow (customer, partner, agent).

4. **Shared audit infrastructure** — Single audit log records all token events with correlation ID (`jti`). Compliance officers query one log to reconstruct: "Which user authorized transaction X? Which agents were involved? What scope was granted at each hop?"

5. **Simplified operations** — One IS 7.3 instance to deploy, patch, monitor. One database for all identity data. One JWKS to rotate. One audit log to retain. Operational cost and complexity reduced 3×.

6. **Extensibility** — Adding a fourth integration pattern (e.g., employee AD federation) is a configuration change in IS 7.3 Console, not a new identity system.

7. **Compliance defensibility** — A single hub satisfies regulatory audits: PSD2 (customer SCA), B2B audit trail, and agent auditability all stemming from one, well-understood system.

### Negative

1. **IS 7.3 becomes a single point of failure** — If IS 7.3 is down, all three flows are affected. No customer payments, no B2B partner integrations, no AI agent operations.
   - **Mitigation:** Deploy IS 7.3 in active-active cluster (3–5 nodes behind load balancer). Database replication across AZs. CloudFront cache for JWKS endpoint (reduce origin load). Target RTO: 5 minutes.

2. **Introspection endpoint becomes a bottleneck** — Every request from every flow calls IS 7.3 introspection to validate tokens. At scale (10K customer sessions + 500 agents × 5 API calls/min), introspection can become CPU-bound.
   - **Mitigation:** Cache introspection results at APIM gateway level (TTL = 5 min for compliance, matching token lifetime). Deploy IS 7.3 read replicas for introspection queries. Use token lifetime as cache key to reduce stale data.

3. **Token lifetime / revocation tradeoff** — Introspection cache TTL (5 min for compliance) means revocation takes up to 5 min to propagate. During those 5 minutes, a revoked token is still accepted if cached.
   - **Mitigation:** Use short-lived agent tokens (5 min lifetime; expires before revocation would be detected). For high-risk operations (large payment transfers), enforce real-time introspection with no cache. For low-risk operations (read queries), allow cache.

4. **Operational dependency on AWS SigV4 (for AgentCore)** — AWS region outage means agents cannot assume roles; credential vending fails. Non-agent flows (customer, B2B) continue but agent operations stop.
   - **Mitigation:** For non-critical agents, fall back to pre-authorized tokens (RFC 7523 JWT bearer) as a secondary auth path. For critical agents, run backup identity service in a different cloud region (expensive, rarely justified).

5. **Scope explosion** — With three integration patterns, IS 7.3 must define and manage scopes for all three: customer scopes (e.g., `payments:read`), B2B scopes (e.g., `partner-api:write`), agent scopes (e.g., `agent:payments:initiate`), MCP scopes (e.g., `mcp:payments:read`). Scope collision is possible.
   - **Mitigation:** Use scope namespacing: `customer:*`, `partner:*`, `agent:*`, `mcp:*`. Document scope taxonomy in IS 7.3. Audit scope requests at token exchange time.

## Alternatives Considered

### Alternative 1: Separate IdP per Flow

**Option:** Run three separate identity systems (OAuth2 AS for customer, OAuth2 AS for B2B, OAuth2 AS for agents).

**Rejected because:**
- **No shared revocation** — User revokes customer session; agent tokens remain valid (no propagation mechanism).
- **3× JWKS management** — APIM gateway maintains three separate key lists; key rotation becomes manual and error-prone.
- **Fragmented audit** — Compliance officers manually correlate three separate audit logs to answer: "Did this user authorize this transaction?"
- **3× operational complexity** — Three systems to deploy, patch, scale, troubleshoot, monitor. Cost and risk multiplied.
- **Interop problems** — If a customer app needs to call an agent-protected API, there's no shared trust model.

### Alternative 2: API Key–Based Agent Identity

**Option:** Agents authenticate with a static API key (like AWS access key ID). No OAuth2 for agents; just key validation.

**Rejected because:**
- **No user context** — API key has no `sub` claim; audit log cannot answer "which user initiated this agent action?"
- **No revocation** — Revoking the API key revokes all agents; fine-grained revocation per agent is impossible.
- **No scope** — API key grants full access or nothing; no ability to scope an agent to specific capabilities.
- **No compliance path** — Regulatory audit asks: "Which user authorized transaction X?" Answer: "Unknown; it was an API key." Compliance fails.

### Alternative 3: AWS IAM Only for Agents (No IS 7.3 Integration)

**Option:** Use AWS IAM for agent identity; forget OAuth2 for agents entirely.

**Rejected because:**
- **Agents cannot call WSO2-protected APIs** — IS 7.3 expects OAuth2 tokens; AWS IAM credentials are not OAuth2-compatible.
- **No user context in IS 7.3 tokens** — User token has `sub`=user, but agent receives AWS credentials with no user information. Agents can use the user's token directly (impersonation risk) or not at all.
- **No consent integration** — User cannot revoke agent access through the mobile app; must go to AWS console (unlikely for end users).
- **Fragmented audit** — CloudTrail (AWS) logs agent API calls; IS 7.3 audit logs user authentication; payment API logs transactions. Three separate logs; no correlation.

## Implementation Roadmap

### Phase 1: IS 7.3 Hub Configuration (Week 1–2)

- [ ] Deploy IS 7.3 cluster (3 nodes, HA setup)
- [ ] Configure FAPI 2.0 compliance mode
- [ ] Register three applications (MobileBank, PartnerAPI, AgentOrchestrator)
- [ ] Enable token exchange grant
- [ ] Configure external OIDC IdP (AWS)
- [ ] Test: customer app authorization code flow
- [ ] Test: B2B partner mTLS + client_credentials

### Phase 2: Agent Identity Integration (Week 3–4)

- [ ] Deploy AgentCore
- [ ] Configure IAM roles per agent type (orchestrator, tool)
- [ ] Enable AWS OIDC federation with IS 7.3
- [ ] Test: token exchange (user token → agent token)
- [ ] Test: multi-hop delegation (orchestrator → tool)
- [ ] Test: revocation propagation via introspection

### Phase 3: Production Hardening (Week 5–6)

- [ ] Deploy APIM gateway with introspection caching
- [ ] Configure audit log retention and archival
- [ ] Load test: introspection endpoint at scale
- [ ] Security review: scope definitions, actor trust policies
- [ ] Compliance review: PSD2, B2B, agent auditability

### Phase 4: Rollout (Week 7+)

- [ ] Customer app migration: old auth system → IS 7.3
- [ ] B2B partner onboarding: mTLS certificate provisioning
- [ ] Agent integration: Bedrock workflows start using OBO tokens
- [ ] Monitor: audit trail, introspection latency, revocation timing

## References

### RFC Documents

- **RFC 9126 (PAR)** — Pushed Authorization Request
- **RFC 9396 (RAR)** — Rich Authorization Request
- **RFC 9449 (DPoP)** — Demonstration of Possession
- **RFC 8705 (mTLS)** — Mutual TLS
- **RFC 8693 (OBO)** — OAuth 2.0 Token Exchange (RFC)
- **RFC 7523 (JWT Bearer)** — JSON Web Token (JWT) Profile for OAuth 2.0 Client Authentication and Authorization Grants
- **RFC 6234 (PKCE)** — Proof Key for Public OAuth2 Clients

### WSO2 IS 7.3 Specification

- `authn_authz_mastery/docs/superpowers/specs/2026-09-30-authn-authz-mastery-design.md` — Full curriculum spec (Days 1–30)

### Day Files (Reference)

- **Days 1–10** (Phase 1): Hard protocols foundation
- **Days 11–20** (Phase 2): IS 7.3 deep-dive
- **Days 21–30** (Phase 3): Agent identity + capstone

### Architecture Diagrams

- `labs/capstone/architecture.md` — 5 Mermaid diagrams (FAPI 2.0, B2B mTLS, AI agent OBO, IS 7.3 hub, token lifecycle)

### Configuration Examples

- `labs/capstone/configs/is73_hub_config.toml` — Annotated IS 7.3 deployment.toml
- `labs/capstone/configs/agentcore_delegation_config.json` — Annotated AgentCore IAM roles and federation config

### Decision Tree

- `labs/capstone/decision_tree.md` — Mermaid flowchart routing all caller types to correct protocols

---

## Sign-Off

**Author:** Architect (you)

**Date Reviewed:** [To be filled in after team review]

**Security Board Approval:** ☐ Approved ☐ Approved with conditions ☐ Rejected

**Conditions/Comments:**

---

## Appendix: Glossary of Terms

- **`sub` claim** — Subject; the original user's identity, preserved throughout all delegation chains.
- **`act` claim** — Acting principal; the agent's identity, added by IS 7.3 at token exchange time. Nests on multi-hop exchanges.
- **Token exchange (RFC 8693)** — Mechanism for agents to exchange a user's token for a narrowed agent token.
- **`actor_token`** — In RFC 8693, the token identifying the requesting agent (typically an OIDC token from AWS).
- **Introspection** — IS 7.3 endpoint that validates tokens and checks if they've been revoked. Result is cached by resource servers (5min TTL for compliance).
- **DPoP** — Demonstration of Possession; binds a token to a client's public key to prevent token theft.
- **mTLS** — Mutual TLS; both client and server authenticate each other via X.509 certificates.
- **FAPI 2.0** — Financial-grade API profile for OAuth2; includes SCA, PAR, RAR, DPoP, JARM.
- **PSD2** — Payment Services Directive (EU regulation); mandates SCA for payments.
- **AgentCore** — AWS service that vends short-lived credentials to AI agents via STS AssumeRole.
- **Session tag** — Metadata attached to temporary credentials (e.g., `userId=alice`, `agentId=orchestrator`).

