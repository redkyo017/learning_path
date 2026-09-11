# Day A2 lab — five predict → capture → execute → verify → revert cycles

**Goal:** run five mutating operations against a small ECS stack you own
outright, and get back from every one of them. An ECR retag that fails on
purpose, a scale to zero and back through a waiter, the `put-metric-alarm`
full-replace trap sprung and diffed, a task-definition revision rolled
back to its predecessor, and a drift hunt against `terraform plan`.

**Success signal:** every cycle reverted, `terraform plan` reports no
changes, and `verify-teardown.sh` is clean after teardown.

Read `content/dayA2.md` first. This README assumes you already know the
pre-flight triad, the three reversibility buckets, what `put` semantics
mean for an alarm, and why a mutation's own response is not evidence that
anything converged. It does not re-teach any of that — it makes you do it
five times.

Budget ~115 minutes for the five cycles and ~20 more for Break it / Fix
it. Cost while this stack is up is ~$0.0099/h for the one arm64 Fargate
task (0.25 vCPU / 0.5 GB), plus the alarm (first 10 free) and whatever
`/ecs/awsdevops-cli` ingests at ~$0.50/GB. Follow `teardown.md` and the
whole day lands near $0.03.

---

## Before you start

- `labs/foundation/` must already be applied. This stack borrows its VPC,
  public subnets, and the `awsdevops-sample` ECR repository, and creates
  no networking of its own beyond one egress-only security group,
  `awsdevops-cli-tasks`.
- You need at least one image in that ECR repository, pushed by Day 1's
  CodeBuild and tagged with a commit short-SHA. **Cycle C1 needs two
  images with different digests** — Day 1's Break it / Fix it produced a
  second one. If it did not, see C1's precondition check.
- **If you destroyed `labs/day01/` — Day A1's `teardown.md` §2 tells you
  to — re-apply it before you start.** The stack itself is not what these
  cycles read, but C1's remedy for a missing second image runs
  `aws codebuild start-build` against Day 1's `codebuild_project_name`
  Terraform output, and with that stack destroyed the substitution comes
  back empty and the command fails on a blank project name. Re-apply Day 1
  (`labs/day01/README.md`, steps 1–3), and destroy it again afterward.
- If Day 1's Break it / Fix it left the repository at
  `imageTagMutability = MUTABLE`, put it back to `IMMUTABLE` before C1.
  C1 checks this for you, and it is the whole reason C1 works.
- Create `terraform.tfvars` and apply:

  ```bash
  cd labs/dayA2
  cp terraform.tfvars.example terraform.tfvars
  # edit terraform.tfvars: set image_tag to a real tag from Day 1's ECR pushes
  terraform init
  terraform plan
  terraform apply
  ```

- Nothing here runs Terraform or the AWS CLI for you. Every command below
  is yours to run and read the output of.

**There is no load balancer anywhere in this stack, and no NAT gateway.**
Nothing in these drills routes traffic, so there is nothing to route it
through. If you were expecting to `curl` something, you are thinking of
Day 3.

---

## The shape of every cycle

Every one of the five cycles below has the same five sub-steps, always in
this order:

**predict → capture → execute → verify → revert**

- **Predict.** Before you touch the keyboard, write down — in a file, not
  in your head — which resource, which field, and which value will be
  different afterward. One sentence. If you cannot write it, run `help`
  first.
- **Capture.** Read the current state into a timestamped file. This is the
  step people skip, and it is the one that decides whether the change is
  bucket two or bucket three.
- **Execute.** Run exactly one mutating command.
- **Verify.** Re-read *the resource*, not the mutation's own response. A
  response says the API accepted a request. Only a fresh `describe-` says
  the system converged.
- **Revert.** Run the command you had already written down in the predict
  step. A revert you design after the fact is not a revert.

Set up once, in the shell you will use for the whole lab:

