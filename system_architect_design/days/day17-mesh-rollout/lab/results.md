# Day 17 lab results

Date: ____  Router: Traefik (or nginx)

## 1. Baseline 90/10 split

| weights (v1/v2) | requests | v1 % | v2 % | errors % |
|-----------------|---------:|-----:|-----:|---------:|
| 90 / 10         |          |      |      |          |

Was the split ~90/10 as configured? ____

## 2. Bounded blast radius (v2 errRate=0.30 at 10% weight)

| requests | v1 % | v2 % | errors % | expected errors ≈ 10%×30% |
|---------:|-----:|-----:|---------:|---------------------------|
|          |      |      |          |                           |

## 3. Promote then roll back

| state | weights | v1 % | v2 % | errors % |
|-------|---------|-----:|-----:|---------:|
| promoted to v2 |  |  |  |  |
| v2 failing (errRate=0.5) |  |  |  |  |
| rolled back to v1 |  |  |  |  |

## 4. Break-it: v2 fails its health check (weights back to 90/10)

| step | v1 % | v2 % | errors % |
|------|-----:|-----:|---------:|
| v2 healthy |  |  |  |
| v2 /health -> 503 |  |  |  |
| v2 healthy again |  |  |  |

What did the router do when v2 was unhealthy but still weighted 10, and why?  ____
(Traefik active vs nginx passive health — which did you use, and what differed?)

## Design linkage
- What would your **automated** rollback trigger measure, and over what window?
  (from your ADR): ____
- Which risk does the canary NOT protect against, and how would you cover it? ____

## Break-it summary
- What I broke: ____
- How I diagnosed it: ____
- The fix / why the design handled it: ____
