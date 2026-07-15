# AWS Bedrock AgentCore Gateway — 3-Day Mastery

Entry point for the 3-day aggressive learning plan. Goal: production-grade
proficiency with AgentCore Gateway as an enterprise tool registry.

## Where everything lives

| Path | What it is |
|---|---|
| `docs/superpowers/specs/2026-07-14-bedrock-agentcore-gateway-mastery-design.md` | Design spec — purpose, strategy, mistakes table, success criteria |
| `docs/superpowers/plans/2026-07-14-bedrock-agentcore-gateway-mastery-plan.md` | This execution plan — follow it task by task |
| `content/dayNN.md` | Theory layer — read BEFORE each day's hands-on labs |
| `labs-go/cmd/day*/` | Go lab programs — one directory per lab exercise |
| `aws/iam/` | IAM policy JSON files |
| `aws/lambda/` | Lambda function source code |
| `aws/openapi/` | OpenAPI spec files for Day 2 tool registration |

## Daily rhythm (6–8 hrs)

1. **Primer** (30 min) — read the day's content doc + relevant SDK source
2. **Core lab** (2.5 hrs) — build the day's main exercise
3. **Failure lab** (1 hr) — break things deliberately, read errors
4. Break (15 min)
5. **Extend** (1.5 hrs) — wire the day's feature into the prior day's work
6. **Teach-it-back** (30 min) — write one explanation as if briefing an on-call teammate
7. **Journal + teardown** (20 min) — reflect; run teardown to avoid AWS costs

## Start here

`content/day01.md`, then `labs-go/cmd/day01-iam/main.go`.
