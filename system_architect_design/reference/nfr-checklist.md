# NFR Checklist — the "-ilities"

Non-functional requirements decide almost every real architecture argument.
Each day, pick the **top 3** that dominate the system you're designing. You
cannot maximize all of them at once — that's the whole point.

| NFR | The question it answers | How to measure it | Common tension |
|-----|-------------------------|-------------------|----------------|
| **Scalability** | Does it hold up as load grows? | Max sustained QPS at target latency; cost-per-request curve | vs simplicity, vs consistency |
| **Availability** | What fraction of time is it up? | Nines (99.9% = 8.7h/yr down); measured as successful/total requests | vs consistency (CAP), vs cost |
| **Latency** | How fast does a request return? | p50 / p95 / p99 / p999 (tail is what users feel) | vs durability, vs consistency |
| **Consistency** | Do all readers see the same data? | Linearizable? read-your-writes? eventual? staleness window | vs availability, vs latency |
| **Durability** | Once written, does it survive? | Nines of durability; replication factor; RPO | vs cost, vs write latency |
| **Reliability** | Does it behave correctly under faults? | Error budget; MTBF; correctness under retries | vs velocity |
| **Security** | Is data protected & access controlled? | authN/authZ coverage; attack surface; encryption at rest/in transit | vs convenience, vs latency |
| **Observability** | Can you tell what it's doing? | Are the golden signals (RED/USE) measurable? trace coverage | vs cost (cardinality) |
| **Operability** | Can a human run & fix it? | MTTR; runbook coverage; deploy/rollback time | vs feature velocity |
| **Evolvability** | Can it change cheaply? | Coupling; blast radius of a change; contract stability | vs short-term speed |
| **Cost** | What does it cost to run? | $/month; $/1K requests; unit economics | vs everything |
| **Elasticity** | Does it scale down too? | Time to scale up/down; idle cost | vs simplicity |

## How to use in a design

1. Read the requirements. Ask: **if this system failed, which of these would the
   business scream about first?** Those are your top 3.
2. Write the top 3 with a *target* each: "availability 99.95%", "p99 < 100ms",
   "read-your-writes for the user's own data".
3. Judge every option in step 5 of the method against exactly these three.

## The nines cheat-sheet

| Availability | Downtime/year | Downtime/month |
|--------------|---------------|----------------|
| 99% (two nines) | 3.65 days | 7.2 h |
| 99.9% (three) | 8.76 h | 43.8 min |
| 99.99% (four) | 52.6 min | 4.4 min |
| 99.999% (five) | 5.26 min | 26 s |

**Rule of thumb:** each extra nine costs roughly an order of magnitude more.
Don't buy nines the business doesn't need.

## The AWS Well-Architected lens (a useful NFR checklist)

Operational Excellence · Security · Reliability · Performance Efficiency · Cost
Optimization · Sustainability. When stuck, walk these six pillars against your
design — each surfaces NFRs you may have skipped.
