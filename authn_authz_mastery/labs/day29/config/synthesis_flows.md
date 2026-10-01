# Day 29 Lab — Three-Flow Synthesis: Comparison Table & Hub Diagram

This file contains:
1. The comparison table template (6 dimensions × 3 flows)
2. Guidance for filling it in
3. Deployment.toml mapping
4. Audit query patterns per flow

---

## Comparison Table: Six Dimensions × Three Flows

Fill in each cell with substantive analysis (not placeholder text). Reference Day 29 content and the labs for Days 1–28.

| Dimension | **Flow 1: Customer App (FAPI 2.0)** | **Flow 2: B2B Partner (mTLS)** | **Flow 3: AI Agent (OBO)** |
|-----------|------|-------|---------|
| **1. Auth Method** | *How does the client prove identity? Which OAuth2 flow?* | | |
| **2. Token Binding** | *How is the token bound to prevent theft or replay?* | | |
| **3. Audit Claim** | *Which claim identifies the principal in audit logs?* | | |
| **4. Revocation Mechanism** | *How is revocation triggered and propagated?* | | |
| **5. APIM Enforcement** | *What does APIM gateway check? Rate limit per what?* | | |
| **6. Regulatory Driver** | *What compliance requirement drives this pattern?* | | |

---

## Guidance for Each Cell

### Row 1: Auth Method

**What to describe:**
- Which OAuth2 authorization grant (authorization code, client credentials, token exchange)?
- Which additional mechanisms (PAR, PKCE, RAR, SCA)?
- How is the client identified?

**Examples:**
- Customer app: "Authorization Code flow with PAR (Pushed Authorization Request) for secure request initiation. PKCE for client app running on user device. RAR (Rich Authorization Request) for granular consent. SCA (Strong Customer Authentication) via FIDO2 or TOTP (Day 17)."
- B2B partner: "Client Credentials grant with mTLS client authentication. Client certificate (issued by bank's PKI) identifies the partner organization. No PKCE or SCA (machine-to-machine flow)."
- AI agent: "RFC 8693 Token Exchange grant. Client authentication via private_key_jwt (Day 22). Orchestrator/tool agents authenticate using their private keys, not shared secrets."

---

### Row 2: Token Binding

**What to describe:**
- How is the token bound to prevent theft or misuse?
- What happens if the token is stolen?

**Examples:**
- Customer app: "DPoP (Demonstration of Possession, Day 16). Token is bound to the mobile app's public key. If stolen, attacker cannot use the token without the app's private key. DPoP proof is required on every API call."
- B2B partner: "Certificate hash binding (cnf.x5t#S256 claim). Token includes SHA-256 hash of the partner's client certificate. Payment API verifies the cert hash matches the incoming TLS certificate. If stolen, token is useless without the cert."
- AI agent: "Scope narrowing + act claim chain. Token is narrowed to specific scope (e.g., agent:payments:initiate). Additionally, the act claim records the agent's identity. If stolen by an unrelated service, the narrow scope limits blast radius. Missing act claim signals unauthorized use."

---

### Row 3: Audit Claim

**What to describe:**
- Which JWT claim identifies the principal?
- What can be extracted from the audit log to identify who did what?

**Examples:**
- Customer app: "`sub` (user subject), `aud` (audience = mobilebank app), `scope` (permissions granted). Audit log query: find all actions by sub=user_id on date=X."
- B2B partner: "`sub` (org_id), `cnf.x5t#S256` (certificate hash). Audit log query: find all API calls by org_id=partner_123 in period Y."
- AI agent: "`sub` (user subject), `act` (agent identity; single or nested for multi-hop). Audit log query: find all actions by act.sub=risk_scorer on behalf of sub=user_001."

---

### Row 4: Revocation Mechanism

**What to describe:**
- How is revocation triggered?
- How quickly does revocation propagate?
- What systems honor the revocation?

**Examples:**
- Customer app: "User-initiated (user clicks 'Sign out everywhere' in mobile app). Revocation is immediate at IS 7.3 level. Propagation via introspection: APIM gateway introspects on every request; cache TTL = 5 minutes. All active tokens become invalid within 5 minutes (banking compliance requirement)."
- B2B partner: "Admin-initiated (bank operator revokes partner's certificate or org_id). Revocation is typically scheduled (weekly certificate refresh or as-needed for security incidents). Partner API may cache tokens for up to 24 hours; revocation latency can be 24 hours in worst case (acceptable for B2B integrations)."
- AI agent: "User-initiated (same as customer app). Revocation is immediate at IS 7.3 level. Propagation via introspection chain check: if user revokes, all derived agent tokens become invalid on next introspection (even if not yet expired). Latency = 5 minutes (cache TTL)."

