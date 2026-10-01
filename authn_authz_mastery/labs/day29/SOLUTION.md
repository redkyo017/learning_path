# Day 29 Lab — Solution

## Completed Comparison Table

| Dimension | **Flow 1: Customer App (FAPI 2.0)** | **Flow 2: B2B Partner (mTLS)** | **Flow 3: AI Agent (OBO)** |
|-----------|------|-------|---------|
| **1. Auth Method** | Authorization Code + PAR + PKCE. User proves identity via App-Native Auth (username/password + 2FA). PKCE prevents authorization code interception on the device. PAR secures the authorization request from tampering in transit. No shared secret (mobile app cannot securely store one). | Client Credentials grant with mTLS. Partner organization proves identity via client certificate (issued by bank's PKI). Certificate subject CN identifies the partner. No user context (machine-to-machine flow). Certificates are rotated annually or as-needed for security. | RFC 8693 Token Exchange. Agent proves identity via private_key_jwt client authentication (Day 22): JWT signed with agent's private key, validated by IS 7.3 against agent's JWKS. Subject token is the user's access token (delegation source). Actor token is the agent's JWT (proof of agent identity). |
| **2. Token Binding** | DPoP (Demonstration of Possession, Day 16). Token is cryptographically bound to the mobile app's public key. Every API request requires a DPoP proof (signed timestamp + public key hash + method + URI). If token is stolen, attacker cannot use it without the app's private key. Prevents token replay and theft. | Certificate hash binding (cnf.x5t#S256 claim). Token includes SHA-256 hash of the partner's client certificate. Payment API verifies: (1) token signature is valid, (2) cnf.x5t#S256 matches the certificate presented in the TLS handshake. If stolen from a non-partner, token is useless without the matching certificate. | Scope narrowing + act claim chain. Token scope is restricted to agent-specific capabilities (e.g., agent:payments:initiate, not full payments:write). Additionally, the act claim records the full agent delegation chain (sub + act nesting). If stolen by an unrelated service, narrow scope limits damage. Missing or mismatched act claim signals unauthorized use. |
| **3. Audit Claim** | `sub` (user subject, e.g., alice_001). `aud` (audience = mobilebank). `scope` (permissions granted). Audit log query: SELECT * FROM audit WHERE sub='alice_001' AND timestamp > now-24h. Result: all actions by user alice_001, with scope and timestamp. Enables user-centric audit trail (for compliance: "show all actions by user X"). | `sub` (organization ID, e.g., org_id=partner_123). `cnf.x5t#S256` (certificate hash). `iss` (token issuer = IS 7.3). Audit log query: SELECT * FROM audit WHERE org_id='partner_123' AND event_type='token_issue' AND timestamp > now-7d. Result: all tokens issued to partner_123, with timestamps. Enables organization-level audit trail (for compliance: "show all partner activity"). | `sub` (user subject, e.g., alice_001). `act` (agent identity; single-hop: {sub: risk_scorer}, or nested for multi-hop: {sub: risk_scorer, act: {sub: payment_orchestrator}}). `jti` (unique token ID for correlation). Audit log query: SELECT * FROM audit WHERE sub='alice_001' AND actor_client='risk_scorer' AND timestamp > now-24h. Result: all token exchanges for alice_001 by risk_scorer. Enables agent-per-user audit (for compliance: "show all actions by agent X on behalf of user Y"). |
| **4. Revocation Mechanism** | User-initiated. User clicks "Sign out everywhere" in mobile app → IS 7.3 token revoke endpoint → human token revoked. Propagation: introspection-based. APIM gateway introspects every token on every request. IS 7.3 introspection checks the token's validity; if revoked, returns active=false. Cache TTL = 5 minutes (banking compliance: revocation propagates within 5 min). Result: all active user tokens become invalid within 5 minutes. Sub-5-minute latency is achievable if APIM introspects without caching (trade-off: more IS 7.3 load). | Admin-initiated. Bank operator revokes partner's certificate (certificate expires, is revoked in PKI system) or updates org_id revocation list. Propagation: Long-lived tokens (24h lifetime) are typically not revoked mid-lifetime; instead, partner's next authentication attempt is denied. For emergency revocation: certificate is added to CRL (Certificate Revocation List); payment API may not check CRL frequently (not real-time). Result: revocation latency can be hours or even until token expires naturally. Acceptable for B2B integrations (lower security bar than customer-facing); different from banking compliance for consumer payments. | User-initiated. Same as customer app: user revokes session → human token revoked. Propagation: introspection-based, same chain-check logic. If user revokes at T=60min, derived agent tokens are not explicitly revoked. But when payment API calls introspect on an agent token at T=65min, IS 7.3 checks the chain: agent_token.subject = orchestrator_token, orchestrator_token.subject = human_token, human_token.revoked? YES → introspection returns active=false. Result: all agent tokens become invalid within 5 minutes (cache TTL). Multi-hop chains are also validated: revocation at the top (user) breaks the entire chain. |
| **5. APIM Enforcement** | APIM validates: (1) scope (user requested scope=payments:write, APIM checks token has payments:write), (2) DPoP proof (token is bound to caller; APIM verifies DPoP signature), (3) user_id (identify the user for audit log). Rate limit: 1000 calls/hour per user_id (per-user quota; different users have independent limits). Additional policy: if scope=payments:initiate AND amount > 100, trigger SCA verification step (user must enter OTP from authenticator). Routing: forward to APIM backend (payment API, accounts API, etc.) with Authorization: Bearer token header. | APIM validates: (1) org_id (org_id claim in token matches partner's subscription), (2) certificate hash (cnf.x5t#S256 matches TLS certificate subject), (3) org_id subscription (is partner's org subscribed to this API? Check subscription database). Rate limit: 10000 calls/hour per org_id (per-organization quota; allows high throughput for enterprise partners). Additional policy: if endpoint is sensitive (e.g., export data), require additional authentication (e.g., IP whitelist, additional cert pin). Routing: forward to backend API with Authorization: Bearer token. | APIM validates: (1) scope (agent scope is authorized for the resource; agent:payments:initiate allows payments initiation), (2) act claim (agent identity is recorded; act.sub is in allow-list of authorized agents), (3) sub claim (user is recorded; enables audit trail linking). Rate limit: 5000 calls/hour per agent_id (per-agent quota; agents aggregate multiple user requests, so higher than per-user limit of 1000). Additional policy: if agent_id is unknown (not in allow-list), log security event, rate-limit aggressively (100 calls/hour for unknown agents), and alert security team. Routing: forward to backend API with both token and X-AgentCore-Caller-Identity header (if AgentCore proxy is used). |
| **6. Regulatory Driver** | PSD2 (Payment Services Directive, EU). Requires: (1) Strong Customer Authentication (SCA) for payments — addressed by SCA policy (FIDO2 or TOTP). (2) User consent for data access — addressed by RAR (Rich Authorization Request) for granular consent (consent per account, per scope). (3) User revocation rights — addressed by instant revocation (sign out everywhere) and introspection-based propagation (≤5 min). (4) Open data (PSD2 Open Banking) — token-based access to partner APIs, enabled by OAuth2 + scope-based authorization. Bank is compliant: every customer payment has SCA, consent, and audit trail. | B2B Service Agreements + Internal Audit Requirements. Partners require: (1) Guaranteed uptime and low latency — addressed by long token lifetimes (24h, fewer auth calls to IS 7.3). (2) Organization-level audit trail — addressed by org_id claim in all logs (audit queries per partner). (3) Secure client authentication — addressed by mTLS (no shared secrets, certificates are industry standard). (4) Service Level Agreements (SLAs) — partner quotas (10k calls/hour) ensure fair resource allocation. Bank is operationally efficient: reduced auth overhead, per-partner audit, and partner data isolation. | Agent Auditability + User Consent Compliance (emerging regulatory requirement for AI agents). Regulators require: (1) Every API call traceable to the human user who initiated it — addressed by sub claim (user identity is preserved). (2) Every agent in the delegation chain recorded — addressed by act claim (single or nested nesting). (3) User can revoke agent access instantly — addressed by user-initiated revocation (same as customer app). (4) Agent cannot escalate beyond user's scope — addressed by scope narrowing at each exchange (user scope >= orchestrator scope >= tool scope). Bank is audit-compliant: regulators can query audit log to reconstruct any agent action and trace it to the authorizing user. |

---

## IS 7.3 Hub Diagram (Filled In)

### Full Annotated Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    IS 7.3 Hub (Central)                     │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Shared Endpoints (All Flows)               │  │
│  │  • PAR (/oauth2/par)                                │  │
│  │  • JWKS (/oauth2/jwks)                              │  │
│  │  • Introspection (/oauth2/introspect)               │  │
│  │  • DCR (/api/identity/oauth2/dcr/v1.1/register)     │  │
│  │  • Token Endpoint (/oauth2/token)                   │  │
│  │  • Structured Audit Log (JSON)                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Flow 1 Config   │  │  Flow 2 Config   │               │
│  │  (Customer App)  │  │  (B2B Partner)   │               │
│  │  • PKCE enabled  │  │  • mTLS enabled  │               │
│  │  • JARM response │  │  • Org scoping   │               │
│  │  • DPoP binding  │  │  • Cert hash     │               │
│  │  • SCA policy    │  │  • Long TTL      │               │
│  └──────────────────┘  └──────────────────┘               │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │        Flow 3 Config (AI Agent)                     │  │
│  │  • Token exchange grant enabled                     │  │
│  │  • private_key_jwt client auth                      │  │
│  │  • Actor trust policies (org-specific)              │  │
│  │  • Scope narrowing enforced                         │  │
│  │  • Act claim nesting                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘

      ↓ Incoming Flows ↓         ↓ Outgoing Flows ↓
┌─────────────────────┐      ┌──────────────────────┐
│ Mobile App          │      │ APIM Gateway         │
│ (Flow 1)            │      │ • Validates scope    │
│ Authorization Code  │      │ • Verifies DPoP      │
│ + PAR + PKCE        │      │ • Rate limits users  │
└─────────────────────┘      │ • Logs all calls     │
                              └──────────────────────┘
┌─────────────────────┐      ┌──────────────────────┐
│ Partner App         │      │ Partner API          │
│ (Flow 2)            │      │ • Validates org_id   │
│ mTLS Cert Auth      │      │ • Verifies cert hash │
│ Client Credentials  │      │ • Rate limits orgs   │
└─────────────────────┘      └──────────────────────┘
┌─────────────────────┐      ┌──────────────────────┐
│ Agent Orchestrator  │      │ Payment API          │
│ (Flow 3)            │      │ • Validates act      │
│ Token Exchange      │      │ • Verifies chain     │
│ private_key_jwt     │      │ • Rate limits agents │
└─────────────────────┘      └──────────────────────┘

All flows log to: Unified Audit Log
Correlation: All tokens have `jti` (or derived IDs like sessionId)
Query pattern: WHERE jti=<value> OR actor_client=<value> OR org_id=<value>
```

---

## deployment.toml Mapping (Completed)

### Global Configuration

```toml
[oauth]
allowed_grant_types = [
  "authorization_code",
  "refresh_token",
  "client_credentials",
  "urn:ietf:params:oauth:grant-type:token-exchange"
]
# All grant types enabled; Console per-app config decides which each app uses

[oauth.jwt]
enable_jarm = true
# JARM (JWT-encoded responses) for Flow 1 (customer app)
# Other flows use standard application/json responses

[oauth.mtls]
enable_client_auth = true
certificate_validation = true
# mTLS support for Flow 2 (B2B partner)

[oauth.token_exchange]
enable = true
max_actor_chain_depth = 3
introspection_cache_ttl_seconds = 300
# RFC 8693 support for Flow 3 (AI agent)
# Max depth prevents runaway delegation chains
# 300s (5 min) cache TTL ensures revocation propagates within banking compliance window

[log.audit]
log_format = "structured"
# JSON logging enables all flows to benefit from query-friendly audit format
# Fields: timestamp, event_type, sub, org_id, actor_client, scope, jti, etc.
```

### Per-Application Configuration (Console)

**App 1: MobileBank**
```
Name: MobileBank
Client ID: mobilebank
Client Type: Public
Grant Types: authorization_code, refresh_token
Token Endpoint Auth: PKCE (no secret)
Response Type: code
Response Mode: jwt (JARM)
Redirect URIs: https://mobilebank.bank.com/callback
Scopes:
  - payments:read
  - payments:write
  - accounts:read
  - accounts:write
  - openid
  - profile
DPoP Binding: Enabled
SCA Policy:
  - Condition: scope CONTAINS "payments:write"
  - Effect: Require SCA (FIDO2 or TOTP)
Token Lifetime: 3600 (1 hour)
Refresh Token Lifetime: 604800 (7 days)
```

**App 2: PartnerAPI**
```
Name: PartnerAPI
Client ID: partner-api
Client Type: Confidential
Grant Types: client_credentials
Token Endpoint Auth: mtls_client_auth
Certificate Requirements:
  - Issuer: CN=Bank Root CA
  - Org ID Claim: Extract from certificate subject alt name
Redirect URIs: (none)
Scopes:
  - partner-api:read
  - partner-api:write
Token Lifetime: 86400 (24 hours)
Certificate Rotation: Annual + ad-hoc for revocation
```

**App 3: AgentOrchestrator**
```
Name: AgentOrchestrator
Client ID: payment_orchestrator
Client Type: Confidential
Grant Types: urn:ietf:params:oauth:grant-type:token-exchange
Token Endpoint Auth: private_key_jwt
JWKS URI: https://agent-platform.bank.com/.well-known/jwks.json
Redirect URIs: (none)
Scopes:
  - agent:payments:initiate
  - agent:accounts:read
  - agent:payments:read
Actor Trust Policies:
  - Actor: payment_orchestrator, Subject: group:financial-users, Effect: Allow
  - Actor: risk_scorer, Subject: group:financial-users, Effect: Deny (pending security review)
  - Actor: *, Subject: group:super-admins, Effect: Deny (catch-all)
Token Lifetime: 900 (15 minutes for orchestrator exchange)
Sub-Applications (registered via DCR):
  - Client ID: risk_scorer, JWKS: https://risk-scorer.bank.com/.well-known/jwks.json
  - (More tool agents as needed)
```

---

## Audit Query Examples (Completed)

### Flow 1: Customer App

**Query: All authentications by user alice_001 in past 24 hours**
```sql
SELECT timestamp, event_type, scope, result_status, client_id
FROM is73_audit
WHERE event_type IN ('authorization', 'token_issue', 'token_refresh')
  AND sub = 'alice_001'
  AND timestamp >= now() - interval '24 hours'
ORDER BY timestamp DESC;
```

**Result:** Shows all logins, token refreshes, and scope grants for alice_001. Compliance can verify: "User logged in at 10:00 AM, requested payments:write scope, SCA was required and passed, token issued."

**Query: All SCA challenges failed in past hour**
```sql
SELECT timestamp, sub, sca_method, error_code
FROM is73_audit
WHERE event_type = 'sca_challenge'
  AND result_status = 'failure'
  AND timestamp >= now() - interval '1 hour'
ORDER BY timestamp DESC;
```

**Result:** Identifies potential fraud attempts (repeated SCA failures). Security team can investigate.

---

### Flow 2: B2B Partner

**Query: All API calls by partner org_id='partner_123' in past 7 days**
```sql
SELECT timestamp, event_type, endpoint, method, result_status, http_status_code
FROM is73_audit
WHERE org_id = 'partner_123'
  AND timestamp >= now() - interval '7 days'
ORDER BY timestamp DESC;
```

**Result:** Shows all partner activity: token requests, introspection calls, potential errors. Partners can self-audit or provide to their compliance team.

**Query: Certificate authentications for partner_123**
```sql
SELECT timestamp, cert_subject, cert_issuer, auth_result, token_jti
FROM is73_audit
WHERE event_type = 'mtls_auth'
  AND org_id = 'partner_123'
  AND timestamp >= now() - interval '30 days'
ORDER BY timestamp DESC;
```

**Result:** Tracks certificate-based authentications, enables certificate rotation audits.

---

### Flow 3: AI Agent

**Query: All token exchanges by agent risk_scorer in past 24 hours**
```sql
SELECT timestamp, subject_client, actor_client, issued_scope, policy_result, token_jti
FROM is73_audit
WHERE actor_client = 'risk_scorer'
  AND event_type = 'token_exchange'
  AND timestamp >= now() - interval '24 hours'
ORDER BY timestamp DESC;
```

**Result:** Shows which users were delegated tokens to risk_scorer, what scope was granted, whether policy allowed the exchange. Security team can verify policy is being enforced.

**Query: All agent actions on behalf of user alice_001 in past 7 days**
```sql
SELECT timestamp, actor_client, issued_scope, event_type, policy_result
FROM is73_audit
WHERE subject_client = 'alice_001'
  AND actor_client IS NOT NULL
  AND event_type = 'token_exchange'
  AND timestamp >= now() - interval '7 days'
ORDER BY timestamp DESC;
```

**Result:** Shows all agents that exchanged tokens for alice_001, what scopes they got, whether policies allowed. Enables per-user agent activity audit.

**Query: Token revocation events**
```sql
SELECT timestamp, subject_client, event_type, reason
FROM is73_audit
WHERE event_type = 'token_revoke'
  AND subject_client IN (SELECT sub FROM is73_audit WHERE event_type='token_revoke' AND timestamp > now-1h)
  AND timestamp >= now() - interval '30 days'
ORDER BY timestamp DESC;
```

**Result:** Tracks revocation events, helps compliance prove that user revocation mechanisms are working.

---

## Summary: Why Single Hub Wins

| Metric | Single Hub | Three Instances |
|--------|-----------|-----------------|
| **Operational Cost** | 1 IS 7.3 team, 1 instance, 1 backup strategy | 3 teams, 3 instances, 3 backup strategies = 3x cost |
| **JWKS Consistency** | One JWKS endpoint, all apps' keys together | Three JWKS endpoints, apps in resource servers must trust three sources, key rotation coordination is complex |
| **Audit Completeness** | All flows in one audit log, correlated via `jti` | Three audit logs, compliance must manually correlate by timestamp (error-prone) |
| **Configuration Complexity** | Three apps in Console, one deployment.toml | Three IS 7.3 instances, three deployment.toml files, three separate configurations |
| **Cross-Flow Queries** | Single SQL query across all flows | Multiple queries to three systems, then manual correlation |
| **Availability Trade-off** | Single point of failure (mitigated with active-active clustering, multi-region replication) | Per-flow isolation (one instance down doesn't affect others, but more infrastructure to manage) |

**Recommendation:** Deploy single IS 7.3 hub in production. Mitigate availability risk with:
- Active-active clustering (2–3 nodes)
- Multi-region replication (hot standby)
- Database replication (synchronized across regions)
- Health checks and automatic failover
- Load balancer with per-region routing

With these measures, single hub is more reliable and cost-effective than three instances.

---

## Lesson: Architectural Thinking

This synthesis demonstrates a key principle: **constraints are opportunities for consolidation.** Three flows have different compliance drivers, threat models, and token structures. But they share common OAuth2 primitives. A well-designed identity architecture:

1. **Identifies shared primitives** (PAR, JWKS, introspection, DCR)
2. **Consolidates on shared infrastructure** (single hub, not three)
3. **Allows per-flow divergences via configuration** (Console per-app settings, deployment.toml sections)
4. **Unifies audit trail** (all flows log to one system, queryable via correlation IDs)
5. **Trades single point of failure for operational simplicity and compliance visibility**

This is the architecture that a bank's principal architect presents to the security board.
