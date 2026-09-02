# Day 3 — Promotion Is Only Safe If Reversible

**Chain link:** REVERSE
**Time:** ~3.75h (content ~60m · lab ~125m · break/fix ~25m · teardown ~15m)
**Cost if you follow teardown:** ~$0.13

**A note on time:** the header budget above is tight. In practice this day
tends to run 4–4.5h, almost all of it CodeDeploy waiting (canary windows,
bake periods, the health-check gate) rather than reading or typing. If
you're pressed for time, protect the hands-on lab and both Break-it stages
as one sitting; the written Exercises and Self-check below are fine to
finish separately, later.

## Why this matters

This is the day that maps directly onto your day job: deploying WSO2
components to ECS Fargate. Everything below — two target groups, a
listener CodeDeploy mutates outside Terraform, a health check that means
something, an alarm wired in as a rollback trigger — is the mechanism that
makes a Friday-afternoon deploy something you can walk away from instead
of something you sit and watch. A promotion you can't undo isn't a
deployment strategy, it's a bet. The point of today is to stop betting.

## The question of the day

How do we undo a promotion, and how long are users hurt before we do?

## Core concepts

### 1. Reversibility is a build-time property

You cannot roll back to an artifact that doesn't exist as an addressable
object. If Day 1 didn't give you an immutable, digest-addressable image —
if the "previous version" is really just "whatever tag pointed here
before someone else pushed over it" — there is nothing to reverse *to*.
Everything in this file assumes the artifact discipline from Day 1 (PRODUCE)
already holds. REVERSE is downstream of PRODUCE; a broken PRODUCE link
shows up here as a rollback that can't execute (see Exercise 4).

### 2. Blue/green on ECS

Two target groups behind one ALB listener. "Blue" holds the task set
currently receiving production traffic; "green" is where CodeDeploy stands
up the replacement task set for a new deployment. Critically: **green is a
second task set, not a second cluster, not a second service.** Same ECS
cluster, same `aws_ecs_service`, same task definition family — CodeDeploy
registers a new revision of that family, launches tasks from it, and
attaches them to the green target group. Once the deployment succeeds, the
labels swap: green becomes the new blue for next time, and the old blue
task set is torn down after its bake period.

### 3. Traffic-shifting strategies

CodeDeploy's ECS deployment configs come in three shapes:

- **`CodeDeployDefault.ECSAllAtOnce`** — every bit of traffic moves to green
  the moment it's healthy. Fastest deploy duration. Catches only what the
  health check catches (a task that fails to start or fails `/readyz`) — a
  bug that passes the health check gets 100% of traffic immediately, with
  no observation window at all.
- **`CodeDeployDefault.ECSCanary10Percent5Minutes`** — 10% of traffic moves
  to green, holds for 5 minutes, then the rest moves. Adds 5 minutes to
  deploy duration. Can catch a bug that shows up in *aggregate* metrics —
  error rate, latency — within that 5-minute window, at 10% traffic volume.
- **`CodeDeployDefault.ECSLinear10PercentEvery1Minutes`** — traffic moves in
  10 steps, one every minute (10 minutes total). Slower than canary, but
  each step is another chance for an alarm to fire before more traffic is
  exposed — a linear rollout can catch a bug that a single 10%-for-5-minutes
  canary window might miss if it happens to land outside that window.

The honest point, whichever strategy you pick: **canary and linear only
catch bugs that show up in aggregate metrics within their observation
window, at whatever percentage of traffic they're exposing.** A bug that
affects 0.1% of requests — a specific customer segment, a specific input
shape, a specific edge case — will sail through every one of these
strategies undetected, because it never generates enough failed requests
in the sampled window to move an aggregate metric. Traffic-shifting
strategies buy you statistical protection against common failure modes,
not proof of correctness.

### 4. The bake period and automatic rollback

`termination_wait_time_in_minutes` (this lab: 5) is how long the *old*
(blue) task set stays running and idle after traffic has fully shifted to
green, before CodeDeploy terminates it. This is what makes rollback fast:
if something goes wrong during the bake, CodeDeploy just points the
listener back at blue — which is still warm, still running, no cold start.
The tradeoff is direct and unavoidable: you pay for both task sets running
simultaneously for the entire bake period. Exercise 3 does the arithmetic;
the answer is that this tradeoff is nearly free at Fargate's per-task
pricing, which makes a short bake period a false economy almost every
time.

