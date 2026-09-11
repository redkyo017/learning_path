# CLI-MASTERY — the AWS CLI, indexed by the question you are asking

This is a lookup reference: you open it at one section, read three lines, close it, and do the same thing again next Tuesday with someone waiting in a Slack thread. It teaches nothing — the reasoning behind every line here lives in `content/dayA1.md` (INTERROGATE: what is actually there?) and `content/dayA2.md` (OPERATE: changing things you can undo), and this file assumes you have already read them.

**Day A1's four labels are the vocabulary underneath every section here.** Every `aws` invocation is
**WHO** (which identity and region resolved), **WHAT** (which operation, with which parameters),
**WHAT CAME BACK** (what the API actually returned), and **WHAT DID I SEE** (what you chose to
display). `## Identity triage` is WHO; `## One-liners by question` is WHAT; the pagination block and
the three-state not-found material are WHAT CAME BACK; `## JMESPath recipes` is WHAT DID I SEE. If
you cannot say which of the four is failing, start at `## Identity triage`.

**Conventions.** AWS CLI v2, `zsh` on macOS, region `us-east-1`. Resource names are this path's (`awsdevops-*`, `awsdevops-cli-*`). `123456789012` is a placeholder account ID and `<ANGLE_BRACKETS>` are yours to fill in. Every JMESPath argument is quoted as a whole, because in `zsh` an unquoted `[?...]` is a glob — single quotes by default, double quotes on the outside when the expression itself contains a single-quoted literal.

---

## Identity triage

Run one of these *before* you conclude anything about a resource. Every row below costs less than a minute of guessing.

| Symptom | Discriminating command | What its output rules out |
|---|---|---|
| **"Which account am I in?"** | `aws sts get-caller-identity --output json --no-cli-pager` | Everything. It returns `UserId`, `Account`, `Arn`, needs no permission beyond being authenticated, and is the only answer that cannot be argued with. It says nothing about *region* — that is the row below. |
| **"Which region did that actually go to?"** | `aws configure list` — read the `region` row's **Type** and **Location** | Distinguishes *no region* (loud, immediate error) from *wrong region* (a valid, empty, confident answer). `Type: env` names the shell tab you are standing in. |
| **"Why is this denied?"** | `aws sts get-caller-identity` for the exact ARN, then `aws iam simulate-principal-policy --policy-source-arn <THAT_ARN> --action-names <service:Action> --resource-arns <TARGET_ARN>` | `AccessDenied` already rules out identity *resolution* — credentials were valid and a principal was established, so re-checking your profile is wasted motion. The simulator returns an `EvalDecision` of `allowed`, `implicitDeny` (nothing grants it) or `explicitDeny` (something actively forbids it), and those have different fixes. |
| **"It worked yesterday."** | `aws configure list` — the **Type** and **Location** columns, not the `Value` column | Rules out "the API changed." An `AWS_PROFILE` or `AWS_REGION` you exported three hours ago shows up as `Type: env`, and there is no arguing with it. |
| **"My profile is ignored."** | `aws configure list --profile <NAME>`, then look at the file headers | `~/.aws/config` requires `[profile NAME]`; `~/.aws/credentials` requires `[NAME]` with **no** prefix; `[default]` takes no prefix in either. `[profile personal]` in the credentials file creates a profile literally named `profile personal`, which nothing will ever select. |
| **"Token expired."** | Read the error text first, then `aws sso login --profile <NAME>` | SSO expiry surfaces as a token-loading/refresh error, **not** as `AccessDenied`. If you are reading an IAM policy in response to a token error you are debugging the wrong thing. Cached tokens live under `~/.aws/sso/cache/`. |
| **Nothing above explains it** | `aws ecs list-clusters --debug --no-cli-pager 2>/tmp/aws-debug.log` | Grep the trace case-insensitively for the *concepts*, not literal lines: `credential` (which provider supplied them), `endpoint` (the host name carries the region), `status` and `requestid` (what support will ask for). |

