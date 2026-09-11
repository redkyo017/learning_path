# Teardown — Day A2 (CLI appendix ECS stack)

This is a light teardown compared to Day 3's. There is **no load balancer
and no NAT gateway** anywhere in this stack, and no CodeDeploy deployment
that can wedge a `destroy` mid-flight. What there is: one arm64 Fargate
task at ~$0.0099/h, one CloudWatch alarm (the first 10 are free), and one
log group at ~$0.50/GB ingested with 1-day retention.

The risk here is not a stuck destroy. It is that a lab whose entire
subject is *changing things by hand* can leave behind something Terraform
never knew it created — and `destroy` cannot remove a resource that is not
in its state. Read the whole file before running anything.

**This stack does not come back.** Unlike Day 3's, nothing later in the
path re-applies `labs/dayA2/`. Once it is down, it is done.

---

## Ordered steps

### 1. Finish your reverts first

Do not use `destroy` to clean up an unfinished cycle. `destroy` removes
the resource and the evidence together, and the whole point of the day was
to find out whether you could get back.

```bash
cd labs/dayA2
terraform plan -detailed-exitcode
echo "plan exit status: $?"
```

Exit status `0` — "No changes" — before you go on. If it is `2`, the plan
names the resource whose revert did not land; `SOLUTION.md`'s final table
maps each one back to the cycle that owns it. Fix the cycle, then re-plan.

If Break it / Fix it left you with a half-applied script state, resolve
that here too: `desiredCount` back to `1`, the alarm back to threshold
`80` with all of its fields, and `/ecs/awsdevops-cli` recreated by
`terraform apply` if you deleted it. **A resource Terraform does not know
about is a resource `destroy` will not remove, and it will still be there
next month.**

### 2. Scale the ECS service to 0

```bash
aws ecs update-service \
  --cluster "$(terraform output -raw cluster_name)" \
  --service "$(terraform output -raw service_name)" \
  --desired-count 0 \
  --no-cli-pager > /dev/null

aws ecs wait services-stable \
  --cluster "$(terraform output -raw cluster_name)" \
  --services "$(terraform output -raw service_name)" \
  --no-cli-pager
echo "waiter exit status: $?"
```

Belt and suspenders. It is not strictly required for `terraform destroy`
to succeed, but it stops Fargate task minutes accruing while you work
through the rest of this file, and it removes one source of "something is
still attached to this ENI" errors later. Check the waiter's exit status
here the same way you did in C2 — a waiter that gave up looks exactly like
one that succeeded.

### 3. `terraform destroy`

```bash
cd labs/dayA2
terraform destroy
```

Confirm with `yes`. This removes everything in this stack's state: the ECS
cluster `awsdevops-cli-cluster`, the service `awsdevops-cli-service`, the
task definition family `awsdevops-cli-task`, the alarm
`awsdevops-cli-cpu-high`, the log group `/ecs/awsdevops-cli`, the security
group `awsdevops-cli-tasks`, and the two IAM roles
`awsdevops-cli-ecs-execution` and `awsdevops-cli-ecs-task`.

Note what it does **not** remove, because none of it was ever in state:
task-definition revisions you registered by hand in C4 (they stay in the
family, `ACTIVE` or `INACTIVE`; they are free and they are not billable,
but they are clutter), and anything you created outside this directory.

### 4. Verify

```bash
bash ../verify-teardown.sh
```

No flags. The script defaults to region `us-east-1` and prefix
`awsdevops`, which is exactly what this stack uses, and every one of this
lab's three leak risks is already covered by a section of it:

| Leak risk | Why this lab specifically | Which section catches it |
|---|---|---|
| An ECS service left at `desiredCount > 0` | C2 and C5 both set the count by hand, and both have a revert you can forget. A service scaled by CLI but never destroyed keeps launching tasks | **ECS services with desiredCount > 0** |
| A running Fargate task | The one that actually costs money — ~$0.0099/h, metered whether or not anything is looking at it, and a task can outlive a service deletion by a few moments | **Running Fargate tasks** |
| A log group under `/ecs/awsdevops-cli` that state does not know about | Break it / Fix it (a) deletes it out of band. If you recreated it by any route other than `terraform apply` in this directory, `destroy` never saw it, and a hand-made group has no retention set — a never-expire slow leak | **CloudWatch log groups matching 'awsdevops' with no retention limit** |

On that third row: a task start does **not** recreate the group. This
stack's container definition sets no `awslogs-create-group` option, which
is precisely why deleting the group breaks task startup instead of
silently regenerating it — that is the whole second half of Break it /
Fix it (a). So the only way a group comes back is that something created
it, and the only supported something is `terraform apply` here. If you
recreated it that way before step 3, `destroy` removed it and this row is
already clean.

Read the output rather than skimming it. The two lines that matter most:

```text
✅ No ECS services with desiredCount > 0 found under prefix 'awsdevops'.
✅ No running Fargate tasks found under prefix 'awsdevops'.
```

The alarm section reports `ℹ️` rather than `⚠️` and does not count toward
the unexpected total, because alarms are free below ten. Read it anyway —
`awsdevops-cli-cpu-high` should not be in that list, and if it is, step 3
did not finish.

A clean `terraform destroy` exit code proves Terraform cleared what it
knew about. C5 was the cycle where you proved that is not the same thing
as everything being gone.

---

## The cost of forgetting

Leave this stack up overnight and it is Fargate task time and nothing
else: `24h × $0.0099/h ≈ $0.24`, plus a fraction of a cent for whatever
the log group ingested at ~$0.50/GB, plus $0 for the alarm while you are
under ten. That is small enough to be genuinely easy to miss on a monthly
bill, which is the actual hazard — this is not a Day 3 ALB that announces
itself. If C5 left the service at `desiredCount = 2`, double the Fargate
line.

Run the verify script. Do not rely on memory, especially after a day spent
deliberately changing things by hand.

---

## What NOT to tear down

**Leave `labs/foundation/` running.** The VPC, the public subnets, and the
`awsdevops-sample` ECR repository are shared by every lab in this path,
and this stack only borrowed them — it created nothing there. Destroying
the foundation breaks other days and is not part of this day's teardown.

`verify-teardown.sh` says so itself, at the bottom of its output:

```text
ℹ️  labs/foundation/ VPC (CIDR 10.42.0.0/16) — free (VPC, IGW, public subnets, route tables).
ℹ️  labs/foundation/ ECR repository 'awsdevops-sample' — ~$0.002/month for a ~15 MB image.
```

Neither line is a warning. Their presence is correct at every point in the
path.

**One thing to check before you walk away**, if you ran Day 1's Break it /
Fix it or C1's revert step: the ECR repository's tag mutability should be
back at `IMMUTABLE`.

```bash
aws ecr describe-repositories \
  --repository-names "$(cd ../foundation && terraform output -raw ecr_repository_name)" \
  --query 'repositories[0].imageTagMutability' \
  --output text --no-cli-pager
```

```text
IMMUTABLE
```

That setting is a property of the foundation stack, not this one, so
`terraform destroy` here will never fix it. It is also the last out-of-band
change in this appendix that would still be sitting there next week — and
a drift you leave behind on teardown day is the exact failure C5 spent
twenty minutes on.
