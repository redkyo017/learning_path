# AWS DevOps & SRE (CI/CD-First) — Design Spec

**Date:** 2026-09-02
**Location:** `aws_devops_sre/`
**Duration:** 5 days, ~3–4 h/day (~17h of scheduled work), plus a ~30 min Day 0 pre-flight
**Path type:** Applied / engineering → ships `labs/` with Terraform
**Learner:** Senior backend engineer (Golang), returning to hands-on IC work from management. Team stack: Terraform + AWS ECS Fargate.

---

## Purpose & Goals

The goal is not to be able to *configure* CodeBuild, CodePipeline, and CodeDeploy. Configuration is
documentation lookup, and it decays. The goal is to be able to **design a promotion strategy** for a
service and defend it — to walk into a room where someone says "we rebuild the image in each
environment so the config is baked in" and explain, in one sentence, what that costs them.

That skill is what the job interview probes and what the on-call rotation punishes. It is also what
five days can realistically produce, provided the days are spent on composition rather than on
service tours.

The learner already has AWS network, security, compute/load-balancing, and integration-pattern paths
in this repo. This path assumes VPC, IAM, ALB, and target-group fundamentals and does not re-teach
them. It assumes strong Go, so the sample workload is a Go service and no time is spent on
application code.

The learner's day job deploys WSO2 components to ECS Fargate. Day 3 — safe, reversible deployment to
ECS Fargate behind an ALB — is therefore the highest-transfer day in the path and is weighted
accordingly. Kubernetes is deliberately held to a single conversancy-level day; a dedicated EKS path
comes later.

## Success Criteria

By the end of Day 5, without notes, the learner can:

1. **Explain the chain of custody** for a deployed artifact — name which AWS service owns each link
   (produce / prove / promote / reverse / measure) and what breaks if that link is removed.
2. **Answer "what code is running in production right now?"** for a system they designed, and explain
   why a `:latest` tag makes that question unanswerable.
3. **Write a `buildspec.yml` from memory** for a containerized Go service, including cache
   configuration, and explain why each phase is where it is.
4. **Choose between CodePipeline and GitHub Actions** for a given team and justify it on concrete
   grounds (trust model, artifact store, approval semantics, cost) rather than preference.
5. **Write an IAM trust policy for GitHub OIDC** that is correctly scoped to one repository and one
   branch, and explain what a too-wide `sub` condition grants.
6. **Configure a blue/green ECS deployment with alarm-triggered rollback**, and state what the
   deployment circuit breaker does and does not catch.
7. **Explain where configuration lives** across image / task definition / Parameter Store / Secrets
   Manager, and defend the boundary they chose.
8. **Map the same promotion chain onto Kubernetes** — name the ECS↔K8s analog for task role, target
   group shifting, and health check, and explain why image immutability matters more on K8s.
9. **Define an SLI, an SLO, and an error budget** for a service and connect the error budget to
   deployment velocity.
10. **Measure the four DORA metrics** from a pipeline they built, naming the data source for each.
11. **Write a rollback runbook** another engineer could execute at 3am without asking questions.
12. **Estimate the monthly cost of a CI/CD stack** and name the three resources that dominate it.

## Constraints & Environment

**Accounts and tools**
- Learner's personal AWS account. Region: **us-east-1** (cheapest, earliest feature availability;
  latency is irrelevant for these labs).
- Learner's own GitHub account, connected via **CodeConnections**. AWS **CodeCommit is closed to new
  customers** (AWS stopped onboarding new accounts in July 2024) — no lab may depend on it, and any
  tutorial that opens with `git push codecommit` is unusable for this learner.
- Terraform >= 1.5, AWS CLI v2, Docker, `kind` + `kubectl` (Day 4 only).
- Go toolchain (for local iteration on the sample service; builds happen in CodeBuild).

**Cost constraints** — the learner is willing to pay but asked for maximum cost safety. Three rules
are binding on every lab in this path:

