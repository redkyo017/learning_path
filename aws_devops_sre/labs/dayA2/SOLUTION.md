# Day A2 lab — solution notes

Worked commands for all five sub-steps of every cycle, plus the expected
output shapes. Every value below that looks like an account ID, an ARN, a
digest, or a timestamp is a **placeholder** — `123456789012` is not a real
account. Your own values will differ, and the shapes are the point.

One thing this file deliberately does **not** contain: the waiter's
polling interval and attempt count. That is a number you read out of the
CLI in front of you, never out of a document, and it is in this lab for
that reason.

The variables `CLUSTER`, `SERVICE`, `FAMILY`, `ALARM`, `LOG_GROUP`,
`REPO`, `CAPTURE_DIR`, and `STAMP` are the ones set up in `README.md`.

---

## C1 — Retag an ECR image

### Predict

The honest answer, before running anything:

- The call **fails**. `awsdevops-sample` is created in
  `labs/foundation/main.tf` with `image_tag_mutability = "IMMUTABLE"`, and
  such a repository rejects an attempt to move an existing tag rather than
  silently overwriting it.
- The repository is in **exactly** the state it was in before. A rejected
  mutation is not a partial mutation.
- Had the repository been `MUTABLE`, the tag would now point at the newer
  digest and the association it used to name would have no name left. You
  could re-point the tag *if* you had written the old digest down — which
  is the entire content of the capture step, and the reason bucket one and
  bucket three can look identical from the command line.

### Capture

```bash
aws ecr describe-repositories \
  --repository-names "$REPO" \
  --query 'repositories[0].imageTagMutability' \
  --output text --no-cli-pager
```

```text
IMMUTABLE
```

If that says `MUTABLE`, Day 1's Break it / Fix it was never undone. Put it
back before executing, or this cycle teaches the opposite lesson.

The image capture:

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecr describe-images \
  --repository-name "$REPO" \
  --query 'imageDetails[*].{tags:imageTags,digest:imageDigest}' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-ecr-before.json"
```

```json
[
    {
        "tags": [
            "a1b2c3d4e5f6"
        ],
        "digest": "sha256:9f2e4b1c7a3d5f8e0b6c4a2d9e1f3b5c7a9d1e3f5b7c9a1d3e5f7b9c1a3d5e7f"
    },
    {
        "tags": [
            "f6e5d4c3b2a1"
        ],
        "digest": "sha256:3b7d9f1a5c2e8b4d6f0a2c4e6b8d0f2a4c6e8b0d2f4a6c8e0b2d4f6a8c0e2b4d"
    }
]
```

### Execute

```bash
OLD_TAG="a1b2c3d4e5f6"
NEW_TAG="f6e5d4c3b2a1"

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

`batch-get-image` hands back the manifest ECR already stores, so no layers
move and nothing is uploaded — this is a pure "point this tag at that
manifest" request, which is exactly the operation immutability exists to
refuse.

### Verify

```text
An error occurred (ImageTagAlreadyExistsException) when calling the
PutImage operation: <ECR's message, which names the tag and the repository>

put-image exit status: <non-zero>
```

**Write the exception name out of your own error and write it down.** Day 1
already named this one — `content/day01.md:211` and
`labs/day01/README.md:95` both print `ImageTagAlreadyExistsException` — so
the exercise here is *confirmation*, not discovery, and confirming is the
habit. The ECR API surface is not the `docker push` surface Day 1 showed
you: Day 1's failure arrives as a registry `denied:` message from the
Docker client, and this one arrives as a modeled service exception from the
CLI. Same repository setting, same refusal, two error shapes. Noticing that
they carry the same name is the point; a mismatch would be the more
interesting result, and you cannot notice either without reading your own
output.

The exit status is a documented non-zero CLI return code; read the number
off your own terminal rather than trusting one printed here.

Then prove nothing changed:

```bash
aws ecr describe-images \
  --repository-name "$REPO" \
  --query 'imageDetails[*].{tags:imageTags,digest:imageDigest}' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-ecr-after.json"

diff "${CAPTURE_DIR}/${STAMP}-ecr-before.json" \
     "${CAPTURE_DIR}/${STAMP}-ecr-after.json" && echo "no change"
```

```text
no change
```

That empty diff is the cycle's real output. "The command errored" is your
memory of what happened; the diff is evidence.

### Revert

Nothing to revert — and that is a finding, not a skipped step. The only
revert this cycle can need is the one for an out-of-band change *someone
else* made: if the capture said `MUTABLE`, restore it.

```bash
aws ecr put-image-tag-mutability \
  --repository-name "$REPO" \
  --image-tag-mutability IMMUTABLE \
  --no-cli-pager
```

```json
{
    "registryId": "123456789012",
    "repositoryName": "awsdevops-sample",
    "imageTagMutability": "IMMUTABLE"
}
```

