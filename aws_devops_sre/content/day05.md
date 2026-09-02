# Day 5 — MEASURE: how do we know the chain is healthy?

**Chain link:** MEASURE
**Time:** ~3.5h (content ~50m · lab ~130m · break/fix ~15m · teardown ~15m)
**Cost if you follow teardown:** ~$0.11

## Why this matters

Every link you built this week — produce, prove, promote, reverse — exists to get a known artifact
running safely in production. None of that tells you whether production is actually *healthy*, or
lets you prove it to someone who didn't build it. That's a different question, and it needs its own
instrumentation: a target you agreed to hit, a budget for how often you can miss it, and numbers
about the pipeline itself — not just the service — that say whether the chain is getting faster or
slower, safer or riskier. On your day job, this is the difference between "the WSO2 deployment looks
fine" and being able to tell your manager, with a number, whether this week's deploys made things
better or worse.

## The question of the day

How do we know the chain is healthy, and how do we prove it to someone else?

## Core concepts

### 1. SLI → SLO → error budget, and the dial it controls

An **SLI** (service level indicator) is a measurement: the proportion of requests to `/readyz` that
return `2xx`, taken over some window. An **SLO** (service level objective) is a target on that
measurement: "99.5% of `/readyz` requests succeed, measured over a rolling 30 days." The **error
budget** is what the target leaves you: if the SLO is 99.5%, you are allowed 0.5% badness. That's it —
three ideas, in order.

Here is the part that makes the three ideas operational instead of decorative: **the error budget is
the deployment velocity dial.**

- Budget remaining → ship. Deploy the next feature, run the next canary, take the next risk your
  error budget can absorb.
- Budget exhausted → stop shipping features. Spend the team's next cycle on reliability work —
  fixing the thing that burned the budget — not on the next feature, until the budget recovers.

If your SLO document doesn't say what happens at each burn threshold, it isn't a policy, it's a
number on a slide. `SLO-TEMPLATE.md` in this lab has an explicit **error budget policy** section for
exactly this reason — a document without one is decoration.

### 2. Choosing an SLI: as close to the user as possible

The natural instinct is to reuse Day 3's `HTTPCode_Target_5XX_Count` alarm as your SLI. It's a fine
*alarm* — reused this week for exactly that purpose — but as an SLI it is a **proxy**, not a direct
measurement of user experience, and proxies have blind spots:

- A `200` response carrying the wrong body (a stale cache, a partial render) never shows up as a
  5XX. The ALB thinks the request succeeded; the user didn't get what they asked for.
- Client-side failures — a mobile app that times out waiting for a slow-but-eventually-200 response,
  a JS error rendering a correct payload — never touch the ALB at all.
- Anything that fails *before* the request reaches the ALB (DNS, TLS handshake, a client that can't
  resolve your domain) is invisible to a metric the ALB itself emits.

The rule: measure as close to the user as you can afford to. A synthetic canary hitting `/readyz`
from outside your VPC (this lab) is closer to the user than a target-group metric; real user
monitoring in a browser SDK would be closer still. Every step further from the user's actual
experience is a step where problems can hide.

### 3. The four golden signals, mapped to what Day 3 already gives you

