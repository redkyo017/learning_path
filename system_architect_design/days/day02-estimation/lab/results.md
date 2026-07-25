# Day 2 Lab Results — estimate vs measured

## My estimate (from design/sizing.md)
| Quantity | My number | Decision it forced |
|----------|-----------|--------------------|
| Write QPS avg |  |  |
| Write QPS peak (×__) |  |  |
| Read QPS peak |  |  |
| 5-yr storage (RF 3) |  |  |
| Cache working set |  |  |
| **Riskiest assumption** (wrong by 10× → breaks design) |  |  |

## MODE=rate runs (constant target RPS, 60s)
| TARGET_RPS | Achieved RPS (http_reqs/60) | p95 (ms) | error rate | p95 < budget? |
|------------|------------------------------|----------|------------|---------------|
| 1000 |  |  |  |  |
| 3000 |  |  |  |  |
| ____ |  |  |  |  |

## MODE=spike run — the single-instance ceiling
- Knee (p95 breaks budget) at approx **______ RPS**.
- Error rate at the knee: ______
- Dominant symptom past the knee (timeouts / pool wait / CPU): ______

## Break-it — moving the ceiling with the pool size
| MAX_OPEN_CONNS | Ceiling RPS at p95 budget |
|----------------|---------------------------|
| 20 (default)   |  |
| 4              |  |
Confirmed the binding constraint is: ______ (expected: DB connection pool, per Little's Law)

## Estimate vs reality
- Per-instance ceiling measured: ______ RPS.
- Instances needed for the 6,000/s fleet peak ≈ `6000 / ceiling` = ______
- Was my estimate right? What did measuring change about the design? ______
- Biggest surprise: ______