**Credential precedence, documented order:** (1) command-line `--profile` / `--region`, (2) environment variables, (3) assume-role / web-identity from config, (4) IAM Identity Center (SSO), (5) `~/.aws/credentials`, (6) `~/.aws/config`, (7) container credentials, (8) EC2 instance metadata. Read it once, then stop trusting it and **confirm locally with `aws configure list`** — your laptop's state outranks a remembered list.

**Your two accounts reach AWS by two different mechanisms, and they fail differently.**

- **Company account — IAM Identity Center (SSO).** `aws configure sso` writes an `[sso-session NAME]` block plus a `[profile NAME]` block into `~/.aws/config`; several profiles can share one session block, which is why one login reaches several accounts. `aws sso login --profile <NAME>` refreshes it. Failure mode: token expiry, which is a credential-and-expiry problem, never an authorization one.
- **Personal account — long-lived IAM user keys.** An access key ID and secret in `~/.aws/credentials` under a bare `[personal]` header, resolving at step 5 of the chain. It has no expiry, survives a stolen laptop, survives you changing jobs, and is readable by every process running as you. Scope the IAM user narrowly, rotate deliberately, and know the key ID well enough to recognize it in CloudTrail.

---

## JMESPath recipes

`--query 'EXPR'` is **client-side**: it runs on your machine after the entire response has already crossed the network. It cannot reduce API calls, bytes, or throttling — only a server-side `--filters` / `--filter` / named parameter can do that.

| What question this answers | Expression | Note |
|---|---|---|
| "Just the IDs, out of a response nested two levels deep" | `--query 'Reservations[].Instances[].InstanceId'` | Projection: walk every element of every list, collect one field |
| "Only the ones whose field equals this value" | `--query "services[?status=='ACTIVE'].serviceName"` | Filter expression. **Double** quotes outside, because single quotes do not nest |
| "Same filter, but I want to keep the outer single quotes" | ``--query 'services[?status==`"ACTIVE"`].serviceName'`` | JSON literal in backticks. Never put this form inside double quotes — a bare backtick or `$` there is shell substitution |
| "Give me named columns a human can read" | `--query 'services[].{Name:serviceName,Running:runningCount,Desired:desiredCount}'` | Multiselect hash. Use this whenever a person will read the output |
| "Two fields per row, positionally" | `--query 'imageDetails[].[imageDigest,imagePushedAt]'` | Multiselect list. Order is yours; nothing is labeled |
| "How many are there?" | `--query 'length(taskDefinitionArns)'` | Count without eyeballing |
| "Which is the newest?" | `--query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]'` | `&field` is an expression reference; `[-1]` is the whole "most recent" idiom. You almost never need to sort descending |
| "All of them, oldest to newest" | `--query 'sort_by(imageDetails,&imagePushedAt)[].imageTags[0]'` | Same sort, no index |
| "One line I can paste into a thread" | `--query "join(', ', clusterArns)"` | Double quotes outside — the delimiter is a single-quoted literal |
| "Anything whose name contains this substring" | `--query "taskDefinitionArns[?contains(@, 'awsdevops-cli')]"` | `@` is the current element |
| "Anything whose name starts with this prefix" | `--query "services[?starts_with(serviceName, 'awsdevops-cli')]"` | Prefix match |
| "Flatten these nested lists into one list" | `--query 'Reservations[].Instances[]'` | A bare `[]` flattens |
| "Just the first few, in order" | `--query 'services[0].events[0:5].message'` | Slice. This is client-side and does **not** limit the API call |
| "Is this field present or null?" | ``--query 'deploymentInfo.rollbackInfo!=`null`'`` | A comparison is an expression: emits `True` or `False` |
| "One scalar, for a shell variable" | `--query 'services[0].serviceArn'` with `--output text` | `--output text` is safe when the projection returns **exactly one scalar**, and suspect otherwise |

**Pipe expression**, kept out of the table above because a markdown table would need to escape the
`|` and this is a file people copy-paste from. Run the left side, then feed its result to the right:

