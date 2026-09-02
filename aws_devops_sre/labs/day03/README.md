# Day 3 lab — blue/green deploy to ECS Fargate, alarm-triggered rollback

**Goal:** Deploy the sample app to ECS Fargate behind an ALB using
CodeDeploy blue/green, then break it twice on purpose — once in a way
CodeDeploy's own health-check gate catches, once in a way only a
CloudWatch alarm catches — and watch each one roll back.

**Success signal:** A bad build reaches 10% of live traffic, an alarm
fires, and traffic returns to the previous task set without a human doing
anything.

This is the heaviest lab in the path. Budget the full ~125 minutes plus
~25 minutes for Break it / Fix it — and expect the day as a whole to run
closer to 4-4.5h once you count CodeDeploy's canary and bake waits (see
`content/day03.md`'s note near the top). Read `content/day03.md` first —
this README assumes you already know what a target group pair, a bake
period, and CodeDeploy's health-check gate are, and specifically that this
lab's `CODE_DEPLOY` deployment controller means the ECS deployment circuit
breaker does not apply here (Core concept 5).

---

## Before you start

- `labs/foundation/` must already be applied (Day 1). You need its
  `vpc_id`, `public_subnet_ids`, and `ecr_repository_url` outputs.
- You need at least one image already pushed to that ECR repo, tagged with
  something other than `latest` (Day 1's CodeBuild does this). You'll pass
  that tag as `image_tag`.
- Nothing here runs Terraform, AWS CLI, or Docker for you. Every command
  below is yours to run and read the output of.

---

## Run steps

1. **Configure and apply the stack.**

   ```bash
   cd labs/day03
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars: set image_tag to a real tag from Day 1's ECR pushes
   terraform init
   terraform plan
   terraform apply
   ```

   This creates the ALB (blue + green target groups, one listener), the
   ECS cluster/task definition/service (`deployment_controller.type =
   CODE_DEPLOY`, one task on the blue target group), and the CodeDeploy
   app/deployment group with the rollback alarm wired in. The ECS service
   starts with a normal (non-CodeDeploy) first deployment — CodeDeploy
   only takes over from the second deployment onward, which is the one
   you'll trigger next.

2. **Confirm the service is healthy and reachable.**

   ```bash
   terraform output alb_dns_name
   curl "http://$(terraform output -raw alb_dns_name)/readyz"   # expect: ready
   curl "http://$(terraform output -raw alb_dns_name)/"          # expect: JSON with version/commit
   ```

3. **Register a new task definition revision and deploy it through
   CodeDeploy.** This is the mechanism every deploy in this lab uses —
   including both Break it stages below, just with different environment
   variables.

   `taskdef.json.example` is a plain, valid ECS task definition — no
   comment keys, because `--cli-input-json` validates strictly against the
   API shape and rejects unknown fields like `"//"`. `<IMAGE1_NAME>` is
   CodePipeline's own placeholder convention: on Day 5, the pipeline's
   Build stage writes an `imageDetail.json` naming the exact image digest
   it just pushed, and the ECS deploy action substitutes that value for
   `<IMAGE1_NAME>` before calling `RegisterTaskDefinition`. On Day 3 you
   substitute it by hand with the same ECR URL:tag you used as `image_tag`.

   ```bash
   # Substitute <IMAGE1_NAME> with the same ECR URL:tag you used as
   # image_tag, and the role ARNs with your account's (see terraform
   # output).
   cp taskdef.json.example taskdef.json
   # edit taskdef.json by hand, or with sed/jq

   aws ecs register-task-definition --cli-input-json file://taskdef.json

   # Fill in appspec.yaml from the template: substitute <TASK_DEFINITION>
   # with the ARN register-task-definition just printed.
   cp appspec.yaml.example appspec.yaml
   # edit appspec.yaml by hand

   # AWS CLI shorthand can't carry a multi-line YAML appspec (it will fail
   # to parse or silently truncate) — build a JSON revision document
   # instead and pass it with --cli-input-json. This is the reliable form;
   # use it for every create-deployment call in this lab, including both
   # Break it stages below.
   jq -n \
     --arg app "$(terraform output -raw codedeploy_app_name)" \
     --arg group "$(terraform output -raw codedeploy_group_name)" \
     --rawfile appspec appspec.yaml \
     '{applicationName: $app, deploymentGroupName: $group,
       revision: {revisionType: "AppSpecContent",
                  appSpecContent: {content: $appspec}}}' \
     > create-deployment.json

   aws deploy create-deployment --cli-input-json file://create-deployment.json
   ```

   Watch it in the console (CodeDeploy → Applications → your app → your
   deployment group) or poll:

   ```bash
   aws deploy get-deployment --deployment-id <id-from-create-deployment-output>
   ```

   A healthy deploy: green task set starts, passes the `/readyz` health
   check, gets 10% of traffic for 5 minutes (`ECSCanary10Percent5Minutes`),
   then gets the rest, then the old blue task set is kept alive for a
   5-minute bake before being terminated.

---

## Break it / Fix it

Two escalating stages. Run them in order — the contrast between them is
the whole point of this lab.

### Stage (a): `POISON=true` — CodeDeploy's health-check gate catches this one

1. Edit `taskdef.json`: set the container's `POISON` environment variable
   to `"true"`. Leave `BURN_RATE` alone.
2. `register-task-definition`, then `create-deployment`, exactly as above.
3. Watch it — but budget your time honestly here. The new task's `/readyz`
   returns 503 the moment ECS health-checks it, and it never becomes
   healthy in the green target group, so CodeDeploy never shifts any
   traffic to it — but CodeDeploy does **not** fail fast on this. ECS
   keeps killing and relaunching the poisoned task as it retries the
   health check, and CodeDeploy waits for the replacement task set to
   reach steady state, up to roughly a **one-hour** limit if left alone.
   Watch `aws deploy get-deployment --deployment-id <id>` and the ECS
   console for about **2 minutes** — long enough to see the task
   repeatedly launch, fail `/readyz`, and get killed — then stop waiting
   for the timeout and force it:

   ```bash
   aws deploy stop-deployment --deployment-id <id> --auto-rollback-enabled
   ```

   That's the realistic, deliberate way to end stage (a); waiting out the
   natural timeout is not a good use of lab time. **Before a single real
   user request ever reached the poisoned task**, it was already excluded
   from traffic — the manual stop just ends the lab's wait, it doesn't
   change what already happened (or didn't) to users.

**Question:** How long were users affected? Zero seconds — no traffic ever
reached it, regardless of how long the deployment itself took to resolve.
What caught it? The ALB target group health check on `/readyz`, feeding
CodeDeploy's own health-check gate and its `DEPLOYMENT_FAILURE`
auto-rollback. No alarm fired. None was needed. (This is not the ECS
deployment circuit breaker — this lab's `CODE_DEPLOY` controller doesn't
have one; see `content/day03.md` Core concept 5.)

### Stage (b): `BURN_RATE=0.5` — only the alarm catches this one

1. Edit `taskdef.json` again: set `POISON` back to `"false"`, and set
   `BURN_RATE` to `"0.5"`.
2. `register-task-definition`, then `create-deployment`.
3. Watch it differently this time. `/readyz` still returns 200 —
   `BURN_RATE` doesn't touch `/readyz` at all — so the new task set passes
   its health check and CodeDeploy proceeds exactly as it would for a good
   deploy: 10% of traffic shifts to green. But every request that lands on
   `/burn` (drive traffic at it — see below) now fails ~50% of the time.
   ALB `HTTPCode_Target_5XX_Count` climbs. Within the alarm's 60-second
   window, the `${name_prefix}-5xx` alarm trips, `DEPLOYMENT_STOP_ON_ALARM`
   fires, and CodeDeploy automatically rolls back: green is torn down,
   100% of traffic reverts to the still-running blue task set.

   Drive some traffic at `/burn` while the canary window is open so the
   alarm has something to observe:

   ```bash
   for i in $(seq 1 60); do curl -s -o /dev/null "http://$(terraform output -raw alb_dns_name)/burn"; sleep 1; done
   ```

**Question:** How long were users affected — some fraction of them, at the
canary's 10% traffic weight, for however long it took the alarm to
evaluate a breaching datapoint plus CodeDeploy's reaction time (worst case
approaching the 5-minute canary window, best case under a minute)? What
would have caught it sooner? A tighter alarm (shorter period, lower
threshold) trades speed for false-positive risk — see Exercise 2 in
`content/day03.md`.

### Heads-up: the alarm now blocks your next deployment

CodeDeploy refuses to start a new deployment while any alarm named in its
`alarm_configuration` is in `ALARM` state. Right after stage (b) rolls
back, the `${name_prefix}-5xx` alarm is likely still `ALARM` for at least
one more 60-second evaluation period. If you immediately try another
`create-deployment` (or jump straight to Day 3's teardown-then-Day-5-reapply
flow), you can hit a confusing "deployment failed because alarm ... is in
ALARM state" error with no traffic-related cause at all — this is expected,
not a new bug you introduced.

**Recovery:** stop driving traffic at `/burn`, then wait for the alarm to
return to `OK`:

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$(terraform output -raw rollback_alarm_name)" \
  --history-item-type StateUpdate --max-items 5
```

Once it shows `OK`, `create-deployment` works normally again.

### Read the rollback in the deployment's own record

```bash
aws deploy get-deployment --deployment-id <deployment-id>
```

Look at `deploymentInfo.status` (`Failed` for stage (a), or
`Stopped`/`Failed` after `DEPLOYMENT_STOP_ON_ALARM` for stage (b)) and
`deploymentInfo.errorInformation`. For stage (b), also check the alarm's
own history:

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$(terraform output -raw rollback_alarm_name)" \
  --history-item-type StateUpdate
```

---

## Cleanup

Do not run `terraform destroy` yet if either deployment above is still
"InProgress" — see `teardown.md`, which explains why and gives the full,
ordered teardown sequence. This stack is also re-applied at the start of
Day 5 — see `teardown.md` for what that means for you.