```bash
cd labs/dayA2

CLUSTER=$(terraform output -raw cluster_name)
SERVICE=$(terraform output -raw service_name)
FAMILY=$(terraform output -raw task_family)
ALARM=$(terraform output -raw alarm_name)
LOG_GROUP=$(terraform output -raw log_group_name)
REPO=$(cd ../foundation && terraform output -raw ecr_repository_name)

CAPTURE_DIR=~/aws-preflight
mkdir -p "$CAPTURE_DIR"

printf '%s\n' "$CLUSTER" "$SERVICE" "$FAMILY" "$ALARM" "$LOG_GROUP" "$REPO"
```

Expected:

```text
awsdevops-cli-cluster
awsdevops-cli-service
awsdevops-cli-task
awsdevops-cli-cpu-high
/ecs/awsdevops-cli
awsdevops-sample
```

If any of those six lines is empty or is a bare `awsdevops-cluster` /
`awsdevops-service` / `awsdevops-task`, stop. Those are **Day 3's**
resources, not this stack's, and you are one command away from operating
on the wrong thing. Re-run `terraform output` from `labs/dayA2/`.

And run the first question of the triad before anything mutating, in this
terminal, in this session:

```bash
aws sts get-caller-identity --output json --no-cli-pager
```

Scrollback from an hour ago is not evidence of the current profile.

---

## C1 — Retag an ECR image

The cycle that fails on purpose. Everything about it is real except the
outcome you probably expect.

**Precondition.** You need two images with different digests in
`awsdevops-sample`:

```bash
aws ecr describe-images \
  --repository-name "$REPO" \
  --query 'sort_by(imageDetails,&imagePushedAt)[*].{tag:imageTags[0],digest:imageDigest,pushedAt:imagePushedAt}' \
  --output table --no-cli-pager
```

If that shows only one row, produce a second the way Day 1 did. **Commit a
trivial change and push it** — the tag CodeBuild derives comes from the
resolved source version, so a build against an unpushed working tree
produces the *same* short-SHA tag, fails on the same immutability rule,
and leaves you with the one image you started with. Push first, then run
the build — this needs `labs/day01/` applied, per "Before you start":

```bash
aws codebuild start-build \
  --project-name "$(cd ../day01 && terraform output -raw codebuild_project_name)" \
  --no-cli-pager
```

**1. Predict.** You are about to take the manifest of the *newer* image
and put it under the tag the *older* image already holds. Before you run
anything, commit to an answer in writing:

- Does the call succeed or fail?
- If it succeeds, which digest does the older tag point at afterward, and
  what happened to the association it used to name?
- If it fails, is the repository in a different state than before?

Write the answer down before you continue. The point of this cycle is not
the result — it is finding out whether your prediction matched it.

**2. Capture.** Two reads, and the first one matters more than it looks:

```bash
aws ecr describe-repositories \
  --repository-names "$REPO" \
  --query 'repositories[0].imageTagMutability' \
  --output text --no-cli-pager

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecr describe-images \
  --repository-name "$REPO" \
  --query 'imageDetails[*].{tags:imageTags,digest:imageDigest}' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-ecr-before.json"
```

The first read is the pre-flight question "what will this touch?" asked
about a *setting* rather than a resource. `IMMUTABLE` means this cycle is
a rejected call. `MUTABLE` means it is a silent, unrecoverable tag move —
bucket three wearing bucket one's clothes. Do not run step 3 until that
read says `IMMUTABLE`.

**3. Execute.**

```bash
OLD_TAG="<TAG_OF_THE_OLDER_IMAGE>"
NEW_TAG="<TAG_OF_THE_NEWER_IMAGE>"

MANIFEST=$(aws ecr batch-get-image \
  --repository-name "$REPO" \
  --image-ids imageTag="$NEW_TAG" \
  --query 'images[0].imageManifest' \
  --output text --no-cli-pager)

MEDIA_TYPE=$(aws ecr batch-get-image \
  --repository-name "$REPO" \
  --image-ids imageTag="$NEW_TAG" \
  --query 'images[0].imageManifestMediaType' \
  --output text --no-cli-pager)

aws ecr put-image \
  --repository-name "$REPO" \
  --image-tag "$OLD_TAG" \
  --image-manifest "$MANIFEST" \
  --image-manifest-media-type "$MEDIA_TYPE" \
  --no-cli-pager
echo "put-image exit status: $?"
```