```bash
aws ecs describe-services --cluster <CLUSTER> --services <SERVICE> \
  --query 'services[].serviceName | length(@)'
```

**Three traps that live in this section.**

1. **The truncation trap.** `--max-items` is a client-side cap applied *before* your projection runs, so `--max-items 10` plus a filter searches ten items and honestly reports no matches. The empty array is not a fact about the account. Prefer a server-side narrowing parameter (`--family-prefix`, `--status`, `--filters`) over capping at all.
2. **`--output text` parsed positionally.** `text` is tab-separated with nested structures flattened, so the column your `cut -f3` lands on is decided by data you do not control — an absent field or a second tag shifts everything after it. One scalar out, or take JSON and parse it as JSON.
3. **`grep`-ing JSON instead of querying it.** `grep` matches the string at any depth, including a nested key with the same name, and returns nothing when the field is one level deeper than you assumed. A projection names the exact path and fails loudly.

**Pagination, in one block.** v2 auto-paginates by default. `--page-size` sets the per-request API page size (not how many items you end up with). `--max-items` is a client-side cap that emits a continuation token. `--no-paginate` issues exactly one API call — the right flag for an exploratory look at a list that might be enormous. And `--no-cli-pager` is required in anything non-interactive, because a pager waiting for a keypress with no keyboard is a hang, not an error.

---

## One-liners by question

Commands marked *(path)* already appear somewhere in `content/day01.md`–`day05.md` or `labs/`, so this section doubles as an index into the week.

### EC2

**"What is actually running in this region?"**
```bash
aws ec2 describe-instances \
  --filters 'Name=instance-state-name,Values=running' \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,Az:Placement.AvailabilityZone}' \
  --output table --no-cli-pager
```
`--filters` is the API doing the narrowing; the query is your laptop formatting what came back.

**"Which subnets belong to this VPC?"**
```bash
aws ec2 describe-subnets --filters 'Name=vpc-id,Values=<VPC_ID>' \
  --query 'Subnets[].{Id:SubnetId,Az:AvailabilityZone,Cidr:CidrBlock}' --output table
```

**"Would IAM even let me make this change?"**
```bash
aws ec2 stop-instances --instance-ids <INSTANCE_ID> --dry-run
```
`DryRunOperation` means the call would have been permitted; `UnauthorizedOperation` means it would not. That is the entire answer — it is an authorization probe, not a simulation, and it has no opinion about whether the change is correct. Most services do not support the flag at all.

### S3

**"Which buckets exist, and when were they created?"**
```bash
aws s3api list-buckets --query 'Buckets[].{Name:Name,Created:CreationDate}' --output table
```

**"Does this bucket exist, and can this identity see it?"** *(path: `labs/day05/teardown.md`)*
```bash
aws s3api head-bucket --bucket "<BUCKET_NAME>"
```

**"What is in it, and how much of it is there?"**
```bash
aws s3 ls "s3://<BUCKET_NAME>" --recursive --summarize | tail -n 3
```

**"`terraform destroy` is failing on a non-empty bucket."** *(path: `labs/day02/teardown.md`)*
```bash
aws s3 rm "s3://<BUCKET_NAME>" --recursive
```
Irreversible. Read the bucket name twice.

### IAM

**"Who am I, in one word?"** *(path: `labs/dayA2/README.md`)*
```bash
aws sts get-caller-identity --query 'Account' --output text --no-cli-pager
```

**"Can this principal do this thing, on this resource?"** *(path: `content/dayA1.md`, `content/dayA2.md`)*
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/<ROLE_NAME> \
  --action-names ecs:UpdateService \
  --resource-arns <TARGET_RESOURCE_ARN> \
  --no-cli-pager
```
Returns an `EvalDecision` per action: `allowed`, `implicitDeny`, or `explicitDeny`.

**"What is attached to this role?"**
```bash
aws iam list-attached-role-policies --role-name <ROLE_NAME> \
  --query 'AttachedPolicies[].PolicyArn' --output text