---

### Row 5: APIM Enforcement

**What to describe:**
- What does APIM gateway verify before allowing the request?
- How does APIM rate-limit or apply different policies?

**Examples:**
- Customer app: "APIM verifies: (1) scope (user is authorized for the requested resource), (2) DPoP proof (token is bound to caller's key), (3) user_id (identify the user). Rate limit: 1000 calls/hour per user_id (different users have independent limits). Additional policy: if scope=payments:initiate, add SCA verification step."
- B2B partner: "APIM verifies: (1) org_id (partner organization), (2) certificate hash (cert subject is partner), (3) org_id subscription (is partner's org subscribed to this API?). Rate limit: 10000 calls/hour per org_id (org-level quota). Additional policy: require org_id to match TLS certificate subject."
- AI agent: "APIM verifies: (1) scope (agent is authorized for the action), (2) act claim (agent identity is recorded), (3) sub claim (user is recorded). Rate limit: 5000 calls/hour per agent_id (per-agent quota, higher than per-user because agents aggregate requests). Additional policy: if act.sub is unknown (agent not in allow-list), log security event and rate-limit aggressively."

---

### Row 6: Regulatory Driver

**What to describe:**
- Which regulatory requirement or compliance standard drives this pattern?
- Why is this pattern important for that requirement?

**Examples:**
- Customer app: "PSD2 (Revised Payment Services Directive, EU). Requires: (1) Strong Customer Authentication (SCA) for payments, (2) user consent (RAR for granular consent), (3) revocation rights (user can revoke instantly). DPoP and SCA address SCA requirement. PAR + RAR address consent. Introspection-based revocation addresses revocation requirement."
- B2B partner: "B2B Service Level Agreements (SLAs) + Audit Requirements. Partners require: (1) guaranteed uptime (long token lifetimes reduce auth server load), (2) audit trail per organization (org_id in all logs). Long token lifetime (24h) reduces auth calls. Org_id claim enables per-organization audit queries."
- AI agent: "Agent Auditability + User Consent Compliance. Regulators require: (1) every API call traceable to the user who initiated it (via sub), (2) every hop in the delegation chain recorded (via act), (3) user revocation affects all agents immediately (via introspection). This pattern satisfies all three: sub + act chain + introspection-based revocation = full auditability."

---

## Deployment.toml Mapping

### Global Settings (enable all flows)

```toml
[oauth]
# All grant types are listed globally
allowed_grant_types = [
  "authorization_code",      # Flow 1
  "refresh_token",           # Flow 1
  "client_credentials",      # Flow 2
  "urn:ietf:params:oauth:grant-type:token-exchange"  # Flow 3
]

# Flow 1: Customer app (FAPI 2.0) specific
[oauth.jwt]
enable_jarm = true             # JARM response (JWT-encoded) for customer app
response_mode = "jwt"

# Flow 2: B2B partner (mTLS) specific
[oauth.mtls]
enable_client_auth = true      # mTLS client authentication
certificate_validation = true

# Flow 3: AI agent (OBO) specific
[oauth.token_exchange]
enable = true                  # RFC 8693 token exchange
max_actor_chain_depth = 3      # Limit delegation chain depth

# All flows benefit
[log.audit]
log_format = "structured"      # JSON logging for all systems
```

### Per-Application Configuration (Console)

**Application 1: MobileBank (Customer App)**
```
Name: MobileBank
Client Type: Public (mobile app)
Grant Types: authorization_code, refresh_token
Token Endpoint Auth: PKCE (no shared secret)
Response Type: code
Response Mode: jwt (JARM)
Redirect URIs: https://mobilebank.bank.com/callback
Scopes: payments:read, payments:write, accounts:read, accounts:write, openid, profile
DPoP Binding: Enabled
SCA Policy: Required for scope=payments:write or amount > 100
PKCE: Required (Proof Key for Public Clients)
```

