# AWS DevOps / SRE — Glossary

Plain-English reference for terms used across Days 1–5. Day content files
link here rather than re-defining these terms inline.

---

## Artifact

The exact, immutable thing you build once and move through every
environment — for this path, a container image identified by its digest.
It matters because the chain-of-custody model only holds if "the artifact"
refers to one specific object, not a recipe that gets rebuilt each time.

## Attestation

A recorded claim about an artifact — a test passed, a scan ran clean, a
human approved a promotion — tied to that artifact's identity. Attestations
are what let you answer "what do we know about this image?" days or months
after it was built.

## Bake period

The window CodeDeploy waits after shifting traffic to a new deployment
before it's considered safe, during which alarms are actively watched for a
rollback trigger. A bake period too short means real regressions ship
before anyone notices; too long just wastes time once you trust the alarms.

## Blue/green deployment

A release strategy that stands up a second, complete environment (green)
alongside the current one (blue) and shifts traffic between them, so
rollback is "shift traffic back" rather than "redeploy the old version."
This is the deployment model CodeDeploy uses for ECS in Day 3.

## buildspec

The YAML file (`buildspec.yml`) that tells CodeBuild what to do in each
build phase — install, pre_build, build, post_build — and what to produce
as artifacts or reports. It's the one file in this path you should be able
to write from memory by Day 5.

## Canary (deployment)

A traffic-shifting pattern that routes a small percentage of traffic to the
new version first, watches it, then increases the percentage in steps —
contrast with all-at-once, which cuts everything over immediately. Named
for the same instinct as a canary in a coal mine: catch the problem while
the blast radius is still small.

## Canary (synthetic)

A scheduled script (CloudWatch Synthetics) that calls your live endpoints
from outside your infrastructure and alarms if they fail or slow down. It
matters because it tells you a service is broken the same way a real user
would find out — not the way your internal metrics assume it's fine.

## Chain of custody

The organizing model for this whole path: a pipeline exists to carry one
artifact through a sequence of environments without letting it change
along the way, and each stage either preserves that guarantee or breaks
it. See `STRATEGY.md` for the full five-link breakdown.

## Change failure rate

One of the four DORA metrics: the percentage of deployments that result in
a failure requiring remediation (rollback, hotfix, patch). It's the metric
that keeps "deploy faster" honest — speed without this number is just
recklessness with good marketing.

## CodeConnections

The AWS service that brokers a secure, OAuth-based link between AWS and an
external source provider (GitHub, in this path), so CodePipeline and other
services can read your repository without you handing AWS a personal
access token. It replaces the older, deprecated CodeStar Connections name.

## Composite alarm

A CloudWatch alarm built from a boolean expression over other alarms (e.g.
`ALARM(a) AND ALARM(b)`), used to suppress noise by requiring several
signals to agree before it fires. It matters because a rollback trigger
built on one twitchy metric pages people for nothing.

## Deployment circuit breaker

An ECS feature that automatically detects a failing deployment (tasks that
won't reach a healthy state) and rolls it back without CodeDeploy alarms.
It catches deployments that never come up at all — it does not catch a
deployment that comes up healthy but is behaviorally wrong, which is what
CloudWatch alarms are for.

## DORA metrics

Four metrics (deployment frequency, lead time for changes, change failure
rate, mean time to recovery) identified by the DevOps Research and
Assessment team as the strongest predictors of software delivery
performance. Day 5 has you extract all four from the pipeline you built.

## Error budget

The amount of unreliability an SLO allows before it's breached (e.g. an
SLO of 99.9% availability implies a 0.1% error budget). It matters because
it turns "should we ship this risky change" into a number: if the budget
isn't spent, ship; if it is, stop shipping features and fix reliability.

## Four golden signals

Latency, traffic, errors, and saturation — the four dimensions Google's
SRE book proposes as the minimum set to instrument any service, because
between them they cover nearly every way a service actually fails users.

## Image digest

A cryptographic hash of an image's content, and the artifact's *real*
identity. Contrast with a **tag**: a tag is a label someone can move to
point at a different image tomorrow, but a digest is the content itself —
it cannot be moved without becoming a different digest. Custody is only
real when you promote digests through environments, not tags: promoting
`:latest` promotes a pointer that might mean something different by the
time it's read.

## Image tag immutability

