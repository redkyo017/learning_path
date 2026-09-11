# Day A2 — OPERATE: changing things you can undo

**Appendix:** AWS CLI mastery (depends on Days 1–3 and Day A1)
**Time:** ~3.5h (content ~65m · lab ~115m · break/fix ~20m · teardown ~10m)
**Cost if you follow teardown:** ~$0.03

## Why this matters

A human typing a mutating command into a terminal is a promotion stage —
it changes production — but it is a promotion stage with no code review,
no stored artifact, no approval gate, and no automatic rollback. Every
control the path spent five days building for your pipeline is absent the
moment you paste a command into a shell, and the blast radius is
identical. Day 3 taught you to ask of every stage *what does this prove,
and is it reversible?* Turn those two questions on your own keystrokes and
they get **harder**, not easier: a CodeDeploy stage at least has a bake
period, an alarm, and a documented revert. Your terminal has whatever you
thought to do first.

## The question of the day

**Do I know what this command will change, and can I get back?**

## Core concepts

### 1. You are a pipeline stage

Day 3's REVERSE link was about a machine promoting an artifact. This day
is the same link with a human in the stage's place, and the same three
obligations survive the substitution:

- **Predict.** Say out loud, before you press enter, what will be
  different afterward — which resource, which field, which value. If you
  cannot say it in one sentence, you do not know what the command does
  yet, and `help` costs less than a rollback.
- **Observe.** Read the resource back afterward. Not the command's own
  output — the resource (Core concept 7).
- **Reverse.** Know the specific command that undoes this one, and know
  it *before* running the forward one. A revert you would have to design
  under incident pressure is not a revert, it is an intention.

A pipeline stage that could not do all three would never have passed
review on Day 3. Hold yourself to the standard you hold your pipeline to.

### 2. The pre-flight triad

Day A1's four labels — **WHO**, **WHAT**, **WHAT CAME BACK**, **WHAT DID
I SEE** — were an interrogation loop, run to learn about a system. The
pre-flight triad is the same discipline moved to *before* the change, and
it is three questions, always in this order:

1. **Who am I?** Verified, not assumed. `aws sts get-caller-identity`
   returns `UserId`, `Account`, `Arn`, needs no permission beyond being
   authenticated, and is the only honest answer. The most expensive CLI
   mistakes are not wrong commands; they are right commands in the wrong
   account.
2. **What will this touch?** The *resolved* target, read back. Not the
   name you typed — the thing that name resolved to. A cluster name is
   region-scoped, a task definition family without a revision means
   "latest", and `--service my-svc` in the wrong cluster is a different
   service that may well exist.
3. **What is the current state?** Captured to a file, because **a revert
   you cannot perform is not a plan.** This is the step people skip, and
   it is the one that turns bucket-two mistakes (Core concept 5) into
   bucket-three ones.

The capture idiom is unglamorous and takes four seconds:

```bash
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p ~/aws-preflight

aws sts get-caller-identity \
  --output json --no-cli-pager \
  > ~/aws-preflight/${STAMP}-whoami.json

aws cloudwatch describe-alarms \
  --alarm-names awsdevops-cli-cpu-high \
  --query 'MetricAlarms[0]' \
  --output json --no-cli-pager \
  > ~/aws-preflight/${STAMP}-cpu-high-before.json
```

Two things about that file. First, it is your revert source — the values
you will need to restate are in it. Second, it is your *evidence*: after
the mutation, capture an `-after.json` the same way and diff the two. A
diff between two captured states is a far better answer to "what did that
change?" than your memory of what you meant to change.

### 3. The tooling of care

**`--dry-run` is not a preview.** Lead with the correction, because the
flag is commonly mistaught. EC2's `--dry-run` is an
**authorization probe, not a simulation**: `DryRunOperation` means the
call would have been permitted, `UnauthorizedOperation` means it would
not. That is the entire contents of the answer. It says nothing about
whether the change is correct, whether the parameters are the ones you
meant, or whether doing it is a good idea. Most services do not support
it at all. Treat `DryRunOperation` as "IAM would not have stopped me,"
which is a much smaller claim than the one people hear.