```

**"Is the GitHub OIDC provider registered in this account?"** *(path: `labs/day00`, `labs/day02`)*
```bash
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text
```

IAM is **eventually consistent**: a successful write may not be visible to an immediately following read, or usable by an immediately following call. When an IAM-adjacent step fails right after an IAM write, retry before you investigate.

### ECS

**"What clusters exist at all?"** *(path: `content/dayA1.md`, `labs/verify-teardown.sh`)*
```bash
aws ecs list-clusters --query 'clusterArns' --output text
```

**"What services are in this cluster?"** *(path: `labs/verify-teardown.sh`)*
```bash
aws ecs list-services --cluster <CLUSTER> --query 'serviceArns' --output text
```

**"Is this service actually healthy — desired versus running?"** *(path: `labs/dayA2/README.md`)*
```bash
aws ecs describe-services --cluster <CLUSTER> --services <SERVICE> \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
  --output json --no-cli-pager
```
`desired` is what someone asked for. `running` is what is true. Only the second is evidence.

**"Did I just name something that does not exist?"**
```bash
aws ecs describe-services --cluster <CLUSTER> --services <SERVICE> --query 'failures'
```
On ECS batch describes this is the check that matters — see the Error decoder.

**"What is actually deployed right now?" — service to ECR digest**
```bash
aws ecs describe-services --cluster <CLUSTER> --services <SERVICE> \
  --query 'services[0].taskDefinition' --output text

aws ecs describe-task-definition --task-definition <TASKDEF_ARN_FROM_ABOVE> \
  --query 'taskDefinition.containerDefinitions[].image' --output text

aws ecr describe-images --repository-name <REPO> \
  --image-ids imageTag="<TAG_FROM_THAT_IMAGE_URI>" \
  --query 'imageDetails[0].imageDigest' --output text
```
Four links of one chain — service → task definition → image URI → digest — and the argument to each `describe-` comes out of the previous answer. Stop at the tag and you have a label that can be moved; the digest is the artifact. The repository name is the last path segment of the image URI, the tag is whatever follows its final `:`.

**"What is the service telling me it is doing?"** *(path: `labs/dayA2/README.md`)*
```bash
aws ecs describe-services --cluster <CLUSTER> --services <SERVICE> \
  --query 'services[0].events[0:5].message' --output text
```

**"Why did that task stop?"** *(path: `labs/dayA2/README.md`)*
```bash
aws ecs list-tasks --cluster <CLUSTER> --desired-status STOPPED \
  --query 'taskArns[0]' --output text

aws ecs describe-tasks --cluster <CLUSTER> --tasks <TASK_ARN_FROM_ABOVE> \
  --query 'tasks[0].{stopped:stoppedReason,containers:containers[*].reason}' --output json
```

**"Which revisions does this family have?"**
```bash
aws ecs list-task-definitions --family-prefix awsdevops-cli-task \
  --query 'taskDefinitionArns' --output text
```
`--family-prefix` is server-side, which is why this one is safe and `--max-items` plus a `contains()` filter is not.

**"Wait until it converges, and fail the script if it does not."**
```bash
aws ecs wait services-stable --cluster <CLUSTER> --services "<SERVICE>"
```
A waiter polls on a fixed interval up to a bounded number of attempts, then **exits non-zero** — that non-zero exit under `set -e` is the whole reason it belongs in a script instead of a `while sleep 5` loop. Get the interval and attempt count from `aws ecs wait services-stable help` on the CLI you actually have installed, never from a number quoted in a document, including this one.

**"Scale it."** *(path: `content/dayA2.md`)*
```bash
aws ecs update-service --cluster <CLUSTER> --service <SERVICE> --desired-count 1
```
The response reports that the API **accepted** the request, not that the system **converged**. Re-read the resource.

### ECR

**"Which repositories exist?"**
```bash
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text
```

**"What is the newest image tag in this repository?"** *(path: `content/dayA1.md`, `labs/dayA2/variables.tf`)*
```bash
aws ecr describe-images --repository-name <REPO> \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text
```

**"What is in there — tag, digest, push time?"** *(path: `labs/day01/README.md`)*
```bash
aws ecr describe-images --repository-name <REPO> \
  --query 'imageDetails[*].{tag:imageTags[0],digest:imageDigest,pushedAt:imagePushedAt}'
