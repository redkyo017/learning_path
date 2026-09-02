# Teardown — Day 3 (blue/green ECS + CodeDeploy)

**This is the most important teardown in the path.** This lab is the only
one that runs an ALB (~$0.0225/hour, whether or not it's serving traffic)
and the only one where a background process — an in-progress CodeDeploy
deployment — can make `terraform destroy` fail outright if you skip a
step. Read this whole file before running anything.

**Also: this stack comes back.** Unlike every other day lab, Day 3's stack
is destroyed here at the end of Day 3 and then **RE-APPLIED at the start
of Day 5** (`cd ../day03 && terraform apply`), because Day 5's alarms and
canary observe this exact ALB/ECS/CodeDeploy stack. Don't be surprised
when Day 5 tells you to rebuild what you're about to tear down — that's
expected, not a mistake in either day's instructions.

---

## Ordered steps

Run these in order. Skipping ahead — especially straight to step 3 — is
the single most common way this teardown gets stuck.

### 1. Stop any in-progress deployment

```bash
aws deploy list-deployments \
  --application-name "$(terraform output -raw codedeploy_app_name)" \
  --deployment-group-name "$(terraform output -raw codedeploy_group_name)" \
  --include-only-statuses InProgress Queued Ready

# For each deployment ID returned:
aws deploy stop-deployment --deployment-id <id> --auto-rollback-enabled
```

`terraform destroy` will fail while CodeDeploy is mid-deployment — it
can't delete a target group, listener, or service that CodeDeploy is
actively mutating. If you just finished Break it / Fix it, double-check
here: stage (b)'s rollback can still be "InProgress" for a few seconds
after the alarm trips.

### 2. Scale the ECS service to 0

```bash
aws ecs update-service \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --service "$(terraform output -raw ecs_service_name)" \
  --desired-count 0
```

Wait for running task count to reach 0 (`aws ecs describe-services ...
--query 'services[0].runningCount'`) before continuing. This is a
belt-and-suspenders step: it isn't strictly required for `terraform
destroy` to succeed, but it stops Fargate task minutes from accruing while
you work through the rest of this checklist, and it removes one more
source of "something is still attached to this ENI/subnet" errors later.

### 3. `terraform destroy`

```bash
cd labs/day03
terraform destroy
```

Confirm with `yes`. This removes everything Terraform's state file knows
about: the ALB, both target groups, the listener, the ECS
cluster/service/task definition, the CodeDeploy app/deployment group, the
IAM roles, the log group, and the security groups.

### 4. Handle what `destroy` can miss

Terraform's state only tracks what Terraform created. Two categories of
resource routinely escape it in this lab:

- **CodeDeploy-created ECS task sets.** During a blue/green deployment,
  CodeDeploy creates ECS "task sets" (a lower-level primitive than the
  service itself) that are not Terraform resources — Terraform only knows
  about `aws_ecs_service`. If a deployment was ever stopped uncleanly (or
  step 1 above was skipped), a task set can survive the service's
  destruction. Check for stragglers:

  ```bash
  aws ecs describe-task-sets --cluster "$(terraform output -raw ecs_cluster_name)" \
    --service "$(terraform output -raw ecs_service_name)" 2>/dev/null
  ```

  If this returns anything after the service itself is gone (or errors
  because the cluster/service no longer exist, which is the expected
  clean outcome), there's nothing further to do — a task set cannot
  outlive the service and cluster that owned it. The risk case is
  catching one *before* step 3, mid-deployment; step 1 is what prevents
  that.

- **A listener-mutated ALB.** CodeDeploy rewrites the listener's
  `default_action` outside Terraform (that's exactly what
  `lifecycle { ignore_changes = [default_action] }` in `alb.tf` is for).
  Normally this doesn't block `destroy` — Terraform deletes the listener
  resource itself regardless of what its current `default_action` points
  at. But if `terraform destroy` errors specifically on the ALB or
  listener, check the console (EC2 → Load Balancers) for a load balancer
  matching `${name_prefix}-alb` that Terraform's state no longer
  references (this happens if state got out of sync with reality —
  e.g., someone deleted resources by hand). Delete it manually if so.

### 5. Verify

```bash
bash ../verify-teardown.sh
```

**Read the ALB section of that output specifically.** Of everything this
script checks, the ALB line is the one most likely to catch something
Day 3 left behind, because it's the one resource in this whole path that
both (a) only Day 3 (and later Day 5) create at all, and (b) costs money
every single hour it exists, traffic or not. A "✅ No load balancers
matching 'awsdevops' found" line here is the real confirmation that
teardown worked — a clean `terraform destroy` exit code alone only proves
Terraform cleared what it knew about, not that nothing else is running.

---

## The cost of forgetting

If you skip this teardown and leave the stack up overnight: **~$0.85 for
that one night** — ALB $0.0225/hour × 24 hours ≈ $0.54, plus Fargate task
time for the one task still running, $0.0123/hour × 24 hours ≈ $0.30. Not
catastrophic for one night. But this is a lab you will likely run more
than once (Break it / Fix it, then again on Day 5), and both the ALB and
the Fargate task are metered by the hour whether or not anyone is looking
at them — the mistake compounds every night it's left running, and it's
the kind of line item that's easy to miss in a monthly bill because $0.85
alone doesn't look like an emergency. Run the verify script; don't rely on
memory.

---

## What NOT to tear down

**Leave `labs/foundation/` running.** It's shared by every lab in this
path (Day 1 through Day 5) and stays up for the whole week. Destroying it
now breaks Day 4 and Day 5, and there is nothing in this lab that requires
it to come down.
