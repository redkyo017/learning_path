# Rollback runbook — `<SERVICE_NAME>`

**Audience:** an engineer paged at 3am who did not build this system and has never seen this document
before tonight. Every command below must be copy-pasteable as written, with only the bracketed
placeholders replaced. If a step requires knowledge that lives only in someone's head, it isn't done —
write it down.

A blank runbook teaches nothing, so this file has two parts: the blank template you fill in for your
own service, and a filled-in worked example for the sample service built in this lab. Read the worked
example first if this is your first time through — then fill in the blank template for your own
service.

---

## Part 1 — blank template

Copy this section, fill in every `<...>`, and delete this line.

### Symptom

`<What the page actually says — the exact alarm name and the exact text of the notification. e.g.
"CloudWatch alarm <ALARM_NAME> is in ALARM: <METRIC> breached <THRESHOLD>.">`

### First check — run these, in order

1. **Is this a real rollback, or already handled?** Check whether CodeDeploy already auto-rolled back:

   ```bash
   aws deploy list-deployments \
     --application-name <CODEDEPLOY_APP_NAME> \
     --deployment-group-name <CODEDEPLOY_GROUP_NAME> \
     --include-only-statuses Succeeded Failed Stopped \
     --query 'deployments[0]' --output text
   ```

   Then check that deployment's detail for a `rollbackInfo` block:

   ```bash
   aws deploy get-deployment --deployment-id <DEPLOYMENT_ID> \
     --query 'deploymentInfo.{status:status,rollbackInfo:rollbackInfo,completeTime:completeTime}'
   ```

   If `rollbackInfo` is already populated and `status` is a terminal success, CodeDeploy's
   alarm-triggered auto-rollback already acted — skip to **Confirm it worked**, below.

2. **What does the dashboard say right now?** `<CLOUDWATCH_DASHBOARD_URL_OR_NAME>` — check all four
   golden signals, not just the one that paged. A latency page with errors also elevated is a
   different situation than a latency page alone.

3. **What do the logs say?** Run the Logs Insights query for the last 15 minutes:

   ```
   fields @timestamp, @message
   | filter @message like /5\d\d|error|panic/
   | sort @timestamp desc
   | limit 50
   ```

   `<Note here which log group this targets, and what you're actually looking for — this path's
   own sample-service logs are not yet structured enough for a field-level query; see the worked
   example below for what to do about that honestly.>`

### Decision tree — roll back now, or investigate first?

```
Is the alarm that paged tied to a deployment that completed in the last <BAKE_WINDOW_MINUTES> minutes?
├── YES → roll back now. Do not spend time diagnosing root cause first — a fresh deploy is the
│         highest-probability cause of a fresh alarm, and rollback is fast and reversible. You can
│         diagnose the bad build off to the side, after traffic is safe.
└── NO  → this is not a deployment problem (or the deployment is old enough that a rollback target
          is stale/irrelevant). Investigate: check the golden-signals dashboard for what actually
          changed, check dependency health, check for a config or infra change outside the pipeline.
          Escalate per "Who to notify" below rather than guessing.
```

`<Fill in your own BAKE_WINDOW_MINUTES — how long after a deploy completes do you still treat "just
deployed" as the leading suspect? This lab's CodeDeploy bake period from Day 3 is one input to that
number, not the whole answer.>`

### The rollback command

```bash
aws deploy stop-deployment \
  --deployment-id <DEPLOYMENT_ID> \
  --auto-rollback-enabled
```

`<If your deployment group's alarm-triggered auto-rollback already triggers this automatically on the
alarm that paged, say so here explicitly — and give the manual command anyway, because the engineer at 3am
needs to know what to run if the automatic path didn't fire, or if they need to abort a bad
deployment BEFORE the alarm's evaluation periods elapse.>`

### Confirm it worked

```bash
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID> \
  --query 'deploymentInfo.{status:status,completeTime:completeTime}'
```

`<Then confirm at the traffic layer, not just the deployment-API layer — e.g. curl the health route
directly, or watch the alarm referenced in "Symptom" return to OK:>`

```bash
aws cloudwatch describe-alarms --alarm-names <ALARM_NAME> \
  --query 'MetricAlarms[0].StateValue'
```

Rollback is confirmed when both: (1) the deployment API reports the rollback deployment `Succeeded`,
and (2) the alarm that paged has returned to `OK` — not just stopped increasing.

### Who to notify

- `<Primary: e.g. #<team>-incidents Slack channel, post the alarm name, the deployment ID rolled
  back, and the confirm-it-worked evidence above.>`
- `<Escalate to: e.g. service owner / on-call lead, if rollback does NOT resolve the symptom within
  <N> minutes — that means this was not a deployment problem after all, and the decision tree above
  was wrong for this incident.>`
- `<Anyone downstream who depends on this service and needs to know it was degraded, even briefly.>`

### What to record for the postmortem

- Exact timestamps: when the alarm fired, when rollback started, when it completed, when the alarm
  returned to OK. (This is your MTTR number for this incident — and note honestly whether it was
  auto-rollback-only or needed a human step, per content/day05.md Core Concepts §4.)