**`--generate-cli-skeleton` and `--cli-input-json` are how a change
becomes reviewable by a human first.** `--generate-cli-skeleton` emits the
input shape for an operation; `--cli-input-json file://input.json`
consumes it. Both are available across services. A file is reviewable, and
a file is diffable:

```bash
aws ecs update-service --generate-cli-skeleton \
  --no-cli-pager > update-service.json
# edit update-service.json, then have someone read it
aws ecs update-service --cli-input-json file://update-service.json
```

This is the closest thing the CLI has to a pull request. For anything
touching an account you share with other people, it is worth the extra
two minutes.

**`--cli-auto-prompt` / `--no-cli-auto-prompt`** (config key
`cli_auto_prompt`) controls v2's interactive parameter prompting. Useful
for guarded interactive work on an operation whose parameters you do not
have memorized; strictly wrong in a script.

**`--no-cli-pager`** matters more than it looks. CLI v2 sends output
through a pager by default; `--no-cli-pager`, or setting `cli_pager` to
empty, disables it. Required in anything non-interactive — a command that
blocks a pipeline waiting for someone to press `q` is a failure mode you
only debug once.

### 4. Idempotency, and why `put-` is not `patch`

This is the most consequential paragraph on this page.

**`put-metric-alarm` fully replaces the alarm definition. Optional
settings you do not restate are dropped, not preserved.** That is `put`
semantics, not `patch` semantics, and the CLI gives you no warning, no
confirmation prompt, and no indication in the response that anything
other than what you typed changed. The command returns silently. The
alarm is now a different alarm.

`labs/dayA2/` springs this on you deliberately in **cycle 3**. Its alarm,
`awsdevops-cli-cpu-high`, carries `alarm_description`,
`datapoints_to_alarm`, and `treat_missing_data` for exactly this reason.
A reasonable-looking one-line threshold bump:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name awsdevops-cli-cpu-high \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --statistic Average \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 90 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=awsdevops-cli-cluster \
               Name=ServiceName,Value=awsdevops-cli-service
```

...leaves you with an alarm that has no description, no
`datapoints_to_alarm`, and default missing-data handling. Re-read Day 3's
Core concept 7 if the last of those looks harmless: `treat_missing_data`
is the difference between an alarm that fires and an alarm that is
theater. Nobody attributes the next outage to "someone changed a
threshold," because on the surface, someone only changed a threshold.

The defense is the triad, mechanically: capture the alarm to
`-before.json`, build the new command by restating **every** field in
that capture with one value changed, run it, capture `-after.json`, and
diff. If the diff has one line, you did what you intended. If it has
four, you just learned what `put` means for free.

**Which operations repeat safely.** The rule of thumb, and it is only a
rule of thumb: operations that assert a desired end state
(`update-service --desired-count 1`, `put-*`, most `tag-*`) are
repeatable — run them twice and the second run is a no-op or an identical
overwrite. Operations that *create a new thing each time* are not.
`register-task-definition` run twice gives you two revisions, not one;
that is harmless but not free, and it is why a retried script can leave a
family with a surprising revision count.

**Client request tokens.** Several AWS APIs accept a caller-supplied
idempotency token so that a retried call is recognized as the same call
rather than a second one. The parameter is spelled differently per
service — `--client-token`, `--client-request-token`,
`--idempotency-token` — so check the operation's own `help` output rather
than assuming. Where one exists and you are writing a retry loop, use it;
where none exists, your retry logic has to be safe on its own.

### 5. The reversibility taxonomy

Three buckets. The whole point is that the bucket is knowable *in
advance*.

| Bucket | Examples | What it demands of you |
|---|---|---|
| **trivially reversible** | Tags; scaling a service with `update-service --desired-count` | Do it — and capture state anyway, out of habit, because habits are what survive an incident |
| **reversible with effort** | A new task-definition revision (the old revision still exists and is addressable); a service update; adding or removing a security-group rule; **an alarm threshold changed with `put-metric-alarm`** | Know the *specific* revert command before you run the forward one. For ECS that is `aws ecs update-service --cluster C --service S --task-definition FAMILY:REVISION` — in `labs/dayA2/`, `--task-definition awsdevops-cli-task:<PREVIOUS_REVISION>`. For the alarm it is another **full** `put-metric-alarm` restating every field, which only works *if you captured the alarm first* — without a capture, the settings you dropped are gone and this was bucket three wearing bucket one's clothes |
| **irreversible** | `delete-log-group`; `delete-repository --force`; `batch-delete-image` on the only copy of an image; `terminate-instances` | Stop. Say the command out loud. Confirm the account with `get-caller-identity`. Then decide whether you actually need it today |

The rule: **know your bucket before pressing enter.** And treat "which
bucket is this?" as a question with a checkable answer rather than a
feeling — you check it by naming the revert command. If you can name it,
you are in bucket one or two. If naming it produces "restore from
somewhere," you are in bucket three and you did not realize it.

Note what makes bucket two bucket two: **the previous state still exists
as an addressable object.** That is Day 1's PRODUCE thesis and Day 3's
REVERSE thesis arriving at the same place from the operator's side. A
task-definition revision is revertible because revision N-1 was never
deleted. An image tag moved over a mutable tag is not, because the thing
you would go back to no longer has a name.

### 6. Waiters

Waiters exist per service. The one you will use most in this path:

```bash
aws ecs wait services-stable \
  --cluster awsdevops-cli-cluster \
  --services awsdevops-cli-service
