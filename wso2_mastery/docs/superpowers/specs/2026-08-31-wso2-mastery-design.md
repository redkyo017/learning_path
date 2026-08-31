# WSO2 System Architect Mastery — Design Spec

**Date:** 2026-08-31
**Location:** `wso2_mastery/`
**Duration:** 4 phases × 15 days = 60 days, ~3h/day (~180h total)
**Tracking:** `wso2_mastery/PROGRESS.md`

---

## Purpose & Goals

Master WSO2 APIM 4.7 + IS 7.3 at architect depth — not as a user of the product,
but as someone who understands the internals well enough to debug production failures,
make deployment architecture decisions, and extend the system with custom components.

**Learner profile:** Strong Go engineer; minimal Java/Spring experience; daily operator
of a distributed WSO2 deployment on AWS ECS Fargate (Control Plane, Universal GW,
Traffic Manager, IS as 3rd-party Key Manager deployed separately). The unconventional
lever: use Go expertise to *port* the critical path of each WSO2 subsystem rather than
just reading about it. Building forces understanding that reading never achieves.

**What "done" looks like:** You can sit in a production incident, pull log4j2 logs from
all four services, trace a token failure or throttle anomaly end-to-end, and know exactly
which component is misbehaving and why. You can also write a custom key manager adapter
or gateway handler in Go, and evaluate infra PRs for your company's ECS Fargate deployment.

---

## Success Criteria

By the end of Phase 4 you can, without notes:

1. Explain the full OAuth2/OIDC token lifecycle through WSO2 IS — grant types, JWT
   claim assembly, introspection, revocation — and point to the source classes.
2. Trace an API call from client → Universal GW → Traffic Manager throttle check →
   backend, and identify where each failure mode manifests in logs.
3. Explain how the Control Plane syncs API/subscription/throttle data to the GW
   (event hub, JMS topics, periodic pull) and what breaks when sync lags.
4. Write a Go service that implements the WSO2 Key Manager REST interface, deployable
   as a drop-in 3rd-party key manager.
5. Write a Go reverse proxy that validates WSO2-issued JWTs and enforces subscription
   and throttle policies using data synced from the control plane.
6. Design and justify a distributed ECS Fargate deployment for a given traffic profile,
   including scaling triggers, health check paths, and log aggregation strategy.
7. Read any log4j2 output from WSO2 APIM/IS and map log lines to subsystem and failure class.

---

## Constraints & Environment

| Constraint | Rule |
|---|---|
| Lab environment | Local Docker (Phases 1-2), AWS ECS Fargate (Phases 3-4) |
| Credentials | Never write real AWS keys/secrets/tokens in any file — use placeholders |
| Git | Learner handles all commits — no `git commit` during authoring |
| Real infra during authoring | Labs are *written* by the author, *run* by the learner |
| Source reference | WSO2 IS 7.3 checkout: `/Users/hunghan/Downloads/wso2is-7.3.0` |
| Source reference | WSO2 APIM Universal GW: `/Users/hunghan/Downloads/wso2am-universal-gw-4.7.0` |
| Source reference | WSO2 APIM ACP (Control Plane): `/Users/hunghan/Downloads/wso2am-acp-4.7.0` |
| Go port scope | Working, testable implementations of the critical path — not production-grade replacements |
| Java depth | Just enough to read WSO2 source; no Java/Spring authoring required |

---

## Strategy (the unconventional top-1% approach)

**The trap beginners fall into:** They read WSO2 documentation (which describes what
the product does) instead of reading source code (which reveals why it works that way).
They spend weeks learning the admin UI before understanding the engine. They treat WSO2
as a black box and get permanently stuck at "it's not working, check the logs."

**The top-1% move:** Work backwards from the protocols. OAuth2/OIDC (RFC 6749/7519/7662),
JWT, JMS/AMQP, and HTTP are language-agnostic. WSO2 IS is an OAuth2 server written in Java
on OSGi — but the *protocol* is the same whether it's Java or Go. By porting the critical
path to Go, you're forced to understand every decision WSO2 made, because you have to
make the same decisions yourself. You don't need to understand OSGi bundles; you need to
understand the token endpoint contract.

**Mistakes that waste 80% of beginners' time:**
1. Reading the OSGi bundle loader and Carbon kernel before touching the actual feature code.
2. Starting with admin REST APIs instead of the core token/mediation engine.
3. Skipping log4j2 config — half of debugging WSO2 is knowing which logger to turn on.
4. Trying to run a full WSO2 stack locally before understanding what each process does.
5. Conflating WSO2 IS (identity provider, key manager) with WSO2 APIM (gateway + lifecycle).
   They share a codebase history but serve completely different runtime roles.

**The daily loop (every day of the plan):**
1. Read 1-2 WSO2 source files related to the day's topic (use the checked-out repos).
2. Build the Go equivalent — even a 50-line stub that handles the same contract.
3. Test it against the WSO2 spec (JWT claims, HTTP response shapes, error codes).
4. Write one paragraph in a personal "why" log: why did WSO2 make this design choice?

---

## Curriculum (Phase Outline)

### Phase 1 — Identity Core (Days 1–15, ~45h)
**Goal:** Build a Go OAuth2/OIDC server that speaks the WSO2 IS Key Manager interface.

