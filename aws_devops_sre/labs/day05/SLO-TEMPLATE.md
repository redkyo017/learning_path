# SLO document — `<SERVICE_NAME>`

Copy this file, fill in every `<...>` placeholder, and delete this line. A blank template with the
target left as "<TARGET>" is not an SLO — see the error budget policy section below for why.

---

## Service name

`<SERVICE_NAME>` — e.g. `awsdevops-sample`, running on `<ECS_CLUSTER_NAME>` / `<ECS_SERVICE_NAME>`
behind `<ALB_DNS_NAME>`.

## SLI definition

- **Metric:** `<EXACT_METRIC>` — name the exact source, not a description. E.g. "percentage of
  `/readyz` requests returning `2xx`, measured by the CloudWatchSynthetics `SuccessPercent` metric
  for canary `<CANARY_NAME>`" or "percentage of ALB requests NOT recording
  `HTTPCode_Target_5XX_Count`, measured from `AWS/ApplicationELB`."
- **Measurement window:** `<WINDOW>` — e.g. "rolling 30 days." State whether it's rolling or
  calendar-aligned; the error budget math in the next section depends on which.
- **How it's queried:** `<CLI_OR_CONSOLE_COMMAND>` — the exact command or console path someone would
  run to reproduce this number today, not "check the dashboard."

## SLO target and why that number

- **Target:** `<TARGET>` — e.g. "99.5% availability."
- **Why this number, not a higher or lower one:** `<JUSTIFICATION>` — tie it to something concrete:
  what the business actually needs, what the current architecture can realistically sustain, or what
  peer services in the same org commit to. "Because 99.9% sounds more professional" is not a
  justification — it's a budget you can't spend on anything else. A number with no justification is
  as undefined as no number at all.

## Error budget

- **Formula:** `(1 - target) × minutes in window`
- **This service's budget:** `<BUDGET_MINUTES>` minutes per `<WINDOW>`.
  Worked example at 99.5% over 30 days: `(1 - 0.995) × 43,200 min = 216 min`.
- **What spends it:** `<WHAT_SPENDS_IT>` — every minute the SLI in this document is outside its
  target: canary failures, 5XX responses at volume, a rollback's bake period if it doesn't already
  count as "up." Name it precisely enough that two engineers reading this would count the same
  incident the same way.

## Error budget policy

**This section is what makes this document real instead of decorative.** An SLO with a target but no
stated consequence at each burn threshold is a number nobody is required to act on. Fill in what your
team actually commits to doing — not what sounds responsible, what you will really do — at each
threshold, and who owns enforcing it.

| Budget burned | What the team does | Who decides / enforces |
|---|---|---|
| **50%** | `<e.g. Flag it in the next team sync. No behavior change yet, but start watching burn rate — if half the budget went in a tenth of the window, that's a trend, not noise.>` | `<owner>` |
| **75%** | `<e.g. Feature work due to ship this window gets a second reviewer look for reliability risk. New canary/alarm coverage for known gaps gets prioritized over new features.>` | `<owner>` |
| **100%** | `<e.g. Feature deploys freeze. Only reliability fixes and rollbacks ship until the budget recovers (i.e., until the rolling window ages the burning incident out, or the underlying issue is fixed and verified). This is the deployment-velocity dial made explicit — see content/day05.md Core Concepts §1.>` | `<owner, typically someone with authority to actually block a deploy>` |

**Who can override the 100% freeze, and under what condition:** `<e.g. Eng lead sign-off, logged in
the incident channel, for a specific named change — never a blanket exception.>`

## Explicit exclusions

State what does NOT count against this SLO, and why. Without exclusions, every ambiguous edge case
becomes a debate during an incident postmortem instead of a decision made in advance.

- `<e.g. Planned maintenance windows, announced >24h in advance, do not count against the budget.>`
- `<e.g. Failures caused by a canary or monitoring outage itself (not the service) are excluded —
  document how you tell the difference.>`
- `<e.g. Requests to routes outside the SLI's scope (health-check-only traffic, admin endpoints) are
  excluded — name which routes are in scope and which aren't.>`

## Review cadence

- **Reviewed:** `<e.g. every 2 weeks, in the team's existing ops sync — not a new meeting.>`
- **What gets reviewed:** current burn rate, whether the target is still the right number (targets
  drift out of date as the service and its dependents change), and whether the policy above was
  actually followed the last time it triggered.
- **Owner of this document:** `<name/role>` — the person who updates it when any of the above changes,
  not just whoever wrote the first draft.

---

## Worked example — the sample service

A filled-in version of this template, for `awsdevops-sample` as built in this lab, is in
`SOLUTION.md`. Read it after you've made your own attempt, not before — filling this in yourself is
the exercise.