| Golden signal | What it means | CloudWatch metric on the Day 3 stack |
|---|---|---|
| Latency | How long requests take | `AWS/ApplicationELB` `TargetResponseTime` (this lab adds a p99 alarm on it) |
| Traffic | How much demand there is | `AWS/ApplicationELB` `RequestCount` |
| Errors | Rate of failed requests | `AWS/ApplicationELB` `HTTPCode_Target_5XX_Count` (Day 3's rollback alarm) |
| Saturation | How full the system is | `AWS/ECS` `CPUUtilization` / `MemoryUtilization` on the Day 3 service |

You already own all four metrics — nothing new to instrument. This lab's dashboard (`main.tf`) puts
all four in one place, which is the point: an incident channel with four separate graphs is slower to
read than one dashboard with all four signals framed the same way.

### 4. DORA metrics, measured from the pipeline you actually built

DORA metrics measure the *pipeline*, not the service. For each one, here is the exact data source in
what you built this week — no hand-waving, no separate tool:

| DORA metric | Exact data source in this path |
|---|---|
| Deployment frequency | `aws deploy list-deployments` against Day 3's CodeDeploy application — count of deployments in a window |
| Lead time for changes | The commit timestamp (from `git log` or GitHub's API for the commit that triggered the pipeline) subtracted from that deployment's `completeTime` (`aws deploy get-deployment`) |
| Change failure rate | Deployments whose `get-deployment` response includes a non-empty `rollbackInfo` block, divided by total deployments in the window |
| MTTR (mean time to restore) | A rolled-back deployment's `createTime` subtracted from the timestamp its rollback deployment reports `completeTime` |

Be honest about what that MTTR number actually covers: it only measures deployments that Day 3's
alarm-triggered auto-rollback (CodeDeploy failing the deployment plus `auto_rollback_configuration`
on `DEPLOYMENT_STOP_ON_ALARM` — not an ECS deployment circuit breaker, which doesn't exist on this
`CODE_DEPLOY`-controlled service) caught and rolled back. It says nothing about an incident that
needed a human to notice, diagnose, and decide — those take longer, by definition, and this
measurement method **undercounts** them because they never show up as a CodeDeploy rollback at all.
A pipeline-only MTTR number is optimistic. Say so when you report it.

### 5. Composite alarms: one incident, one page

Five separate alarms firing for one real outage produce five pages, five Slack messages, and one
confused on-call engineer trying to figure out if this is five problems or one. A **composite alarm**
collapses that: `ALARM(a) AND ALARM(b)` only fires when both underlying alarms are already in ALARM
state, which is a much stronger signal than either alone.

This lab's composite alarm combines Day 3's 5XX rollback alarm with a new p99 latency alarm — the
noise-reduction tradeoff is explicit in a comment in `main.tf`: requiring both means a spike in one
signal alone (a brief latency blip with no error increase, or a low-volume error burst that hasn't
moved p99) won't page anyone. That's the correct tradeoff for a page, and the wrong one for a
dashboard — dashboards should still show every underlying signal, even ones that never escalate.

Cost angle: composite alarms are **not** part of the standard-alarm free tier. They're billed
separately, as their own line item, at roughly $0.50/alarm-month, regardless of how many of the
first-10-free standard alarms you're using. One composite alarm for a few hours of lab time is a
fraction of a cent, but don't reason about its cost by counting it against the 10-free-alarms
allowance — that allowance is for standard metric alarms only.

### 6. Synthetic canaries: the signal that works at zero traffic

Every signal in section 3 depends on real traffic existing. A CloudWatch Synthetics **canary** is
different: it's a scheduled script (this lab: a Node.js heartbeat) that generates its own traffic on
a fixed interval, so it produces a signal even when nobody is hitting your service — which is exactly
the situation in this lab between exercises, and exactly the situation at 3am in production. At
roughly $0.0012/run, a canary running every 5 minutes costs a fraction of a cent per hour.

The part that surprises people at teardown: a Synthetics canary silently creates two extra resources
on your behalf — an **S3 bucket** for its screenshots/logs (`aws_synthetics_canary` requires one) and
a **Lambda function** it packages and runs your script inside. Neither shows up if you only think
"I created one canary." Both are teardown traps, called out again in `teardown.md`.

### 7. Structured logging: back to `app/main.go`

Go back to the log lines you've been shipping since Day 1:

```go
log.Printf(`{"level":"info","msg":"starting","version":%q,"commit":%q,"port":%q,"poisoned":%t,"burn_rate":%v}`,
    version, gitCommit, port, poisoned, burnRate)
```

It's valid JSON, which is better than nothing — but critique it honestly:

- **No timestamp field.** CloudWatch Logs stamps an ingestion time on every event, but that's *when
  CloudWatch received the line*, not when the container's own clock produced it. If you need to
  correlate this log against an X-Ray trace or another service's log during an incident, the
  container's own clock is the one that matters, and it isn't here.
- **No request ID.** The `/burn` and `/readyz` handlers log nothing per-request at all — only the
  startup line logs anything. There is no way to find "the log lines for this one request" because
  there are no per-request log lines.
- **No trace correlation.** Even if there were a per-request log line, nothing ties it to an X-Ray
  trace ID, so you can't jump from "this trace was slow" to "here are its log lines" or back.

What would need to change: emit one JSON line per request, with `timestamp` (RFC3339, from the
container clock), a generated `request_id`, the X-Ray `trace_id` if present, `status`, and
`duration_ms`. Once that exists, a CloudWatch Logs Insights query like this becomes possible:

```
fields @timestamp, request_id, status, duration_ms
| filter status >= 500
| sort @timestamp desc
| limit 20
```

Exercise 3 asks you to write the query you'd actually want (p99 latency by version) and explain why
it can't run yet — the instrumentation gap, not the query syntax, is the lesson.

### 8. X-Ray, briefly

A log line tells you what one process thought happened. A **trace** tells you what happened *across*
a request as it crosses service boundaries — which hop added the latency, which downstream call
failed. That's the thing logs alone can't give you once you have more than one service in the path.
The cost control is **sampling rules**: tracing every request at scale is expensive and mostly
redundant, so X-Ray defaults to a low fixed rate plus a reservoir, and you tune the rule rather than
tracing (or not tracing) everything. This path doesn't wire X-Ray into the sample service — one
service with no downstream calls has nothing interesting to trace — but you should be able to state
what it would buy you the moment a second service enters the picture.

### 9. Cost retrospective: which resource dominated?

Before you look at `COST.md` or any bill, answer for yourself: across the whole week — CodeBuild,
ECR, CodePipeline, Fargate, CloudWatch, Synthetics, and everything else — which single resource
dominated the spend?

**Answer: the ALB.** At ~$0.0225/hour plus LCU charges, and present for the multi-hour duration of
both Day 3 and Day 5 (it's destroyed between them and re-applied for this lab — see `README.md` Step
0), it outspends every CodeBuild minute, every Fargate task-hour, and every CloudWatch alarm
combined. Nothing else in this path comes close. That's also why teardown discipline matters more for
Day 3 and Day 5 than for any other day.

## Decision rules

| When you see... | Choose... | Because |
|---|---|---|
| You need a signal that still works with zero real user traffic (lab, 3am, new region) | A synthetic canary, not a traffic-derived alarm | Traffic-derived metrics (5XX rate, p99) are silent when there's no traffic to measure; a canary generates its own |
| Five alarms could fire for the same root cause | A composite alarm gating the page, individual alarms still visible on the dashboard | Cuts pages to one per incident without losing per-signal visibility for diagnosis |
| Change failure rate is high but MTTR is low | Don't automatically slow down deploys | Total error-budget burn (frequency × duration) is what matters, not either number alone — see Exercise 2 |
| An SLO document has a target but no stated action at 50/75/100% burn | Treat it as incomplete, not ready to operate against | Without an error-budget policy, "we missed the SLO" has no defined consequence, so the target changes nothing |
| A log line has no timestamp, request ID, or trace correlation | Don't build a Logs Insights query around it yet | Fix the instrumentation gap first; a clever query over ungrounded data still can't answer the question |

## Lab

See `labs/day05/`. Goal: run the full capstone — commit, build, promote, canary deployment, drive
`/burn` traffic until the 5XX alarm breaches, watch CodeDeploy auto-rollback, then pull all four DORA
metrics from the pipeline with the AWS CLI and fill in `SLO-TEMPLATE.md` and `RUNBOOK-TEMPLATE.md`
for the sample service. Success signal: **you can hand both filled-in documents to another engineer
and they could operate this service without asking you a question.**

## Break it / Fix it

`app/main.go` ships a `LATENCY_MS` env var (a fixed delay applied to `GET /` and `GET /burn` before
either responds — see `app/README.md`) precisely so this exercise can drive two genuinely different
failures, not the same one twice. Register three new Day 3 task definition revisions in turn (same
mechanic as Day 3's own Break-It), redeploy, and drive `/burn` traffic against each:

1. **5XX-only** (`BURN_RATE=0.5`, `LATENCY_MS=0`): fast, cheap errors. Day 3's 5XX alarm trips.
   `TargetResponseTime` barely moves — a `500` returned in a few milliseconds doesn't touch p99 — so
   the p99 alarm stays `OK`, and this lab's composite alarm, which requires *both*, stays `OK` too.
2. **Latency-only** (`BURN_RATE=0`, `LATENCY_MS=1500`): every request still returns `200`, just ~1.5s
   slower than the 1s threshold. The p99 alarm trips. The 5XX alarm stays `OK` — nothing is actually
   failing. The composite alarm stays `OK` again, for the opposite reason from stage 1.
3. **Both at once** (`BURN_RATE=0.5`, `LATENCY_MS=1500`): now both underlying alarms trip, and only
   now does the composite alarm.

Restore `BURN_RATE=0`, `LATENCY_MS=0` and redeploy after each stage before moving to the next. The
contrast is the lesson: two single-signal incidents that individually page nobody, and a combined
incident that pages once. That's Core Concepts §5's tradeoff made concrete — ask yourself which real
incident shape (stage 1 or stage 2 alone) you just decided not to page for, and whether that's the
failure mode you'd actually accept in production.

## Exercises

1. Write an SLO for the sample service, then compute the error budget in minutes for a 30-day
   window.
   **Hint:** Start from the SLI you'd actually trust (Core Concepts §2), pick a target, and multiply
   the allowed-failure fraction by the total minutes in 30 days (43,200).
   **Solution sketch:** e.g., 99.5% availability over 30 days → 0.5% × 43,200 min = 216 minutes of
   budget. The exact number matters less than being able to say, out loud, what spends it — every
   minute of `/readyz` failure, every canary run that comes back non-200.

2. Your change failure rate is 20% but MTTR is 4 minutes. Should you slow down deploys?
   **Hint:** DORA metrics are meant to be read together, not one at a time — think about total error
   budget burned (failure rate × recovery time × request volume during the failure) rather than
   either number in isolation.
   **Solution sketch:** Probably not. A high failure rate with fast, automatic recovery can burn less
   error budget than a low failure rate with slow, manual recovery — 1-in-5 deploys failing for 4
   minutes each is a different risk profile than 1-in-20 deploys failing for an hour each. Compare
   total budget burn, not either number alone. This is exactly the reasoning DORA is for.

3. Write a CloudWatch Logs Insights query returning p99 latency by version from the sample service's
   logs, then explain why it cannot work as the logs are currently written.
   **Hint:** Look again at the two log lines `app/main.go` actually emits, and check whether either
   one carries a latency value or a per-request line at all.
   **Solution sketch:** A query like
   `fields @timestamp, version, duration_ms | stats pct(duration_ms, 99) by version` is the shape
   you'd want — but the app logs no `duration_ms` field and no per-request line at all (only a
   startup line). The exercise is to notice that the *instrumentation* is the gap, not the query
   syntax — see Core Concepts §7.

4. Design a composite alarm that pages only for a real user-facing outage.
   **Hint:** You want a real-traffic signal and an independent, always-on signal to both be true —
   which two alarms in this lab qualify?
   **Solution sketch:** `ALARM(5xx_rate) AND ALARM(canary_failure)` — requiring both a real-traffic
   signal and a synthetic one filters out single-source noise (a canary blip with no real user
   impact, or a low-volume real error that hasn't tripped the canary's own check). Then state the
   failure mode you just accepted: a real outage that only affects real users and happens to fall
   between two canary runs (up to your 5-minute schedule interval) is now slower to page than a
   single-alarm design would have been.

## Anti-patterns / Common mistakes

- **SLOs with no error-budget policy.** A target with no stated consequence at 50/75/100% burn is a
  number on a slide, not something a team operates against — see Core Concepts §1.
- **Alarming on causes instead of symptoms.** An alarm on CPU utilization tells you a resource is
  busy; it doesn't tell you a user was affected. Alarm on what the user experiences (error rate,
  latency, canary failure), and use cause-level metrics for diagnosis after the symptom alarm pages.
- **Measuring MTTR only for auto-rollbacks.** It's the easy number to compute from `list-deployments`
  and it systematically undercounts the incidents that actually needed a human — see Core Concepts
  §4. Report it labeled for what it is, not as "our MTTR."
- **Never-expiring log retention.** Every CloudWatch log group this path's Terraform *declares* is
  set to `retention_in_days = 1`. This lab is the one honest exception, and it's an instructive one:
  the Synthetics canary causes AWS to auto-create a `/aws/lambda/cwsyn-<canary>-<id>` log group
  behind the scenes, with never-expire retention, and it is not a Terraform resource at all —
  `terraform destroy` cannot touch it. That's precisely the anti-pattern this bullet warns about,
  showing up in this path's own lab. See `teardown.md` for the manual delete step it requires.

## Teardown

Follow `labs/day05/teardown.md` — it also closes out the whole path, in strict order: stop the
canary first (a running canary keeps recreating artifacts even mid-teardown), empty this lab's own
capstone-pipeline artifact bucket and destroy this lab, then Day 3 (the ALB), then Day 2 (empty its
S3 bucket first), then Day 1, then finally the foundation stack. Finish with `bash
../verify-teardown.sh` and a Cost Explorer check 24 hours later — some charges land late.

## Self-check

1. You changed nothing about the service code between two deploys, but your dashboard shows p99
   latency rose and 5XX rate didn't move. Would your composite alarm from this lab page? Should it?
2. A teammate reports "our change failure rate is only 5%, we're doing great." What number would you
   ask for next before agreeing, and why?
3. Someone hands you a service with no SLO document and asks "should we ship this feature today?"
   What's missing that makes the question unanswerable, and what would you need from them first?
