# ADR Template: Architectural Decision Records

An ADR documents a significant decision, the reasoning behind it, alternatives considered, and consequences. Use this template when deciding on scaling strategies, infrastructure changes, or architectural shifts.

---

## ADR Template Structure

```markdown
# ADR-NNN: <Decision Title>

**Status:** Proposed | Accepted | Superseded by ADR-NNN

**Date:** YYYY-MM-DD

**Author:** Your Name

## Context

What problem are we solving? What constraints or forces drove this decision?
Include: current load profile, team size, budget, operational maturity, existing infrastructure.

## Decision

What did we decide to do? Be specific — include:
- Resource sizes and counts
- Service-level objectives (SLOs)
- Configuration thresholds and limits
- Timeline or phasing

## Consequences

### Positive:
- Benefit 1 (be specific about impact: cost, latency, availability)
- Benefit 2

### Negative / Trade-offs:
- Cost or risk 1 (quantify if possible)
- Cost or risk 2

### Risks Mitigated:
- Risk 1 and how the decision addresses it
- Risk 2 and how the decision addresses it

## Alternatives Considered

| Option | Pros | Cons | Why Rejected |
|---|---|---|---|
| Option A | Pro 1, Pro 2 | Con 1 | Main reason this wasn't chosen |
| Option B | Pro 1 | Con 1, Con 2 | Main reason |

## Review Trigger

Under what circumstances should this ADR be revisited?
Examples:
- When [metric] exceeds [threshold]
- When [new technology or service] becomes available
- Annually, as part of [review process]

## Notes

Any additional context, links to related ADRs, or follow-up actions.
```

---

# Example: ADR-001 — Keep CP and IS at Fixed Replica Count

**Status:** Accepted

**Date:** 2026-09-17

**Author:** WSO2 Platform Team

## Context

The WSO2 API Manager deployment consists of four services:
- **Gateway (GW):** Stateless, validates JWTs, proxies requests, enforces throttles. Linear horizontal scale-out.
- **Carbon Publisher (CP):** Holds API metadata (names, versions, auth schemes, throttle tiers) in an in-memory HashMap. Currently deployed on ECS Fargate with 1 vCPU / 2048 MB.
- **Identity Server (IS):** Holds active tokens and user sessions in memory. Processes token issuance and revocation. Deployed on ECS Fargate with 1 vCPU / 2048 MB.
- **Throttle Manager (TM):** Processes throttle events from GW. Receives events on ports 9611 (binary) and 9711 (SSL). Can scale horizontally with stateless event fanout.

**Current constraints:**
- No external database for API metadata or session state (RDS/DynamoDB/Redis not provisioned).
- Single-AZ deployment (no cross-AZ failover for CP or IS).
- Peak load projection: 3000 RPS, requiring ~3 GW tasks at 60% CPU target. 20 tokens/sec issuance rate → 72,000 steady-state sessions.
- Team: 2 platform engineers, ops-on-call model (no 24/7 dedicated monitoring).

## Decision

**Fixed replica count for CP and IS:**
- **CP:** 1 replica (no horizontal scaling).
- **IS:** 1 replica (no horizontal scaling).
- **GW:** Horizontal scaling via ECS autoscaling target. Min 1, max 4, target 60% CPU, scale-out cooldown 120s.
- **TM:** Horizontal scaling via ECS autoscaling target. Min 1, max 2, target 60% CPU, scale-out cooldown 120s.

**Justification:**
- CP metadata is ~3 MB for 10,000 APIs. Horizontal scaling without a shared database (e.g., PostgreSQL, Consul) causes inconsistency: CP-1 has the latest API list, CP-2 has the previous snapshot. Result: ~50% of requests get stale metadata → 5xx errors.
- IS sessions are in-memory. Horizontal scaling without session replication (e.g., Redis, DynamoDB) causes 401 Unauthorized: token issued on IS-1, request routed to IS-2, IS-2 doesn't recognize the token.
- GW and TM are stateless/event-fanout; they scale linearly with load.

**Configuration:**
```hcl
resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/wso2/wso2-gw"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_ecs_service" "cp" {
  desired_count = 1
  # No autoscaling target; fixed replica
}

resource "aws_ecs_service" "is" {
  desired_count = 1
  # No autoscaling target; fixed replica
}
```

## Consequences