### The tie back to Day 1

Day 1 hit this same wall through `docker push` from CodeBuild, and the
build failed. Here you hit it through the ECR API directly, with no Docker
daemon involved at all. Same repository setting, same refusal,
`ImageTagAlreadyExistsException` underneath both — and two completely
different-looking errors on screen. The name is the stable part; the
message around it is not, which is why you go looking for the name rather
than for text you recognize.

The deeper tie: a mutable tag cannot answer "which commit is this?"
Day 1's Break it / Fix it makes you feel that; this cycle makes you notice
that the reversibility bucket of a tag move depends entirely on a
repository setting you did not type into the command and may not have
checked. `imageTagMutability` is not a property of your command. It is a
property of the thing your command is aimed at, and the capture step is
where you find that out.

---

## C2 — Scale to zero and back

### Predict

`desiredCount` on `awsdevops-cli-service` in cluster
`awsdevops-cli-cluster` goes from `1` to `0`; the running Fargate task is
stopped; `runningCount` reaches `0` within roughly a minute. The revert is
`aws ecs update-service --cluster awsdevops-cli-cluster --service
awsdevops-cli-service --desired-count 1`, and you can write it from
memory, which is what makes this **trivially reversible**.

On the waiter question: `services-stable` waits for the service's
deployments to settle and for `runningCount` to equal `desiredCount`. With
`desiredCount` at `0`, zero running tasks *is* stable, so the waiter
returns as soon as the last task has actually stopped — it is not waiting
for a task to exist.

### Capture

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

```json
{
    "desired": 1,
    "running": 1,
    "status": "ACTIVE"
}
```

### Execute

```bash
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 0 \
  --no-cli-pager > /dev/null
```

### Verify

```bash
aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
WAITER_STATUS=$?
echo "waiter exit status: ${WAITER_STATUS}"
```

```text
waiter exit status: 0
```

A waiter that timed out prints nothing extra and returns you to the same
prompt. The exit status is the only difference between "converged" and
"gave up," which is why it gets read every single time. Under `set -e` the
non-zero status stops the script for you — but only if you did not swallow
it, which is the mistake the corrected script at the end of this file
avoids.

Where the interval and attempt count come from:

```bash
aws ecs wait services-stable help
```

Read them there, on the CLI you actually have installed. A number
memorized from a document is a bug waiting for a CLI upgrade, and this
file is a document.

Then the resource itself:

```bash
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
  --output json --no-cli-pager
```

```json
{
    "desired": 0,
    "running": 0,
    "status": "ACTIVE"
}
```

Note `status` is still `ACTIVE`. A service scaled to zero is not a deleted
service, and `verify-teardown.sh` treats those two very differently.

### Revert

```bash
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 1 \
  --no-cli-pager > /dev/null

aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
WAITER_STATUS=$?
echo "waiter exit status: ${WAITER_STATUS}"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
  --output json --no-cli-pager
```

```json
{
    "desired": 1,
    "running": 1,
    "status": "ACTIVE"
}
```

Both numbers, not one. `desired: 1, running: 0` is a service that accepted
your revert and has not performed it, and it is indistinguishable from a
successful revert if you only read the field you changed.

### The hint's answer

The capture buys you nothing *this time*, because you knew the count was
`1`. It buys you everything the time the count was `3`, or the time you
were reverting at 2am and "it was one, wasn't it?" was the only record
that existed. The habit is what survives an incident; a habit you only
practice when it matters is not a habit. That is also why the capture in
this cycle writes the **whole** service object and not just the count —
the field you wish you had captured is never the field you changed.

---

## C3 — The alarm trap

### Predict

The correct prediction, from reading
`aws_cloudwatch_metric_alarm "cpu_high"` in `main.tf`: the command in the
execute step restates nine settings. The alarm has three more that it does
not restate — `alarm_description`, `datapoints_to_alarm`, and
`treat_missing_data` — and `put-metric-alarm` **fully replaces** the alarm
definition, so all three are dropped rather than preserved.

And on the round-trip question: **no**, `describe-alarms` output cannot be
fed straight back into `put-metric-alarm --cli-input-json`. The describe
response carries read-only fields the put API does not accept as input —
the alarm ARN, the state value and its reason, and the configuration and
state timestamps. Those are CloudWatch's fields, not yours. See the revert
step for the two ways to get around that.