| Days | Topic | WSO2 source focus | Go deliverable |
|---|---|---|---|
| 1-3 | OAuth2 grant types + token endpoint | `org.wso2.carbon.identity.oauth` | `/token` endpoint: client_credentials + auth_code |
| 4-6 | JWT assembly + claims | `JWTTokenGenerator`, `OAuthTokenIssuerImpl` | JWT signer with WSO2 claim format |
| 7-9 | Token introspection + revocation | `IntrospectionDataProvider`, `OAuthRevocationProcessor` | `/introspect` + `/revoke` endpoints |
| 10-12 | WSO2 Key Manager REST API (3rd-party interface) | `KeyManagerInterface`, REST API spec | Full Key Manager adapter in Go |
| 13-15 | log4j2 reading + IS debug patterns | log4j2 configs in IS checkout | Log parsing lab + debug playbook |

### Phase 2 — API Gateway (Days 16–30, ~45h)
**Goal:** Build a Go reverse proxy that enforces subscriptions and throttle using WSO2-issued JWTs.

| Days | Topic | WSO2 source focus | Go deliverable |
|---|---|---|---|
| 16-18 | Synapse mediation engine concepts | `SynapseMessageContext`, `AbstractMediator` | Go middleware pipeline (handler chain pattern) |
| 19-21 | JWT validation at gateway | `JWTValidator`, `GraphQLConstants` | JWT validation middleware (verify sig + claims) |
| 22-24 | Subscription enforcement | `APIKeyValidationService`, `SubscriptionDataStore` | Subscription check middleware |
| 25-27 | Throttle check + Traffic Manager | `ThrottleHandler`, `GlobalThrottleEngineClient` | Token-bucket throttle middleware + TM client |
| 28-30 | log4j2 reading + GW debug patterns | GW log4j2 configs | Gateway log parsing lab + debug playbook |

### Phase 3 — Control Plane + Sync (Days 31–45, ~45h)
**Goal:** Build a Go control plane REST API and event-driven sync to the gateway.

| Days | Topic | WSO2 source focus | Go deliverable |
|---|---|---|---|
| 31-33 | API lifecycle + publisher flow | `APIProvider`, `APIConsumer`, `AbstractAPIManager` | API registry CRUD REST API |
| 34-36 | Subscription management | `SubscriptionDAOImpl`, `ApplicationDAOImpl` | Subscription + application endpoints |
| 37-39 | Event hub + JMS sync | `EventHub`, `JMSMessagePublisher`, topic names | Go event bus (NATS/channels) + GW subscriber |
| 40-42 | ECS Fargate deployment patterns | N/A (infra focus) | Terraform modules for CP + GW + IS layout |
| 43-45 | End-to-end integration | All | Wire all four Go services; smoke test against WSO2 JWT |

### Phase 4 — Production Mastery (Days 46–60, ~45h)
**Goal:** Architect, debug, and extend production WSO2 at expert level.

| Days | Topic | Focus | Deliverable |
|---|---|---|---|
| 46-48 | Distributed tracing + log correlation | Correlation IDs across CP/GW/IS/TM logs | Correlation log parser + trace playbook |
| 49-51 | Custom extension points | `APIHandler`, `OAuthGrantHandler`, custom mediator | Go custom extension blueprint |
| 52-54 | Failure mode catalog | Common production failures + their log signatures | Failure → root cause lookup table |
| 55-57 | Scaling + capacity design | ECS Fargate autoscaling, throttle tuning, IS session limits | Architecture decision record templates |
| 58-60 | Capstone: full system review | Entire Go port + WSO2 source | Final architecture diagram + personal runbook |

---

## Directory Layout

```
wso2_mastery/
├── PROGRESS.md                        # session-to-session tracking file
├── README.md                          # quickstart, phase map, day index
├── STRATEGY.md                        # top-1% unconventional strategy (standalone)
├── content/
│   ├── GLOSSARY.md                    # WSO2/OAuth2/JMS terms in plain English
│   ├── phase1/
│   │   └── day01.md … day15.md
│   ├── phase2/
│   │   └── day16.md … day30.md
│   ├── phase3/
│   │   └── day31.md … day45.md
│   └── phase4/
│   │   └── day46.md … day60.md
├── labs/
│   ├── phase1/
│   │   └── day01/ … day15/            # Go source, Dockerfile, README, SOLUTION.md
│   ├── phase2/
│   │   └── day16/ … day30/
│   ├── phase3/
│   │   └── day31/ … day45/            # includes Terraform for ECS Fargate
│   └── phase4/
│       └── day46/ … day60/
└── docs/superpowers/
    ├── specs/                          # this file
    └── plans/                          # per-phase implementation plans (written next)
```

---

## Content Day Skeleton

```markdown
# Day N — <Title>

## Why this matters
<1 paragraph: concrete connection to production debugging / architecture / extension>

## WSO2 source reading
- File: `<path in checkout>` — Lines N–M: <what to look for>
- Key insight: <the "aha" that reading the source gives you>

## Core concepts
<Body: protocol spec + WSO2 design decision + how the Go port maps to it>

## Lab
See `labs/phaseX/dayNN/`. Goal: <one line>. Success signal: <one line>.

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. ...

## Anti-patterns / Common mistakes
- <2-3 bullets>

## Teardown
<checklist: stop containers, remove test certs, no billable AWS resources left running>
```

---

## Next Steps

1. **This session ends here** — spec is complete, tracking file written.
2. **Next session (Phase 1 plan):** Open `PROGRESS.md`, run `writing-plans` skill for Phase 1 (Days 1–15) only. Each subsequent phase gets its own plan session.
3. **Content sessions:** One phase of content per session, dispatched via `subagent-driven-development`.
