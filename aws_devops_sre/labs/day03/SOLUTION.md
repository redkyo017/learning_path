# Day 3 lab — solution notes

## Deployment lifecycle events, side by side

This contrast is the core teaching moment of the whole lab (and arguably
of the whole path): two deploys, both of a "bad" build, caught by two
completely different mechanisms because they fail in two completely
different ways.

| Stage | `TASK_PROVISIONING` | `/readyz` health check | Traffic shifted? | 5XX metric | Rollback trigger | Time to rollback |
|---|---|---|---|---|---|---|
| (a) `POISON=true` | Task starts, ECS retries repeatedly | **Fails** (503, every check) | **No — 0%, ever** | Not affected (no traffic reached it) | CodeDeploy's health-check gate → `DEPLOYMENT_FAILURE` auto-rollback | The green task set never becomes eligible for traffic, but CodeDeploy does not fail fast — left alone it can take up to ~1 hour. This lab has you stop it manually (`aws deploy stop-deployment --auto-rollback-enabled`) after ~2 minutes of watching it fail |
| (b) `BURN_RATE=0.5` | Task starts | **Passes** (200, unaffected by `BURN_RATE`) | **Yes — 10% (canary)** | Climbs immediately once traffic hits `/burn` | `${name_prefix}-5xx` CloudWatch alarm → `DEPLOYMENT_STOP_ON_ALARM` | Up to ~1 alarm period (60s) to detect + CodeDeploy's reaction time — worst case, most of the 5-minute canary window if traffic is thin |

The row that matters: stage (a) never shifts any traffic, so there is
nothing for an alarm to see and nothing for a human to be angry about —
that's true regardless of how long the deployment itself takes to resolve.
Stage (b) *looks* like a normal, correct deployment right up until the 5XX
count crosses the threshold — same health check, same canary percentage,
same everything CodeDeploy's health-check gate inspects. **That gate (like
the ECS deployment circuit breaker it's often confused with — this lab's
`CODE_DEPLOY` controller doesn't have one; see `content/day03.md` Core
concept 5) observes task startup and health checks. It cannot observe
response correctness, because correctness is a statement about the
response body and status code under real traffic, which is exactly what an
alarm on a business/infra metric is for and a health check is not.**

## The alarm math

```
metric_name = HTTPCode_Target_5XX_Count
namespace   = AWS/ApplicationELB
statistic   = Sum
period      = 60      # seconds
evaluation_periods = 1
threshold   = 5
comparison  = GreaterThanOrEqualToThreshold
treat_missing_data = notBreaching
```

Five or more 5XX responses, summed across a single 60-second window, from
any target behind this ALB. At `BURN_RATE=0.5` and even light traffic
(one request every couple of seconds hitting `/burn`), a 60-second window
sees enough requests to cross 5 failures quickly once the canary is live.
`evaluation_periods = 1` means the alarm doesn't wait for a second
confirming window — it fires on the first breaching period, which is what
makes the reaction time in the table above closer to "one period" than
"several."

`treat_missing_data = notBreaching` matters here specifically because the
lab traffic is bursty (you're the only source of load) — during quiet
seconds with zero requests, CloudWatch has no datapoint, and
`notBreaching` correctly treats "no traffic, so no failures" as healthy
rather than leaving the alarm's evaluation state stuck. Compare this
against Exercise 2 in `content/day03.md`, which works through what happens
to this exact alarm shape at a much lower, steadier request rate (2
rpm) — the answer is not "it just works, only slower."

## Answers to the two questions

**How long were users affected?**
- Stage (a): 0 seconds, 0 users. No traffic was ever routed to the
  poisoned task set — the failure was caught entirely by the deployment
  gate, before the "REVERSE" step (undoing a bad promotion) was ever
  needed, because nothing was promoted.
- Stage (b): some non-zero fraction of users, for roughly one alarm period
  plus CodeDeploy's reaction time, bounded above by whatever remained of
  the 5-minute canary window when the alarm fired. This is the honest
  answer for a rollback that depends on an alarm crossing a threshold —
  it is not instantaneous, and pretending otherwise is how "we have
  automatic rollback" becomes false comfort.

**What would have caught it sooner?**
- Stage (a): nothing needs to catch it sooner — it was caught before any
  user impact, which is the ceiling for "sooner."
- Stage (b): a shorter alarm period, a lower threshold, or a rate-based
  metric (5XX / total requests, via CloudWatch metric math) instead of a
  raw count would all shrink the detection window — at the cost of more
  false positives on a real, noisier production service. There is no
  version of this that is both instant and reliable; see Exercise 2.

## What you should now be able to explain

Mapped to Success Criteria 6 and 7 (`docs/superpowers/specs/2026-09-02-aws-devops-sre-design.md`):

**Criterion 6 — configure a blue/green ECS deployment with alarm-triggered
rollback, and state what the deployment circuit breaker does and does
not catch:**
- What "green" actually is: a second task set behind a second target
  group, not a second cluster or a second service.
- Why the ALB health check targets `/readyz` and not `/healthz`, and what
  would go wrong (never, ever failing) if it targeted `/healthz` instead.
- **A precise correction, since this is the single most commonly
  misstated fact in this lab:** the ECS deployment circuit breaker only
  exists for the `ECS` rolling-update deployment controller. This lab's
  service uses `deployment_controller { type = "CODE_DEPLOY" }`, so what
  actually gates and rolls back stage (a) is CodeDeploy's own health-check
  gate plus its `DEPLOYMENT_FAILURE` auto-rollback — not the circuit
  breaker. The circuit breaker is the *rolling-update analog* of that
  gate; know both names and know which one this lab actually exercised.
- What that gate inspects (task startup, health checks) and what it
  structurally cannot inspect (response correctness under real traffic) —
  stage (a) vs. stage (b) above is the proof. The ECS circuit breaker has
  the identical blind spot, for the identical reason.
- Why the alarm needs its own threshold/period tuning distinct from the
  health check's — they are answering different questions on different
  timescales.

**Criterion 7 — explain where configuration lives across image / task
definition / Parameter Store / Secrets Manager, and defend the boundary
chosen:**
- `POISON` and `BURN_RATE` live in the task definition's `environment`
  block because they're non-secret, environment-scoped knobs this lab
  needs to flip per-deployment — exactly the class of config task
  definitions are for.
- Contrast with what would belong in Parameter Store (non-secret config
  that should change *without* a new task definition revision/deploy) and
  Secrets Manager (actual secrets, ~$0.40/secret/month, with rotation) —
  see `content/day03.md` Core concept 8.
- ECS injects both Parameter Store and Secrets Manager values via the
  same `secrets` block in the container definition — the running code
  reads an env var either way and cannot tell which store it came from.
  That's the point: the boundary is an operational/security decision, not
  a code-level one.
