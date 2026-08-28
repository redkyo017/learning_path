# The Top 1% Strategy for AWS Integration Patterns

## The core mental model: integration is about boundaries

Every enterprise integration pattern exists to manage what crosses a boundary
and under what terms. Four boundary types in this path:

- **Ingress boundary** — client → your system (who can enter, how, at what rate)
- **API gateway boundary** — the contract layer between external clients and backend services (payload shape, protocol, auth policy, rate contract). Distinct from ingress: ingress controls *admission* (who enters, at what rate, L4 vs L7 routing); the API gateway controls *interface* (what shape the request takes and what cross-cutting policies apply before services see it).
- **Internal boundary** — service → service inside your system (coupling, reliability)
- **Egress boundary** — your system → AWS services or internet (cost, PCI scope, auditability)
- **External boundary** — your system ↔ third-party systems (webhooks, partner APIs)

Once you see every pattern through this lens, the right pattern for any new
situation becomes *derivable*, not memorized.

## The pattern loop (apply to every day)

1. Name the pattern and the problem it was invented to solve
2. Draw the boundary it manages
3. Map it to AWS — which services implement it and what each trades off
4. Wire it — minimal real Terraform lab
5. Break it — remove a component, inject a failure
6. Fix it — add the resilience mechanism the pattern implies

## What the 80% waste time on

| Trap | Why it fails |
|---|---|
| Service-first learning (SQS docs → SNS docs → EventBridge docs) | Learns features, not composition |
| Happy-path-only labs | Understands operation, not failure — senior engineers are hired for failure reasoning |
| Treating API Gateway as "just a proxy" | Misses BFF, anti-corruption layer, API composition |
| Ignoring egress | VPC endpoint vs NAT vs PrivateLink is the #1 gap junior→senior |
| Async without the outbox pattern | Ships integrations that silently lose messages under failure |

## What the top 1% do differently

- They learn the *pattern* before the *service*
- They intentionally break systems in labs to understand failure modes
- They can name the pattern AND the problem it solves AND one scenario where it's the wrong choice
- They treat egress as a first-class design concern, not an afterthought
- They always ask: "what happens when this component is unavailable?"
