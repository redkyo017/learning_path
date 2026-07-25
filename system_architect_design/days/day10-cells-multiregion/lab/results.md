# Day 10 Lab results — blast-radius containment

## Setup
- N cells: ______  Router mapping: ______ (fnv1a % N)
- Tenants driven: ______ (loadgen.sh N)

## Containment measurements

| Scenario | cell-a ok/fail | cell-b ok/fail | % tenants impacted | cell-b p95 (unchanged?) |
|----------|----------------|----------------|--------------------|--------------------------|
| Baseline (both healthy) |  |  | 0% |  |
| **cell-a killed** |  |  |  |  |
| cell-a killed (anti-pattern: reroute to cell-b) |  |  |  |  |

## What broke and how I diagnosed it
- Killed: __________ (how: `lsof -ti:8081 | xargs kill`)
- Observed on cell-a tenants: __________ (expect 503, X-Cell-Error:1)
- Observed on cell-b tenants: __________ (expect unaffected — 200, flat latency)
- Extrapolated blast radius at N=25 cells: __________ %

## Anti-pattern note (optional Part A step 5)
- What happened when the dead cell's traffic was rerouted to the healthy cell: ___
- Why that re-couples their fate: __________

## AWS path (if used)
- Resources created: ALB __________, target groups __________, instances ________
- Break-it (deregistered cell-a): __________
- **Teardown verified** (describe-load-balancers empty, instances terminated): ___
- Approx cost: $______

## Takeaway
- One-line: cells convert a 100%-blast-radius failure into a ____%-blast-radius,
  *nameable* failure — at the cost of __________.
