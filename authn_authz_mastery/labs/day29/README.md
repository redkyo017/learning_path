# Day 29 Lab — Architecture Synthesis

## Objective

Design and compare three integration flows (customer-facing FAPI 2.0, B2B partner mTLS, AI agent OBO) converging on a single IS 7.3 hub. Success signal: you can explain how the same IS 7.3 instance serves divergent security requirements without fragmentation, and you can fill in the synthesis comparison table with substantive analysis.

## Scenario

A bank is consolidating identity infrastructure. Currently, they operate:
- **Customer-facing banking app** using FAPI 2.0 with SCA (separate IS 7.3 instance or auth service)
- **B2B partner API** using mTLS for organization-level integrations (separate or same IS 7.3?)
- **AI agent system** using RFC 8693 token exchange (new feature, unclear whether to run separate or integrate)

**Problem:** Three distinct flows, each with different compliance drivers and threat models. Running separate IS 7.3 instances triples operational cost. But can a single hub safely serve all three?

## What you'll produce

1. **Comparison table** (6 dimensions × 3 flows):
   - Auth method, token binding, audit claim, revocation mechanism, APIM enforcement, regulatory driver
   - One row per dimension; each column is a flow

2. **IS 7.3 hub diagram** (Mermaid):
   - All three flows converging on central IS 7.3 instance
   - Shared endpoints: PAR, JWKS, introspection, DCR
   - Per-flow divergences shown as branching paths

3. **Deployment.toml mapping**:
   - Which sections of deployment.toml enable each flow
   - Console application config (what to set per application)

4. **Audit log query examples**:
   - One query per flow showing how to filter/trace each integration pattern

## Steps

### Step 1: Review the scenario

Three flows, one hub. Each flow has different security posture:
- Customer app: user-centric, SCA-required, revocation within 5min
- B2B partner: org-centric, mTLS-based, can tolerate longer revocation (24h token lifetime)
- AI agent: agent-centric, delegation chain, per-user auditability

### Step 2: Study the comparison table template

Open `config/synthesis_flows.md`. This file outlines the six dimensions and three flows. You'll fill in the table with the characteristics of each.

### Step 3: Analyze each flow

**Flow 1: Customer App (FAPI 2.0)**
- Auth: Authorization Code + PAR + RAR (Day 4, 8)
- Strong auth: SCA via FIDO2/passkey or TOTP (Day 17)
- Token binding: DPoP (Demonstration of Possession, Day 16)
- Response format: JARM (JWT-encoded response, Day 9)
- Scope: User-driven granular consent (payments:read, payments:write, accounts:read, etc.)
- Revocation: User-initiated; propagates within 5min via introspection

**Flow 2: B2B Partner (mTLS)**
- Auth: mTLS (mutual TLS, Day 6); client certificate identifies the partner organization
- Client cert: Issued by bank's PKI; embedded in TLS handshake
- Token structure: Org-scoped (org_id claim); certificate hash bound (cnf.x5t#S256)
- Scope: Partner-specific (partner-api:read, partner-api:write)
- Revocation: Admin-initiated; typically weekly or as-needed

**Flow 3: AI Agent (OBO)**
- Auth: RFC 8693 token exchange (Day 23); `private_key_jwt` client auth (Day 22)
- User identity: Flows from initial user login; preserved via `sub` claim
- Agent identity: Each agent has client_id; recorded in `act` claim
- Token structure: `sub=user`, `act=agent_id` (single or nested)
- Scope narrowing: Each exchange narrows scope to agent-specific capabilities
- Revocation: User-initiated; propagates to all agent tokens via introspection

### Step 4: Fill the comparison table

Use `config/synthesis_flows.md` template. Rows:
1. **Auth method** — How does the client prove identity? (Authorization Code, mTLS, token exchange)
2. **Token binding** — How is the token bound to prevent theft/replay? (DPoP, certificate hash, scope narrowing)
3. **Audit claim** — What claim identifies the principal? (`sub` for user, `org_id` for org, `act` for agent)
4. **Revocation mechanism** — How is token invalidation propagated? (User-initiated, admin-initiated, schedule-based)
5. **APIM enforcement** — What does APIM gateway verify? (Scope, org_id subscription, agent authorization)
6. **Regulatory driver** — What compliance requirement drives this pattern? (PSD2 SCA, B2B audit trail, agent auditability)

### Step 5: Design the IS 7.3 hub diagram

The diagram should show:
- Central IS 7.3 instance
- Three incoming flows (customer app, B2B partner, AI agent)
- Shared endpoints (PAR, JWKS, introspection, DCR)
- Three outgoing flows to resource servers (APIM, partner API, payment API)

Mermaid diagram structure:
```
graph LR
  App[Customer App] -->|OAuth Code Flow| IS73{IS 7.3 Hub}
  Partner[B2B Partner] -->|mTLS| IS73
  Agent[AI Agent] -->|Token Exchange| IS73
  
  IS73 -->|Token| APIM[APIM Gateway]
  IS73 -->|Token| PartnerAPI[Partner API]
  IS73 -->|Token| PaymentAPI[Payment API]
```

### Step 6: Analyze shared vs. divergent infrastructure

**Shared (all three flows use):**
- PAR (`/oauth2/par`) — secure authorization request initiation
- JWKS (`/oauth2/jwks`) — JWT key set for signature verification
- Introspection (`/oauth2/introspect`) — token status check
- DCR (`/api/identity/oauth2/dcr/v1.1/register`) — client registration
- Audit log — centralized record of all auth events

**Divergent (per-flow customization):**
- **Customer app:** PKCE, JARM response, SCA enforcement, DPoP validation
- **B2B partner:** mTLS cert validation, org_id claim mapping, cert hash binding
- **AI agent:** Token exchange grant, actor trust policy, `act` claim processing, scope narrowing

### Step 7: Map deployment.toml

Identify which deployment.toml sections enable each flow:
- `[oauth]` — global grant type enablement (affects all flows)
- `[oauth.jwt]` — JARM response encoding (customer app)
- `[oauth.mtls]` — mTLS client auth (B2B partner)
- `[oauth.token_exchange]` — RFC 8693 support (AI agent)
- `[log.audit]` — structured logging (all flows benefit)

### Step 8: Write audit query examples

For each flow, write a SQL or query pattern to extract relevant audit entries:
- **Customer app:** Query by `client_id` (mobilebank) and `event_type=authorization` or `token_issue`
- **B2B partner:** Query by `org_id` and look for `mtls_auth_success` events
- **AI agent:** Query by `act.sub` (agent client_id) to find all agent-initiated token exchanges

## Success Criteria

- Comparison table is complete with 6 rows and 3 columns
- Each cell contains substantive analysis (not placeholder text)
- IS 7.3 hub diagram is clear and shows shared/divergent endpoints
- You can explain why a single hub is better than three separate instances
- You can describe the trade-off: single point of failure vs. operational simplicity
- deployment.toml sections are mapped to flows with explanations
- Audit query examples are specific (not generic)

## Time estimate

60–80 minutes

## Key concepts (reference Day 29 content)

- **IS 7.3 hub** — single OAuth2 server supporting multiple integration patterns
- **Shared primitives** — PAR, JWKS, introspection, DCR used by all flows
- **Per-flow divergences** — auth method, token binding, audit claims
- **Unified audit trail** — all flows record to same log; enables cross-flow audit queries
- **Operational consolidation** — one IS 7.3 to operate, maintain, monitor