### 5. What actually gates a bad task set (it isn't the circuit breaker)

ECS has a real feature called the **deployment circuit breaker**
(`deploymentConfiguration.deploymentCircuitBreaker`) — but it only exists
for the **`ECS` rolling-update deployment controller**. This lab's service
sets `deployment_controller { type = "CODE_DEPLOY" }` (`labs/day03/ecs.tf`),
so the circuit breaker is not configured anywhere in this stack, and it
cannot be — CodeDeploy blue/green deployments don't have one. Say this
plainly to yourself now, because it is easy to reach for the familiar term
later and be wrong in an interview.

What gates a bad task set here instead is two things working together: the
ALB target group health check on the **green** task set (it must pass
`/readyz` before CodeDeploy will shift any traffic to it), and CodeDeploy's
own `auto_rollback_configuration`, which reverts to blue automatically on
either a `DEPLOYMENT_FAILURE` event (the deployment itself fails — for
example, the green task set never reaches steady state because it never
passes its health check) or a `DEPLOYMENT_STOP_ON_ALARM` event (Core
concept 7). Call this **CodeDeploy's health-check gate + `DEPLOYMENT_FAILURE`
auto-rollback** — that's the mechanism you'll watch catch Break-it stage (a)
below.

It's still worth knowing the circuit breaker by name and knowing exactly
where it fits: it's the rolling-update analog of the gate you're about to
watch CodeDeploy enforce. If this same service ran a plain ECS rolling
deployment instead of CodeDeploy blue/green, the circuit breaker — not
CodeDeploy — would be what counted consecutive health-check failures and
rolled the service back for you. Day 4 revisits this exact pairing against
Kubernetes's `progressDeadlineSeconds`.

Both mechanisms — CodeDeploy's health-check gate and ECS's circuit
breaker — watch exactly two things: does the task **start** (image pulls,
container launches), and does it **pass its health check**. That's the
entire scope of either one. Neither has any visibility into response
content, response correctness, or business logic — a task that starts
cleanly and returns HTTP 200 with the wrong data, or corrupted data, or
data for the wrong tenant, is invisible to both. This is not a gap to be
fixed by tuning either mechanism harder; it's a structural limit of what
"did the process start and answer its health check" can tell you.
**This distinction is the whole reason alarms exist as a separate control**
— an alarm can watch a metric that neither mechanism can structurally see.

### 6. Health checks that mean something

The ALB target group health check in this lab targets `/readyz`, not
`/healthz`. The two routes answer different questions:

- `/healthz` (liveness): "is the process alive?" In this app it always
  returns 200 — it doesn't check anything except that the HTTP server is
  answering requests at all.
- `/readyz` (readiness): "should this instance receive traffic right now?"
  In this app it returns 503 when `POISON=true`.

A health check pointed at a route that always returns 200 will happily
certify a broken deploy as healthy, because "the process is running" and
"the process should be trusted with traffic" are different claims. Point
your ALB target group health check at readiness, always — liveness checks
belong to the orchestrator's own container-health mechanism (ECS container
health checks, Kubernetes liveness probes), not to the traffic-routing
decision.

### 7. Alarms as rollback triggers

`alarm_configuration` on the CodeDeploy deployment group names a
CloudWatch alarm; when that alarm enters `ALARM` state during a
deployment (and `DEPLOYMENT_STOP_ON_ALARM` is in
`auto_rollback_configuration.events`), CodeDeploy stops the deployment and
reverts traffic to blue automatically. This lab wires up an ALB
`HTTPCode_Target_5XX_Count` alarm. Three parameters decide whether that
rollback is fast or theoretical:

- **`period`** — how wide a window CloudWatch sums the metric over. Wider
  windows are less noisy but slower to trip.
- **`evaluation_periods`** — how many consecutive windows must breach
  before the alarm fires. More periods reduce false positives; each one
  adds latency to detection.