### Capture

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json"
```

```json
{
    "AlarmName": "awsdevops-cli-cpu-high",
    "AlarmArn": "arn:aws:cloudwatch:us-east-1:123456789012:alarm:awsdevops-cli-cpu-high",
    "AlarmDescription": "CLI appendix drill alarm. Day A2 mutates and reverts this.",
    "AlarmConfigurationUpdatedTimestamp": "2026-09-11T09:14:02.331000+00:00",
    "ActionsEnabled": true,
    "OKActions": [],
    "AlarmActions": [],
    "InsufficientDataActions": [],
    "StateValue": "OK",
    "StateReason": "<STATE_REASON_TEXT>",
    "StateUpdatedTimestamp": "2026-09-11T09:15:44.102000+00:00",
    "MetricName": "CPUUtilization",
    "Namespace": "AWS/ECS",
    "Statistic": "Average",
    "Dimensions": [
        {
            "Name": "ClusterName",
            "Value": "awsdevops-cli-cluster"
        },
        {
            "Name": "ServiceName",
            "Value": "awsdevops-cli-service"
        }
    ],
    "Period": 60,
    "EvaluationPeriods": 2,
    "DatapointsToAlarm": 2,
    "Threshold": 80.0,
    "ComparisonOperator": "GreaterThanThreshold",
    "TreatMissingData": "notBreaching"
}
```

Your CLI version may include additional read-only fields. That does not
change the lesson; it enlarges it.

### Execute

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

```text
put-metric-alarm exit status: 0
```

No output body at all. No warning, no confirmation, no indication that
anything other than the threshold changed. The alarm is now a different
alarm and the command that made it that way succeeded.

### Verify — the diff

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-cpu-high-after.json"

diff "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json" \
     "${CAPTURE_DIR}/${STAMP}-cpu-high-after.json"
```

```text
4,5c4
<     "AlarmDescription": "CLI appendix drill alarm. Day A2 mutates and reverts this.",
<     "AlarmConfigurationUpdatedTimestamp": "2026-09-11T09:14:02.331000+00:00",
---
>     "AlarmConfigurationUpdatedTimestamp": "2026-09-11T09:31:17.884000+00:00",
28,31c27,28
<     "DatapointsToAlarm": 2,
<     "Threshold": 80.0,
<     "ComparisonOperator": "GreaterThanThreshold",
<     "TreatMissingData": "notBreaching"
---
>     "Threshold": 90.0,
>     "ComparisonOperator": "GreaterThanThreshold"
```

**The two piles.**

Pile one — fields you dropped, three of them, exactly the three the
Terraform resource sets and your command did not restate:

| Terraform attribute in `main.tf` | Field in the describe output | What its absence changes |
|---|---|---|
| `alarm_description` | `AlarmDescription` | Gone. Cosmetic until an on-call engineer opens the alarm at 3am looking for what it means and finds nothing |
| `datapoints_to_alarm` | `DatapointsToAlarm` | Gone. With it unset, the alarm requires all `EvaluationPeriods` datapoints to breach rather than the number you chose — a behavioral change with no visible trace |
| `treat_missing_data` | `TreatMissingData` | Gone. Missing-data handling reverts to CloudWatch's default instead of `notBreaching`, and this is the one that decides whether the alarm fires or is theater. Re-read Day 3's Core concept 7 |

Pile two — fields CloudWatch owns rather than you. The one that certainly
changed is `AlarmConfigurationUpdatedTimestamp`: you reconfigured the
alarm, and CloudWatch stamped it. `AlarmArn` is in this pile too even
though it did not change — it is not yours to set. `StateValue`,
`StateReason`, and `StateUpdatedTimestamp` may also differ in your own
diff, because the alarm keeps evaluating the metric while you work; do not
read anything into whether they moved. Nothing in this cycle's lesson
depends on them.

**Pile two is why the round trip fails.** Those fields are in the describe
response and are not accepted by the put API, so
`put-metric-alarm --cli-input-json file://<the capture>` errors out. The
capture is a reference a human reads, not machine input. People who try
the round trip once and watch it fail often conclude the capture was
useless; the correct conclusion is that a read shape and a write shape are
different shapes.

And one field that is in neither pile because it is in neither response:
**tags**. `describe-alarms` does not return them at all, so this diff
cannot tell you anything about them. If you need to know, that is a
separate read:

```bash
ALARM_ARN=$(aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0].AlarmArn' \
  --output text --no-cli-pager)

aws cloudwatch list-tags-for-resource \
  --resource-arn "$ALARM_ARN" \
  --no-cli-pager
```

A diff that silently covers only part of the object is a hazard in its own
right, and knowing which part is the difference between evidence and
reassurance.

### Revert — the explicit restatement

This is the primary form. Every settable field, restated, with the
threshold back at `80`, read out of `-before.json` by a human:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM" \
  --alarm-description "CLI appendix drill alarm. Day A2 mutates and reverts this." \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --datapoints-to-alarm 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --dimensions Name=ClusterName,Value="$CLUSTER" \
               Name=ServiceName,Value="$SERVICE" \
  --no-cli-pager
