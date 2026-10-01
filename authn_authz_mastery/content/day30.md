# Day 30 — Capstone Architect Deliverable

## Why this matters

You've studied 30 days of authentication and authorization: hard protocols (FAPI 2.0, PAR, RAR, DPoP, mTLS, SCA, CIBA), a deep dive into WSO2 IS 7.3 (App-Native Auth, FAPI mode, APIM integration), and the complete journey of AI agent identity through delegation chains. An architect who can draw the diagrams, write the config stubs, build the decision tree, and draft the ADR from memory — without copying from previous days — has internalized the full curriculum. The capstone is not a test; it is the real-world output. These deliverables are the artifacts your teammates will act on immediately: a reference architecture, a protocol decision tree, and a written rationale for the platform's design.

## Core concepts

### 1. The capstone challenges

Your capstone produces four deliverables:

1. **Architecture diagrams** (5 Mermaid sequence diagrams) — visualize the three integration flows (customer-facing FAPI 2.0 + SCA, B2B mTLS, AI agent OBO + AgentCore) and how they converge on the same IS 7.3 hub. Include the token lifecycle and revocation propagation.

2. **Configuration stubs** (IS 7.3 + AgentCore) — annotated TOML and JSON showing how to deploy IS 7.3 and AgentCore as the unified identity hub. Focus on the settings that enable all three flows: FAPI mode, mTLS, token exchange grant, external IdP federation.

3. **Protocol decision tree** (Mermaid flowchart) — a single diagram answering "What kind of caller is making the API request?" Branches cover human users, B2B services, AI agents, and MCP tools. Each leaf references a specific day's content.

4. **Architecture Decision Record (ADR)** — one-page record justifying the choice of IS 7.3 + AgentCore as the unified hub. Include context, decision, positive/negative consequences, and alternatives rejected.

### 2. Success criteria

- **5 Mermaid diagrams**: drawn from your understanding (not copied from days 1–29), covering the three flows, their convergence on IS 7.3, and token lifecycle with introspection/revocation.
- **Config stubs**: each setting annotated with a comment explaining what it does (not just `<PLACEHOLDER>`). Show how the three flows differ in their configuration sections.
- **Decision tree**: the flowchart must cover all three integration scenarios (human FAPI, B2B mTLS, AI agent OBO) and reference the relevant day files.
- **ADR**: a written argument defensible to a security board — why this architecture, what risks are accepted, what alternatives were rejected.

### 3. What to focus on

During the capstone, do not re-explain Phase 1 or Phase 2 concepts. Assume the reader has completed Days 1–29:

- **Phase 1 fundamentals** (FAPI 2.0, PAR, RAR, DPoP, mTLS, CIBA, SCA) — reference them, don't re-teach.
- **Phase 2 deep-dive** (IS 7.3 console configuration, APIM integration, FIDO2) — reference the day files.
- **Phase 3 synthesis** — focus on how all three flows share IS 7.3 as a hub and how agent identity is handled differently from human and B2B flows.

## WSO2 IS 7.3 / AgentCore mapping

The capstone is the synthesis. By Day 30, you understand:

- **IS 7.3 as the hub**: single OAuth2 authorization server configured with:
  - FAPI 2.0 compliance mode (`[server.fapi]`)
  - DPoP + mTLS token binding (`[oauth]`)
  - Token exchange grant (`[oauth.token_exchange]`) for AI agents
  - External OIDC IdP federation (AWS IAM Identity Center or STS) for AgentCore

