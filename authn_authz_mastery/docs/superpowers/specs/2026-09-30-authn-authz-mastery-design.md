# AuthN/AuthZ Mastery — Design Spec

**Date:** 2026-09-30
**Location:** `authn_authz_mastery/`
**Duration:** 30 days, ~3h/day (~90h total)
**Phases:** 3 × 10 days — each phase is a self-contained execution unit

---

## Purpose & Goals

This course closes the gap between a strong WSO2 practitioner (wso2_mastery complete) and a principal-level
identity architect who can design and defend the full authentication and authorization stack for a
banking/fintech company adopting WSO2 IS 7.3, WSO2 APIM 4.7, and AWS AgentCore Gateway with AI agent
integration.

The learner is a strong Go engineer with deep WSO2 APIM/IS internals, OAuth2/OIDC fundamentals, JWT, and
API gateway mediation already mastered. This course builds the next layer: the hard protocols that banking
regulators and FAPI compliance demand, the new IS 7.3 capabilities that go beyond the Key Manager focus of
wso2_mastery, and the emerging AI agent identity layer (OBO chains, AgentCore delegation, MCP service auth)
that the company needs to architect in the near term.

The primary deliverable is a real architect output — sequence diagrams, annotated WSO2 and AgentCore config
stubs, a protocol decision tree, and an Architecture Decision Record — that teammates can act on
immediately for backend service integration with the WSO2 stack plus AI agent connectivity.

---

## Success Criteria

By the end of the 30 days, the learner can, without notes:

1. Draw the full FAPI 2.0 + PAR + RAR + CIBA + DPoP + mTLS composite banking auth flow and explain why
   each protocol layer is present.
2. Configure WSO2 IS 7.3 for FAPI 2.0 compliance mode, CIBA backchannel endpoint, and DPoP/mTLS token
   binding from memory.
3. Design a B2B organization model in IS 7.3 (root org → sub-orgs, org-scoped tokens, per-org external IdP
   federation) for a banking partner integration scenario.
4. Implement an app-native authentication flow and adaptive auth policy in IS 7.3 using the REST auth API
   and JavaScript engine.
5. Trace a complete OBO (RFC 8693) delegation chain from a user token through an AI agent to a
   WSO2-protected backend API, naming each token exchange, claim, and trust boundary.
6. Explain how AWS AgentCore Gateway vends credentials to AI agents, how it federates trust with WSO2 IS
   7.3, and how MCP tools authenticate to IS 7.3-protected services.
7. Produce a team-shareable architect deliverable (sequence diagrams, IS 7.3 + AgentCore config stubs,
   decision tree, ADR) covering the company's three integration scenarios: customer-facing banking app,
   B2B partner API, and AI agent integration.

---

## Constraints & Environment

| Constraint | Rule |
|---|---|
| Lab mode | Theory + architecture diagrams (Mermaid) + annotated config stubs as primary; local Docker (WSO2 IS 7.3 container) for Phase 2 labs that benefit from it |
| Real infra | No `terraform apply`, no cloud CLI against real accounts during authoring |
| Credentials | Never write real secrets, keys, tokens, or account IDs — placeholders + fill-in comments only |
| Git commits | User handles all VCS; never commit on their behalf |
| Git in subagents | No `git status`, `git diff`, `git log` in any implementer or reviewer dispatch |
| Exercises | Every exercise ships with Hint + Solution sketch — no bare problems |
| Prerequisite | Assumes wso2_mastery Phase 1 (OAuth2/OIDC, Key Manager, JWT) complete — do not re-explain basics |
| Authorized testing | Any offensive/security lab targets only the learner's own deployed instance |

---

## Strategy

**The unconventional top-1% approach for this domain:**

Most engineers learn identity protocols by reading RFCs in isolation. This course flips the order: every
protocol is introduced through the failure mode or attack it was designed to prevent. You learn PAR because
you first understand front-channel authorization request leakage. You learn DPoP because you understand
bearer token theft at the TLS termination proxy. This anchors the "why" before the "how" and makes the
config details stick.

The second insight is that RFC 8693 (Token Exchange / OBO) is the master key for the entire AI agent
identity domain. Every AI agent auth pattern — AgentCore delegation, MCP tool auth, cross-service agent
calls — is a specialization of the token exchange primitive. Phase 3 radiates outward from day 23 (OBO)
rather than introducing each pattern independently.

**Mistakes that waste 80% of beginners' time:**

- Treating FAPI 2.0 as a checklist of flags rather than a coherent threat model — leads to compliant-on-paper but insecure configs
- Configuring IS 7.3 CIBA without understanding poll vs. push mode tradeoffs — causes silent failures in mobile banking flows
- Conflating `client_credentials` grant with agent identity — agents need OBO (delegated user context), not service account tokens
- Building MCP tool auth with API keys instead of scoped OAuth2 tokens — breaks auditability and revocation
- Skipping the `actor` and `may_act` claims in OBO — breaks downstream trust chain verification
- Treating B2B org management in IS 7.3 as just multi-tenancy — misses the federated IdP-per-org model that banking partners require

---

## Curriculum