| Rule | Rationale |
|---|---|
| **Zero NAT gateways, path-wide** | ~$0.045/h (~$32/mo) plus per-GB. Fargate tasks run in public subnets with public IPs; VPC endpoints appear only where a lab teaches them. This also rules out VPC-attached CodeBuild, which no lab needs. |
| **ALB exists only on Days 3 and 5** | ~$0.0225/h plus LCU. CodeDeploy blue/green on ECS *requires* an ALB, so it cannot be avoided on those days — but it is destroyed in teardown and the teardown is *verified by CLI check*, not by trust. |
| **No EKS control plane** | ~$0.10/h (~$73/mo) before nodes or networking. Day 4 uses local `kind`. EKS Terraform is authored but never applied during this path. |

Target total spend for the week, running ~4h/day with teardown after each session: **~$0.74**
(up to ~$2.40 if the Day 3 and Day 5 stacks are left up overnight instead) — revised down from
an earlier $3–8 estimate after the per-lab costs were recomputed at the arm64 Fargate rate.
Reference prices (us-east-1, subject to change — the learner verifies at Day 0):

| Resource | Price | Notes for this path |
|---|---|---|
| CodeBuild `ARM_SMALL` | ~$0.0034/build-min | ~30% cheaper than x86 small; Go cross-compiles cleanly to arm64 |
| CodeBuild Lambda compute | cheaper still, faster cold start | Introduced on Day 1 as the default-beating choice |
| CodePipeline V2 | ~$0.002/action-min, 100 free action-min/month | The whole path likely lands inside the free allowance |
| ECR storage | ~$0.10/GB-month | `scratch`-based Go image ≈ 15 MB → effectively free |
| ECR basic scanning | free | Enhanced (Inspector) scanning is named but not enabled |
| Fargate 0.25 vCPU / 0.5 GB | ~$0.0123/h | One task; blue/green briefly doubles it |
| ALB | ~$0.0225/h + LCU | Days 3 and 5 only |
| CloudWatch alarms | 10 free, then ~$0.10/alarm-month | Path stays under 10 |
| CloudWatch Logs | ~$0.50/GB ingested | All log groups set to **1-day retention** |
| CloudWatch Synthetics canary | ~$0.0012/run | Day 5, short window only |
| `kind` cluster | $0 | Day 4 |

**Day 0 pre-flight (~30 min, outside the 18h budget)**
1. AWS Budgets alarm at $10/month with email notification.
2. CodeConnections handshake to GitHub (one-time console step; the ARN feeds Terraform).
3. Confirm region (us-east-1 recommended above; any region works if the learner prefers one) and a naming prefix, both recorded in `terraform.tfvars`.
4. Verify `aws sts get-caller-identity`, `terraform version`, `docker info`, `kind version`.

**Standing rules during authoring** (per the `building-learning-path` skill)
- No git commits, adds, or pushes on the learner's behalf — the learner owns all VCS.
- No real secrets, keys, tokens, or account IDs in any file. Placeholders plus fill-in comments;
  ship `terraform.tfvars.example`.
- Labs are **authored, not run**. No `terraform apply`, no live AWS CLI calls against real
  infrastructure during content creation.
- Every exercise ships a hint and a solution sketch. No bare problems.
- Every lab ships `README.md` + `SOLUTION.md` + `teardown.md`.

## Strategy (the core design decision)

### The mental model: a pipeline is a chain of custody

The organizing idea for all five days is that **a pipeline is not a sequence of stages that run
scripts — it is a chain of custody for one artifact.** Five links:

| Link | Question it answers | AWS service that owns it |
|---|---|---|
| **PRODUCE** | What exactly is the thing we ship, and is it identical every time? | CodeBuild → ECR |
| **PROVE** | What do we know about it, and who attested to that? | CodeBuild reports, ECR scanning |
| **PROMOTE** | How does it cross an environment boundary without changing? | CodePipeline / GitHub Actions |
| **REVERSE** | How do we undo a promotion, and how fast? | CodeDeploy, alarms, circuit breaker |
| **MEASURE** | How do we know the chain is healthy? | CloudWatch, SLOs, DORA metrics |

The payoff is that design questions become **derivable instead of memorized**. "Should we rebuild per
environment?" is not a preference once you hold the model — rebuilding severs custody, so the
artifact in prod is not the artifact you tested, so your staging evidence is void. The learner should
finish able to derive that in one breath.

PROVE is the one link without a day of its own: it is distributed across Day 1 (build reports, ECR scanning, digests as identity) and Day 2 (what each pipeline stage attests to), because proving things about an artifact is an activity that attaches to producing and promoting rather than a separate phase.

