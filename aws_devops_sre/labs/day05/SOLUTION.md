# Solution — Day 5 capstone

Worked answers for the capstone in `README.md`: sample DORA calculations with realistic CLI output,
a filled-in SLO document, a filled-in runbook, and a final self-check against all 12 Success Criteria
for the whole path.

## Worked DORA metrics

Sample data below is from one run of Step 3–5 in `README.md`: a bad deploy (BURN_RATE too high),
5XX alarm trips, CodeDeploy auto-rolls-back, and a prior week of normal deploys for context.

### Deployment frequency

```bash
aws deploy list-deployments \
  --application-name awsdevops-app \
  --deployment-group-name awsdevops-group \
  --create-time-range startTime=2026-08-26T00:00:00Z,endTime=2026-09-02T00:00:00Z \
  --query 'length(deployments)'
```

```
7
```

**7 deployments in a 7-day window → deployment frequency ≈ 1/day.** For a single learner running one
capstone session, that's an artificially high rate driven by the lab itself, not a real team's
cadence — the number matters less here than knowing exactly which API call produced it.

### Lead time for changes

Commit for the Step 2 change landed at `2026-09-02T02:58:41Z`. Its deployment:

```bash
aws deploy get-deployment --deployment-id d-EXAMPLE01 \
  --query 'deploymentInfo.completeTime'
```

```
"2026-09-02T03:07:55Z"
```

**Lead time = 03:07:55 − 02:58:41 = 9 minutes 14 seconds.** That's pipeline time only (build → scan →
promote → deploy) — it does not include how long the change sat in review before merge, which is a
separate, and usually larger, contributor to real-world lead time.

### Change failure rate

```bash
for d in $(aws deploy list-deployments \
  --application-name awsdevops-app --deployment-group-name awsdevops-group \
  --query 'deployments[]' --output text); do
  aws deploy get-deployment --deployment-id "$d" \
    --query '[deploymentId, deploymentInfo.rollbackInfo!=`null`]' --output text
done
```

```
d-EXAMPLE01  True
d-EXAMPLE02  False
d-EXAMPLE03  False
d-EXAMPLE04  False
d-EXAMPLE05  False
d-EXAMPLE06  False
d-EXAMPLE07  False
```

**1 rollback ÷ 7 deployments = change failure rate ≈ 14%.**

### MTTR

```bash
aws deploy get-deployment --deployment-id d-EXAMPLE01 \
  --query 'deploymentInfo.{createTime:createTime,rollbackInfo:rollbackInfo}'
```

```json
{
  "createTime": "2026-09-02T03:11:04Z",
  "rollbackInfo": {
    "rollbackDeploymentId": "d-EXAMPLE01-RB",
    "rollbackTriggeringDeploymentId": "d-EXAMPLE01"
  }
}
```

```bash
aws deploy get-deployment --deployment-id d-EXAMPLE01-RB \
  --query 'deploymentInfo.completeTime'
```

```
"2026-09-02T03:17:10Z"
```

**MTTR = 03:17:10 − 03:11:04 = 6 minutes 6 seconds.**

**Honest caveat, stated plainly:** this MTTR number covers exactly one thing — a deployment
CodeDeploy's alarm-triggered auto-rollback caught and rolled back with no human involved (this
service uses the `CODE_DEPLOY` controller, which has no ECS deployment circuit breaker at all —
what catches it is CodeDeploy failing the deployment plus `auto_rollback_configuration` on
`DEPLOYMENT_STOP_ON_ALARM`). It says nothing about how long
recovery takes when a human has to notice a symptom, decide it's real, diagnose the cause, and choose
an action — those incidents are categorically slower and this measurement method **excludes them
entirely** because they never produce a CodeDeploy `rollbackInfo` block to query. Report this as "auto-
rollback MTTR," never as "our MTTR," in front of anyone who might use the number to argue the team's
incident response is faster than it actually is for the incidents that matter most.

### Reading the four together (Exercise 2, applied to real numbers)

