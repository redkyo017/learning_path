# Day 5 lab — MEASURE: the capstone

**Goal:** run the whole chain end to end — commit, build, promote, canary deployment, drive
synthetic failure traffic, watch the alarm-triggered rollback fire, then measure the pipeline itself
with DORA metrics and turn what you learned into two documents someone else could operate from.

**Success signal:** you can hand `SLO-TEMPLATE.md` and `RUNBOOK-TEMPLATE.md`, filled in for the
sample service, to another engineer, and they could operate this service without asking you a
question.

This is one continuous exercise, not a series of independent steps — do it in order.

---

## Step 0 — bring the Day 3 stack back up

**This is not optional and it is not a formality.** Day 3's stack (ALB, ECS service, CodeDeploy app)
was destroyed at the end of Day 3's session on purpose — leaving an ALB up for two nights between
labs costs real money for zero learning value (see `labs/day03/teardown.md`). Everything in this
lab — the p99 alarm, the composite alarm, the canary, the dashboard — observes that stack, so it has
to exist again before any of this means anything.

```bash
cd ../day03
terraform apply
```

Confirm it came back with the outputs this lab reads:

```bash
terraform output
# alb_dns_name, ecs_cluster_name, ecs_service_name, codedeploy_app_name,
# codedeploy_group_name, rollback_alarm_name
```

**Why re-create it from code rather than leave it up all week:** this is itself the lesson of the
whole path. If your infrastructure is fully described in Terraform, tearing it down between sessions
and re-applying it is a ten-minute, ~$0 round trip — cheaper than paying for an idle ALB across two
nights, and proof that the Terraform is actually a complete description of the stack rather than a
partial one that only worked because a console click filled the gap. If `terraform apply` here
*doesn't* cleanly reproduce Day 3, that's a bug in Day 3's Terraform worth fixing before you go
further, not a reason to route around it by hand.

## Step 1 — apply this lab

```bash
cd ../day05
cp terraform.tfvars.example terraform.tfvars   # fill in codeconnection_arn, github_owner, github_repo
terraform init
terraform fmt -check
terraform plan
terraform apply
```

This creates the p99 latency alarm, the composite alarm, the Synthetics canary (and its S3 bucket and
IAM role), the golden-signals dashboard, all pointed at the Day 3 stack you just re-applied — **and,
per this path's capstone ruling, the capstone pipeline itself**: a CodeConnections GitHub source, a
CodeBuild project that reuses Day 1's `buildspec.yml` unchanged, and a `CodeDeployToECS` deploy action
against the Day 3 deployment group you just re-applied. This is not Day 2's pipeline reapplied — Day
2's is torn down and stays torn down. See the `RULING (C5)` comment at the top of `main.tf` for why.

Watch the canary start reporting `SuccessPercent = 100` on the dashboard within a few minutes — that
confirms it can reach `/readyz` on the re-created ALB before you touch anything else.

## Step 2 — commit a change, let this lab's own pipeline promote it

Commit a small, deliberate change to `app/main.go` (a log message tweak is enough) and push it to
`var.github_branch`. This lab's capstone pipeline (`<name_prefix>-capstone-pipeline`, applied in Step
1) picks it up automatically via its trigger filter on `app/**`. Record the commit timestamp — you'll
need it for the lead-time-for-changes DORA metric in Step 5.