### Phase 1 — Hard Protocols (Days 1–10)
Banking/fintech lens: every protocol introduced via its threat model, then its mechanics.

| Day | Title | Core Topics |
|-----|-------|-------------|
| 1 | FAPI 2.0 Security Profile | Threat model, PAR mandatory, PKCE enforced, JARM (JWT-secured auth response), `response_mode=jwt`, FAPI 2.0 vs FAPI 1.0 |
| 2 | PAR — Pushed Authorization Requests | RFC 9126: `request_uri` lifecycle, replay protection, front-channel leakage attack, PAR endpoint mechanics |
| 3 | RAR — Rich Authorization Requests | RFC 9396: `authorization_details` object, banking `type` values (payment_initiation, account_information), composing granular scopes beyond string scopes |
| 4 | CIBA — Backchannel Authentication | Poll/ping/push modes, `auth_req_id`, decoupled consent (server-side call, user on mobile), banking headless flow patterns |
| 5 | DPoP — Proof-of-Possession Tokens | RFC 9449: DPoP proof JWT construction, `jti`+`ath` binding, sender-constrained tokens, replay defence at the resource server |
| 6 | mTLS Client Auth + Certificate-Bound Tokens | RFC 8705: `tls_client_auth` vs `self_signed_tls_client_auth`, `cnf.x5t#S256` binding, PKI chain in banking, mTLS at the API gateway |
| 7 | SCIM 2.0 Provisioning | RFC 7643/7644: schemas, `/Users` `/Groups` endpoints, PATCH ops, JIT provisioning vs. scheduled sync, B2B org user federation |
| 8 | Consent Management | PSD2 consent lifecycle: creation → confirmation → authorized use → revocation, consent receipts, `claims` parameter patterns, consent as a first-class resource |
| 9 | SCA — Strong Customer Authentication | PSD2 RTS: possession + knowledge + inherence factors, dynamic linking to transaction, exemptions (low-value, TRA, merchant whitelist), step-up auth trigger |
| 10 | Protocol Composition | How FAPI 2.0 + PAR + RAR + CIBA + DPoP + mTLS assemble into one coherent banking auth flow; protocol decision tree: which combination for which banking use case |

### Phase 2 — WSO2 IS 7.3 Deep-dive (Days 11–20)
What IS 7.3 adds beyond wso2_mastery Phase 1. Assumes Key Manager, token flows, and APIM integration
already known.

| Day | Title | Core Topics |
|-----|-------|-------------|
| 11 | App-Native Authentication | IS 7.3 REST auth API (`/authn`), step-based visual flow builder in Console, replacing redirect flows for mobile/SPA, stateful auth session model |
| 12 | Adaptive Authentication | JavaScript-based adaptive auth engine, `onLoginRequest` hook, risk factor injection (IP, device, user history), conditional step insertion, session context object |
| 13 | FAPI 2.0 Compliance Mode | Enabling FAPI profile in IS 7.3, PAR endpoint config, JARM response signing key, PKCE enforcement flag, FAPI-compliant client registration via DCR |
| 14 | CIBA in IS 7.3 | Backchannel authentication endpoint, poll vs. push mode config, `auth_req_id` lifecycle management, consent portal integration for CIBA flows |
| 15 | DPoP + mTLS in IS 7.3 | Token binding config, certificate extraction from TLS termination, `cnf` claim injection into access token, token introspection with binding validation |
| 16 | B2B Organization Management | IS 7.3 org hierarchy: root org → sub-orgs, org-scoped token issuance, B2B federation (external IdP registered per sub-org), shared application model, cross-org token exchange |
| 17 | FIDO2 / Passkeys | IS 7.3 WebAuthn API: registration ceremony, assertion ceremony, resident keys (passkeys), `userVerification` policy, fallback authenticator chains |
| 18 | RAR + Consent Portal | IS 7.3 `authorization_details` parsing, consent portal customization, per-resource consent record storage, consent revocation API, linking RAR to PSD2 consent object |
| 19 | IS 7.3 Extension Points | Custom Authenticator SPI (Java interface + deployment), custom grant handler, Identity Event framework (pre/post events), event publisher to Choreo or webhook |
| 20 | IS 7.3 + APIM 4.7 Integration Patterns | Key Manager interface changes in IS 7.3, new token validation path, subscription enforcement updates, gateway–IS token exchange patterns beyond wso2_mastery Phase 1 (org-scoped tokens, FAPI-mode gateway) |

### Phase 3 — AI Agent Identity + Capstone (Days 21–30)
Agent auth fundamentals → OBO as the master pattern → AWS AgentCore Gateway → MCP → IS 7.3 as agent IdP
→ capstone architect deliverable.