### Positive:
- **Operational simplicity:** No state consistency issues. CP is the single source of truth for API metadata. IS is the single source for active tokens.
- **Cost efficiency:** Fixed replicas (CP=1, IS=1) cost ~$40/month each (ECS Fargate 1 vCPU / 2GB = $41.58/month, ~20% average utilization). Eliminates the overhead of managing state replication (Redis cluster, RDS multi-AZ).
- **Predictable behavior:** No hidden state synchronization delays. API updates take effect immediately on the single CP. Token revocation is instant on the single IS.
- **Compliant with team capacity:** 2 platform engineers don't need to manage distributed state replication; they focus on GW/TM scaling and throttle policy tuning.

### Negative / Trade-offs:
- **Single point of failure:** CP downtime = no API lifecycle changes (updates, deploys, versioning). IS downtime = new logins fail (can't issue tokens). No horizontal redundancy for failover.
  - **Mitigation:** Deploy multi-AZ (separate AZs but not replicas). Use ECS service health checks + CloudWatch alarms. On-call engineer can redeploy in ~5 minutes.
- **Vertical scaling ceiling:** If token issuance exceeds 100 tokens/sec or API count exceeds 50,000, single IS and CP tasks will hit CPU/memory limits. Must then scale vertically (e.g., 2 vCPU / 4 GB, ~$80/month) or refactor to external state.
- **Session memory exhaustion risk:** At 72,000 steady-state sessions (2 KB each), IS uses ~141 MB. At 100 tokens/sec, that's 100,000 sessions = ~195 MB. Still within 2 GB, but approaching 20% utilization. Beyond ~200,000 sessions, risk of OOM.

### Risks Mitigated:
- **Metadata inconsistency:** Fixed CP avoids split-brain where different instances have different API metadata versions.
- **Token revocation races:** Fixed IS ensures token revocation is atomic—all requests see the updated revocation list.
- **Operational overhead:** No need to manage Redis cluster or RDS replication. Reduces complexity and deployment time.

## Alternatives Considered

| Option | Pros | Cons | Why Rejected |
|---|---|---|---|
| **Horizontal CP/IS with RDS** | 2 CP tasks for HA, 2 IS tasks with RDS session store | RDS adds $50–100/month; network latency (RDS queries ~5ms); schema migrations; backup overhead; team expertise gap | Cost and operational overhead not justified at current load (<100 tokens/sec) |
| **Horizontal CP/IS with Redis** | Faster than RDS (~1ms latency); simpler schema | Redis cluster adds $30–50/month; still requires state replication logic; Redis persistence (AOF) adds complexity; single point of failure if Redis dies | Current load doesn't justify Redis; can add later |
| **Scaled CP/IS with read replicas (async)** | HA without distributed state | CP read-write splits still cause inconsistency; eventual consistency leads to intermittent 404s; testing nightmare | Doesn't solve the fundamental problem |
| **Microservices: separate metadata/session services** | Decouples API registry from token handling | More services to manage; inter-service calls add latency; network complexity; 4 → 6 services; on-call burden | Premature optimization; single-layer design works for current scale |

## Review Trigger

Revisit this ADR when:
1. **IS CPU sustained > 70%** under normal load (e.g., 50 tokens/sec for 1 week). Indicates token issuance is CPU-bound and scaling vertically is imminent.
2. **Token issuance rate > 150 tokens/sec sustained.** At ~10ms per token, 150 tokens/sec = 100% CPU on a single 1 vCPU task. Beyond this, horizontal scaling is necessary.
3. **API count exceeds 50,000.** Memory footprint ~15 MB. Still fits in 2 GB, but approaching resource contention.
4. **Production incident related to CP/IS failover time > 5 minutes.** Triggers evaluation of multi-region or Redis-backed architecture.
5. **Redis or managed session service (e.g., DynamoDB) price drops or team adds database engineering expertise.** May make horizontal scaling cost-effective or feasible.

---

## Notes

- **Follow-up actions:**
  - Monitor IS CPU and session count daily. Create CloudWatch dashboards.
  - Document runbook for CP/IS failover (manual redeploy via Terraform).
  - Capacity test at 150 tokens/sec to validate the scaling boundary.
  
- **Related decisions:**
  - ADR-002 (TBD): GW autoscaling parameters (max 4, target 60% CPU, scale-out cooldown 120s).
  - ADR-003 (TBD): Throttle policy limits for Gold/Silver/Bronze tiers.

- **References:**
  - Day 32 Go lab (API struct design, memory estimation).
  - Day 55 (ECS autoscaling fundamentals, stateless vs stateful).
  - Terraform lab (main.tf with autoscaling configuration).

---

## Approval

| Role | Name | Date | Sign-off |
|---|---|---|---|
| Tech Lead | Platform Team Lead | 2026-09-17 | Approved |
| Ops | On-Call Engineer | 2026-09-17 | Acknowledged |

---

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-09-17 | Platform Team | Initial creation |