echo "put-metric-alarm exit status: $?"
```

Twelve arguments to restore what one argument destroyed. That ratio is the
argument for the capture step, and it only works because you took it.

Check `-before.json` for anything set on your alarm that is not in the
list above and add it. `ActionsEnabled` is `true` here, which is also the
API default, and `OKActions`, `AlarmActions`, and `InsufficientDataActions`
are all empty — this alarm has no actions wired to it, unlike Day 3's
rollback alarm. If yours has any of those, they are settable and they get
restated too.

### Revert — deriving it from the capture instead

If you would rather not retype twelve arguments, extract the settable
fields explicitly with a projection. This is not a round trip: you are
naming, one by one, the keys that belong in the write shape, and
everything you do not name is left behind.

```bash
jq '{AlarmName, AlarmDescription, Namespace, MetricName, Statistic,
     Dimensions, Period, EvaluationPeriods, DatapointsToAlarm,
     Threshold, ComparisonOperator, TreatMissingData, ActionsEnabled}' \
  "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json" \
  > "${CAPTURE_DIR}/${STAMP}-cpu-high-restore.json"

cat "${CAPTURE_DIR}/${STAMP}-cpu-high-restore.json"

aws cloudwatch put-metric-alarm \
  --cli-input-json "file://${CAPTURE_DIR}/${STAMP}-cpu-high-restore.json" \
  --no-cli-pager
```

Two warnings, both real:

- `jq`'s `{Key}` shorthand emits `null` for a key that is absent from the
  input. That is safe here **only because you are projecting the
  pre-change capture**, where all thirteen keys exist. Run the same
  projection against `-after.json` and you get `"TreatMissingData": null`,
  which the API will not accept. Always `cat` the projection before you
  send it.
- The projection is a list you maintain. If AWS adds a settable field, or
  your alarm has one this list omits, the projection drops it exactly the
  way the careless command in the execute step did. The explicit
  restatement has the same weakness and wears it in public; this form
  hides it in a `jq` filter.

### Verify the revert

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-cpu-high-restored.json"

diff "${CAPTURE_DIR}/${STAMP}-cpu-high-before.json" \
     "${CAPTURE_DIR}/${STAMP}-cpu-high-restored.json"
```

Expect differences **only** in pile two — the configuration timestamp, and
possibly the alarm's own state fields. Every line naming `AlarmDescription`, `DatapointsToAlarm`,
`TreatMissingData`, or `Threshold` should be gone from the diff. If any of
those four is still there, your restatement missed a field, and
`terraform plan` will say so too.

---

## C4 — Task definition revision and rollback

### Predict

`register-task-definition` creates revision N+1 of family
`awsdevops-cli-task` and changes nothing about the running task —
registering is purely additive, and no service moves until you tell one
to. `update-service --task-definition` starts a rolling replacement under
the default ECS deployment controller (this stack has no
`deployment_controller` block, so it is not Day 3's CodeDeploy blue/green).

The rollback, writable before either forward command runs:

```text
aws ecs update-service --cluster awsdevops-cli-cluster \
  --service awsdevops-cli-service \
  --task-definition awsdevops-cli-task:<PREVIOUS_REVISION>
```

If you cannot fill in `<PREVIOUS_REVISION>` at predict time, you do not
have a rollback — you have an intention. That number is what the capture
step is for.

### Capture

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].taskDefinition' \
  --output text --no-cli-pager \
  | tee "${CAPTURE_DIR}/${STAMP}-taskdef-before.txt"
```

```text
arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:1
```

The trailing `:1` is the whole revert. Write it on paper if that is what
it takes.

```bash
aws ecs describe-task-definition \
  --task-definition "$FAMILY" \
  --query 'taskDefinition' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-taskdef-before.json"
```

Note that `--task-definition awsdevops-cli-task` with no revision means
"the latest ACTIVE revision," which is a resolution step you did not type
and should be aware of — the second question of the pre-flight triad,
asked about a task definition.

### Execute

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

```json
{
    "family": "awsdevops-cli-task",
    "revision": 2,
    "arn": "arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:2"
}
```

That `jq del(...)` is the same lesson as C3 in different clothing: a
`describe-` response and a `register-` request are different shapes, and
the read-only fields in the first are rejected by the second. Strip them
deliberately, by name, and know why each one is on the list.

```bash
NEW_REVISION="2"

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "${FAMILY}:${NEW_REVISION}" \
  --no-cli-pager > /dev/null
```

### Verify

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

```json
{
    "taskdef": "arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:2",
    "desired": 1,
    "running": 1
}
```

```bash
aws ecs list-task-definitions \
  --family-prefix "$FAMILY" \
  --status ACTIVE \
  --output json --no-cli-pager