Days 1, 2, 3, and 5 walk the links in order. **Day 4 exists to falsify the model**: if the chain of
custody is a real abstraction and not an ECS-shaped story, it must survive a substrate swap to
Kubernetes. It does, and watching it survive is what converts the model from a slogan into a tool.

A single tiny Go service — `/healthz`, `/readyz`, and a deliberate poison switch — becomes an
artifact on Day 1, and the learner follows *that exact artifact* for five days.

### Why the alternatives were rejected

**Control-loop spine (SRE-first).** Frames every deploy as setpoint / measurement / actuator. Elegant,
and it makes SRE structural rather than bolted on. Rejected as the spine because it is weak at
explaining build mechanics — it would yield 18 hours of systems theory and thin CodeBuild fluency,
the opposite of the learner's stated priority. **Retained as the Day 5 synthesis lens.**

**Trust-boundary spine (security-first).** Who may cause what to run in production: IAM, OIDC,
approvals, supply chain. Genuinely senior-level, but it substantially duplicates the learner's
existing `aws_security_components` path and under-covers deployment mechanics. **Retained as a thread
woven through Days 2 and 3** (OIDC scoping, least-privilege pipeline roles, secrets at deploy time).

### What the 80% waste time on

| Trap | Why it fails |
|---|---|
| Service-first learning — CodeBuild docs, then CodePipeline docs, then CodeDeploy docs | Produces someone who can configure three services and design zero promotion strategies. This is the single largest time sink in the field. |
| Following CodeCommit tutorials | Closed to new accounts since July 2024. Hours lost before the first build ever runs. |
| Mutable `:latest` tags | Destroys custody. "What is in prod?" becomes unanswerable, and rollback becomes a guess. |
| Rebuilding the image per environment | The artifact you tested is not the artifact you shipped. All staging evidence is void. |
| Long-lived IAM access keys in CI | The credential outlives the engineer who created it. OIDC federation solves this and takes 20 minutes to learn. |
| Happy-path-only labs | Deployment skill *is* failure skill. Someone who has never watched a rollback fire cannot design one. |
| Treating rollback as an afterthought | Reversibility is a build-time property, not an incident-time one. If the artifact is not immutable and addressable, there is nothing to roll back *to*. |
| Learning EKS before learning delivery | Kubernetes is a substrate, not a delivery model. Learners who start there acquire `kubectl` muscle memory and no promotion strategy. |
| Ignoring cost until the bill arrives | NAT gateways and idle ALBs teach an expensive lesson that a $10 budget alarm teaches for free. |

### What the top 1% do differently

- They design the **artifact** first and the pipeline second.
- They can state, for any stage, **what it proves** — and delete stages that prove nothing.
- They rehearse rollback deliberately, because the first rollback should never be during an incident.
- They treat the **trust boundary of CI** as production infrastructure, not developer tooling.
- They measure the pipeline itself (lead time, change fail rate), not just the service.
- They can name one scenario where each pattern is the *wrong* choice.

## Curriculum

Daily shape: **~55 min content → ~2h lab → ~20 min break-it/fix-it → ~10 min teardown** ≈ 3.2–3.75 h.

### Realism check

| Day | Content | Lab | Break/fix | Teardown | Total | New AWS services |
|---|---|---|---|---|---|---|
| 1 | 55m | 115m | 20m | 5m | ~3.3h | CodeBuild, ECR |
| 2 | 60m | 120m | 20m | 5m | ~3.4h | CodePipeline, CodeConnections, GH OIDC |
| 3 | 60m | 125m | 25m | 15m | ~3.75h | CodeDeploy, ECS/Fargate, ALB, CloudWatch alarms |
| 4 | 55m | 110m | 20m | 5m | ~3.2h | none billable (`kind`) |
| 5 | 50m | 130m | 15m | 15m | ~3.5h | Synthetics, X-Ray, composite alarms |

Day 3 is the longest and the heaviest; it is placed mid-week deliberately. Day 4 is the lightest
billable day and acts as recovery before the Day 5 capstone. No day introduces more than three new
services, which is the empirical ceiling for retention at this pace.

### Day 1 — PRODUCE: what exactly is the artifact?