**4. Verify.** The call fails. **Read the exception name out of the error
text and write it down.** Day 1 already named this one:
`ImageTagAlreadyExistsException` (`content/day01.md:211`,
`labs/day01/README.md:95`). Confirm that the error you actually got says
the same thing — confirming is the habit, and the ECR API surface is not
the `docker push` surface Day 1 showed you. It is the same habit as
`aws ecs wait services-stable help`: read the answer out of the system in
front of you rather than the document in front of you.

Then prove the repository is unchanged, rather than assuming it:

```bash
aws ecr describe-images \
  --repository-name "$REPO" \
  --query 'imageDetails[*].{tags:imageTags,digest:imageDigest}' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-ecr-after.json"

diff "${CAPTURE_DIR}/${STAMP}-ecr-before.json" \
     "${CAPTURE_DIR}/${STAMP}-ecr-after.json" && echo "no change"
```

**5. Revert.** There is nothing to revert, and that is the finding, not a
missing step — a rejected mutation leaves no state to undo, which is why
the empty `diff` above is the cycle's real output. The one thing that does
need reverting is Day 1's out-of-band change, if you still have it: if the
capture in step 2 said `MUTABLE`, put it back now.

```bash
aws ecr put-image-tag-mutability \
  --repository-name "$REPO" \
  --image-tag-mutability IMMUTABLE \
  --no-cli-pager
```

**Hint:** Day 1 met this same guarantee through a different door — a
`docker push` from CodeBuild that failed on an already-used tag, and
`labs/day01/README.md:95` prints the exception verbatim. This is the same
repository setting refusing the same operation through the API directly,
so the name should match and the surrounding message should not. If your
error names something else, that is worth more of your attention than a
match would have been. Then ask yourself which of the three reversibility
buckets a tag move would have been *if the repository had been mutable*,
and why Day 1 spends a whole Break it / Fix it stage on that question.

---

## C2 — Scale to zero and back

**1. Predict.** Write down: which field on which resource changes, what
`runningCount` will be sixty seconds later, and the exact command that
puts it back. Also predict what `aws ecs wait services-stable` does when
`desiredCount` is `0` — does it wait for a task, or is zero running tasks
already stable?

**2. Capture.**

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-service-before.json"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
  --output json --no-cli-pager
```

**3. Execute.**

```bash
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 0 \
  --no-cli-pager > /dev/null
```

That redirect is deliberate. `update-service` returns the whole service
object and it is the least useful thing on your screen right now — it
reports the desired state the API just accepted, not the state of
anything running. Throwing it away removes the temptation to read it as
evidence.

**4. Verify.** Two different claims, and you want both. The waiter's claim
is an exit status; the `describe-` call's claim is a number.

```bash
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
WAITER_STATUS=$?
echo "waiter exit status: ${WAITER_STATUS}"
```

Check that status explicitly every time — a waiter that gave up looks
exactly like a waiter that succeeded if you only look at your prompt.
Before you decide the wait was "too long" or "too short," find out what it
actually is on the CLI you have installed:

```bash
aws ecs wait services-stable help
```

Read the interval and the attempt count out of that, not out of any
document — including this one. Then read the resource:

```bash
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
  --output json --no-cli-pager
```

**5. Revert.** Run the command you wrote in step 1, then wait and verify
again the same way. Confirm `desired` and `running` are both back to `1`
before you move on — not one of the two.

**Hint:** This is the cleanest **trivially reversible** change in the lab,
and the capture in step 2 is therefore the easiest one to skip. Ask what
that file buys you here. Then consider the case where `desiredCount` was
`3` rather than `1` when you started, and you set it to `0` at 2am from
memory.

---

## C3 — The alarm trap

The cycle this lab exists for. Run it exactly as written, including the
part that is wrong on purpose.

**1. Predict.** Read `awsdevops-cli-cpu-high` in `main.tf` — it is the
`aws_cloudwatch_metric_alarm "cpu_high"` resource. Then write down: after
a `put-metric-alarm` that names only the alarm name, namespace, metric
name, statistic, period, evaluation periods, threshold, comparison
operator, and dimensions, **which fields of that alarm are different?**
Commit to a list before running anything. Predict the revert command too,
and predict whether `describe-alarms` output can be fed straight back into
`put-metric-alarm`.

**2. Capture.** This is not optional here. Without it, this cycle is
bucket three.

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json"

cat "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json"
```