```

```json
{
    "taskDefinitionArns": [
        "arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:1",
        "arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:2"
    ]
}
```

Revision `1` is still listed, still `ACTIVE`, still addressable. Nothing
was overwritten and nothing needs restoring, which is the definition of
bucket two.

### Revert

```bash
PREVIOUS_REVISION="1"

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "${FAMILY}:${PREVIOUS_REVISION}" \
  --no-cli-pager > /dev/null

aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
WAITER_STATUS=$?
echo "waiter exit status: ${WAITER_STATUS}"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].taskDefinition' \
  --output text --no-cli-pager
```

```text
arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:1
```

Compare that against `-taskdef-before.txt`. Same string, character for
character, or the revert did not land.

Revert to **revision 1 specifically**, not to `$FAMILY` with no revision.
An unqualified family name means "latest ACTIVE," which is now revision 2
— the thing you are rolling back from. That is the mistake that makes a
rollback a no-op and gets described afterward as "I rolled back and it
didn't help."

### The full chain — what is actually deployed?

The revert restored a task definition ARN. That is not yet an answer to
"what is actually deployed right now?", because a task definition names an
image by *tag* and a tag is a label. One more link reaches the artifact:

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
```

```text
arn:aws:ecs:us-east-1:123456789012:task-definition/awsdevops-cli-task:1
123456789012.dkr.ecr.us-east-1.amazonaws.com/awsdevops-sample:a1b2c3d4e5f6
```

The `[?name=='awsdevops-cli-app']` filter is not decoration. This task
definition happens to hold one container, so `containerDefinitions[0]`
would work today; naming the container makes the command survive the day a
sidecar is added, and `| [0]` unwraps the one-element list the filter
returns. Double quotes on the outside, because the expression contains the
single-quoted literal `'awsdevops-cli-app'`.

Then the last link — the tag is everything after the URI's final `:`:

```bash
aws ecr describe-images \
  --repository-name "$REPO" \
  --image-ids imageTag="${IMAGE##*:}" \
  --query 'imageDetails[0].{tag:imageTags[0],digest:imageDigest,pushedAt:imagePushedAt}' \
  --output json --no-cli-pager
```

```json
{
    "tag": "a1b2c3d4e5f6",
    "digest": "sha256:9f2e4b1c7a3d5f8e0b6c4a2d9e1f3b5c7a9d1e3f5b7c9a1d3e5f7b9c1a3d5e7f",
    "pushedAt": "2026-09-11T08:02:19.417000+00:00"
}
```

**The sentence that chain buys you:** service `awsdevops-cli-service` in
cluster `awsdevops-cli-cluster` is running `awsdevops-cli-task:1`, whose
`awsdevops-cli-app` container is
`awsdevops-sample:a1b2c3d4e5f6`, which resolves to digest
`sha256:9f2e4b1c…` pushed at `2026-09-11T08:02:19Z`. Every clause of it
came out of an API, none of it out of a deployment tool's memory of what
it thinks it did, and the digest is the only clause a moved tag cannot
falsify — which is exactly C1's lesson arriving from the other direction.

### The hint's answers

**What the new revision costs.** Nothing in dollars. But revision 2 is now
permanent clutter in the family, and a retried script that runs
`register-task-definition` three times leaves you with revisions 2, 3, and
4, all identical — `register-task-definition` creates a new object every
call, so it is *repeatable* but not *idempotent*, and those are different
properties. Where an operation offers a client request token, a retry loop
should use it; `register-task-definition` does not offer one, so the retry
logic has to be safe on its own.

`aws ecs deregister-task-definition --task-definition awsdevops-cli-task:2`
moves revision 2 to `INACTIVE` and stops `list-task-definitions --status
ACTIVE` from listing it. It does not remove it. Cleaning up is optional
here and does not affect `terraform plan` either way, because Terraform
tracks the revision it created — revision 1 — and you have pointed the
service back at exactly that.

**What the new revision does not carry.** Tags.
`describe-task-definition --query 'taskDefinition'` does not include them
(they arrive separately, via `--include TAGS`), so the revision you just
registered has none, while the Terraform-managed revision 1 has its `Name`
tag and the provider's `default_tags`. Nobody notices, because nothing
about a running task depends on a tag — right up until someone runs a
cost-allocation report, or a policy that keys on `Project`, and finds a
resource that answers to nothing.

---

## C5 — The drift hunt

### Predict

`terraform plan` will propose `desired_count = 2 -> 1` on
`aws_ecs_service.this`. Read the direction carefully: that is not
Terraform reporting your change, it is Terraform announcing its **intent
to undo it** on the next apply. Which may be in five minutes, or next
quarter, in someone else's pipeline, for an entirely unrelated reason,
during business hours.