Watch the pipeline execution in the console (or `aws codepipeline get-pipeline-state --name
<name_prefix>-capstone-pipeline`) move through Source -> Build -> Deploy. Confirm the new image digest
reached ECR (Build stage's `imageDetail.json`, same file and same digest logic as Day 1 and Day 2) and
that CodeDeploy started a blue/green deployment against the Day 3 service — this is the first time in
the whole path an actual pipeline execution has triggered an actual CodeDeploy deployment; every
earlier day either built the artifact by hand (Day 1), deployed by hand (Day 3), or had a
pipeline with only placeholder deploy stages (Day 2).

## Step 3 — drive `/burn` traffic and watch it fail on purpose

Once the new task set is serving traffic (or even mid-deployment, to test the bake period), drive
failure traffic against the `/burn` route to push the 5XX rate over Day 3's rollback alarm threshold:

```bash
ALB_DNS=$(cd ../day03 && terraform output -raw alb_dns_name)

while true; do
  curl -s -o /dev/null -w "%{http_code}\n" "http://${ALB_DNS}/burn"
  sleep 0.2
done
```

Let it run. Watch three things in parallel, in another terminal or the console:

1. Day 3's `rollback_alarm_name` alarm trip to `ALARM`.
2. This lab's composite alarm (`<name_prefix>-real-outage`) — does it also trip? It requires the p99
   alarm too, so a pure error-rate spike with fast, cheap 500s (unlikely to move latency much) may
   trip the 5XX alarm without tripping the composite. That's the tradeoff from `content/day05.md`
   Core Concepts §5 and this lab's Break-It exercise, live.
3. CodeDeploy roll the deployment back automatically — confirm with:

   ```bash
   aws deploy get-deployment --deployment-id <DEPLOYMENT_ID> \
     --query 'deploymentInfo.{status:status,rollbackInfo:rollbackInfo}'
   ```

Stop the `while` loop once the rollback is confirmed. Leaving it running only burns your own error
budget for no further data.

## Step 4 — the canary during zero traffic

Stop driving `/burn` traffic entirely for a few minutes and watch the dashboard. Every ALB-derived
metric (RequestCount, 5XX count, TargetResponseTime) goes flat or stops updating meaningfully — there
is no traffic to measure. The canary keeps reporting on its `rate(5 minutes)` schedule regardless.
That's Core Concepts §6 made concrete: the canary is the one signal that still tells you something at
zero traffic, which is the exact situation you're in right now, and the exact situation at 3am.

## Step 5 — pull the four DORA metrics

Use the CLI commands below, substituting your own values. `<CODEDEPLOY_APP_NAME>` and
`<CODEDEPLOY_GROUP_NAME>` are Day 3's `codedeploy_app_name` / `codedeploy_group_name` outputs
(`cd ../day03 && terraform output`) — the capstone pipeline you applied in Step 1 deploys against
that same application and group, it does not create its own.

**Deployment frequency:**

```bash
aws deploy list-deployments \
  --application-name <CODEDEPLOY_APP_NAME> \
  --deployment-group-name <CODEDEPLOY_GROUP_NAME> \
  --create-time-range startTime=<WINDOW_START>,endTime=<WINDOW_END> \
  --query 'length(deployments)'
```

**Lead time for changes** (commit timestamp from Step 2 → this deployment's `completeTime`):

```bash
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID> \
  --query 'deploymentInfo.completeTime'
# lead time = completeTime - <commit timestamp you recorded in Step 2>
```

**Change failure rate** (deployments with `rollbackInfo` present ÷ total in the window):

```bash
for d in $(aws deploy list-deployments \
  --application-name <CODEDEPLOY_APP_NAME> \
  --deployment-group-name <CODEDEPLOY_GROUP_NAME> \
  --query 'deployments[]' --output text); do
  aws deploy get-deployment --deployment-id "$d" \
    --query '[deploymentId, deploymentInfo.rollbackInfo!=`null`]' --output text
done
# count "True" rows ÷ total rows
```

**MTTR** (rolled-back deployment's `createTime` → its rollback deployment's `completeTime`):

```bash
aws deploy get-deployment --deployment-id <ORIGINAL_DEPLOYMENT_ID> \
  --query 'deploymentInfo.{createTime:createTime,rollbackInfo:rollbackInfo}'
aws deploy get-deployment --deployment-id <ROLLBACK_DEPLOYMENT_ID> \
  --query 'deploymentInfo.completeTime'
# MTTR = rollback completeTime - original createTime
```

Report this MTTR honestly: it only covers deployments CodeDeploy's alarm-triggered auto-rollback
caught and rolled back on its own — not an ECS deployment circuit breaker, which doesn't exist on
this `CODE_DEPLOY`-controlled service (see `content/GLOSSARY.md`). It says nothing about incidents that needed a human to notice and diagnose — see
`content/day05.md` Core Concepts §4 and `SOLUTION.md` for the worked numbers from this lab's own
rollback in Step 3.

## Step 6 — write the two real deliverables

Copy `SLO-TEMPLATE.md` and `RUNBOOK-TEMPLATE.md` and fill them in for `awsdevops-sample` as deployed
in this lab. Use the numbers you just pulled in Step 5, the alarms this lab created, and the
rollback you just watched happen. Don't guess at values you didn't measure — if you don't have a real
number for something, that's a gap to note, not to paper over with a plausible-looking placeholder.

When you're done, apply the test from the top of this file: hand both documents to someone who has
never seen this lab, and check honestly whether they could act on the rollback runbook and understand
the SLO's error budget policy without asking you anything. `SOLUTION.md` has a worked example of both
to compare against — read it after your own attempt, not before.

## Break it / Fix it

See `content/day05.md`'s "Break it / Fix it" section for the full walkthrough. In outline: register
three new Day 3 task definition revisions in turn (same technique as Day 3's own Break-It — copy the
current task definition, edit the environment block, `aws ecs register-task-definition`, `aws deploy
create-deployment`) and drive `/burn` traffic against each:

1. `BURN_RATE=0.5`, `LATENCY_MS=0` — 5XX-only. Confirm Day 3's 5XX alarm goes to `ALARM`, this lab's
   p99 alarm stays `OK` (fast errors don't move latency), and the composite alarm stays `OK`.
2. `BURN_RATE=0`, `LATENCY_MS=1500` — latency-only. Confirm the p99 alarm goes to `ALARM`, the 5XX
   alarm stays `OK` (every response is still a `200`, just slow), and the composite alarm stays `OK`.
3. `BURN_RATE=0.5`, `LATENCY_MS=1500` — both at once. Confirm both underlying alarms go to `ALARM`
   and, only now, the composite alarm does too.

Restore `BURN_RATE=0`, `LATENCY_MS=0` and redeploy after each stage. This is `LATENCY_MS`
(`app/main.go`, `app/README.md`) doing real work — before it existed there was no way to drive a
latency-only failure at all, and the exercise couldn't run.

## Teardown

**Do not skip straight to `terraform destroy` here.** This lab's canary is a scheduled, self-running
process, and its pipeline's artifact bucket has no `force_destroy` (same deliberate choice as Day 2's)
— see `teardown.md` for the full, strict, end-of-path order, starting with stopping the canary first.