```

A waiter polls on a fixed interval up to a bounded number of attempts,
and then **exits non-zero**. Do not trust any specific interval or
attempt count from a document — including this one. Run:

```bash
aws ecs wait services-stable help
```

and read the numbers out of the CLI you actually have installed. Looking
it up is the habit; a memorized number is a bug waiting for a CLI upgrade.

Contrast the thing everyone writes once:

```bash
while sleep 5; do
  aws ecs describe-services --cluster awsdevops-cli-cluster \
    --services awsdevops-cli-service \
    --query 'services[0].deployments | length(@)' --output text
done
```

That loop has no timeout, no exit code that means anything, and a success
condition you invented. The non-zero exit on timeout is the entire reason
a waiter is safe to put in a script: under `set -e` it stops the script,
and in CI it fails the job. A hand-rolled loop that never converges just
runs until something else kills it, and everything after it in the script
runs against a service that never stabilized.

### 7. Did it actually happen?

A mutation's response reports that the API **accepted** the request. It
does not report that the system **converged**. Those are two different
events, separated by anywhere from milliseconds to minutes — an
`update-service` returns a full service object the instant the API
accepts it, describing a desired state that no running task has reached
yet. Reading `desiredCount: 3` out of that response and concluding three
tasks are running is a category error, and it is a common source of "but
the command succeeded."

So re-read the resource:

```bash
aws ecs describe-services \
  --cluster awsdevops-cli-cluster \
  --services awsdevops-cli-service \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' \
  --output json --no-cli-pager
```

`desired` is what you asked for. `running` is what is true. Only the
second one is evidence.

**Eventual consistency makes this structural, not just a timing quirk.**
IAM in particular is eventually consistent: a successful write may not be
visible to an immediately following read, or usable by an immediately
following call. Create a role and attach a policy, then immediately use
that role, and the failure you get is not a permissions bug — it is a
propagation delay wearing a permissions bug's error message. That
distinction has cost people entire afternoons of debugging a policy that
was correct the whole time. When an IAM-adjacent step fails immediately
after an IAM write, retry before you investigate.

### 8. Operating in an account you do not own

Doctrine, not drills. **No drill in this appendix mutates anything
outside your own personal account.** Everything in this section is for
the account you reach through IAM Identity Center at work, and you should
read it before you need it, not during.

**Read-only by default.** The default profile for a shared account should
be one that cannot change anything. Reaching for write access should be a
deliberate act with its own profile, and that profile should be *named*
so a mutating command in the wrong terminal looks obviously wrong on
sight — `company-prod-write` in your scrollback is a thing you notice;
`default` is not.

**Establish what you can do before finding out by accident.** IAM will
tell you, without you having to try:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/<YOUR_ROLE> \
  --action-names ecs:UpdateService \
  --resource-arns <TARGET_RESOURCE_ARN> \
  --no-cli-pager
```