This cycle only works because `main.tf` deliberately omits
`lifecycle { ignore_changes = [...] }` on the service. `labs/day03/ecs.tf`
includes it on `task_definition`, `load_balancer`, and `desired_count`,
because CodeDeploy legitimately owns those three fields there. Same block,
opposite verdicts, one deciding question: **is there a system that
legitimately owns this field?** Here, nothing does, so the change is drift
and should be visible as drift.

### Capture

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount}' \
  --output json --no-cli-pager \
  | tee "${CAPTURE_DIR}/${STAMP}-drift-before.json"
```

```json
{
    "desired": 1,
    "running": 1
}
```

### Execute

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

### Verify

```bash
terraform plan -detailed-exitcode
echo "plan exit status: $?"
```

```text
aws_ecs_service.this: Refreshing state... [id=arn:aws:ecs:us-east-1:123456789012:service/awsdevops-cli-cluster/awsdevops-cli-service]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_ecs_service.this will be updated in-place
  ~ resource "aws_ecs_service" "this" {
      ~ desired_count                      = 2 -> 1
        id                                 = "arn:aws:ecs:us-east-1:123456789012:service/awsdevops-cli-cluster/awsdevops-cli-service"
        name                               = "awsdevops-cli-service"
        # (unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

plan exit status: 2
```

`-detailed-exitcode` gives you three answers instead of a wall of text:
`0` no changes, `2` changes proposed, `1` the plan itself failed. That is
the same rule the waiter taught — check exit codes, not output text —
applied to Terraform, and it is what lets a drift check live in CI.

**The drift, read out loud:** *"Terraform intends to set `desired_count`
on `awsdevops-cli-service` from 2 back to 1, and it will do that the next
time anyone applies this stack, for any reason."* The version people say
instead — "the plan shows a desired count change" — has no direction, no
actor, and no time, which is why it does not alarm anyone.

### Revert — or codify

Both are defensible. Pick one, write down why, and end with a clean plan.

**Option A — revert.** The right call here, and the justification is the
one from `content/dayA2.md`'s table: this was *investigation*, it is over
within the hour, and you captured state before it. Reverting and then
proving it with a plan is what makes it legitimate rather than just
undocumented.

```bash
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 1 \
  --no-cli-pager > /dev/null

aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --no-cli-pager
echo "waiter exit status: $?"

terraform plan -detailed-exitcode
echo "plan exit status: $?"
```

```text
No changes. Your infrastructure matches the configuration.

plan exit status: 0
```

**Option B — codify.** Defensible when `2` is the value you actually want.
Edit `desired_count` in your copy of `main.tf` from `1` to `2`, then:

```bash
terraform apply
terraform plan -detailed-exitcode
echo "plan exit status: $?"
```

The apply reports `0 to add, 0 to change, 0 to destroy` — reality already
matches the new configuration; you are updating state and configuration to
agree with the world, not changing the world. The justification: the value
now lives where the next person will read it, and the drift is gone
because the disagreement is gone, not because the detector was disabled.

**The answer that is not acceptable:** adding
`lifecycle { ignore_changes = [desired_count] }` to quiet the plan. That
makes the plan clean without making anything true — it deletes the drift
signal instead of the drift. It is the right block in
`labs/day03/ecs.tf`, where CodeDeploy owns the field. It is the wrong
block here, where nothing does.

If you chose Option B, put `desired_count` back to `1` and apply again
before teardown, so you are not paying ~$0.0198/h for two tasks while you
finish the day.

---

## Break it / Fix it — (a) delete the log group

### What you should have seen

The delete itself returns nothing and exits `0`:

```bash
aws logs delete-log-group --log-group-name "$LOG_GROUP" --no-cli-pager
echo "delete-log-group exit status: $?"
```

```text
delete-log-group exit status: 0
```

Then the two reads fail in two different ways:

```text
# describe-log-streams against the deleted group
An error occurred (<ExceptionName>) when calling the DescribeLogStreams
operation: <the message, naming /ecs/awsdevops-cli>
```

```json
{
    "logGroups": []
}
```

That contrast is the diagnosis rule: a `describe-` against a missing
resource **raises a service exception**, while a `list-`/prefix query
**returns an empty array**. "No output" means something different in each
case — an exception says *this does not exist*, an empty array says
*nothing matched*, and confusing them sends you looking in the wrong
place. You met the same rule on ECS clusters and ECR repositories.

**There is no recovery for the contents.** Not a snapshot, not a restore
API, not a support ticket. You can recreate the group; the ingested log
data is gone. That is the third bucket, and this is the only way to
actually learn it.

### The second consequence

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

```text
waiter exit status: <non-zero>
```

The waiter gives up. This is the first time in the lab that exit status is
non-zero, and it is worth noticing how little the terminal does to tell
you — the same silent return to the same prompt as every successful wait.

```bash
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].events[0:5].message' \
  --output json --no-cli-pager