14% change failure rate with 6-minute auto-rollback MTTR is not, by itself, a signal to slow down
deploys. What it actually says: roughly 1 in 7 deploys needs a rollback, and when it does, the system
catches and fixes it in about 6 minutes with no human paged. The total error-budget burn from that
pattern (frequency × duration, from the SLO's error budget math below) is what should drive the
"slow down or not" decision — not the failure rate alone.

## Filled-in SLO document

A complete filled-in copy of `SLO-TEMPLATE.md` for `awsdevops-sample`:

---

**Service name:** `awsdevops-sample`, running on `awsdevops-cluster` / `awsdevops-service` behind
`<ALB_DNS_NAME>`.

**SLI definition**
- Metric: percentage of ALB requests to `awsdevops-sample` NOT recording
  `HTTPCode_Target_5XX_Count`, from `AWS/ApplicationELB`, cross-checked against the
  `CloudWatchSynthetics` `SuccessPercent` metric for canary `awsdevops-readyz` (the canary is closer
  to the user — see content/day05.md Core Concepts §2 — so it is the tie-breaker when the two
  disagree).
- Measurement window: rolling 30 days.
- Queried via: `aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name
  HTTPCode_Target_5XX_Count ...` for the numerator, `RequestCount` for the denominator.

**SLO target:** 99.5% availability. Chosen because this is a single-instance lab service with no
redundancy built in (one Fargate task, no multi-AZ target group depth) — a stricter target like
99.9% would imply reliability engineering this stack doesn't actually have.

**Error budget:** (1 − 0.995) × 43,200 min = **216 minutes per 30-day window**.

**Error budget policy**
| Burned | Action | Owner |
|---|---|---|
| 50% (108 min) | Flag in team sync; start watching burn rate trend. | Service owner |
| 75% (162 min) | New feature deploys get a second reviewer for reliability risk; canary/alarm gaps found this cycle get prioritized. | Service owner + reviewer on rotation |
| 100% (216 min) | Feature deploys freeze. Only reliability fixes and rollbacks ship until the rolling window recovers or the root cause is fixed and verified. | Eng lead |

Override: eng lead sign-off, logged in the incident channel, for one named change only — never a
blanket exception.

**Explicit exclusions:** planned maintenance announced ≥24h ahead; failures traced to the canary's own
infrastructure (its Lambda or IAM role) rather than the service; traffic to `/healthz` (liveness-only,
not a user-facing route).

**Review cadence:** every 2 weeks in the existing ops sync. Owner: service owner listed above.

---

## Filled-in rollback runbook

See `RUNBOOK-TEMPLATE.md` Part 2 for the complete filled-in worked example for `awsdevops-sample` —
reproduced in full there rather than duplicated here, so there is exactly one canonical copy. Summary
of what it demonstrates end to end: alarm fires → `aws deploy get-deployment` shows CodeDeploy already
auto-rolled-back (`rollbackInfo` populated) → dashboard and Logs Insights checked for corroborating
signal (and the Logs Insights step comes back empty, exposing the same instrumentation gap as
Exercise 3, live during an incident) → decision tree correctly routes to "roll back now" because the
alarm fired inside the bake window → rollback confirmed via both the deployment API and the alarm's
`OK` state → notified in `#awsdevops-incidents` → postmortem record includes the 6m6s auto-rollback
MTTR, labeled honestly as auto-rollback-only.

## Self-check — all 12 Success Criteria, mapped to the day that covered each

| # | Success Criteria | Covered in |
|---|---|---|
| 1 | Explain the chain of custody for a deployed artifact — name which AWS service owns each link and what breaks if it's removed | **Day 1–5**, introduced Day 1 (`content/day01.md`), completed here — MEASURE is the fifth and final link |
| 2 | Answer "what code is running in production right now?" and explain why `:latest` makes that unanswerable | **Day 1** — image digests as true identity, tag immutability |
| 3 | Write a `buildspec.yml` from memory for a containerized Go service, including cache configuration | **Day 1** — CodeBuild phases and caching lab |
| 4 | Choose between CodePipeline and GitHub Actions for a given team, justified on concrete grounds | **Day 2** — trust model, artifact store, approval semantics, cost decision rules |
| 5 | Write an IAM trust policy for GitHub OIDC scoped to one repo and one branch, and explain a too-wide `sub` condition | **Day 2** — OIDC lab and Break-It (widened `sub` wildcard) |
| 6 | Configure a blue/green ECS deployment with alarm-triggered rollback; state what CodeDeploy's health-check gate and `DEPLOYMENT_FAILURE`/`DEPLOYMENT_STOP_ON_ALARM` auto-rollback do and do not catch (and why this `CODE_DEPLOY`-controlled service has no ECS deployment circuit breaker at all) | **Day 3** — CodeDeploy blue/green lab, poison-switch Break-It |
| 7 | Explain where configuration lives across image / task definition / Parameter Store / Secrets Manager, and defend the boundary | **Day 3** — configuration-boundary section |
| 8 | Map the promotion chain onto Kubernetes — ECS↔K8s analogs for task role, target group shifting, health check; why image immutability matters more on K8s | **Day 4** — substrate-swap day |
| 9 | Define an SLI, an SLO, and an error budget for a service, and connect the error budget to deployment velocity | **Day 5** — Core Concepts §1, `SLO-TEMPLATE.md`'s error budget policy |
| 10 | Measure the four DORA metrics from a pipeline they built, naming the data source for each | **Day 5** — Core Concepts §4, worked calculations above |
| 11 | Write a rollback runbook another engineer could execute at 3am without asking questions | **Day 5** — `RUNBOOK-TEMPLATE.md`, filled-in worked example |
| 12 | Estimate the monthly cost of a CI/CD stack and name the three resources that dominate it | **Day 5** — Core Concepts §9 cost retrospective (ALB dominates; CodeBuild minutes and Fargate task-hours are the next two, both well behind it) |

If any row above is unanswerable without re-reading its day's content file, that's the honest signal
to go back — this table is the path's own final exam, not a formality.