```

**"Is this repository tag-immutable?"** *(path: `labs/dayA2/README.md`)*
```bash
aws ecr describe-repositories --repository-names <REPO> \
  --query 'repositories[0].imageTagMutability' --output text
```
An `IMMUTABLE` repository **rejects** an attempt to move an existing tag rather than silently overwriting it. Day 1 already names the exception — `ImageTagAlreadyExistsException` (`content/day01.md:211`, `labs/day01/README.md:95`). Confirm it against your own error anyway and write down what you got, which is the same habit as reading a waiter's numbers out of `help`.

**"Log Docker in."** *(path: `content/day01.md`)*
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### CloudWatch Logs

**"Show me what this service is saying, right now."**
```bash
aws logs tail /ecs/awsdevops-cli --since 15m --follow
```

**"Which log groups exist under this prefix?"** *(path: `labs/day01/teardown.md`, `labs/day05/teardown.md`)*
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/codebuild/awsdevops-build \
  --query 'logGroups[*].logGroupName' --output text
```

**"Which log groups are quietly costing me money forever?"** *(path: `labs/verify-teardown.sh`)*
```bash
aws logs describe-log-groups \
  --query 'logGroups[?retentionInDays==`null`].logGroupName' --output text
```
No retention means never expires. CloudWatch Logs is ~$0.50/GB ingested (`COST.md`), and storage of what you already ingested does not stop on its own.

**"Which stream got the most recent event?"** *(path: `labs/dayA2/README.md`)*
```bash
aws logs describe-log-streams --log-group-name /ecs/awsdevops-cli \
  --order-by LastEventTime --descending \
  --query 'logStreams[*].{stream:logStreamName,lastEvent:lastEventTimestamp}'
```
`--order-by`/`--descending` are server-side, so the first rows really are the newest.

**"Delete a log group."** *(path: `content/dayA2.md`)*
```bash
aws logs delete-log-group --log-group-name /ecs/awsdevops-cli
```
Irreversible, and it can break a task that names the group in its `awslogs-group` option.

### CloudWatch (metrics and alarms)

**"Is this alarm firing right now?"** *(path: `labs/day05/RUNBOOK-TEMPLATE.md`)*
```bash
aws cloudwatch describe-alarms --alarm-names <ALARM_NAME> \
  --query 'MetricAlarms[0].StateValue' --output text
```

**"What is in ALARM across the account?"**
```bash
aws cloudwatch describe-alarms --state-value ALARM \
  --query 'MetricAlarms[].AlarmName' --output text
```
`--state-value` is server-side.

**"When did it change state, and why?"** *(path: `labs/day03/README.md`)*
```bash
aws cloudwatch describe-alarm-history --alarm-name <ALARM_NAME> \
  --history-item-type StateUpdate \
  --query 'AlarmHistoryItems[0:5].{when:Timestamp,summary:HistorySummary}' --output table
```

**"Capture this alarm before I touch it."** *(path: `content/dayA2.md`, `labs/dayA2/README.md`)*
```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p ~/aws-preflight
aws cloudwatch describe-alarms --alarm-names awsdevops-cli-cpu-high \
  --query 'MetricAlarms[0]' --output json --no-cli-pager \
  > ~/aws-preflight/${STAMP}-cpu-high-before.json
```
Do this **before** the `put-`, not after. An `-after.json` with nothing to diff against is a file, not a revert plan.