```

```json
[
    "<ECS service event about a task that stopped>",
    "<ECS service event about starting a task>"
]
```

```bash
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

```json
{
    "stopped": "<the reason ECS records, which is about the container failing to start>",
    "containers": [
        "<the container-level reason, which names the log driver and the missing group>"
    ]
}
```

Read the actual strings on your screen rather than these placeholders —
the exact wording is the CLI's and the agent's, not this file's, and it
changes between versions. What does not change is the shape of the
problem: **the error is about logging.** It does not mention
`delete-log-group`, it does not mention the twenty minutes that passed,
and it does not mention you.

The mechanism, in `main.tf`: the container definition's `logConfiguration`
sets `logDriver = "awslogs"` with an `awslogs-group` option pointing at
`aws_cloudwatch_log_group.ecs.name` — `/ecs/awsdevops-cli`. There is no
`awslogs-create-group` option anywhere in that block, so nothing creates
the group on the task's behalf. The log group was not just a place logs
went. It was a dependency of starting a task at all, and you could not see
that dependency from the `delete-log-group` command.

**This is what bucket three actually feels like:** not "I lost some logs,"
but "I lost some logs and broke something I did not know was connected,
and the failure surfaced somewhere else entirely." Every word of that
sentence is doing work. The lost logs are the *small* half.

### Fix it

```bash
terraform plan
terraform apply
```

```text
Terraform will perform the following actions:

  # aws_cloudwatch_log_group.ecs will be created
  + resource "aws_cloudwatch_log_group" "ecs" {
      + name              = "/ecs/awsdevops-cli"
      + retention_in_days = 1
      + ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

Terraform refreshes, finds the group missing, and creates it again —
**empty**. Then start a task that can now initialize its log driver:

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

```text
waiter exit status: 0
```

The one-sentence answer: **the log group came back and the logs did not,
and the only thing `terraform apply` actually restored was the ability to
start a task.** Recreating the container is not recovering the contents,
and the fact that recovery *looks* complete — plan clean, service stable,
group present — is precisely why bucket three is dangerous. Everything is
fine again except the part nobody can check.

---

## Break it / Fix it — (b) the half-applied script

### The four answers

**1. What exit status did the script report, and what does it describe?**

`0`. Without `set -e`, a script's exit status is the exit status of its
**last command**, which here is an `echo`. The `echo` succeeded. The
script reports success. Two of your three mutations failed. In CI, this is
a green build.

```text
drill-broken.sh complete
script exit status: 0
```

**2. Which mutations landed?** Only the first. Read each resource; do not
reason from the output that scrolled past.

```bash
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount}' \
  --output json --no-cli-pager

aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0].{threshold:Threshold,dta:DatapointsToAlarm,tmd:TreatMissingData}' \
  --output json --no-cli-pager
```

```json
{
    "desired": 2,
    "running": 2
}
```

```json
{
    "threshold": 80.0,
    "dta": 2,
    "tmd": "notBreaching"
}
```

Step 1 ran before the credentials went away, so `desiredCount` is `2`.
Steps 2 and 3 ran *after*, and both failed on authentication — so the
alarm still has threshold `80` with `datapoints_to_alarm` and
`treat_missing_data` intact, and the scale-back-down never happened.

**3. Before, after, or neither?** Neither, and `desiredCount` is the field
that decides it. The "before" state is `desiredCount: 1` with the original
alarm. The "after" state you designed is `desiredCount: 1` with threshold
`95`. What you have is `desiredCount: 2` with threshold `80` — a state
that appears nowhere in the plan, that nobody reviewed, and that the
script reported as a success. Note that the *intended* end state and the
*before* state agree on the count; the failure produced a value neither of
them has.

**4. Which capture, and when?** A full read of both resources **before the
first mutation** — the script's step 1, not step 2. Once step 1 has
executed you no longer know what `desiredCount` was, and once step 2 has
executed against a partially-restated alarm you no longer know what the
alarm was. A capture taken after a mutation is a file, not a revert plan.

The wider lesson: this script's failure mode is not "an AWS call failed."
An AWS call failing is normal and survivable. The failure mode is that
**every subsequent step ran anyway**, against a world that no longer
matched what those steps assumed.

### The corrected script

```bash
#!/usr/bin/env bash
#
# drill-fixed.sh — the same three mutations, made safe to fail.
set -euo pipefail

CLUSTER=awsdevops-cli-cluster
SERVICE=awsdevops-cli-service
ALARM=awsdevops-cli-cpu-high

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
CAPTURE_DIR=~/aws-preflight
mkdir -p "$CAPTURE_DIR"

# --- Pre-flight: who, what, and current state, before anything mutates. ---

aws sts get-caller-identity \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-whoami.json"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-service-before.json"