| Day | Title | Core Topics |
|-----|-------|-------------|
| 21 | Agent Identity Fundamentals | What makes agent auth structurally different from human auth: principal hierarchies, delegation chains, confused deputy problem, audit trail requirements, token lifetime strategy |
| 22 | JWT Bearer Assertion (RFC 7523) | Service-to-service auth without shared secrets: `sub`=service, `iss`=client, `aud`=token endpoint, private key JWT, structured claims for agent identity |
| 23 | OBO — On-Behalf-Of (RFC 8693) | Token exchange spec: `subject_token`, `actor` claim, `may_act`, downstream token minting, chain depth limits, how to trace a multi-hop delegation |
| 24 | AWS AgentCore Gateway Architecture | Gateway identity model, IAM role assumption per agent, request signing (SigV4), credential vending lifecycle, how AgentCore proxies agent-to-API calls |
| 25 | AgentCore Gateway OBO Patterns | How AgentCore uses RFC 8693 token exchange to call WSO2-protected APIs on behalf of an authenticated user; trust federation between AWS IAM and WSO2 IS 7.3 |
| 26 | MCP Service Authentication | OAuth2 for MCP (MCP auth spec): tool discovery, dynamic client registration, scoped tool tokens, IS 7.3 as OAuth2 auth server for MCP tool calls |
| 27 | WSO2 IS 7.3 as Agent IdP | Configuring IS 7.3 to issue tokens for AI agents: `token-exchange` grant type, agent policy enforcement, scope mapping for agent principals, audit log tagging |
| 28 | End-to-End Delegation Chain | Full trace: user authenticates → human token → agent exchanges (OBO) → MCP tool call → backend API; token lifetimes at each hop, revocation propagation, audit trail design |
| 29 | Architecture Synthesis | Design the company's full integration blueprint: customer-facing banking app flow + B2B partner flow + AI agent flow, all sharing IS 7.3 as the identity hub; identify shared primitives and per-flow divergences |
| 30 | Capstone Architect Deliverable | Produce team-shareable document: 5 Mermaid sequence diagrams, annotated IS 7.3 + AgentCore config stubs, protocol decision tree, ADR for adopting this stack |

---

## Directory Layout

```
authn_authz_mastery/
├── README.md                           # quickstart, phase map, day index, usage
├── STRATEGY.md                         # unconventional top-1% approach + mistakes to avoid
├── PROGRESS.md                         # phase handoff file — current status + next session instructions
├── content/
│   ├── GLOSSARY.md                     # plain-English terms (protocols, IS 7.3, AgentCore, MCP)
│   ├── day01.md … day30.md
│   └── appendices/
│       ├── PROTOCOL_DECISION_TREE.md   # which protocol combination for which banking use case
│       └── FAPI_BANKING_REFERENCE.md   # FAPI 2.0 quick-reference card
├── labs/
│   ├── day01/ … day28/
│   │   ├── README.md                   # lab goal + success signal
│   │   ├── diagram.md                  # Mermaid sequence/flow diagrams
│   │   ├── config/                     # annotated config stubs (IS 7.3, AgentCore, APIM)
│   │   └── SOLUTION.md                 # solution explanation + expected output
│   └── capstone/
│       ├── architecture.md             # 5 sequence diagrams (team-shareable)
│       ├── configs/                    # IS 7.3 + AgentCore annotated config stubs
│       ├── decision_tree.md            # protocol decision tree
│       └── ADR.md                      # Architecture Decision Record
└── docs/superpowers/
    ├── specs/
    │   └── 2026-09-30-authn-authz-mastery-design.md  ← this file
    └── plans/
        ├── 2026-09-30-authn-authz-phase1-plan.md
        ├── 2026-09-30-authn-authz-phase2-plan.md
        └── 2026-09-30-authn-authz-phase3-plan.md
```

---

## Content Day Skeleton

```markdown
# Day N — <Title>

## Why this matters
<1 paragraph: concrete banking/AI-agent scenario where missing this knowledge causes a real incident or
wrong design decision>

## Core concepts
<Theory, protocol mechanics, flow description; Mermaid diagrams inline where the concept is visual>

## WSO2 IS 7.3 / AgentCore mapping
<How this protocol/pattern maps to the specific IS 7.3 config or AgentCore feature.
Omit on pure-protocol days (1–10) where it is premature.>

## Anti-patterns / Common mistakes
<2–3 bullets — what teams get wrong, especially in banking contexts>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
3. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>

## Lab
See `labs/dayNN/`. Goal: <one line>. Success signal: <one line>.
```

---

## PROGRESS.md Template

```markdown
# AuthN/AuthZ Mastery — Progress Tracker

**Spec:** `docs/superpowers/specs/2026-09-30-authn-authz-mastery-design.md`
**Total:** 3 phases × 10 days = 30 days, 3h/day (~90h)

## Current Status

| Phase | Days  | Title                          | Status         |
|-------|-------|--------------------------------|----------------|
| 1     | 1–10  | Hard Protocols                 | ⬜ NOT STARTED |
| 2     | 11–20 | WSO2 IS 7.3 Deep-dive          | ⬜ NOT STARTED |
| 3     | 21–30 | AI Agent Identity + Capstone   | ⬜ NOT STARTED |

## Session Log

| Date | Session goal | Result |
|------|-------------|--------|
| 2026-09-30 | Brainstorm + spec | Spec written. 3-phase breakdown complete. |

## Next Session Instructions

Start Phase 1 plan: invoke writing-plans skill, pointer to this spec, produce
`docs/superpowers/plans/2026-09-30-authn-authz-phase1-plan.md`.
```