**3. Execute.** The reasonable-looking one-line threshold bump — the one
that shows up in a chat message as "I just raised the threshold":

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM" \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value="$CLUSTER" \
               Name=ServiceName,Value="$SERVICE" \
  --no-cli-pager
echo "put-metric-alarm exit status: $?"
```

It returns nothing and exits `0`. That is the whole problem.

**4. Verify.** Capture the after-state the same way and diff the two
files:

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-cpu-high-after.json"

diff "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json" \
     "${CAPTURE_DIR}/${STAMP}-cpu-high-after.json"
```

Count the removed lines. You changed one field. Compare the diff against
the list you wrote in step 1 — the gap between those two is the lesson.
Sort the diff into two piles: fields that are *gone because you dropped
them*, and fields that are CloudWatch's rather than yours (the
configuration timestamp, the ARN, and the alarm's own state fields, which
keep moving on their own while you work). You need that second pile for
step 5.

**5. Revert.** Restate **every** field, with the threshold back at its
original value, reading the values out of your `-before.json`.

**Do not** feed the captured file into `put-metric-alarm --cli-input-json`.
`describe-alarms` returns read-only fields that the put API does not
accept as input, so the round trip fails — and the failure is
uninformative enough that people conclude the capture was useless rather
than that the shapes differ. The capture is a **reference a human reads**,
not machine input. `SOLUTION.md` has both the explicit restatement and, if
you want to derive the command from the file, the projection that pulls
out only the settable fields.

Then diff the restored alarm against `-before.json` and confirm the only
remaining differences are in that second pile.

**Hint:** The three fields you are looking for are all in `main.tf`, all
optional, and all absent from the command in step 3. `main.tf` even has a
comment saying why they are there. The one that is not cosmetic is the one
that decides what the alarm does when a metric reports nothing at all —
re-read Day 3's Core concept 7 if that sounds harmless.

---

## C4 — Task definition revision and rollback

**1. Predict.** Write down what `register-task-definition` creates, what
it changes about the *currently running* task, what
`update-service --task-definition` changes, and — before running either —
the exact rollback command including the revision number you would pass
it. If you cannot name that number right now, you do not have a rollback
yet.

**2. Capture.** The revision number is the whole revert, so read it and
write it down:

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].taskDefinition' \
  --output text --no-cli-pager \
  | tee "${CAPTURE_DIR}/${STAMP}-taskdef-before.txt"

aws ecs describe-task-definition \
  --task-definition "$FAMILY" \
  --query 'taskDefinition' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-taskdef-before.json"
```

**3. Execute.** Build the new revision from the captured one. The same
read-only-field problem as C3 shows up here in a different costume — a
`describe-task-definition` response carries fields `register-task-definition`
will not accept, so strip them before adding your change:

```bash
jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
        .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)' \
  "${CAPTURE_DIR}/${STAMP}-taskdef-before.json" \
  > "${CAPTURE_DIR}/${STAMP}-taskdef-next.json"

jq '.containerDefinitions[0].environment += [{"name":"DRILL","value":"c4"}]' \
  "${CAPTURE_DIR}/${STAMP}-taskdef-next.json" \
  > "${CAPTURE_DIR}/${STAMP}-taskdef-c4.json"

aws ecs register-task-definition \
  --cli-input-json "file://${CAPTURE_DIR}/${STAMP}-taskdef-c4.json" \
  --query 'taskDefinition.{family:family,revision:revision,arn:taskDefinitionArn}' \
  --output json --no-cli-pager
```

`DRILL=c4` is an environment variable the sample app does not read. That
is on purpose: this cycle is about the revision mechanics, and a change
with a behavioral effect would let you confuse "the rollback worked" with
"the app started behaving again."

Then point the service at it:

```bash
NEW_REVISION="<REVISION_NUMBER_FROM_ABOVE>"

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "${FAMILY}:${NEW_REVISION}" \
  --no-cli-pager > /dev/null
