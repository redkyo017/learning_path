# WSO2 Mastery — 60-Day Go Port

## Quick Start
Open `PROGRESS.md` for current session status and handoff prompt.

## Phase Map
| Phase | Days | Focus |
|---|---|---|
| 1 | 1–15 | Identity Core — OAuth2/OIDC + Key Manager |
| 2 | 16–30 | API Gateway — JWT validation + throttle |
| 3 | 31–45 | Control Plane + event sync |
| 4 | 46–60 | Production mastery |

## Day Index

### Phase 1 — Identity Core (Days 1–15)

| Day | Title |
|---|---|
| 1 | OAuth2 Fundamentals |
| 2 | OIDC Identity Claims |
| 3 | JWT Structure and Claims |
| 4 | Go Token Endpoint |
| 5 | OAuth2 Grant Types |
| 6 | JWT Signing and Verification |
| 7 | Go Token Introspection |
| 8 | Session Management |
| 9 | Token Revocation |
| 10 | Go Key Manager Adapter |
| 11 | Custom Key Manager Interface |
| 12 | Key Manager Integration |
| 13 | IS Multi-Tenancy |
| 14 | Audit Logging |
| 15 | IS Review and Extension Points |

### Phase 2 — API Gateway (Days 16–30)

| Day | Title |
|---|---|
| 16 | Synapse Mediators Fundamentals |
| 17 | Handler Chain Pattern |
| 18 | Go Message Mediator |
| 19 | Go JWT Validator in GW |
| 20 | Subscription Policies |
| 21 | Request Throttling |
| 22 | Policy Decision Framework |
| 23 | Backend URL Routing |
| 24 | Go Transport Handler |
| 25 | Response Interception |
| 26 | Analytics Integration |
| 27 | Extension: Custom Handler |
| 28 | GW Clustering |
| 29 | Service Mesh Readiness |
| 30 | GW Review and Extensions |

### Phase 3 — Control Plane (Days 31–45)

| Day | Title |
|---|---|
| 31 | API Registry Concepts |
| 32 | Go API Registry CRUD |
| 33 | API Versioning and Deprecation |
| 34 | Developer Portal Simulation |
| 35 | Subscription Management |
| 36 | Go Subscription Manager |
| 37 | Event-Driven Architecture |
| 38 | Go Event Bus (JMS Simulation) |
| 39 | Real-Time Sync via SSE |
| 40 | ECS Basics for WSO2 |
| 41 | Multi-AZ Networking Design |
| 42 | ECS Task Orchestration |
| 43 | Docker Compose Full Stack |
| 44 | Stack Verification |
| 45 | CP Review and Scaling Blueprint |

### Phase 4 — Production Mastery (Days 46–60)

| Day | Title |
|---|---|
| 46 | Distributed Tracing: activityId and Log Correlation |
| 47 | Go Log Correlation Parser |
| 48 | Extended Parser: Filter by ID, Service, JSON Output |
| 49 | Custom Extension Points: Source Reading |
| 50 | Go APIHandler Extension Blueprint |
| 51 | Go OAuthGrantHandler Extension Blueprint |
| 52 | Failure Mode Catalog (7 Classes) |
| 53 | Go Log Failure Classifier |
| 54 | Bash Triage Script + Debug Playbook |
| 55 | ECS Autoscaling Patterns + ADR Templates |
| 56 | Terraform: ECS Autoscaling for GW and TM |
| 57 | Capacity Planning Worksheet |
| 58 | Capstone: Full System Architecture |
| 59 | Capstone: Personal Production Runbook |
| 60 | Capstone: Reflection + Next Steps |

## Lab Setup

Each lab directory has a `README.md`. Run: `docker compose up` (where present).

- **Labs:** `labs/phase{1,2,3,4}/day{XX}/`
- **Content:** `content/phase{1,2,3,4}/day{XX}.md`

No AWS credentials needed for Phase 1–3 — all local. Phase 4 Day 56 (Terraform) requires AWS dev account.