- **`treat_missing_data`** — what the alarm does when a period has no
  datapoint at all. **Warning, stated plainly: `treat_missing_data =
  "missing"` on a low-traffic service produces an alarm that can go for
  long stretches without ever transitioning state, because there's often
  no datapoint to evaluate.** This lab uses `"notBreaching"` instead —
  silence reads as "no failures observed," which is the honest
  interpretation of a quiet period for a *count* metric. See Exercise 2
  for what happens to this whole calculation at real low-traffic volumes.

### 8. Where configuration lives — the four-way boundary

Four places configuration can live, and a rule for choosing among them:

| Location | What belongs there | Changes without a new deploy? |
|---|---|---|
| **Image** | Things true for every environment: the binary, its runtime, its dependencies | No — a new image is a new deploy by definition |
| **Task definition** | Things true for *this* environment but not secret: `PORT`, feature toggles you want version-pinned alongside the code | No — a new task definition revision is itself a deploy |
| **Parameter Store** | Non-secret config that should change *without* redeploying: rate limits, toggle flags, endpoints | Yes |
| **Secrets Manager** | Actual secrets — API keys, DB credentials — with rotation support, at ~$0.40/secret/month | Yes (and can rotate on a schedule) |

The rule: ask whether the value is secret, and whether it should be able
to change independently of a code deploy. Secret + independent → Secrets
Manager. Not-secret + independent → Parameter Store. Anything that should
be version-pinned with the code → the task definition (or the image, if
it's truly universal). ECS injects both Parameter Store and Secrets
Manager values into the container via the same `secrets` block in the
container definition — your application code reads an environment
variable either way and cannot tell which store it came from. That's the
point: the boundary is an operational and security decision, not something
your code needs to know about.

### 9. Task role vs. execution role

The concrete failure modes, which is the fastest way to keep these
straight: an **image pull failure** at task launch means the *execution*
role is wrong (or missing `AmazonECSTaskExecutionRolePolicy`) — the
execution role is what the ECS agent uses before your code ever runs, to
pull the image and ship logs. An **`AccessDenied` from your own
application code** calling an AWS API means the *task* role is wrong — the
task role is what your code assumes at runtime. They are separate IAM
roles serving separate halves of a task's lifecycle; conflating them (or
worse, granting your application's permissions to the execution role
"because it worked") is how a container ends up with far more AWS access
than the code running inside it actually needs.

## Decision rules

| When you see... | Choose... | Because |
|---|---|---|
| Traffic volume high enough that 10% for 5 minutes is a statistically meaningful sample | `CodeDeployDefault.ECSCanary10Percent5Minutes` | Enough real requests hit green to make an aggregate-metric alarm meaningful within the window |
| Very low traffic volume (see Exercise 2) | A longer canary window, or accept slower/less-reliable automated rollback | At low volume, no percentage/window combination reliably generates enough datapoints fast — that's a real constraint, not a config bug |
| A change you're not fully confident in (schema migration, new dependency, first deploy of a rewritten path) | `CodeDeployDefault.ECSLinear10PercentEvery1Minutes` over `CodeDeployDefault.ECSAllAtOnce` | More observation checkpoints before full exposure, at the cost of a slower rollout |
| A trivial change you've deployed the same way dozens of times, in a non-production or low-stakes environment | `CodeDeployDefault.ECSAllAtOnce` (with an alarm still configured) | The bake period and CodeDeploy's health-check gate + auto-rollback are still there; you're only skipping the *staged* traffic exposure, not the rollback mechanism |
| An ALB target group health check | Point it at a readiness route (`/readyz`), never a liveness route (`/healthz`) | Liveness answers "is the process alive," readiness answers "should this get traffic" — only the second question is what a load balancer needs answered |
| A config value that must change without a redeploy | Parameter Store (non-secret) or Secrets Manager (secret) | Task-definition values require a new revision + deployment to change; Parameter Store / Secrets Manager values don't |
| A task failing to *start*, specifically on image pull | Check the execution role first | The execution role, not the task role, governs ECR pulls and log delivery |
| Your application code getting `AccessDenied` on an AWS API call | Check the task role first | The task role, not the execution role, governs what your running code can do |

## Lab

See `labs/day03/`. **Goal:** deploy the sample app to ECS Fargate behind
an ALB using CodeDeploy blue/green, then intentionally break two
deployments in two different ways. **Success signal:** a bad build reaches
10% of traffic, an alarm fires, and traffic returns to the previous task
set without a human doing anything.