```

**4. Verify.** Waiter first, exit status checked, then the resource:

```bash
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
WAITER_STATUS=$?
echo "waiter exit status: ${WAITER_STATUS}"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{taskdef:taskDefinition,desired:desiredCount,running:runningCount}' \
  --output json --no-cli-pager
```

Also confirm, right now, that the revision you are about to roll back to
is still there:

```bash
aws ecs list-task-definitions \
  --family-prefix "$FAMILY" \
  --status ACTIVE \
  --output json --no-cli-pager
```

**5. Revert.** Run the rollback you wrote in step 1 — the previous
revision, by number, from your capture file. Wait, check the exit status,
and re-read `services[0].taskDefinition` to confirm it ends in the old
revision number.

**Then finish the chain, and say what is deployed.** The rollback put a
task definition ARN back where it started. That ARN is not yet an answer
to "what is actually deployed right now?" — it is one link short of the
artifact. Walk the rest of the way and write the answer down as one
sentence naming the service, the family and revision, the image URI, and
the digest:

```bash
TASKDEF=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].taskDefinition' \
  --output text --no-cli-pager)

IMAGE=$(aws ecs describe-task-definition \
  --task-definition "$TASKDEF" \
  --query "taskDefinition.containerDefinitions[?name=='awsdevops-cli-app'].image | [0]" \
  --output text --no-cli-pager)

echo "$TASKDEF"
echo "$IMAGE"

aws ecr describe-images \
  --repository-name "$REPO" \
  --image-ids imageTag="${IMAGE##*:}" \
  --query 'imageDetails[0].{tag:imageTags[0],digest:imageDigest,pushedAt:imagePushedAt}' \
  --output json --no-cli-pager
```

`${IMAGE##*:}` is the tag — everything after the image URI's final `:`.
Stopping at the URI answers "which tag is configured," which is a weaker
claim than it sounds: a tag is a label. The digest is the artifact, and it
is the only part of this chain that Day 1's PRODUCE link would recognize
as an identity.

**Hint:** That `list-task-definitions` output is the entire reason this is
bucket two rather than bucket three: **the previous state still exists as
an addressable object.** Nothing about the rollback needed a backup,
because AWS never deleted the thing you wanted back. Now ask the harder
follow-up — what does the revision you just registered cost you, and what
does it do to the family's revision count if a retried script registers it
three times? And note what the new revision does *not* carry that the
Terraform-managed one did; `SOLUTION.md` names it.

---

## C5 — The drift hunt

This cycle works only because `labs/dayA2/main.tf` deliberately omits
`lifecycle { ignore_changes = [...] }` on its ECS service, unlike
`labs/day03/ecs.tf`. Read the comment at the bottom of the
`aws_ecs_service` resource before you start — the drill depends on
Terraform being allowed to see the drift.

**1. Predict.** You are going to change `desiredCount` by CLI from `1` to
`2` and then run `terraform plan`. Write down: what will the plan say,
which direction will it read in, and what would happen if someone ran
`terraform apply` for an unrelated reason three weeks from now?

**2. Capture.**

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount}' \
  --output json --no-cli-pager \
  | tee "${CAPTURE_DIR}/${STAMP}-drift-before.json"
```

**3. Execute.**

```bash
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 2 \
  --no-cli-pager > /dev/null

aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
echo "waiter exit status: $?"
```

Two tasks is ~$0.0198/h instead of ~$0.0099/h. Do not leave this cycle
half-finished overnight.

**4. Verify.** Not with `describe-services` this time — with Terraform,
because the thing you are verifying is the *disagreement*:

```bash
terraform plan -detailed-exitcode
echo "plan exit status: $?"
```

`-detailed-exitcode` turns "is there drift" into a number: `0` means no
changes, `2` means changes are proposed, `1` means the plan itself
errored. That is the same "check exit codes, not output text" rule the
waiter taught, applied to Terraform.

**Read the drift out loud.** Say the proposed change as a sentence,
including its direction, and say who would execute it and when. The
direction is the part people get backwards.

**5. Revert — or codify.** Both answers are defensible and you must pick
one *and write down why*:

- **Revert.** `update-service --desired-count 1`, then
  `aws ecs wait services-stable` with its exit status read out loud the
  way you read it in C2 — a revert you did not confirm converged is not a
  revert yet — then `terraform plan -detailed-exitcode` again and confirm
  it exits `0`. Justify it: this was investigation, it is over, and
  reality now matches configuration.
- **Codify.** Edit `desired_count` in your copy of `main.tf` to `2`, run
  `terraform apply`, and confirm `terraform plan -detailed-exitcode`
  exits `0`. Justify it: the new value is the value you actually want, and
  it now lives in configuration where the next person can read it.

There is no third acceptable answer. Leaving the plan dirty is the one
outcome this cycle is designed to make you refuse. If you codified,
**revert `desired_count` back to `1` before teardown** so you are not
paying for two tasks while you finish the day.

**Hint:** Ask the deciding question from `content/dayA2.md`'s Core concept
9 — *is there a system that legitimately owns this field?* — and notice
that `lifecycle { ignore_changes = [desired_count] }` would make this
plan clean without making anything true. That block is right in
`labs/day03/ecs.tf` and wrong here, and the difference is not a matter of
taste.

---

## Break it / Fix it

Two stages, both short, both about making an abstraction concrete. Run
them in order.

### (a) Delete the log group and try to get the logs back

This is bucket three, and it is meant to be felt rather than read.

1. Generate something worth losing. Let the task run for a few minutes and
   confirm the log group has streams in it:

   ```bash
   aws logs describe-log-streams \
     --log-group-name "$LOG_GROUP" \
     --query 'logStreams[*].{stream:logStreamName,lastEvent:lastEventTimestamp}' \
     --output json --no-cli-pager
   ```

2. Say the command out loud, confirm the account, then run it:

   ```bash
   aws sts get-caller-identity --query 'Account' --output text --no-cli-pager

   aws logs delete-log-group --log-group-name "$LOG_GROUP" --no-cli-pager
   ```

3. **Spend five honest minutes looking for a way to get the contents
   back.** Not the group — the contents. Try the read you ran in step 1
   again, and try the `list-` form beside it:

   ```bash
   aws logs describe-log-streams \
     --log-group-name "$LOG_GROUP" \
     --output json --no-cli-pager

   aws logs describe-log-groups \
     --log-group-name-prefix "$LOG_GROUP" \
     --output json --no-cli-pager
   ```

   Those two calls fail in two different ways, and the difference is the
   diagnosis: a describe against a missing resource raises a service
   exception, while a prefix listing returns an empty array. "No output"
   means something different in each case. Read the exception name out of
   the first one.

4. **Now find the second consequence**, which is the real reason this
   drill is here. Force the service to start a fresh task:

   ```bash
   aws ecs update-service \
     --cluster "$CLUSTER" \
     --service "$SERVICE" \
     --force-new-deployment \
     --no-cli-pager > /dev/null

   aws ecs wait services-stable \
     --cluster "$CLUSTER" \
     --services "$SERVICE" \
     --no-cli-pager
   echo "waiter exit status: $?"
   ```

   The waiter does not come back clean. Find out why from the service's
   own event stream and from the stopped task:

   ```bash
   aws ecs describe-services \
     --cluster "$CLUSTER" \
     --services "$SERVICE" \
     --query 'services[0].events[0:5].message' \
     --output json --no-cli-pager

   STOPPED_TASK=$(aws ecs list-tasks \
     --cluster "$CLUSTER" \
     --desired-status STOPPED \
     --query 'taskArns[0]' \
     --output text --no-cli-pager)

   aws ecs describe-tasks \
     --cluster "$CLUSTER" \
     --tasks "$STOPPED_TASK" \
     --query 'tasks[0].{stopped:stoppedReason,containers:containers[*].reason}' \
     --output json --no-cli-pager
   ```

   The task definition in `main.tf` names `/ecs/awsdevops-cli` in its
   container definition's `awslogs-group` option, and sets no
   `awslogs-create-group` option, so nothing recreates the group on your
   behalf. The group was not just a place logs went — it was a dependency
   of starting a task at all. Note what the error talks about: logging.
   Not the `delete-log-group` you ran twenty minutes ago.

   **This is what bucket three actually feels like** — not "I lost some
   logs," but "I lost some logs and broke something I did not know was
   connected, and the failure surfaced somewhere else entirely."

5. **Fix it.** Terraform sees the group missing and creates it again:

   ```bash
   terraform plan
   terraform apply
   ```

   Then force a deployment once more and confirm the service stabilizes.
   Write one sentence about what came back and what did not. Recreating
   the log group is easy; that is not the same as getting anything back.

### (b) The half-applied script

**Write this script yourself, run it, then read the wreckage.** Save it as
`drill-broken.sh` in this directory (it is not checked in — it is yours,
and `git` should never see it).

```bash
#!/usr/bin/env bash
#
# drill-broken.sh — three sequential mutations, no error handling.
# Run it with `bash drill-broken.sh` so the exports below die with it.