**"Change the threshold."** *(path: `content/dayA2.md`)*
```bash
aws cloudwatch put-metric-alarm --alarm-name awsdevops-cli-cpu-high ...
```
`put-metric-alarm` **fully replaces** the alarm definition. Every optional setting you do not restate — description, `datapoints_to_alarm`, `treat_missing_data` — is dropped, not preserved, and the command succeeds silently. Build this command by restating every field from the capture above, with one value changed. Ten alarms are free (`COST.md`).

### CodeBuild

**"Run the build."** *(path: `labs/day01/README.md`)*
```bash
aws codebuild start-build --project-name "$(terraform output -raw codebuild_project_name)"
```

**"What happened to that build?"** *(path: `labs/day01/README.md`)*
```bash
aws codebuild batch-get-builds --ids <BUILD_ID> \
  --query 'builds[0].{status:buildStatus,phase:currentPhase}'
```

**"Which builds ran most recently?"**
```bash
aws codebuild list-builds-for-project --project-name <PROJECT_NAME> \
  --query 'ids[0:5]' --output text
```
`ARM_SMALL` is ~$0.0034/build-min (`COST.md`), so a build that hangs is a build that bills.

### CodePipeline

**"Where is the pipeline right now?"** *(path: `labs/day02/README.md`)*
```bash
aws codepipeline get-pipeline-state --name <PIPELINE_NAME> \
  --query 'stageStates[].{stage:stageName,status:latestExecution.status}' --output table
```

**"Kick it off."** *(path: `labs/day02/README.md`)*
```bash
aws codepipeline start-pipeline-execution --name "$(terraform output -raw pipeline_name)"
```

### CodeDeploy

**"How did that deployment end?"** *(path: `labs/day05/README.md`, `labs/day05/RUNBOOK-TEMPLATE.md`)*
```bash
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID> \
  --query 'deploymentInfo.{status:status,rollbackInfo:rollbackInfo,completeTime:completeTime}'
```

**"How many deployments went out in this window?"** *(path: `labs/day05/README.md`)*
```bash
aws deploy list-deployments \
  --application-name <CODEDEPLOY_APP_NAME> \
  --deployment-group-name <CODEDEPLOY_GROUP_NAME> \
  --create-time-range start=<WINDOW_START>,end=<WINDOW_END> \
  --query 'length(deployments)'
```

**"Which of them rolled back?"** *(path: `labs/day05/SOLUTION.md`)*
```bash
for d in $(aws deploy list-deployments \
  --application-name <CODEDEPLOY_APP_NAME> \
  --deployment-group-name <CODEDEPLOY_GROUP_NAME> \
  --create-time-range start=<WINDOW_START>,end=<WINDOW_END> \
  --query 'deployments[]' --output text); do
  aws deploy get-deployment --deployment-id "$d" \
    --query 'deploymentInfo.[deploymentId, rollbackInfo]' --output text
done
```
`GetDeployment` returns exactly one top-level member, `deploymentInfo` — `deploymentId` lives
*inside* it, so project from `deploymentInfo`, not from the root. A second column of `None` means
that deployment did not roll back; anything else means it did.

**"Stop a bad deployment and roll it back."** *(path: `labs/day03/README.md`)*
```bash
aws deploy stop-deployment --deployment-id <DEPLOYMENT_ID> --auto-rollback-enabled
```

---

## Reversibility

Know your bucket **before** you press enter. The bucket is knowable in advance, and the test is mechanical: try to name the exact revert command. If you can name it from memory, bucket one. If you can name it only after reading something first, bucket two. If naming it produces "restore it from somewhere," bucket three — and you did not realize it.