## Break it / Fix it

Two escalating stages, and the contrast between them is the core teaching
moment of this entire day (and arguably of the whole path):

**(a) `POISON=true` in a new task definition revision, deployed.** The
new task's `/readyz` fails from the moment it's checked. The green task
set never passes the ALB target group health check, so the deployment
never shifts any traffic — CodeDeploy's health-check gate stops this
before a single real request reaches the bad task, and the deployment
fails outright (`auto_rollback_configuration` on `DEPLOYMENT_FAILURE`).
Zero user impact, because nothing was ever exposed. (This is *not* the ECS
deployment circuit breaker catching it — this lab's service uses the
CodeDeploy blue/green controller, which doesn't have one. See Core concept
5.)

**(b) `BURN_RATE=0.5` in a new task definition revision, deployed.** The
new task's `/readyz` is completely unaffected — it passes the health check
cleanly, exactly like a good deploy. CodeDeploy shifts 10% of traffic to
it per the canary config. Requests hitting `/burn` now fail about half the
time, driving ALB 5XX responses up. The CloudWatch alarm trips, and
`DEPLOYMENT_STOP_ON_ALARM` triggers an automatic rollback — but only after
some real, if limited, user impact, and only because an alarm — not the
health-check gate — was watching.

**Make the distinction explicit before you run this:** CodeDeploy's
health-check gate only ever observes task startup and health checks. It
cannot see a task that starts healthy and then serves errors — that class
of failure is invisible to it by construction, not by oversight. Only an
alarm watching an independent signal (here, ALB 5XX count) catches stage
(b). Full walkthrough, commands, and the deployment-lifecycle comparison
table: `labs/day03/README.md` and `labs/day03/SOLUTION.md`.

## Exercises

1. A blue/green deploy succeeds, CodeDeploy's health-check gate never
   trips, and the service returns HTTP 200 with wrong data. Which control
   should have caught it?

   **Hint:** Walk through what the health-check gate actually inspects —
   task startup and health checks — and ask whether "wrong data at 200"
   touches either of those. (The ECS deployment circuit breaker, the
   rolling-update analog of this gate, has the exact same blind spot.)

   **Solution sketch:** None of the deployment controls — this needs an
   alarm on a *business* SLI (correctness, not availability), which is
   Day 5's territory (MEASURE). CodeDeploy's health-check gate (and the
   circuit breaker, on a rolling ECS deployment) only observes task
   startup and health checks; neither was ever designed to, or
   structurally can, catch a response that is well-formed and 200 but
   wrong.

2. Given a service handling 2 requests/minute, design a 5XX rollback
   alarm that actually fires.

   **Hint:** A 60-second period at 2 rpm sees roughly 2 requests per
   evaluation window — a single failed request can look identical to
   total silence in terms of datapoint sparsity. Think about what a short
   period with few datapoints does to signal-to-noise at this volume.

   **Solution sketch:** Short periods with few datapoints are noisy at
   this traffic volume — a single failure or a single quiet minute both
   look like "not much happened." Three honest options, none of them
   free: (1) lengthen the period (e.g., 5 or 10 minutes) and accept a
   slower rollback in exchange for a statistically meaningful sample; (2)
   use a metric math expression that computes a *rate* (5XX ÷ total
   requests) rather than a raw count, so a single failure out of two
   requests can register as meaningful without needing five raw failures;
   (3) set `treat_missing_data` deliberately and accept the tradeoff it
   implies (`notBreaching` won't false-trigger on silence but also won't
   protect you if the service silently stops responding at all — that
   failure mode needs a different alarm). The real answer this exercise
   is testing for: **at 2 rpm you cannot have both fast and reliable
   automated rollback simultaneously, and recognizing that constraint —
   rather than fighting it with alarm-config cleverness — is the correct
   engineering answer.**