aws cloudwatch describe-alarms \
  --alarm-names "$ALARM" \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > "${CAPTURE_DIR}/${STAMP}-alarm-before.json"

echo "pre-flight captured under ${CAPTURE_DIR}/${STAMP}-*"

# --- 1. Scale up, and do not proceed until it converged. ---

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 2 \
  --no-cli-pager > /dev/null

if ! aws ecs wait services-stable \
       --cluster "$CLUSTER" \
       --services "$SERVICE" \
       --no-cli-pager; then
  echo "step 1: service never stabilized at desired-count 2; stopping here." >&2
  echo "        before-state is in ${CAPTURE_DIR}/${STAMP}-service-before.json" >&2
  exit 1
fi

# --- 2. Raise the threshold, restating EVERY field the alarm has. ---
#     A partial put-metric-alarm would silently drop alarm_description,
#     datapoints_to_alarm, and treat_missing_data. See C3.

aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM" \
  --alarm-description "CLI appendix drill alarm. Day A2 mutates and reverts this." \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --datapoints-to-alarm 2 \
  --threshold 95 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --dimensions Name=ClusterName,Value="$CLUSTER" \
               Name=ServiceName,Value="$SERVICE" \
  --no-cli-pager

# --- 3. Scale back down, and verify that too. ---

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 1 \
  --no-cli-pager > /dev/null

if ! aws ecs wait services-stable \
       --cluster "$CLUSTER" \
       --services "$SERVICE" \
       --no-cli-pager; then
  echo "step 3: service never stabilized at desired-count 1." >&2
  exit 1
fi

echo "all three mutations applied and verified"
```

### What each change buys, and the one trap in it

| Change | What it prevents |
|---|---|
| `set -e` | Step 3 running after step 2 failed. This is the whole bug |
| `set -u` | A typo'd variable expanding to the empty string and sending `--cluster ""` to the API |
| `set -o pipefail` | A failure on the left of a pipe being hidden by a `jq` or `grep` that exits `0`. Nothing here pipes yet; scripts grow |
| `if ! aws ecs wait ...; then` | Proceeding against a service that never converged. The waiter's non-zero exit is the *only* signal here, and this is the form that reads it |
| Pre-flight capture | Every one of those `exit 1` paths leaving you with a file that says what to go back to |
| Full alarm restatement | Step 2 silently dropping three fields on its way to changing one |
| `--no-cli-pager` everywhere | The script blocking forever in CI waiting for someone to press `q` |
| `> /dev/null` on the mutations | Nobody mistaking `update-service`'s echoed desired state for evidence of convergence |

**The trap:** under `set -e`, the C2 idiom

```bash
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"
WAITER_STATUS=$?
```

never reaches the second line — `set -e` kills the script on the waiter's
non-zero exit before the status can be captured. That idiom is for an
interactive shell. In a script, put the command in an `if !` condition (as
above) or append `|| WAITER_STATUS=$?`, both of which exempt it from
`set -e`. This is a real and common way to write a script that looks like
it checks exit codes and does not.

### Cleaning up after this stage

The fixed script deliberately leaves the alarm at threshold `95` — it is
the same forward change the broken script attempted. Undo it with C3's
explicit restatement (threshold back to `80`, all twelve arguments), and
confirm `desiredCount` is `1`:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM" \
  --alarm-description "CLI appendix drill alarm. Day A2 mutates and reverts this." \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --datapoints-to-alarm 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --dimensions Name=ClusterName,Value="$CLUSTER" \
               Name=ServiceName,Value="$SERVICE" \
  --no-cli-pager

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].desiredCount' \
  --output text --no-cli-pager
```

```text
1
```

Then delete `drill-broken.sh` and `drill-fixed.sh`, or move them somewhere
`git` will not see them. They contain no secrets — the expired-credential
stand-in is a profile name that does not exist — but a script that scales
a service is not a thing to leave lying in a lab directory.

---

## The success check

```bash
cd labs/dayA2
terraform plan -detailed-exitcode
echo "plan exit status: $?"
```

```text
No changes. Your infrastructure matches the configuration.

plan exit status: 0
```

If it is not `0`, the plan names the resource whose revert did not land.
Match it against the cycles:

| Resource in the plan | Cycle you did not finish |
|---|---|
| `aws_ecs_service.this` — `desired_count` | C2 or C5 |
| `aws_ecs_service.this` — `task_definition` | C4, and you probably reverted to the family rather than to revision 1 |
| `aws_cloudwatch_metric_alarm.cpu_high` | C3 — and the attribute named in the plan is the field your restatement missed |
| `aws_cloudwatch_log_group.ecs` | Break it / Fix it (a) — the `terraform apply` step never ran |

Fix the cycle, not the plan. Then go to `teardown.md`.