| Bucket | Examples | The revert, and what it demands |
|---|---|---|
| **trivially reversible** | Tags; `aws ecs update-service --cluster C --service S --desired-count N` | Set it back. Do it — and capture state anyway, out of habit, because habits are what survive an incident and your memory is of the value you *meant* to set |
| **reversible with effort** | A new task-definition revision (the old revision still exists and is addressable); a service update; adding or removing a security-group rule; **an alarm threshold changed with `put-metric-alarm`** | Know the *specific* revert command before you run the forward one. ECS: `aws ecs update-service --cluster C --service S --task-definition FAMILY:REVISION`. Alarm: another **full** `put-metric-alarm` restating every field — which only works *if you captured the alarm first*. Without a capture the settings you dropped are gone, and this was bucket three wearing bucket one's clothes |
| **irreversible** | `aws logs delete-log-group`; `aws ecr delete-repository --force`; `aws ecr batch-delete-image` on the only copy of an image; `aws ec2 terminate-instances` | Stop. Say the command out loud. Confirm the account with `aws sts get-caller-identity`. Then decide whether you actually need it today |

**What makes bucket two bucket two: the previous state still exists as an addressable object.** A task-definition revision is revertible because revision N-1 was never deleted. An image tag moved over a mutable tag is not, because the thing you would go back to no longer has a name.

**Two things that quietly move a change down a bucket.**

- **`put-` is not `patch`.** `put-metric-alarm` replaces the whole object. Anything you omit is dropped, the response looks identical either way, and nobody attributes the next outage to "someone changed a threshold."
- **Repeatable is not idempotent.** `update-service --desired-count 1`, `put-*` and most `tag-*` assert an end state and are safe to repeat. `register-task-definition` run twice gives you two revisions, not one. Where an operation accepts a caller-supplied idempotency token the parameter is spelled differently per service — `--client-token`, `--client-request-token`, `--idempotency-token` — so check that operation's own `help` rather than assuming.

**The pre-flight triad, in order, every time:** (1) *Who am I?* `aws sts get-caller-identity`. (2) *What will this touch?* Read the **resolved** target back, not the name you typed. (3) *What is the current state?* Captured to a timestamped file, because a revert you cannot perform is not a plan.

---

## Error decoder

| Message fragment | Family | What it rules out | Next command |
|---|---|---|---|
| `Unknown options: --clustre`, `Invalid choice: 'describe-service'`, `Parameter validation failed: Unknown parameter in input` | Client-side validation | Everything on the AWS side. The request **never left the machine** — stop checking permissions, region, credentials, and whether the resource exists | `aws ecs describe-services help`, or `--generate-cli-skeleton` for the input shape |
| `ExpiredToken` | Credential and expiry | The operation and its parameters — you never got far enough for them to matter. Also rules out a policy change | `aws sso login --profile <NAME>` for an SSO session; otherwise `aws configure list` to see what resolved |
| An SSO token-loading / refresh error | Credential and expiry | `AccessDenied` as an explanation. Expiry does **not** surface as `AccessDenied`, so no policy changed | `aws sso login --profile <NAME>` |
| `InvalidClientTokenId` | Credential and expiry | An expiry story. This is a wrong, deleted, or disabled key — re-logging in does not fix it | `aws configure list` for the `Type`/`Location` of `access_key`, then check the key still exists |
| `Unable to locate credentials` | Credential and expiry | Everything about the operation. Nothing resolved at all | `aws configure list`; check the profile header syntax in both files |
| `AccessDenied`, `AccessDeniedException` | Authorization | Identity **resolution**. Credentials were valid and a principal was established, or you would have a different error — stop re-checking your profile | `aws sts get-caller-identity` for the exact ARN, then `aws iam simulate-principal-policy` against it |
| `UnauthorizedOperation` | Authorization | Same as above. On an EC2 `--dry-run`, it is the "no" answer of a two-answer probe | `aws iam simulate-principal-policy` — `implicitDeny` and `explicitDeny` have different fixes |
| `DryRunOperation` | Authorization (success) | Only that IAM would not have stopped you. It rules out **nothing** about whether the change is correct, targets the right resource, or is wise | Nothing — decide separately whether to make the change. `--generate-cli-skeleton` into a reviewable file if you are unsure it is right |
| `RepositoryNotFoundException` (and other raised `...NotFoundException`s) | Not found vs. empty | Nothing yet. Most often this is *wrong region* or *wrong account*, not a missing resource | `aws configure list` for the region; re-run as the matching `list-` to see what does exist |
| `ClusterNotFoundException` | Not found vs. empty | Raised only when a `--cluster` **parameter** names a cluster that does not exist — `describe-services`, `list-services`, `list-tasks`. It is never what `describe-clusters --clusters` gives you | `aws ecs list-clusters --query 'clusterArns' --output text`, then `aws configure list` for the region |
| Exit 0, empty main array, `failures[]` with `reason: "MISSING"` | Not found vs. empty | Nothing. Exit 0 does **not** mean "found" here | Read `failures[]`. Then `aws configure list` for the region before concluding anything |
| Exit 0 and a bare `[]` from a `list-` | Not found vs. empty | Nothing. This is a claim about one account, one region, one identity — not about the world | `aws configure list`, then re-run without the projection |
| `zsh: no matches found: [?Name==...]` | Shell, before the CLI ran | Everything AWS. `zsh` globbed an unquoted bracket expression and never invoked `aws` | Quote the whole argument: `--query 'services[0].serviceArn'`, or double quotes outside when the expression holds a single-quoted literal |
| Nothing in the four families fits | — | — | `aws ecs list-clusters --debug --no-cli-pager 2>/tmp/aws-debug.log`, then grep case-insensitively for `credential`, `endpoint`, `status`, `requestid` |