3. Compute the cost of a 30-minute blue/green deploy with a 15-minute
   bake, two 0.25 vCPU / 0.5 GB Fargate tasks.

   **Hint:** Only the bake period has *two* task sets running
   simultaneously — figure out the per-task hourly rate first, then apply
   it to just the overlapping window.

   **Solution sketch:** Fargate ARM at 0.25 vCPU / 0.5 GB runs roughly
   $0.0099/hour per task. During the 15-minute (0.25h) bake, both the old
   and new task sets are running: extra cost ≈ 1 additional task ×
   $0.0099/h × 0.25h ≈ **$0.002**. Even rounding generously, bake time
   costs a fraction of a cent. The point of doing this arithmetic: bake
   time is nearly free relative to the fast-rollback capability it buys
   you, which makes cutting the bake period short to "save money" a false
   economy — the money saved is negligible and the rollback speed you give
   up is not.

4. Your rollback needs a rebuild to execute. Name the design error.

   **Hint:** Ask what the deployment actually referenced as "the previous
   version" — a specific, immutable, addressable object, or something
   that could have changed underneath you.

   **Solution sketch:** The deploy consumed a mutable reference — a tag
   that could be overwritten, or a source ref (branch, commit-ish) that
   requires re-running a build pipeline to materialize — instead of a
   stored, digest-addressable artifact. The previous artifact no longer
   exists as a thing you can point at; it has to be *recreated*, and a
   rebuild is never guaranteed to reproduce exactly what was previously
   running (dependency drift, base image updates, non-reproducible build
   steps). Custody was broken all the way back at PRODUCE (Day 1) — the
   symptom just didn't show up until REVERSE, when you actually needed to
   go backward and discovered there was nothing solid to go backward to.

## Anti-patterns / Common mistakes

- **Health checks that only prove the process is alive.** Pointing an ALB
  target group health check at `/healthz` instead of `/readyz` (or any
  liveness-only route) means the health check certifies "the HTTP server
  answers requests," not "this instance should get traffic" — a poisoned
  or misconfigured task can pass it forever.
- **Rollback plans that require a rebuild.** If reverting to "the previous
  version" means running a build pipeline instead of pointing at an object
  that already exists, your rollback plan has an RTO measured in however
  long that pipeline takes, and no guarantee the rebuild reproduces what
  was actually running before.
- **Secrets in task-definition `environment`.** Plaintext in the task
  definition is visible to anyone who can call
  `DescribeTaskDefinition` — no different from committing a credential to
  source control, just in a different system. Use the container
  definition's `secrets` block against Secrets Manager (or Parameter
  Store for non-secret values) instead.
- **All-at-once deploys with no alarm configured.** `CodeDeployDefault.ECSAllAtOnce` without an
  `alarm_configuration` means the only thing standing between a bad deploy
  and 100% of production traffic is CodeDeploy's health-check gate — which,
  per Core concept 5, cannot see the entire class of failure this lab's
  stage (b) demonstrates. Speed and safety aren't mutually exclusive;
  skipping the alarm to go faster is skipping the one control that catches
  what the health-check gate can't.

## Teardown

See `labs/day03/teardown.md` — read it in full before running anything;
it is the most detailed teardown in this path for a reason. In short:
stop any in-progress CodeDeploy deployment first (`terraform destroy`
fails while one is running), scale the ECS service to 0, run `terraform
destroy`, then check for CodeDeploy-created task sets and a
listener-mutated ALB that `destroy` can miss, then run:

```bash
bash ../verify-teardown.sh
```

and read its ALB section specifically — the ALB is the one resource in
this lab that both only exists because of Day 3 (and later Day 5) and
costs money every hour, traffic or not. **This stack is re-applied at the
start of Day 5**, so don't be surprised to rebuild it there — teardown now
still matters, because Day 5 starts from a clean `terraform apply`, not
from whatever state you left this one in.

## Self-check

1. A deploy passes its health checks, shifts traffic normally, and
   CodeDeploy's health-check gate never trips — but the service is
   returning wrong data to 100% of the users who hit it. Explain,
   precisely, why the health-check gate didn't catch this and what control
   would have.
2. Your ALB target group health check is pointed at `/healthz`. Explain
   the specific failure this allows through, and why pointing it at
   `/readyz` instead closes that gap.
3. You've been asked to add automatic rollback to a service handling 2
   requests/minute. Explain why "just add a 5XX alarm" isn't sufficient
   advice on its own, and what tradeoff you'd actually have to make.

If any of these is unanswerable without flipping back to a specific
section, that section is the one to re-read — 1 and 2 point back to Core
concepts 5–6, and 3 points back to Core concept 7 and Exercise 2.
