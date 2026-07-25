# STRIDE threat-model worksheet

Apply STRIDE per **component** and per **trust-boundary crossing**. Threats
concentrate where data crosses from a less- to a more-trusted zone. For each threat,
name a concrete mitigation. Rate residual risk after mitigation (H/M/L).

> How to use: (1) draw the data-flow diagram with trust boundaries in `../diagrams/`;
> (2) fill one row per (component, category); (3) star (★) the single mitigation that
> most reduces blast radius — that becomes your ADR.

---

## FILLED EXAMPLE — Payment/notification system (Problem 2)

Trust boundaries: internet→edge, edge→services, service→DB, service→external provider,
tenant→tenant.

### Component: API Gateway / edge

| STRIDE | Threat | Mitigation | Residual |
|--------|--------|------------|----------|
| S | Forged client identity | OIDC/JWT validation at edge; mTLS for service callers | L |
| T | Request tampering in transit | TLS everywhere; reject unsigned/altered payloads | L |
| R | Client denies making a request | Access logs with request id + principal, retained | L |
| I | Verbose errors leak internals | Generic error bodies; no stack traces to clients | L |
| D | Flood the create-charge path | Rate-limit per API key (429 + Retry-After); WAF; autoscale | M |
| E | Anonymous access to authed routes | Deny-by-default; authZ check on every route | L |

### Component: Payment Service

| STRIDE | Threat | Mitigation | Residual |
|--------|--------|------------|----------|
| S | Spoofed internal caller | Zero-trust service authN (mTLS/SPIFFE); no network-only trust | L |
| T | Replayed/duplicated charge | Idempotency-Key stored in same tx as charge (Day 8); dedupe | L |
| R | Dispute: "I never authorized this" | Immutable audit log + signed charge receipt; correlation id | M |
| I | Card/PII disclosure | Tokenize PAN (never store it); encrypt at rest/in transit; redact logs | L |
| D | Resource exhaustion via slow provider | Timeouts + circuit breaker + bulkhead (Day 9); queue overflow | M |
| E | ★ Service role can read ALL tenants' data | ★ Least-privilege IAM/DB grants scoped to the charge path; per-tenant authZ | L |

### Component: Payments DB

| STRIDE | Threat | Mitigation | Residual |
|--------|--------|------------|----------|
| S | Rogue client connects directly | Private subnet; IAM/DB auth; no public endpoint | L |
| T | Row tampering | App-only writes; DB audit; constraints | L |
| R | Silent data edit | Change-data-capture / audit table | M |
| I | Backup/snapshot leak | Encrypt backups; restrict snapshot-share IAM | L |
| D | Connection exhaustion | Pool limits; read replicas for reporting | M |
| E | Over-broad DB role | Grant only needed tables/columns; separate read/write roles | L |

### Component: External payment provider (service → provider)

| STRIDE | Threat | Mitigation | Residual |
|--------|--------|------------|----------|
| S | Fake webhook callback | Verify provider signature on every callback | L |
| T | Altered amount in callback | Signed payloads; reconcile against stored charge | L |
| R | Ambiguous timeout (did it charge?) | Same idempotency key on retry; reconciliation job (Day 8) | M |
| I | Secret/API key exposure | Key in secrets manager or short-lived; never in code/env logs | L |
| D | Provider outage cascades | Breaker opens → mark pending, drain later | M |
| E | Compromised key → arbitrary charges | Scope key permissions; rotate; alert on anomalies | M |

**Top mitigation (★):** least-privilege on the Payment Service's IAM/DB role. It
bounds the blast radius of *every* other failure (leaked credential, SSRF, injection)
— this is the Capital One lesson. → this is the security half of the Day-20 ADR.

---

## YOUR DESIGN — <name the prior design you chose>

Trust boundaries: __________________________________________

### Component: __________

| STRIDE | Threat | Mitigation | Residual |
|--------|--------|------------|----------|
| S |  |  |  |
| T |  |  |  |
| R |  |  |  |
| I |  |  |  |
| D |  |  |  |
| E |  |  |  |

_(repeat one table per component / trust-boundary crossing)_

**Top mitigation (★):** __________  → carry into the ADR.
**Mitigation I'm most likely to get wrong (red-team):** __________