It returns an `EvalDecision` per action: `allowed`, `implicitDeny`, or
`explicitDeny`. Note that the two deny values are diagnostically
different — `implicitDeny` means nothing granted it, `explicitDeny` means
something deliberately forbade it, and only the second tells you a human
made a decision about you.

**And the distinction that outranks all of the above:** what your IAM
policy *permits* is not what your team's change process *allows*, and
only one of those two is enforced by the API. `simulate-principal-policy`
returning `allowed` answers a technical question and no organizational
one. Having the permission to restart a production service at 4pm on a
Friday is not the same as it being your call to make, and the API will
never once ask you which it is. In a shared account, the check that
matters is the one nothing enforces.

### 9. The CLI/IaC boundary

This is the highest-transfer section on the page for anyone whose team
runs Terraform against ECS, and the mechanism is simple: **Terraform's
state file records what Terraform last applied, and a CLI mutation
changes reality without touching that file.** The two disagree
immediately, silently, and indefinitely.

`terraform plan` is the detector. It refreshes real resource state,
compares it to configuration, and reports the difference — a CLI change
shows up as a plan that proposes to change something back that nobody
asked to change. That plan output is the drift, and reading it is a
skill: the direction matters. Terraform proposing `desired_count: 3 -> 1`
is Terraform telling you it intends to *undo* your CLI change on the next
apply, which may be in five minutes or next quarter, in someone else's
pipeline, for an unrelated reason.

**The contrast between the two stacks in this repo is the lesson.**
`labs/dayA2/` deliberately omits `lifecycle { ignore_changes = [...] }`
on its ECS service, precisely so `terraform plan` will report the drift
your CLI mutation created — the drift-hunt cycle depends on seeing it.
The service in `labs/day03/ecs.tf` deliberately *includes*
`ignore_changes` on `task_definition`, `load_balancer`, and
`desired_count`, because there CodeDeploy legitimately owns those three
fields: it registers revisions and flips target groups as its normal
operation, and without the block every `terraform apply` would fight the
deployment controller. Same block, opposite verdicts, and the deciding
question is identical in both cases: **is there a system that legitimately
owns this field?** If yes, tell Terraform to stop watching it. If no, any
change outside Terraform is drift and should be visible as drift.

A defensible rule for when reaching past IaC is legitimate:

| Situation | Verdict |
|---|---|
| Incident response — the fix cannot wait for a plan, a review, and an apply | Legitimate. Do it, then open the PR that codifies it *the same day*, while you still remember the exact values |
| Investigation — reading, or a change you will revert within the hour and have captured state for | Legitimate. Revert it, then run `terraform plan` to prove you did |
| Genuinely out-of-band resources — things no Terraform stack manages | Legitimate, and unremarkable. There is no drift where there is no state |
| A small change that "isn't worth a PR" | Not legitimate. This is the one that becomes a drift problem nobody finds for a quarter, discovered when an unrelated apply reverts it during someone else's deploy |

The rule underneath all four rows: an out-of-band change is acceptable
when it is *temporary or codified*, and unacceptable when it is
*permanent and undocumented*. The half-life of "I'll put it in Terraform
later" is longer than your memory of what you changed.

### 10. Composing it

When these commands become a script, three things carry over:

- **`set -euo pipefail`** at the top. Without `-e`, a failed step is
  followed by every subsequent step running against a state nobody
  planned for — which is exactly the half-applied mess the break/fix
  below has you inspect.
- **Check exit codes, not output text.** Error messages get reworded
  between CLI releases; exit codes do not. This is the other half of why
  waiters matter (Core concept 6).
- **Prefer `--output json | jq` over `--output text | cut`.** `--output`
  accepts `json`, `text`, `table`, `yaml`, and `yaml-stream`; `text` is
  tab-separated with nested structures flattened, which is exactly why
  positional `cut`/`awk` against it is fragile — the column your field
  landed in is an artifact of the flattening, not a contract.

The worked example is already in this repo: `labs/verify-teardown.sh`.
Read it as a script, not just as a tool — it makes only read-only calls,
handles the empty-result case explicitly, and reports rather than assumes.

## Decision rules