**Application 2: PartnerAPI (B2B)**
```
Name: PartnerAPI
Client Type: Confidential (server-to-server)
Grant Types: client_credentials
Token Endpoint Auth: mtls_client_auth (client certificate)
Redirect URIs: (none; machine-to-machine)
Scopes: partner-api:read, partner-api:write
Certificate Requirements: 
  - Issuer: Bank's internal PKI
  - Subject: cn=<partner-name>.partners.bank.com
  - Extended: Org ID claim = <partner-id>
Token Lifetime: 86400 (24 hours; long-lived for B2B)
```

**Application 3: AgentOrchestrator (AI Agent)**
```
Name: AgentOrchestrator
Client Type: Confidential (agent service)
Grant Types: urn:ietf:params:oauth:grant-type:token-exchange
Token Endpoint Auth: private_key_jwt (JWT signed with private key)
JWKS URI: https://agent-host/.well-known/jwks.json
Redirect URIs: (none; not using authorization code)
Scopes: agent:payments:initiate, agent:accounts:read, agent:payments:read
Actor Trust Policy:
  - Actor: payment_orchestrator, Subject: group:financial-users, Effect: Allow
  - Actor: risk_scorer, Subject: group:financial-users, Effect: Deny (until approved)
Token Lifetime: 900 (15 minutes for orchestrator exchanges)
May-Act Claim: Optional pre-authorized tool_agent for deeper delegation
```

---

## Audit Query Patterns

### Flow 1: Customer App

**Query all authentications by a specific user in past 24 hours:**
```sql
SELECT timestamp, event_type, scope, result_status
FROM is73_audit
WHERE event_type IN ('authorization', 'token_issue')
  AND sub = '<user_id>'
  AND timestamp >= now() - interval '24 hours'
ORDER BY timestamp DESC
```

**Query all SCA challenges in past hour:**
```sql
SELECT timestamp, sub, sca_method, result_status
FROM is73_audit
WHERE event_type = 'sca_challenge'
  AND timestamp >= now() - interval '1 hour'
ORDER BY timestamp DESC
```

---

### Flow 2: B2B Partner

**Query all API calls by a specific partner organization:**
```sql
SELECT timestamp, org_id, event_type, endpoint, result_status
FROM is73_audit
WHERE org_id = '<partner_id>'
  AND timestamp >= now() - interval '7 days'
ORDER BY timestamp DESC
```

**Query certificate-based authentications:**
```sql
SELECT timestamp, org_id, certificate_subject, result_status
FROM is73_audit
WHERE event_type = 'mtls_auth'
  AND org_id = '<partner_id>'
  AND timestamp >= now() - interval '30 days'
```

---

### Flow 3: AI Agent

**Query all token exchanges for a specific agent:**
```sql
SELECT timestamp, actor_client, subject_client, issued_scope, policy_result
FROM is73_audit
WHERE actor_client = '<agent_id>'
  AND event_type = 'token_exchange'
  AND timestamp >= now() - interval '24 hours'
ORDER BY timestamp DESC
```

**Query all agent actions on behalf of a specific user:**
```sql
SELECT timestamp, actor_client, subject_client, issued_scope
FROM is73_audit
WHERE subject_client = '<user_id>'
  AND actor_client IS NOT NULL
  AND event_type = 'token_exchange'
  AND timestamp >= now() - interval '7 days'
ORDER BY timestamp DESC
```

**Query revocation events:**
```sql
SELECT timestamp, subject_client, event_type
FROM is73_audit
WHERE event_type = 'token_revoke'
  AND subject_client = '<user_id>'
  AND timestamp >= now() - interval '30 days'
```

---

## Synthesis Summary

| Aspect | Single Hub | Three Instances |
|--------|-----------|-----------------|
| **Operational Cost** | Low | 3x higher |
| **JWKS Consistency** | One source of truth | Three endpoints (sync challenges) |
| **Audit Trail** | Unified via `jti` correlation | Manual cross-instance correlation |
| **Availability** | Single point of failure (mitigated with clustering) | Per-flow isolation |
| **Configuration** | Three apps in one Hub | Three instances to manage |
| **Recommended** | Yes (for most banks) | Only if per-flow scaling needed |

**Conclusion:** A single IS 7.3 hub is architecturally sound and operationally superior. Enable all three flows in a single instance; use Console to configure per-application divergences. Deploy in active-active cluster for high availability.