### "Nothing came back" is three states, not two

Flattening this back to two is the diagnostic error that costs you credibility, because you will report absence that is not there.

1. **A `list-*` returns an empty array, at exit 0.** Nothing matched, and the API is telling you so successfully. A real answer about that account, in that region, as that identity.
2. **Some `describe-*` operations raise a service exception** when the named resource does not exist. ECR's `RepositoryNotFoundException` is the clean example — ask for a repository that is not there and you get an error, loudly, on stderr. If a command like that returns *silence*, something upstream swallowed the exception (a `2>/dev/null`, a pipeline that discarded stderr) and you are reading silence as data.
3. **ECS's batch describes do neither.** `describe-clusters`, `describe-services`, and `describe-tasks` return **exit 0**, with the items they found in the main array and a parallel **`failures[]`** array carrying `{arn, reason: "MISSING"}` for every identifier they could not find.

```bash
# Not an error. Exit 0. clusters is empty; the answer is in failures[].
aws ecs describe-clusters --clusters nope
# => {"clusters": [], "failures": [{"arn": "...", "reason": "MISSING"}]}
```

**On an ECS batch describe, an empty main array is not evidence of absence.** Check `failures[]` before you conclude anything, and remember that an empty result from the wrong region looks exactly like an empty result from the right one.

---

## Safety rules

- **Read-only by default in any account you do not own.** The default profile for a shared account should be one that cannot change anything, and write access should be a separately named profile — `company-prod-write` in your scrollback is a thing you notice; `default` is not.
- **Check identity before any mutation.** `aws sts get-caller-identity` costs nothing. Scrollback from an hour ago is not evidence of the current profile; an SSO refresh or an exported environment variable can have changed it since. The most expensive CLI mistakes are not wrong commands, they are right commands in the wrong account.
- **Capture state before a `put-`.** Redirect the current object to a timestamped file, build the new command by restating every field from that file, and diff `-before.json` against `-after.json` afterward. A one-line diff means you did what you intended; a four-line diff means you just learned what `put` means.
- **Know your bucket before pressing enter.** Name the revert command out loud first. If you cannot name it, you are in the irreversible bucket whether you meant to be or not.
- **A mutation's own response is not evidence.** It reports that the API accepted the request, not that the system converged. Re-read the resource, or use a waiter and check its exit code.
- **What IAM permits is not what your team's change process allows,** and only the first of those is enforced by the API. `simulate-principal-policy` returning `allowed` answers a technical question and no organizational one.
- **A CLI change to a Terraform-managed resource is drift the moment you make it.** That is acceptable while it is temporary *or* codified, and unacceptable when it is permanent and undocumented. Open the PR the same day, while you still remember the values.