CLUSTER=awsdevops-cli-cluster
SERVICE=awsdevops-cli-service
ALARM=awsdevops-cli-cpu-high

# 1. Scale up.
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
  --desired-count 2 --no-cli-pager > /dev/null

# --- The credentials expire right here. ---
# A real expiry is an SSO token running out mid-script. This stand-in
# fails the same way from the script's point of view — every AWS call
# after it exits non-zero — without making you wait for a token to age.
export AWS_PROFILE=expired-drill-profile
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# 2. Raise the alarm threshold.
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM" \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 95 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value="$CLUSTER" \
               Name=ServiceName,Value="$SERVICE" \
  --no-cli-pager

# 3. Scale back down.
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" \
  --desired-count 1 --no-cli-pager > /dev/null

echo "drill-broken.sh complete"
```

Run it and read its exit status:

```bash
bash drill-broken.sh
echo "script exit status: $?"
```

**Then answer these before reading `SOLUTION.md`:**

1. What exit status did the script report, and what does that status
   actually describe?
2. Which of the three mutations landed? Prove it by reading each resource,
   not by reasoning about the output you saw.
3. Is the stack now in the "before" state, the "after" state, or neither?
   Name the specific field that decides your answer.
4. Which capture would have let you get back cleanly, and at what point in
   the script would you have had to take it?

Then **fix the script**: `set -euo pipefail` at the top, an explicit
exit-status check on every waiter, a pre-flight capture before the first
mutation, and a full restatement of every alarm field rather than the
partial `put-metric-alarm` above. `SOLUTION.md` has the corrected version
— write yours first. **Then run yours**, so you have seen the fixed
version do the thing the broken one only claimed to do.

Clean up after this stage. What needs undoing depends on which scripts you
ran, so read the resources rather than assuming:

- After **`drill-broken.sh` only**: `desiredCount` is `2` (step 1 landed);
  the alarm is untouched at threshold `80` with all its fields, because
  step 2 failed on credentials before it could drop anything. Put the
  count back to `1`.
- After the **fixed script as well**: it applies all three mutations, so
  `desiredCount` is back to `1` on its own and the alarm is at threshold
  `95` — restore it to `80` with all of its fields, exactly as in C3's
  revert.

Either way, finish with `desiredCount: 1` and an alarm carrying threshold
`80`, its description, `datapoints_to_alarm`, and `treat_missing_data`.

---

## Success signal

All three of these, in this order:

1. **Every cycle reverted.** C1 left nothing to revert and you proved it
   with an empty diff. C2, C4, and C5 are back where they started. C3's
   alarm has its description, its `datapoints_to_alarm`, and its
   `treat_missing_data` back.

2. **`terraform plan` reports no changes:**

   ```bash
   cd labs/dayA2
   terraform plan -detailed-exitcode
   echo "plan exit status: $?"
   ```

   Exit status `0`. **"Clean" is the whole grade** — a plan with anything
   in it means one of your reverts did not actually revert, and the plan
   tells you which one.

3. **`verify-teardown.sh` is clean after teardown.** See `teardown.md`.

If step 2 is dirty, do not skip to teardown to make the problem go away.
`destroy` removes the resource and the evidence together, and the whole
point of the day was to find out whether you could get back.
