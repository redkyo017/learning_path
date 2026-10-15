# Learner Profile

My standing background for every learning path. Claude reads this before asking me questions
(skill.md → Step 0) and only asks about what's missing here or may be out of date.

**How to update:** add a bullet to the right section, ending with `(since YYYY-MM)` or `(as of YYYY-MM)`.
When something stops being true, don't delete it — strike it through (`~~old~~`) and add the new item,
so the history stays visible. Unknown or unsure facts are marked `(?)`; replace them when you know.

---

## Role & career

- Senior backend software engineer, Golang as main language.
- Spent a long period in management; returning to hands-on software engineering (since ?).
- Daily work: backend and API-gateway systems, microservices as the backbone.

## Strong skills (use as leverage, don't re-teach basics)

- Golang — backend, services; target areas: concurrency, performance, infrastructure/system apps, microservices, cloud native.
- Linux as a daily user/operator on servers; studied for the LPI certification years ago (now mostly habit).
- PostgreSQL, MySQL, MongoDB in daily work; database theory learned years ago (now mostly habit).
- Docker and Kubernetes from experience and habit, not systematic study.

## Weak spots / gaps

- Java and Spring Boot — little experience (relevant to WSO2 internals).
- Many skills are "experience and habit" — want them recalled and consolidated systematically, with the theory behind them.
- Vim/Neovim — not a daily editor (nice to have for servers).
- German — zero level (as of the A1 path start).
- English exam (TOEFL iBT) — current level (?).

## Work context

- Company stack: WSO2 API Manager 4.7 + Identity Server 7.3 (IS used as a third-party key manager).
- Distributed WSO2 deployment on AWS ECS Fargate: Control Plane, API Gateway, Traffic Manager, Identity Server deployed separately.
- Team infrastructure-as-code: Terraform (AWS console also used).
- Operate AWS ECS/EC2, RDS and MongoDB servers: access, monitor, debug.
- Upcoming company work: integrating backend services with WSO2, building MCP services and AI agents with AWS AgentCore / AgentCore Gateway.

## Practice environment

- macOS laptop; VS Code + iTerm as daily tools.
- Docker Desktop for local labs (incl. local Kubernetes).
- Personal AWS account (OK for labs, incl. EKS — keep costs low).
- Personal MongoDB account.
- Separate labs repo for doing labs: https://github.com/redkyo017/learning_path_labs (same GitHub account as this repo); local clone path (?) (since 2026-10).
  - **This repo** = single source of truth: learning content, authored lab sources, progress notes.
  - **Labs repo** = where I actually run labs: installed dependencies (Terraform providers, `.terraform/`, modules, venvs, `node_modules`), state, my own attempts. Mirrors this repo's layout: `<path>/labs/dayNN/`.
  - A fix to a lab's *source* belongs here first, then gets copied to the labs repo — never the other way silently.

## Learning preferences

- Hands-on first: labs and real practice over reading.
- Aggressive, fast-track plans; I'll accept a recommended duration if my estimate is off.
- Start with a simple version to save tokens, extend later.
- Link good online resources inside the content.
- For algorithms, solve problems in Go.

## Time budget

- Hours per day available (?) — default: ask per path.