| When you see... | Choose... | Because |
|---|---|---|
| A command whose revert you can write from memory right now | Run it — and capture state to a file anyway | The capture costs four seconds and is the only thing that keeps a **trivially reversible** change trivially reversible when your memory turns out to be of the value you *meant* to set |
| A command whose revert is "restore it from somewhere" | Stop, say the command out loud, and re-run `get-caller-identity` before anything else | That is the **irreversible** bucket, and the failure mode that actually happens is not a wrong command but a right command in the wrong account |
| `put-` at the front of an operation name | Restate every field the resource currently has, from a capture, not from memory | `put` replaces the whole object; anything you omit is dropped rather than preserved, and the response looks identical either way |
| An EC2 mutation you are not certain you are allowed to make | `--dry-run` first | It answers exactly one question — `DryRunOperation` versus `UnauthorizedOperation` — and that question is cheaper to answer before the change than during it |
| Doubt about whether a change is *correct*, not whether it is *permitted* | `--generate-cli-skeleton` into a file, and a second human reading the file | `--dry-run` has no opinion about correctness; a diffable file is the only review mechanism the CLI has |
| A script that must not proceed until an ECS service converges | `aws ecs wait services-stable`, with its exit code checked | It exits non-zero on timeout, which under `set -e` stops the script — a hand-rolled loop's success condition is one you invented and can be wrong |
| An interactive one-off check that a change landed | A fresh `describe-` read of the resource, comparing actual against desired | You need a value to look at, not a gate to pass; the waiter's answer is an exit code, and here you want the number |
| A retry loop around an operation that creates a new object each call | Check the operation's own `help` for a client request token; if there is none, make the retry safe yourself | Retrying `register-task-definition` gives you two revisions, not one — repeatable and idempotent are different properties |
| A Terraform-managed resource and a change that genuinely cannot wait for a review cycle | Make it by CLI, then open the PR that codifies it the same day | An out-of-band change is acceptable while it is temporary *or* codified; the drift nobody finds for a quarter is the one that was neither |
| A field some other system legitimately owns and rewrites as normal operation | `lifecycle { ignore_changes = [...] }`, as in `labs/day03/ecs.tf` | Terraform should stop watching a field it does not own — but only then, because everywhere else that block deletes the drift signal instead of the drift |

## Lab

See `labs/dayA2/`. **Goal:** five predict → execute → verify → revert
cycles against a stack you own outright — an ECR retag against tag
immutability, a scale to zero and back using a waiter, the
`put-metric-alarm` full-replace trap sprung and diffed, a task-definition
revision rolled back to its predecessor, and a drift hunt. **Success
signal:** every cycle reverted, and `terraform plan` clean at the end.

Cycle 1 is worth flagging in advance, because it is the one that fails on
purpose: a repository with `imageTagMutability = IMMUTABLE` **rejects** an
attempt to move an existing tag rather than silently overwriting it. The
drill has you read the exception name out of the real error and write it
down. Day 1 already named this one — `ImageTagAlreadyExistsException`
(`content/day01.md:211`, `labs/day01/README.md:95`) — so the drill is
asking you to *confirm* that the error you get says the same thing, not
to discover it. Confirming is the habit: Day 1 met this exception through
a failing `docker push` inside CodeBuild, and the ECR API surface you are
calling here is not that surface. Same rule, different door, and reading
the actual error rather than assuming is the same habit as running
`aws ecs wait services-stable help` instead of trusting a number.

"Clean" is the whole grade — a plan with anything in it means one of your
five reverts did not actually revert.

## Break it / Fix it

Two stages, both short, both about making an abstraction concrete:

**(a) Delete a lab log group and try to get the logs back.** Run
`aws logs delete-log-group --log-group-name /ecs/awsdevops-cli` and then
spend five honest minutes looking for a way to recover its contents. The
third bucket of the reversibility table stops being a word on a page the
moment you do this on something you actually wanted. Recreating the log
group is easy; that is not the same as getting anything back.