- **AgentCore as the credential vending layer**: each agent type gets:
  - A dedicated IAM role (not a shared service account)
  - Session tags (`userId`, `agentId`, `sessionId`) for audit trail
  - SigV4 request signing for temporary IAM credentials
  - Federation trust with IS 7.3 (AgentCore's OIDC token is `actor_token` in RFC 8693 exchange)

- **The capstone deliverables show this integration in four forms**: architecture diagrams, configuration, decision tree, and written justification.

## Anti-patterns

1. **Skipping the decision tree** — assuming the three flows are "obvious." They're not. A decision tree forces you to clarify: when do we use FAPI 2.0 vs. mTLS? When is OBO the answer vs. a pre-authorized JWT? When should we use AgentCore SigV4 vs. direct token exchange? Writing the tree reveals gaps in your architecture.

2. **Config stubs without annotations** — filling in `[oauth]` sections with no explanation of what each setting does. The config must stand alone: a teammate can read it and understand why each line is there. Comments like "enables DPoP" and "sets token exchange lifetime" are minimal but essential.

3. **ADR that reads like a feature list** — listing capabilities (FAPI 2.0 is PSD2 compliant; mTLS is FIPS 140-2) without addressing the trade-offs. A good ADR answers: "We chose this, which means we accept X risk, we rejected Y alternative because Z." An engineer reading it should understand not just what we chose, but why we didn't choose something else.

## Exercises

**Exercise 1:** Your security team asks: "If IS 7.3 is down, which flows are affected, and for how long?" Draw a 2×2 table (flow × blast radius) and justify your answer based on token lifetime and validation strategy (local vs. introspection). What is the mitigation strategy for each flow?

**Hint:** Token lifetime is your clue. Customer tokens (1h, cached introspection). Partner tokens (24h, often local validation). Agent tokens (5min, introspection required).

**Solution sketch:** 
- Customer flow: affected for 5min (introspection cache TTL); then requests rejected if not cached. Mitigation: increase cache TTL or deploy IS 7.3 HA cluster.
- B2B partner flow: NOT affected for up to 24h (long-lived tokens, local JWT validation often used). Mitigation: not needed for typical outages (< 1h SLA).
- AI agent flow: immediately affected (5min token lifetime, introspection required). Mitigation: agent requests fail; core banking (human users) continues. Deploy IS 7.3 multi-region for HA.

---

**Exercise 2:** A new requirement: internal employees (Windows AD authenticated, 2FA required) must access the same banking APIs. Is this a new flow through the same IS 7.3 hub, or a separate identity system? Justify using the three existing flows as a reference.

**Hint:** Consider JWKS sharing, audit trail consolidation, compliance requirements.

**Solution sketch:** Add as a fourth application (employee-portal) to the same IS 7.3 hub. Reasons: (1) JWKS already shared with three flows; a fourth doesn't increase complexity. (2) Unified audit trail: compliance queries one log to see customer + partner + agent + employee transactions. (3) Operational simplicity: one IS 7.3 to operate. Configure in IS 7.3 Console:
- Grant types: `authorization_code`, `refresh_token`
- Token auth: Windows AD federation (SAML/OIDC bridge)
- Scopes: `admin:read admin:write` (employee-only, separate from customer scopes)
- MFA enforcement: policy requiring 2FA

Separate instance would duplicate JWKS management and fragment the audit trail — not justified.

---

**Exercise 3:** Design a Kubernetes-based deployment of IS 7.3 + AgentCore for a bank running 10,000 concurrent customer sessions + 500 active agents. What is the key bottleneck? How would you scale it?

**Hint:** Introspection is called on every request. Introspection cache TTL = 5min (compliance requirement). Calculate introspection load.

**Solution sketch:** 
- Customer flow: 10,000 sessions × 5 API calls/min = 50K introspection calls/min (worst case, no cache hit).
- Agent flow: 500 agents × 10 tool calls/min = 5K introspection calls/min.
- Total: ~55K introspection calls/min to a single IS 7.3 instance = **unsustainable** (typical IS 7.3 handles ~1K introspection/sec = 60K/min at peak, but with overhead).

Bottleneck: IS 7.3 introspection endpoint. 

Scaling strategy:
1. **Deploy IS 7.3 in active-active cluster** (3–5 nodes, load-balanced) — spreads introspection load horizontally.
2. **Increase introspection cache TTL where feasible** (5min for compliance, but 10min for non-payment APIs reduces load 2×).
3. **Use token introspection result caching at API gateway** (APIM caches introspection results for TTL; backend APIs don't introspect repeatedly).
4. **Separate read replicas** for read-heavy operations (JWKS, introspection); write operations (token issuance, revocation) go to primary.

Expected load after scaling: 3–5 IS 7.3 nodes, 1 database replica, 1 APIM gateway cluster.

## Lab

Complete the capstone exercises in `labs/capstone/`:

1. **`architecture.md`** — 5 Mermaid sequence diagrams covering: (1) Customer FAPI 2.0 + SCA flow, (2) B2B mTLS flow, (3) AI agent OBO + AgentCore flow, (4) IS 7.3 hub with all three flows, (5) Token lifecycle and revocation.
2. **`configs/is73_hub_config.toml`** — annotated IS 7.3 deployment config for all three flows.
3. **`configs/agentcore_delegation_config.json`** — AgentCore IAM role and federation config.
4. **`decision_tree.md`** — Mermaid flowchart routing all caller types to the right protocol.
5. **`ADR.md`** — Architecture Decision Record justifying the hub design.

**Success signal**: You can explain to a teammate why each diagram matters, why each config setting is there, and why IS 7.3 + AgentCore is the right choice for a bank deploying all three flows.