*Concepts.* CodeBuild in depth: buildspec phase semantics and which failures actually fail a build;
compute types, with ARM and Lambda compute as the default-beating choices; local vs S3 caching and
the 40-second-versus-6-minute difference; artifacts vs reports vs test reporting; privileged mode and
Docker-in-CodeBuild; the build role vs the pipeline role and why they must differ. ECR as the custody
register: tag immutability, lifecycle policies, basic scanning, and image digests as the true
identity.

*Lab.* Terraform a CodeBuild project that builds the Go service into a `scratch`-based image tagged
by commit SHA, pushed to ECR with tag immutability enabled and a lifecycle policy capping stored
images.

*Break it.* Disable immutability, push `:latest` twice from different commits, then attempt to answer
"which commit is in this image?" The failure to answer is the lesson.

*Anti-patterns.* `:latest`; per-environment builds; secrets as plaintext buildspec env vars; no cache;
`FROM ubuntu` for a static Go binary.

### Day 2 — PROMOTE: the pipeline is a promotion machine

*Concepts.* CodePipeline V2: stages, actions, the artifact store, source via CodeConnections with
branch and path filters, pipeline variables, manual approval gates, parallel actions, and what makes
an execution deterministically re-runnable. Then the contrast: GitHub Actions assuming an AWS role
via **OIDC** with no long-lived keys, and an explicit decision rule for when each tool is correct.
Supply-chain thread: what each stage attests to.

*Lab.* Terraform `source → build → deploy-staging → manual approval → deploy-prod`, promoting one
image digest end to end. Plus a GitHub Actions workflow with an OIDC trust policy scoped to one repo
*and* one branch.

*Break it.* Widen the OIDC `sub` condition to a wildcard and enumerate exactly what was just granted —
the most common and most consequential misconfiguration in this area.

*Anti-patterns.* Rebuilding per environment; config baked into images; static access keys in CI;
pipelines that cannot be replayed; approval gates that approve nothing specific.

### Day 3 — REVERSE: promotion is only safe if it is reversible

*The heart of the path, and the closest match to the learner's ECS Fargate day job.*

*Concepts.* CodeDeploy blue/green on ECS: target group shifting, canary vs linear vs all-at-once,
the deployment circuit breaker and its limits, health checks that actually detect a bad deploy versus
ones that pass while users suffer, CloudWatch alarms as rollback triggers, and the bake period. Where
configuration lives: image vs task definition vs Parameter Store vs Secrets Manager, and how to
defend that boundary.

*Lab.* Full blue/green deployment behind an ALB with a CloudWatch alarm wired as a rollback trigger.

*Break it.* Flip the Go service's poison switch, promote the bad build, and watch traffic shift back
automatically. Then answer the two questions that matter: how long were users affected, and what
signal would have caught it sooner?

*Anti-patterns.* Health checks that only prove the process is alive; rollback plans that require a
rebuild; secrets in task definition environment variables; all-at-once deploys with no alarm.

### Day 4 — SAME CHAIN, DIFFERENT SUBSTRATE: Kubernetes, lightly

*Scope is deliberately capped at conversancy, not competence. A dedicated EKS path follows later.*

*Concepts.* Only enough Kubernetes to reason: pod / deployment / service / ingress; what the control
plane reconciles and why that differs from a deployment *event*; rolling update vs blue/green; why
image immutability matters more here; readiness probes as the deploy gate; IRSA as the exact analog
of the ECS task role. How a pipeline reaches EKS — `kubectl`-in-CodeBuild (push) vs GitOps (pull) —
and the tradeoff, with GitOps named and deferred.

*Lab.* Free local `kind` cluster. Deploy the same Day 1 image, perform a rolling update, then break
the readiness probe and watch the rollout correctly *stall* rather than ship. Additionally: authored
but never applied EKS + IRSA + ALB-controller Terraform, so the future EKS path starts from working
code.

*Anti-patterns.* Treating `kubectl apply` as a deployment strategy; missing readiness probes; node
IAM roles instead of IRSA; assuming a Deployment rollback restores data.

### Day 5 — CLOSE THE LOOP: SRE, and the capstone

*Concepts.* SLIs, SLOs, and error budgets, with the error budget connected to deployment velocity;
the four golden signals; DORA metrics (lead time, deploy frequency, change failure rate, MTTR) and
the concrete data source for each in the pipeline the learner built; composite alarms to suppress
noise; synthetic canaries; structured logging; X-Ray basics. Cost review of the full stack.