Then notice the second consequence, which is the real reason this drill
is here. The task definition in `labs/dayA2/main.tf` names that exact
group in its container definition's `awslogs-group` option, so the group
is not just a place logs went — it is a dependency of starting a task at
all. With it deleted, a subsequent task start fails on log-driver
initialization, and the error you get talks about logging, not about the
`delete-log-group` you ran twenty minutes ago. That stack sets no
`awslogs-create-group` option, so nothing recreates the group on your
behalf; the recovery is `terraform apply` in `labs/dayA2/`, which sees
the `aws_cloudwatch_log_group` missing and creates it again — empty.
**This is what bucket three actually feels like:** not "I lost some
logs," but "I lost some logs and broke something I did not know was
connected, and the failure surfaced somewhere else entirely."


**(b) Run a multi-step script whose credentials expire partway through,
and inspect the half-applied state.** This is the failure that makes
"check exit codes" a rule rather than a style preference: step 2 failed,
steps 3 through 6 ran anyway, and the resulting state matches neither the
before nor the after you designed. Walkthrough in
`labs/dayA2/README.md`.

## Exercises

1. Classify each of these five commands into **trivially reversible**,
   **reversible with effort**, or **irreversible**:
   (a) `aws ecs update-service --cluster awsdevops-cli-cluster --service awsdevops-cli-service --desired-count 0`;
   (b) `aws logs delete-log-group --log-group-name /ecs/awsdevops-cli`;
   (c) `aws ecs register-task-definition --cli-input-json file://td.json`
   against family `awsdevops-cli-task`;
   (d) `aws cloudwatch put-metric-alarm --alarm-name awsdevops-cli-cpu-high --threshold 90 ...`;
   (e) `aws ecr batch-delete-image --repository-name <REPO> --image-ids imageDigest=<DIGEST>`
   on the only copy of that image.

   **Hint:** For each one, try to write the exact revert command. If you
   can write it from memory, bucket one. If you can write it only after
   reading something first, bucket two. If writing it produces "restore
   from somewhere," bucket three.

   **Solution sketch:** (a) trivially reversible — set the count back;
   capture it first anyway so you know what it was. (b) irreversible —
   you can recreate an empty log group, which is not the same as
   recovering ingested log data. (c) reversible with effort — a new
   revision is additive and the old one is still addressable, so the
   "revert" is pointing the service back at `FAMILY:REVISION`; the
   orphaned revision itself lingers. (d) reversible with effort *only if
   you captured the alarm first* — this is `put` semantics, so the revert
   is another full `put-metric-alarm` restating everything, and without a
   capture you are reconstructing dropped fields from memory. (e)
   irreversible on the only copy — the digest is the artifact, and
   deleting it removes the thing Day 3's rollback would have needed to
   exist.

2. The alarm `awsdevops-cli-cpu-high` is defined with a description,
   `datapoints_to_alarm = 2`, and `treat_missing_data = "notBreaching"`.
   Someone runs `put-metric-alarm` restating only alarm name, namespace,
   metric name, statistic, period, evaluation periods, threshold,
   comparison operator, and dimensions. State exactly what is now
   different, and why nobody notices.

   **Hint:** Compare the field list in the command to the field list in
   `labs/dayA2/main.tf`. Anything in the second list and not the first is
   your answer.

   **Solution sketch:** The description, `datapoints_to_alarm`, and
   `treat_missing_data` are gone — `put-metric-alarm` fully replaces the
   alarm definition rather than patching it, so optional settings that
   were not restated are dropped, not preserved. Nobody notices because
   the command succeeds silently, the console still shows an alarm with
   the right name and the new threshold, and the two behavioral changes
   (`datapoints_to_alarm` reverting to matching `evaluation_periods`, and
   missing-data handling reverting to the default) only manifest during
   an incident — which is the moment you find out the alarm no longer
   behaves the way the runbook says it does.

3. Explain why a mutation's own response is not evidence that the change
   took effect, and name the command that is.

   **Hint:** Ask what the API is actually acknowledging when it returns
   200 — a request, or a world.

   **Solution sketch:** The response reports that the API **accepted the
   request**, not that the system **converged**; those are separate
   events anywhere from milliseconds to minutes apart. An
   `update-service` response echoes the *desired* state immediately,
   before any task has started or stopped. The evidence is a fresh
   `describe-services` read comparing `runningCount` against
   `desiredCount` — or better, `aws ecs wait services-stable`, which
   turns "converged" into an exit code instead of a judgment call.

