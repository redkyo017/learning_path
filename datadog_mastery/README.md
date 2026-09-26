# DataDog Dashboard Mastery

## What This Is
A single-day 8-hour investigation mastery course for DataDog. Stage 1 covers read-only
investigation: navigating Logs, APM, Metrics, Infrastructure, and Alerts to diagnose
production incidents. No dashboard creation. No alert authoring. Pure investigation skill.

## Who This Is For
Engineers who need to investigate incidents in their company's DataDog and don't want to
spend weeks clicking through the UI to build intuition.

## Prerequisites
- Access to your company's DataDog account (read-only is enough)
- Basic understanding of what logs, metrics, and traces are (you don't need prior DataDog experience)
- Stack context used in drills: WSO2 API Gateway + Java Spring Boot on ECS Fargate + RDS MySQL
  (adapt drill steps to your own service names)

## How to Use This Course
1. Open this README and `PROGRESS.md` side-by-side
2. Work through each hour file in order — each builds on the previous
3. Do the investigation drills in your real DataDog, not a sandbox
4. Check off each hour in `PROGRESS.md` as you complete it

## Course Map

| Hour(s) | File | Focus |
|---------|------|-------|
| H1 | [h01_orientation.md](content/h01_orientation.md) | Mental model + navigation |
| H2–H3 | [h02_h03_logs.md](content/h02_h03_logs.md) | Log Explorer + facets |
| H4–H5 | [h04_h05_apm_traces.md](content/h04_h05_apm_traces.md) | APM + trace investigation |
| H6 | [h06_infrastructure.md](content/h06_infrastructure.md) | ECS + RDS metrics |
| H7–H8 | [h07_h08_alerts_capstone.md](content/h07_h08_alerts_capstone.md) | Alerts + capstone drill |

## Reference
- [GLOSSARY.md](content/GLOSSARY.md) — plain-English DataDog terms
- [STRATEGY.md](STRATEGY.md) — the unconventional approach
- [PROGRESS.md](PROGRESS.md) — your stage tracker

## Stages
- **Stage 1 (this):** Investigation mastery — read and navigate confidently
- **Stage 2 (not yet built):** Creation mastery — dashboards, monitors, SLOs