- The deployment ID rolled back, and the artifact digest it was running (chain of custody: what was
  actually in production during the incident).
- The output of every command in "First check," pasted verbatim — not summarized. Summaries lose the
  detail that explains *why* the decision tree pointed where it did.
- Whether the decision tree above gave the right answer. If it said "investigate" and the real cause
  turned out to be the deployment anyway (or vice versa), that's a signal this runbook needs updating,
  not that the responder made a mistake.

---

## Part 2 — worked example: `awsdevops-sample`

### Symptom

CloudWatch alarm `awsdevops-real-outage` is in ALARM: the composite alarm combining
`awsdevops-rollback-5xx` (Day 3's `rollback_alarm_name`) and `awsdevops-p99-latency` (this lab) has
fired — meaning both a real error-rate spike AND elevated p99 latency are happening at once, which by
design (content/day05.md Core Concepts §5) is a strong real-outage signal, not noise.

### First check — run these, in order

1. **Is this a real rollback, or already handled?**

   ```bash
   aws deploy list-deployments \
     --application-name awsdevops-app \
     --deployment-group-name awsdevops-group \
     --include-only-statuses Succeeded Failed Stopped \
     --query 'deployments[0]' --output text
   # -> d-EXAMPLE01

   aws deploy get-deployment --deployment-id d-EXAMPLE01 \
     --query 'deploymentInfo.{status:status,rollbackInfo:rollbackInfo,completeTime:completeTime}'
   ```

   Output showed `"status": "Succeeded"` with a non-null `rollbackInfo` — CodeDeploy's alarm-triggered
   auto-rollback already caught it and rolled back automatically. Time to move to "Confirm it worked."

2. **Dashboard:** `awsdevops-golden-signals` (this lab's `aws_cloudwatch_dashboard`) — 5XX count
   spiked sharply starting at the deployment's `startTime`, p99 latency climbed less sharply but
   crossed the 1s alarm threshold about 90 seconds later. Both signals now flat again post-rollback.

3. **Logs:** ran the Logs Insights query above against the ECS task's log group. It returned nothing
   useful — `app/main.go` only logs a startup line, no per-request line, so there is nothing to
   `filter` on for this specific incident. This is the exact instrumentation gap named in
   content/day05.md Core Concepts §7 and Exercise 3, showing up for real during an incident instead
   of as an exercise.

### Decision tree applied

The alarm fired 4 minutes after a new deployment completed — well inside this service's 10-minute
bake window. **Roll back now** branch applies. Root-cause diagnosis (in this drill: the poison switch
or `BURN_RATE` env var was set too high in the new task definition, per Day 3's Break-It exercise) can
happen after traffic is safe, not before.

### The rollback command

CodeDeploy's alarm-triggered auto-rollback already ran this automatically — confirmed above via
`rollbackInfo`. Had it not fired (e.g. the responder wants to abort before the alarm's evaluation
periods elapse), the manual command is:

```bash
aws deploy stop-deployment \
  --deployment-id d-EXAMPLE01 \
  --auto-rollback-enabled
```

### Confirm it worked

```bash
aws deploy get-deployment --deployment-id d-EXAMPLE01 \
  --query 'deploymentInfo.{status:status,completeTime:completeTime}'
# -> { "status": "Succeeded", "completeTime": "2026-09-02T03:14:22+00:00" }

aws cloudwatch describe-alarms --alarm-names awsdevops-real-outage \
  --query 'MetricAlarms[0].StateValue'
# -> "OK"
```

Both conditions met: rollback deployment succeeded, and the composite alarm returned to OK about 3
minutes after rollback completed (the alarm's own evaluation period, not an instant flip).

### Who to notify

- Posted to `#awsdevops-incidents` with the alarm name, deployment ID `d-EXAMPLE01`, and the two
  confirm-it-worked outputs above.
- No further escalation needed — rollback resolved the symptom within the 10-minute window, which
  confirmed the decision tree's assumption (deployment problem) was correct for this incident.

### What to record for the postmortem

- Alarm fired 03:11:04 UTC. Rollback deployment completed 03:14:22 UTC. Alarm returned OK 03:17:10
  UTC. MTTR for this incident (auto-rollback only, no human diagnosis needed): **6 minutes 6
  seconds**, measured `createTime` of the rollback deployment to the alarm's OK transition — see
  content/day05.md Core Concepts §4 for why this number is honest only because a human never had to
  get involved.
- Rolled-back deployment ID `d-EXAMPLE01`; bad artifact digest recorded from that deployment's task
  definition (`<sha256:...>` — chain of custody again: knowing exactly what was running is what made
  "roll back to what" an unambiguous question).
- Command outputs from "First check," pasted verbatim into the incident doc.
- Runbook accuracy: decision tree correctly routed to "roll back now." Logged as a follow-up: the
  Logs Insights step returned nothing useful — instrumentation work from Exercise 3 is now a tracked
  action item, not just a lab exercise.