4. Write the full pre-flight for scaling `awsdevops-cli-service` in
   cluster `awsdevops-cli-cluster` from 1 task to 3 — every command you
   run before the mutating one, and what each proves.

   **Hint:** Three questions, always in this order, and the third one
   writes a file.

   **Solution sketch:** (1) WHO: `aws sts get-caller-identity` — confirm
   the `Account` is your personal account and not the company one. (2)
   WHAT: `aws ecs describe-services --cluster awsdevops-cli-cluster
   --services awsdevops-cli-service --query 'services[0].serviceArn'
   --output text` — confirm the name resolved to the service you meant,
   in the region you meant. (3) STATE: redirect
   `aws ecs describe-services ... --query 'services[0]' --output json`
   to a timestamped file, so the revert value (`desiredCount: 1`) is
   recorded rather than remembered. Then name the revert command out
   loud — `--desired-count 1` — and only then run the forward one,
   following it with `aws ecs wait services-stable` and an after-capture
   to diff.

5. You run an EC2 mutation with `--dry-run` and get `DryRunOperation`.
   Your colleague reads this as "the change is safe to make." Correct
   them precisely: what did you learn, and what did you not?

   **Hint:** The flag lives in the authorization layer, not the
   simulation layer. Ask which of the two possible answers it can return.

   **Solution sketch:** `--dry-run` on EC2 is an authorization probe, not
   a simulation. `DryRunOperation` means the call would have been
   permitted; `UnauthorizedOperation` means it would not. That is the
   whole result. You have learned that IAM would not have stopped you.
   You have learned nothing about whether the parameters are correct,
   whether the target is the resource you meant, whether the change is
   reversible, or whether making it now is wise. Also worth telling the
   colleague: most services do not support the flag at all, so its
   absence is not a signal about a command's safety either.

6. A deploy script runs `update-service` and then needs to not proceed
   until the service is stable. Compare a waiter against a
   `while sleep 5; do describe-services; done` loop, and say where you
   would get the waiter's polling interval.

   **Hint:** Think about what each one does when the service *never*
   becomes stable, and what the next line of the script sees.

   **Solution sketch:** `aws ecs wait services-stable --cluster C
   --services S` polls on a fixed interval up to a bounded number of
   attempts and then exits non-zero — under `set -e` that stops the
   script, and in CI it fails the job. The hand-rolled loop has no
   timeout, no meaningful exit code, and a success condition you invented
   yourself; when the service never converges it runs forever, and if you
   add a `break` you have invented a success condition that can be wrong.
   The interval and attempt count come from `aws ecs wait
   services-stable help` on the CLI you actually have installed, never
   from a number quoted in a document — including this one.

7. A teammate fixed a production incident by running `aws ecs
   update-service --desired-count 6` against a Terraform-managed service,
   and said nothing. Three weeks later an unrelated `terraform apply`
   takes the service back to 2 during business hours. Explain the
   mechanism, and say when reaching past IaC would have been fine.

   **Hint:** Terraform state records what Terraform last applied, not
   what is true. What does `terraform plan` do with that gap, and who
   reads that plan three weeks later?

   **Solution sketch:** The CLI change altered reality without touching
   Terraform state, so the two disagreed from that moment on. Every
   `terraform plan` since has proposed `desired_count: 6 -> 2` — visible
   drift that nobody read, because nobody was looking for it in an
   unrelated plan. The apply then executed that proposal. The incident
   fix itself was legitimate; not codifying it was not. The correct
   sequence is: make the change, then open the PR that puts `6` in
   configuration the same day. Note the alternative that would have been
   *wrong* here: adding `lifecycle { ignore_changes = [desired_count] }`
   to silence the plan. That block is right in `labs/day03/ecs.tf`, where
   CodeDeploy legitimately owns the field, and wrong here, where no
   system owns it and the drift is real information.