An ECR repository setting that rejects any attempt to push a new image
under a tag that already exists. It converts "someone accidentally
overwrote `:v1.4`" from a silent, undetectable event into a rejected API
call — the cheapest single control this path teaches.

## IRSA

IAM Roles for Service Accounts — the Kubernetes mechanism that lets a pod
assume an AWS IAM role scoped to its Kubernetes service account, rather
than every pod on a node sharing the node's IAM role. It's the exact
Kubernetes analog of the ECS **task role**: see `Task role vs execution
role` below.

## Lead time for changes

One of the four DORA metrics: the time from a commit landing to that
commit running in production. It's the metric that most directly measures
what this whole path is trying to shrink — the distance between "I wrote
this" and "this is real."

## Liveness probe

A health check that answers one narrow question: is the process still
running and not deadlocked? A failing liveness probe gets the container
restarted. It does *not* mean the service is ready to serve traffic — that
is the job of the readiness probe. In this path's sample app, `/healthz`
is the liveness endpoint and always returns 200 unless the process itself
is dead.

## MTTR

Mean time to recovery — one of the four DORA metrics: the average time
from a production incident starting to it being resolved. It's the metric
that rewards fast, well-rehearsed rollback over heroics, which is exactly
what Day 3's alarm-triggered rollback is designed to produce.

## OIDC federation

A way for GitHub Actions (or any external identity provider) to assume an
AWS IAM role by presenting a short-lived, cryptographically signed token
instead of a long-lived AWS access key. It matters because a leaked OIDC
token expires in minutes; a leaked access key is valid until someone
notices and rotates it.

## Promotion

Moving one specific artifact across an environment boundary (dev → staging
→ prod) without changing it. The word is doing real work here: promotion
implies the same object advances, which is exactly what a rebuild-per-
environment strategy violates.

## Readiness probe

A health check that answers: is this specific instance currently able to
serve traffic correctly right now? Unlike a liveness probe, a failing
readiness probe doesn't restart anything — it just removes the instance
from load balancing until it passes again. In this path's sample app,
`/readyz` is the readiness endpoint and returns 503 when the `POISON`
environment variable is set to `true`, simulating a instance that's up but
unwell.

## Rolling update

A deployment strategy that replaces old instances with new ones a few at a
time, rather than all at once or via a parallel environment. It's the
default on Kubernetes and is contrasted in Day 4 with blue/green: rolling
updates use less capacity but make rollback slower and messier mid-roll.

## Rollback

Reverting production to a previously-known-good artifact, ideally by
shifting traffic or redeploying a stored digest rather than rebuilding
anything. A rollback plan that requires a rebuild is not really a rollback
plan — it's a hope that the rebuild works this time.

## SLI

Service Level Indicator — a specific, measured metric of user-facing
behavior (e.g. "percentage of requests completed in under 300ms"). An SLI
is the raw measurement; an SLO is the target you set against it.

## SLO

Service Level Objective — a target value for an SLI over a time window
(e.g. "99.9% of requests under 300ms, measured over 30 days"). SLOs are
what turn "the service should be reliable" into something you can alarm
on, budget against, and defend in a design review.

## Target group

The ALB construct that groups a set of registered targets (ECS tasks, in
this path) and health-checks them, so the load balancer knows which ones
are eligible to receive traffic. Blue/green deployments work by shifting
the ALB listener between two target groups rather than mutating one.

## Task definition

The versioned JSON/Terraform description of how to run a container on ECS
— image, CPU/memory, roles, environment variables, log configuration. Each
deployment registers a new task definition revision, which is itself part
of how ECS keeps deployments addressable and reversible.

## Task role vs execution role

The distinction beginners get wrong most often. The **execution role** is
what ECS itself uses to *start* your container — pull the image from ECR,
write logs to CloudWatch, fetch secrets referenced in the task definition.
The **task role** is what *your application code* uses at runtime — the
permissions your Go service needs to call other AWS APIs while it's
running. Mixing them up either breaks the container's ability to start, or
over-grants your application code permissions it never asked for. The
Kubernetes analog of the task role is **IRSA** (see above) — there is no
Kubernetes analog of the execution role, because kubelet doesn't need
IAM permissions to run a pod.

## Traffic shifting

The general term for moving live traffic between two versions or targets
over time — the mechanism underneath both canary deployments (shift
gradually) and blue/green (shift all at once). Every rollback in this path
is really traffic shifting run in reverse.