*Capstone.* End to end: commit → build → scan → promote → canary → alarm breach → auto-rollback. The
learner then writes two documents — an SLO definition and a rollback runbook executable by another
engineer at 3am. Those documents are the real deliverable of the path.

### Deliberately out of scope

Named and explained where relevant, but not built: CodeArtifact; cross-account and multi-region
promotion; Argo CD / Flux GitOps; chaos engineering; on-call and incident-command process; CodeGuru;
deep EKS (its own path); service mesh.

## Directory Layout

```
aws_devops_sre/
├── README.md                          # quickstart, Day 0 pre-flight, day index, how to use
├── STRATEGY.md                        # chain-of-custody model, the 80% traps, the 1% habits
├── COST.md                            # per-lab estimates, budget alarm setup, teardown verification
├── content/
│   ├── GLOSSARY.md                    # plain-English terms (artifact, digest, IRSA, error budget…)
│   ├── day01.md                       # PRODUCE
│   ├── day02.md                       # PROMOTE
│   ├── day03.md                       # REVERSE
│   ├── day04.md                       # substrate swap (K8s, light)
│   └── day05.md                       # MEASURE + capstone
├── app/                               # the artifact followed for 5 days
│   ├── main.go                        # /healthz, /readyz, poison switch via env var
│   ├── go.mod
│   └── Dockerfile                     # multi-stage → scratch, arm64
├── labs/
│   ├── verify-teardown.sh             # read-only audit: did anything billable survive?
│   ├── day00/README.md                # pre-flight checklist + budget alarm
│   ├── foundation/                    # VPC (public subnets) + ECR repo; ~$0/month
│   │                                  #   stood up on Day 1, destroyed after Day 5;
│   │                                  #   day labs read it via terraform_remote_state
│   ├── day01/                         # README, SOLUTION, main.tf, variables.tf,
│   ├── day02/                         #   terraform.tfvars.example, buildspec.yml,
│   ├── day03/                         #   teardown.md  (+ day02: .github/workflows example)
│   ├── day04/                         # kind manifests + authored-only eks/ subdir
│   └── day05/
└── docs/superpowers/
    ├── specs/2026-09-02-aws-devops-sre-design.md
    └── plans/2026-09-02-aws-devops-sre-plan.md
```

`COST.md` is an addition to the repo's usual convention, justified by the learner's explicit request
for maximum cost safety: per-lab estimates, the Day 0 budget alarm, and a "did I actually tear it
down?" verification script deserve a file rather than a paragraph in the README.

`labs/foundation/` exists because the artifact must outlive any single lab: if each day
re-created its own ECR repository, the chain of custody would be a story the path tells rather than a
fact the learner can verify. It holds only free or near-free resources (VPC, IGW, public subnets,
route tables, and one ECR repository holding a ~15 MB image), so it is safe to leave standing for the
week. `labs/verify-teardown.sh` is the read-only audit `COST.md` and every lab teardown invoke.

`app/` is likewise an addition — the sample service is shared across all five labs rather than
duplicated per day, which is itself an instance of the chain-of-custody idea.

## Content Day Skeleton

```markdown
# Day N — <TITLE>: <the question this day answers>

**Chain link:** PRODUCE | PROVE | PROMOTE | REVERSE | MEASURE
**Time:** ~Xh (content ~Am · lab ~Bm · break/fix ~Cm · teardown ~Dm)
**Cost if you follow teardown:** ~$X.XX

## Why this matters
<One short paragraph, concrete. Ties to the learner's ECS Fargate context where it honestly does.>

## The question of the day
<One sentence the learner should be able to answer cold by the end.>

## Core concepts
<Body. Every mechanism explained in terms of the chain link it serves.
Every service claim paired with what it trades off.>

## Decision rules
<Table: "when you see X → choose Y, because Z". The derivable part.>

## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: <one line>.

## Break it / Fix it
<The deliberate failure and the question it forces the learner to answer.>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. …

## Anti-patterns / Common mistakes
<2–3 bullets, each naming the failure mode, not just the rule.>

## Teardown
<Checklist leaving zero billable resources, with the CLI check that verifies it.>

## Self-check
<3 questions mapped to the Success Criteria. If any is unanswerable, re-read which section.>
```