8. In your company account, `simulate-principal-policy` returns
   `EvalDecision: allowed` for `ecs:UpdateService` on a production
   service. Should you run it? Justify the answer in one sentence.

   **Hint:** Two different systems can say no. Ask which of them the API
   consults.

   **Solution sketch:** No — or at least, not because of that result.
   `allowed` answers a technical question (IAM will not block the call)
   and no organizational one; what your IAM policy *permits* is not what
   your team's change process *allows*, and only the first of those is
   enforced by the API. The simulation is worth running for the opposite
   reason: to learn that you would be blocked *before* discovering it
   halfway through an incident, and to distinguish `implicitDeny`
   (nothing granted it — possibly an oversight worth asking about) from
   `explicitDeny` (someone decided you should not have this).

## Anti-patterns / Common mistakes

- **Trusting a mutation's own response as proof of convergence.** The
  response says the API accepted the request. It does not say the system
  reached the state. Re-read the resource, or use a waiter and check its
  exit code.
- **`put`-ing a partial object.** `put-metric-alarm` with a subset of the
  alarm's settings does not update those fields — it rewrites the alarm
  and drops everything you did not restate. Capture first, restate
  everything, diff after.
- **Hand-rolled polling instead of waiters.** A `while sleep 5` loop has
  no timeout, no meaningful exit status, and a success condition you
  invented. The non-zero exit on timeout is the entire reason a waiter
  belongs in a script and the loop does not.
- **Running a mutation in a terminal whose identity you have not checked
  this session.** Scrollback from an hour ago is not evidence of the
  current profile, and an SSO refresh or an exported environment variable
  can have changed it since. `get-caller-identity` costs nothing.
- **Using the CLI to fix IaC-managed infrastructure and not telling
  anyone.** The fix is often correct; the silence is what creates a drift
  problem nobody finds for a quarter, until an unrelated apply reverts it
  at the worst possible moment.
- **Assuming a permission you have in your personal account exists in the
  company one.** You are an account owner in one and a scoped role in the
  other. `simulate-principal-policy` answers this in advance; discovering
  it mid-incident does not.
- **Treating `--dry-run` as a preview of the change.** It is an
  authorization probe — `DryRunOperation` versus `UnauthorizedOperation`
  — and it has no opinion at all about whether your change is correct.
- **Capturing state after the mutation instead of before.** An
  `-after.json` with nothing to diff it against is a file, not a revert
  plan. The capture only has value if it precedes the change.

## Teardown

From `labs/dayA2/`:

```bash
terraform destroy
bash ../verify-teardown.sh
```

`labs/foundation/` **stays** — the VPC, subnets, and ECR repository are
shared by every lab in this path, and this stack only borrowed them.
Destroying the foundation is not part of this day's teardown.

Read the verify script's output rather than skimming it, and check two
things specifically: **no ECS service left at `desiredCount` > 0**, and
**no running Fargate task under the `awsdevops` prefix**. Those are the
two that keep billing. A clean `terraform destroy` exit proves Terraform
cleared what it knew about; the drift-hunt cycle is the day you proved
that is not the same as everything being gone.

If the break/fix left you with a half-applied script state, resolve it
before destroying — a resource Terraform does not know about is a
resource `destroy` will not remove, and it will still be there next
month.

## Self-check

1. Three weeks ago someone raised an alarm's threshold with a single
   `put-metric-alarm` command and changed nothing else. Last night a real
   incident ran for forty minutes before anyone was paged. Explain the
   causal chain between those two facts, and explain why nobody
   investigating the incident thought to look at the threshold change.
2. A deploy script runs `update-service --desired-count 3`, reads
   `desiredCount: 3` out of the response, and moves on to a step that
   assumes three tasks are serving traffic. Explain precisely why that
   assumption can be false, and explain what kind of claim a waiter makes
   that a re-read of the resource does not.
3. A teammate says `terraform plan` is noisy on your ECS service and
   proposes adding `lifecycle { ignore_changes = [desired_count] }` to
   quiet it. Explain the circumstance in which that is exactly right, the
   circumstance in which it destroys information you need, and the single
   question that tells the two apart.

If any of these is unanswerable without flipping back to a specific
section, that section is the one to re-read — 1 points back to Core
concept 4 and Exercise 2, 2 points back to Core concepts 6–7 and Exercise
3, and 3 points back to Core concept 9 and Exercise 7.
