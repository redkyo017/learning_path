# AWS CLI Mastery Appendix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-day, lab-backed AWS CLI appendix (Days A1 and A2) plus a standalone `CLI-MASTERY.md` reference to the existing `aws_devops_sre` path, so the learner can interrogate and safely operate AWS accounts from the terminal.

**Architecture:** Two content days on two spines — A1 *"every invocation is WHO / WHAT / WHAT CAME BACK / WHAT DID I SEE"*, A2 *"at the keyboard you are a pipeline stage: predict, observe, reverse."* A1's lab ships no Terraform and reuses `labs/foundation/` + `labs/day01/`. A2's lab adds one minimal ALB-less, NAT-less ECS stack whose deliberate lack of `ignore_changes` makes the Terraform-drift drill possible. A reference file at path root serves lookup, which the day files do not.

**Tech Stack:** Markdown content; Terraform >= 1.5 with `hashicorp/aws ~> 5.0`, local backend, `terraform_remote_state` against `../foundation/terraform.tfstate`; AWS CLI v2; bash/zsh.

**Spec:** `aws_devops_sre/docs/superpowers/specs/2026-09-10-aws-cli-appendix-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

- **All paths in this plan are relative to `aws_devops_sre/`.**
- **AWS CLI v2 only.** v2-specific behavior (auto-pagination default, `--cli-auto-prompt`, built-in pager, `aws configure sso`) is used freely. Never present a v1 idiom as current.
- **Shell is `zsh` on macOS.** Every `--query` argument must be quoted as a whole, because an unquoted `[?Name=='x']` is a glob in zsh and fails with `no matches found`. Prefer single quotes. When the JMESPath itself contains a single-quoted string literal, use DOUBLE quotes on the outside — `--query "Connections[?ConnectionName=='awsdevops-github']"` — exactly as `labs/day00/README.md` already does. Double quotes still suppress globbing; just never leave a bare backtick or `$` inside them.
- **Region default `us-east-1`.** `name_prefix` default `"awsdevops"`.
- **Day A2 resource names are `${var.name_prefix}-cli-*`**, never bare `${var.name_prefix}-*` — Day 3's stack already owns `awsdevops-cluster`, `awsdevops-service`, `awsdevops-task`, `awsdevops-ecs-execution`, `awsdevops-ecs-task`, and `/ecs/awsdevops`. IAM role names are account-global and ECS cluster names region-global, so a collision is a hard `terraform apply` failure if both stacks are up.
- **Zero NAT gateways. Zero load balancers. Zero EKS.** Path-wide, non-negotiable, inherited from `COST.md`.
- **No credentials, real account IDs, real ARNs, or real email addresses in any file.** Use `123456789012` for account IDs and `<YOUR_EMAIL>` / `<YOUR_GITHUB_USER>` style placeholders. Ship `*.tfvars.example`, never `*.tfvars`.
- **Every exercise ships a hint AND a solution sketch.** Non-negotiable, no exceptions.
- **Every lab directory ships `README.md`, `SOLUTION.md`, and `teardown.md`.**
- **No git commands in any subagent.** No `git status`, `git log`, `git diff`, `git add`, `git commit`.
- **No real infrastructure.** Never run `terraform apply/plan/destroy`, never call a live AWS API. `terraform fmt` and `terraform validate` are also forbidden (validate contacts the provider registry). Static checks only.
- **Voice.** Match the existing path: direct, opinionated, tables for comparisons, honest about tradeoffs, no marketing register, no "simply"/"just"/"easy". American English.
- **Cost claims** must use `COST.md`'s reference prices verbatim: arm64 Fargate 0.25 vCPU / 0.5 GB = **~$0.0099/h**; CodeBuild `ARM_SMALL` = **~$0.0034/build-min**; CloudWatch alarms **10 free**; CloudWatch Logs **~$0.50/GB ingested**.

## Pinned Facts

These are the load-bearing technical claims of the appendix. **Transcribe them; do not paraphrase them into something stronger, and do not invent adjacent facts.** If you believe one is wrong, say so in your completion report rather than silently changing it.

| # | Fact |
|---|---|
| F1 | AWS CLI credential precedence, documented order: (1) command-line options `--profile`/`--region`, (2) environment variables, (3) assume-role / web-identity from config, (4) IAM Identity Center (SSO), (5) `~/.aws/credentials`, (6) `~/.aws/config`, (7) container credentials, (8) EC2 instance metadata. Always pair this with "confirm locally with `aws configure list`" rather than asking the reader to trust the list. |
| F2 | Profile headers: `~/.aws/config` requires `[profile NAME]`; `~/.aws/credentials` requires `[NAME]` with **no** prefix; `[default]` takes no prefix in either file. |
| F3 | `aws configure list` prints Name / Value / Type / Location for each resolved setting — the **Type** and **Location** columns are the point, because they show *where* each value came from. |
| F4 | `aws sts get-caller-identity` returns `UserId`, `Account`, `Arn`. It is the ground truth for "who am I" and requires no permissions beyond being authenticated. |
| F5 | SSO: `aws configure sso` writes an `[sso-session NAME]` block plus a `[profile NAME]` block into `~/.aws/config`. `aws sso login --profile NAME` refreshes. Cached tokens live under `~/.aws/sso/cache/`. Expiry surfaces as a token-loading/refresh error, **not** as `AccessDenied`. |
| F6 | `--query` is **client-side** JMESPath, evaluated after the full response has been received. Server-side filtering is a different mechanism: `--filters` (EC2 and friends), `--filter`, or a service's own named parameters. |
| F7 | CLI v2 auto-paginates by default. `--page-size` sets the per-request API page size. `--max-items` is a **client-side** cap that emits a continuation token in the output. `--no-paginate` issues exactly one API call. |
| F8 | `--output` accepts `json`, `text`, `table`, `yaml`, `yaml-stream`. `text` is tab-separated with nested structures flattened, which is why positional `cut`/`awk` against it is fragile. |
| F9 | EC2's `--dry-run` is an **authorization probe, not a simulation**: `DryRunOperation` means the call would have been permitted, `UnauthorizedOperation` means it would not. It says nothing about whether the change is correct or wise. Most services do not support it. |
| F10 | `--generate-cli-skeleton` emits the input shape for an operation; `--cli-input-json file://input.json` consumes it. Available across services. |
| F11 | `--cli-auto-prompt` / `--no-cli-auto-prompt` (config key `cli_auto_prompt`) controls v2's interactive parameter prompting. |
| F12 | CLI v2 sends output through a pager by default; `--no-cli-pager` (or setting `cli_pager` to empty) disables it. Required in anything non-interactive. |
| F13 | "Nothing came back" has **three** distinct causes, not two, and conflating them is a real diagnostic error. (a) `list-*` returns an **empty array** at exit 0. (b) Some `describe-*` operations **raise a service exception** when the named resource does not exist — ECR's `RepositoryNotFoundException` is the clean example. (c) **ECS's batch describes do neither.** `describe-clusters`, `describe-services`, and `describe-tasks` return **exit 0** with the found items in the main array and a parallel **`failures[]`** array carrying `{arn, reason: "MISSING"}` for every identifier that was not found — so `aws ecs describe-clusters --clusters nope` yields `{"clusters": [], "failures": [...]}`, not an error. `ClusterNotFoundException` IS raised, but by operations whose `--cluster` *parameter* names a cluster that does not exist (`describe-services`, `list-services`, `list-tasks`) — never by `describe-clusters --clusters`. The consequence to teach: on an ECS batch describe, an empty main array is **not** evidence of absence, and a command that exits 0 can still have found nothing. Always check `failures[]`. |
| F14 | `put-metric-alarm` **fully replaces** the alarm definition. Optional settings you do not restate are dropped, not preserved. This is `put` semantics, not `patch` semantics. |
| F15 | Waiters exist per service, e.g. `aws ecs wait services-stable --cluster C --services S`. A waiter polls on a fixed interval up to a bounded number of attempts and then **exits non-zero**. Do not assert specific interval/attempt numbers — instruct the reader to check `aws ecs wait services-stable help`. |
| F16 | `aws iam simulate-principal-policy --policy-source-arn ARN --action-names ACTION --resource-arns ARN` returns an `EvalDecision` per action: `allowed`, `implicitDeny`, or `explicitDeny`. |
| F17 | An ECR repository with `imageTagMutability = IMMUTABLE` **rejects** an attempt to move an existing tag rather than silently overwriting it. The exception is `ImageTagAlreadyExistsException` — **already established by this path** at `content/day01.md:211,274` and `labs/day01/README.md:95`, so do not withhold it as though unknown; a learner who did Day 1 has already seen it. Do not assert it as a *new* fact of your own either: reference what Day 1 established. The A2 drill still has the learner read the name out of the real error and confirm it — the habit of confirming is the point, not the pretence of ignorance. |
| F18 | IAM is eventually consistent: a successful write may not be visible to an immediately following read, or usable by an immediately following call. |
| F19 | In `zsh`, an unquoted bracket expression such as `[?Name=='x']` is a glob pattern and fails with `zsh: no matches found`. Single-quote the entire `--query` argument. |
| F20 | Rolling back an ECS task definition is `aws ecs update-service --cluster C --service S --task-definition FAMILY:REVISION` — the previous revision still exists and is addressable. |

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `labs/dayA2/main.tf` | The one new stack: ECS cluster, log group, two IAM roles, task definition, service, security group, CloudWatch alarm. No ALB, no NAT, **no `ignore_changes`**. | 1 |
| `labs/dayA2/variables.tf` | `aws_region`, `name_prefix`, `image_tag` (no default). | 1 |
| `labs/dayA2/outputs.tf` | Names the CLI drills need: cluster, service, task family, alarm, log group. | 1 |
| `labs/dayA2/terraform.tfvars.example` | Placeholder `image_tag` with a fill-in comment. | 1 |
| `content/dayA1.md` | INTERROGATE: the four-part model, identity, operations, responses, projections, error families. | 2 |
| `content/dayA2.md` | OPERATE: pre-flight triad, tooling of care, idempotency, reversibility taxonomy, waiters, convergence, other-people's-accounts, IaC boundary, light scripting. | 3 |
| `labs/dayA1/README.md` | The graded drill set (console forbidden), against `foundation/` + `day01/`. | 4 |
| `labs/dayA1/SOLUTION.md` | Worked commands and expected output shapes for every drill. | 4 |
| `labs/dayA1/teardown.md` | Reuses existing stacks; states what to leave standing and why. | 4 |
| `labs/dayA2/README.md` | The five predict→execute→verify→revert cycles plus break-it. | 5 |
| `labs/dayA2/SOLUTION.md` | Worked commands, expected outputs, revert commands. | 5 |
| `labs/dayA2/teardown.md` | `terraform destroy` + `verify-teardown.sh`, with the specific leak risks named. | 5 |
| `CLI-MASTERY.md` | Lookup reference: identity triage, JMESPath recipes, per-service one-liners, reversibility table, error decoder. | 6 |
| `README.md` | Appendix section, day-index rows, prerequisite note. | 7 |
| `COST.md` | Two per-lab rows, the dayA2 stack, revised week total. | 7 |
| `STRATEGY.md` | One row in the traps table. | 7 |
| `content/GLOSSARY.md` | Seven new terms, alphabetically placed. | 7 |
| `labs/verify-teardown.sh` | **Unchanged** — verified in scope, not edited. | 7 |

## Execution Waves

- **Wave 1 (parallel):** Task 1, Task 2, Task 3
- **Wave 2 (parallel, after Wave 1):** Task 4, Task 5, Task 6
- **Wave 3:** Task 7

---

### Task 1: Day A2 Terraform stack

**Files:**
- Create: `labs/dayA2/main.tf`
- Create: `labs/dayA2/variables.tf`
- Create: `labs/dayA2/outputs.tf`
- Create: `labs/dayA2/terraform.tfvars.example`

**Interfaces:**
- Consumes: `labs/foundation/` outputs `vpc_id`, `public_subnet_ids`, `ecr_repository_url` via `data.terraform_remote_state.foundation` with `backend = "local"`, `config = { path = "../foundation/terraform.tfstate" }`.
- Produces, relied on by Tasks 3, 5, 6, 7 — **these exact strings**:
  - ECS cluster name: `awsdevops-cli-cluster`
  - ECS service name: `awsdevops-cli-service`
  - Task definition family: `awsdevops-cli-task`
  - Container name: `awsdevops-cli-app`
  - CloudWatch log group: `/ecs/awsdevops-cli`
  - CloudWatch alarm name: `awsdevops-cli-cpu-high`
  - Security group name: `awsdevops-cli-tasks`
  - IAM roles: `awsdevops-cli-ecs-execution`, `awsdevops-cli-ecs-task`
  - Terraform outputs: `cluster_name`, `service_name`, `task_family`, `alarm_name`, `log_group_name`

- [ ] **Step 1: Write `variables.tf`**

Copy Day 3's shape exactly (`labs/day03/variables.tf`), with `image_tag` keeping no default:

```hcl
variable "aws_region" {
  description = "AWS region for all resources in this stack."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to every resource name in this stack."
  type        = string
  default     = "awsdevops"
}

variable "image_tag" {
  description = <<-EOT
    Image tag to run — the git short-SHA tag Day 1's CodeBuild pushed to
    ECR. Deliberately has NO default.

    Find it with the CLI rather than the console, which is the point of
    this appendix:

      aws ecr describe-images \
        --repository-name awsdevops-sample \
        --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
        --output text
  EOT
  type        = string
}
```

- [ ] **Step 2: Write `main.tf`**

Header comment must state: this is the AWS CLI appendix stack; it is deliberately ALB-less and NAT-less; cost is ~$0.0099/h for one arm64 Fargate task; and — the load-bearing one — **it deliberately omits `lifecycle { ignore_changes = ... }` on the service, unlike `labs/day03/ecs.tf`, because Day A2's drift-hunt drill needs `terraform plan` to actually report the drift a CLI mutation causes.**

Structure, mirroring `labs/day03/ecs.tf` idiom (`terraform` block with `required_version = ">= 1.5"` and `aws ~> 5.0`; `provider "aws"` with the same `default_tags` of `Project`/`ManagedBy`/`Path`; `data "terraform_remote_state" "foundation"`), then:

```hcl
resource "aws_security_group" "tasks" {
  name        = "${var.name_prefix}-cli-tasks"
  description = "Egress-only SG for the CLI appendix task."
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id

  # No ingress rules at all. Nothing routes traffic to this task — there is
  # no ALB in this stack. The task only needs to reach OUT, to pull its
  # image from ECR and ship logs to CloudWatch.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-cli-tasks" }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cli-cluster"
  tags = { Name = "${var.name_prefix}-cli-cluster" }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}-cli"
  retention_in_days = 1
  tags              = { Name = "${var.name_prefix}-cli-ecs-logs" }
}
```

Then `aws_iam_role.execution` (`${var.name_prefix}-cli-ecs-execution`) with the `ecs-tasks.amazonaws.com` assume-role policy and the `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy` attachment, and `aws_iam_role.task` (`${var.name_prefix}-cli-ecs-task`) with the same trust policy and no attachments — both copied in shape from `labs/day03/ecs.tf`.

Then the task definition:

```hcl
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-cli-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "${var.name_prefix}-cli-app"
      image     = "${data.terraform_remote_state.foundation.outputs.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [{ containerPort = 8080, protocol = "tcp" }]

      environment = [
        { name = "POISON", value = "false" },
        { name = "BURN_RATE", value = "0" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "${var.name_prefix}-cli-task" }
}
```

Then the service — note the absent `load_balancer` block, the default (rolling) deployment controller, and the absent `lifecycle` block, each with a comment saying why:

```hcl
resource "aws_ecs_service" "this" {
  name            = "${var.name_prefix}-cli-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # No deployment_controller block: this service uses the default ECS
  # rolling-update controller, NOT the CODE_DEPLOY controller Day 3 used.
  # Day 3 was about a controlled blue/green promotion. This stack exists to
  # be poked at with `aws ecs update-service` by hand, and the rolling
  # controller is what makes that a one-command operation.

  # No load_balancer block, and no ALB anywhere in this stack: none of this
  # day's drills route traffic. Adding one would cost ~$0.0225/h to teach
  # nothing this day teaches.

  network_configuration {
    subnets          = data.terraform_remote_state.foundation.outputs.public_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  # DELIBERATELY no `lifecycle { ignore_changes = [...] }`, unlike
  # labs/day03/ecs.tf. Day 3 ignored task_definition/desired_count because
  # CodeDeploy legitimately owns them there. Here, a CLI change to either
  # field IS drift, and Day A2's drift-hunt drill depends on
  # `terraform plan` saying so out loud. Adding ignore_changes here would
  # silently delete the lesson.

  tags = { Name = "${var.name_prefix}-cli-service" }
}
```

Finally the alarm, deliberately carrying several optional settings so the `put-metric-alarm` full-replace trap (F14) has something to destroy:

```hcl
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name_prefix}-cli-cpu-high"
  alarm_description   = "CLI appendix drill alarm. Day A2 mutates and reverts this."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }

  # alarm_description, datapoints_to_alarm, and treat_missing_data are here
  # on purpose. Day A2 asks you to change ONLY the threshold with
  # `aws cloudwatch put-metric-alarm` and then diff the alarm against the
  # copy you captured first. put-metric-alarm replaces the whole alarm, so
  # these three are exactly what a careless one-line change silently drops.

  tags = { Name = "${var.name_prefix}-cli-cpu-high" }
}
```

- [ ] **Step 3: Write `outputs.tf`**

```hcl
output "cluster_name" {
  description = "Pass to --cluster in every ECS CLI drill on Day A2."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Pass to --services / --service in every ECS CLI drill on Day A2."
  value       = aws_ecs_service.this.name
}

output "task_family" {
  description = "Task definition family. Revisions are addressed as FAMILY:N."
  value       = aws_ecs_task_definition.this.family
}

output "alarm_name" {
  description = "The alarm Day A2's put-metric-alarm drill mutates and reverts."
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "log_group_name" {
  description = "Deleted on purpose in Day A2's break-it step. It does not come back."
  value       = aws_cloudwatch_log_group.ecs.name
}
```

- [ ] **Step 4: Write `terraform.tfvars.example`**

```hcl
# Copy to terraform.tfvars and fill in.
#
# image_tag is the git short-SHA tag Day 1's CodeBuild pushed to ECR.
# Find it with the CLI (the console is not the point of this appendix):
#
#   aws ecr describe-images \
#     --repository-name awsdevops-sample \
#     --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
#     --output text
#
image_tag = "REPLACE_WITH_YOUR_IMAGE_TAG"
```

- [ ] **Step 5: Verify — the naming contract holds**

Run from `aws_devops_sre/`:

```bash
for n in cli-cluster cli-service cli-task cli-app cli-tasks cli-ecs-execution cli-ecs-task cli-cpu-high; do
  grep -q -- "$n" labs/dayA2/main.tf || echo "MISSING NAME: $n"
done
grep -q '/ecs/${var.name_prefix}-cli' labs/dayA2/main.tf || echo "MISSING: log group name"
```

Expected: no output.

- [ ] **Step 6: Verify — the forbidden resources are absent and the deliberate omissions are commented**

```bash
grep -nE 'aws_lb|aws_nat_gateway|aws_lb_target_group|load_balancer|ignore_changes|deployment_controller' labs/dayA2/*.tf \
  | grep -vE ':[0-9]+: *#' && echo "FAIL: forbidden resource on a non-comment line"
```

Expected: no output and no FAIL line. The trailing filter drops comment lines (`file:NN:   # ...`), which is what makes this mechanical rather than a judgement call — the stack's comments legitimately name every one of these to explain why it is absent. This check greps every `.tf` in the directory, not just `main.tf`, because the rule it enforces is about the whole stack.

- [ ] **Step 7: Verify — no secrets, and syntax parses**

```bash
grep -rnE '[0-9]{12}|AKIA|arn:aws:iam::[0-9]{12}' labs/dayA2/ | grep -v '123456789012'
```

Expected: no output.

```bash
python3 - <<'PY'
import re,glob,sys
bad=0
for f in glob.glob('labs/dayA2/*.tf')+glob.glob('labs/dayA2/*.example'):
    s=open(f).read()
    if s.count('{')!=s.count('}'):
        print('UNBALANCED BRACES:',f); bad=1
    if s.count('"')%2:
        print('ODD QUOTE COUNT:',f); bad=1
sys.exit(bad)
PY
```

Expected: exit 0, no output. (`terraform validate` is forbidden — it contacts the provider registry.)

- [ ] **Step 8: Report**

Report the five output names and eight resource names you created, verbatim, so Tasks 3, 5, and 6 can be checked against them.

---

### Task 2: `content/dayA1.md` — INTERROGATE

**Files:**
- Create: `content/dayA1.md`
- Read first (for voice and structure, do not modify): `content/day01.md`, `content/day03.md`

**Interfaces:**
- Consumes: Pinned Facts F1–F13, F16, F19.
- Produces: section numbering and terminology that `labs/dayA1/README.md` (Task 4) and `CLI-MASTERY.md` (Task 6) cite. Use exactly these four labels throughout: **WHO**, **WHAT**, **WHAT CAME BACK**, **WHAT DID I SEE**.

- [ ] **Step 1: Read two existing day files for voice**

Read `content/day01.md` and `content/day03.md` end to end before writing. Match their register, table usage, and section rhythm. Do not modify them.

- [ ] **Step 2: Write the file**

Header block, exactly this shape:

```markdown
# Day A1 — INTERROGATE: what is actually there?

**Appendix:** AWS CLI mastery (depends on Days 1–3)
**Time:** ~3.4h (content ~70m · lab ~110m · break/fix ~20m · teardown ~5m)
**Cost if you follow teardown:** ~$0.02
```

Then, in order:

`## Why this matters` — one paragraph. Make the concrete point: this path has handed you roughly 46 distinct command shapes across five days with the arguments already filled in, and you have not yet written one of your own. State the target plainly — turn an English question about an account into the command that answers it.

`## The question of the day` — bold, one line: **What is actually there, and how do I know the answer isn't lying to me?**

`## Core concepts` with these numbered subsections:

1. **Every invocation is four things.** The WHO / WHAT / WHAT CAME BACK / WHAT DID I SEE table from the spec, then the diagnostic payoff: "the command returned nothing" and "access denied" are each two different bugs, and the four-way split tells you which one you have before you start guessing.
2. **WHO — identity resolution.** F1 (precedence, with the `aws configure list` caveat), F2 (the profile-header prefix rule, called out as a top cause of "my profile isn't being picked up"), F3, F4. Region as a **separate** chain with its own precedence — "no region" and "wrong region" are different bugs and the second is worse, because it succeeds. Then two subsections: **SSO** (F5, framed as the company-account path) and **long-lived keys** (framed as the personal-account path, with an explicit callback to the `STRATEGY.md` trap "Long-lived IAM access keys in CI" now aimed at the reader's own laptop).
3. **WHAT — the operation.** The CLI is generated from service models, which is why `aws ecs describe-services help` outranks a blog post. F10 as a shape-discovery tool. The `list-` / `describe-` / `get-` heuristic — identifiers and summaries / full objects / a single object — and that the argument to a `describe-` usually comes out of a `list-`.
4. **WHAT CAME BACK — the response.** F6 developed properly, in a table contrasting server-side and client-side with the three consequences of confusing them: no reduction in API calls or throttling, no reduction in transfer, and silently wrong answers when combined with pagination limits. Then F7, and the truncation trap stated explicitly: `--max-items` plus `--query` filters what was already cut off.
5. **WHAT DID I SEE — the projection.** JMESPath worth memorizing: projections, `[?Field=='value']`, `[a,b]`, `{Name:name,Id:id}`, `length`, `sort_by`, `join`, `contains`, `starts_with`, pipe expressions, `[]` flattening. Every example single-quoted, with F19 stated as its own short callout since the reader is on zsh. Then F8, and precisely when `text` is a trap. Then F12.
6. **Reading errors as a decision tree.** Four families as a table — column headers: Family · What it looks like · What it rules out · Next command. Client-side validation (never left the machine, so stop checking permissions); authorization (F16 belongs here — the identity resolved fine, so stop re-checking your profile); credential and expiry (F5 — `ExpiredToken` vs a wrong key); and F13, not-found versus empty, with the consequence spelled out: "no output" means something different depending on which verb you used. Close with `--debug` and the three things worth grepping out of its noise.

`## Lab` — three lines: `See labs/dayA1/.` The goal: answer a graded question set about infrastructure you built yourself, by CLI only, console forbidden. Success signal: every drill answered with a command you could reconstruct tomorrow.

`## Exercises` — **eight** exercises, each a single line of the form `N. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>`. These are paper exercises distinct from the lab drills: reading a given error and naming its family; predicting which identity a given `~/.aws/config` + environment resolves to; writing a JMESPath expression for a stated question; explaining why a given `--query` + `--max-items` combination returns a wrong answer; and so on. Every one ships a hint and a solution sketch.

`## Anti-patterns / Common mistakes` — at least five bullets: believing `--query` reduces API load; parsing `--output text` positionally in a script; `grep`-ing JSON instead of querying it; reaching for the console the moment output looks unfamiliar; reading an empty result as proof a resource is gone.

`## Teardown` — this day creates nothing. State that plainly: leave `labs/foundation/` standing (it is meant to survive the week), and destroy `labs/day01/` per its own `teardown.md` if you re-applied it. Then run `labs/verify-teardown.sh`.

- [ ] **Step 3: Verify — structure**

```bash
for h in '^# Day A1 —' '^## Why this matters' '^## The question of the day' '^## Core concepts' '^## Lab' '^## Exercises' '^## Anti-patterns / Common mistakes' '^## Teardown'; do
  grep -qE "$h" content/dayA1.md || echo "MISSING SECTION: $h"
done
```

Expected: no output.

- [ ] **Step 4: Verify — every exercise has a hint and a solution sketch**

```bash
n=$(sed -n '/^## Exercises/,/^## Anti-patterns/p' content/dayA1.md | grep -cE '^[0-9]+\. ')
h=$(sed -n '/^## Exercises/,/^## Anti-patterns/p' content/dayA1.md | grep -cE '\*\*Hint:\*\*')
s=$(sed -n '/^## Exercises/,/^## Anti-patterns/p' content/dayA1.md | grep -cE '\*\*Solution sketch:\*\*')
echo "exercises=$n hints=$h solutions=$s"
[ "$n" -ge 8 ] && [ "$n" = "$h" ] && [ "$n" = "$s" ] || echo "FAIL: counts must be equal and >= 8"
```

Expected: `exercises=8 hints=8 solutions=8` (or higher, all equal), and no FAIL line.

- [ ] **Step 5: Verify — zsh-safe quoting on every `--query`**

```bash
grep -n -- '--query' content/dayA1.md | grep -v "query '" | grep -v 'query "' | grep -vF 'query \' || echo "OK: all --query args single-quoted"
```

Expected: `OK: ...`. Any listed line is a `--query` whose argument is not single-quoted — fix it. (This greps for the distinctive fragment `--query '`, not for a full command line the file may never spell out on one line.)

- [ ] **Step 6: Verify — no secrets anywhere in the file**

```bash
grep -nE '[0-9]{12}|AKIA[0-9A-Z]{16}|aws_secret_access_key *=' content/dayA1.md | grep -v '123456789012'
```

Expected: no output.

- [ ] **Step 7: Report**

Report the exercise count and list your six `## Core concepts` subsection headings verbatim, so Task 6 can cite them.

---

### Task 3: `content/dayA2.md` — OPERATE

**Files:**
- Create: `content/dayA2.md`
- Read first (do not modify): `content/day03.md` (the REVERSE day this one descends from), `content/dayA1.md` if it exists yet — if it does not, rely on the four labels named below.

**Interfaces:**
- Consumes: Pinned Facts F9, F10, F11, F12, F14, F15, F16, F17, F18, F20. Day A1's four labels (**WHO / WHAT / WHAT CAME BACK / WHAT DID I SEE**) may be referenced by name. Task 1's resource names: cluster `awsdevops-cli-cluster`, service `awsdevops-cli-service`, family `awsdevops-cli-task`, alarm `awsdevops-cli-cpu-high`, log group `/ecs/awsdevops-cli`.
- Produces: the **reversibility taxonomy table** (three buckets: *trivially reversible* / *reversible with effort* / *irreversible*) which Task 5 and Task 6 both reproduce. Use exactly those three bucket names.

- [ ] **Step 1: Write the file**

Header block:

```markdown
# Day A2 — OPERATE: changing things you can undo

**Appendix:** AWS CLI mastery (depends on Days 1–3 and Day A1)
**Time:** ~3.5h (content ~65m · lab ~115m · break/fix ~20m · teardown ~10m)
**Cost if you follow teardown:** ~$0.03
```

`## Why this matters` — one paragraph landing the spine: a human typing a mutating command into a terminal is a promotion stage with no code review, no artifact, no approval gate, and no automatic rollback. Day 3 taught you to ask of every stage *what does it prove, and is it reversible?* — those questions get harder here, not easier.

`## The question of the day` — bold, one line: **Do I know what this command will change, and can I get back?**

`## Core concepts`, numbered:

1. **You are a pipeline stage.** Predict / Observe / Reverse, tied explicitly back to Day 3's REVERSE link.
2. **The pre-flight triad.** Who am I (verified, not assumed) · what will this touch (the resolved target, read back) · what is the current state (captured to a file, because a revert you cannot perform is not a plan). Show the capture idiom concretely, e.g. redirecting a `describe-` to a timestamped JSON file before the mutation.
3. **The tooling of care.** F9 — and lead with the correction, because `--dry-run` is usually mistaught as "preview my change." F10 as the way to make a change reviewable by a human first. F11. F12.
4. **Idempotency, and why `put-` is not `patch`.** F14, developed as the most consequential item on the page: `put-metric-alarm` with a subset of settings rewrites the alarm and drops what you did not restate. Name the drill that springs it (`labs/dayA2/`, cycle 3). Then which operations are naturally repeatable versus not, and client request tokens where an API offers one.
5. **The reversibility taxonomy.** The three-bucket table — Bucket · Examples · What it demands of you — using the bucket names fixed in the Interfaces block. Irreversible examples must include `delete-log-group`, `delete-repository --force`, and `batch-delete-image` on the only copy. State the rule: know your bucket **before** pressing enter, and treat "which bucket is this?" as a question with a checkable answer.
6. **Waiters.** F15 — including the instruction to check `aws ecs wait services-stable help` for the exact interval and attempt count rather than trusting a number from a document. Contrast with the hand-rolled `while sleep 5` loop, and make the point that a non-zero exit is what makes a waiter safe to put in a script.
7. **Did it actually happen?** A mutation's response reports that the API *accepted* the request, not that the system *converged* — two events separated by anywhere from milliseconds to minutes. Re-read the resource. F18, with IAM as the canonical example.
8. **Operating in an account you do not own.** Doctrine, not drills. Read-only by default, with a profile named so a mutating command in the wrong terminal looks obviously wrong. F16 to establish what you can do before finding out by accident. Then the distinction that outranks the rest: what your IAM policy *permits* is not what your team's change process *allows*, and only one of those two is enforced by the API. State plainly that no drill in this appendix mutates anything outside the reader's personal account.
9. **The CLI/IaC boundary.** What a CLI mutation does to Terraform state; `terraform plan` as the detector; and a defensible rule for when reaching past IaC is legitimate (incident response, investigation, genuinely out-of-band resources) versus when it starts a drift problem nobody finds for a quarter. Note explicitly that `labs/dayA2/` omits `ignore_changes` on purpose so `terraform plan` will actually report the drift — and that `labs/day03/` includes it on purpose because CodeDeploy legitimately owns those fields there. The contrast is the lesson.
10. **Composing it.** Short. `set -euo pipefail`, check exit codes rather than output text, prefer `--output json | jq` over `--output text | cut` (F8), and point at `labs/verify-teardown.sh` as the worked example already in this repo.

`## Lab` — `See labs/dayA2/.` The goal: five predict→execute→verify→revert cycles against a stack you own. Success signal: every cycle reverted, and `terraform plan` clean at the end.

`## Exercises` — **eight**, same one-line format with hint and solution sketch. Include at minimum: classify five given commands into the three buckets; state what a given partial `put-metric-alarm` silently drops; explain why a mutation's own response is not evidence of convergence; write the pre-flight for a given change.

`## Anti-patterns / Common mistakes` — at least six bullets, drawn from the spec's list.

`## Teardown` — `terraform destroy` in `labs/dayA2/`, then `labs/verify-teardown.sh`. State that `labs/foundation/` stays. Name the specific thing to check: no ECS service left at desiredCount > 0 and no running Fargate task under the `awsdevops` prefix.

- [ ] **Step 2: Verify — structure**

```bash
for h in '^# Day A2 —' '^## Why this matters' '^## The question of the day' '^## Core concepts' '^## Lab' '^## Exercises' '^## Anti-patterns / Common mistakes' '^## Teardown'; do
  grep -qE "$h" content/dayA2.md || echo "MISSING SECTION: $h"
done
```

Expected: no output.

- [ ] **Step 3: Verify — exercises carry hints and solutions**

```bash
n=$(sed -n '/^## Exercises/,/^## Anti-patterns/p' content/dayA2.md | grep -cE '^[0-9]+\. ')
h=$(sed -n '/^## Exercises/,/^## Anti-patterns/p' content/dayA2.md | grep -cE '\*\*Hint:\*\*')
s=$(sed -n '/^## Exercises/,/^## Anti-patterns/p' content/dayA2.md | grep -cE '\*\*Solution sketch:\*\*')
echo "exercises=$n hints=$h solutions=$s"
[ "$n" -ge 8 ] && [ "$n" = "$h" ] && [ "$n" = "$s" ] || echo "FAIL"
```

Expected: equal counts, >= 8, no FAIL.

- [ ] **Step 4: Verify — the taxonomy and the load-bearing facts are present**

```bash
for s in 'trivially reversible' 'reversible with effort' 'irreversible' 'delete-log-group' 'delete-repository' 'batch-delete-image' 'put-metric-alarm' 'DryRunOperation' 'UnauthorizedOperation' 'services-stable' 'simulate-principal-policy' 'ignore_changes'; do
  grep -qi -- "$s" content/dayA2.md || echo "MISSING: $s"
done
```

Expected: no output.

- [ ] **Step 5: Verify — resource names match Task 1 exactly**

```bash
for s in awsdevops-cli-cluster awsdevops-cli-service awsdevops-cli-task awsdevops-cli-cpu-high; do
  grep -q -- "$s" content/dayA2.md || echo "MISSING NAME: $s"
done
grep -nE 'awsdevops-(cluster|service|task)\b' content/dayA2.md && echo "FAIL: used a Day 3 resource name"
```

Expected: no output, and no FAIL line.

- [ ] **Step 6: Verify — no secrets**

```bash
grep -nE '[0-9]{12}|AKIA[0-9A-Z]{16}' content/dayA2.md | grep -v '123456789012'
```

Expected: no output.

- [ ] **Step 7: Report**

Report the exercise count and the three bucket names verbatim, so Tasks 5 and 6 reproduce them exactly.

---

### Task 4: `labs/dayA1/` — the interrogation drill set

**Files:**
- Create: `labs/dayA1/README.md`
- Create: `labs/dayA1/SOLUTION.md`
- Create: `labs/dayA1/teardown.md`
- Read first (do not modify): `content/dayA1.md`, `labs/day01/README.md`, `labs/day01/SOLUTION.md`, `labs/foundation/outputs.tf`

**Interfaces:**
- Consumes: foundation outputs `vpc_id`, `public_subnet_ids`, `ecr_repository_url`, `ecr_repository_name`, `ecr_repository_arn`; the ECR repository is named `awsdevops-sample`; Day 1's CodeBuild project and its IAM role. Day A1's four labels.
- Produces: drill numbering `D1`–`D12`, cited by `SOLUTION.md` and reusable by `CLI-MASTERY.md`.

- [ ] **Step 1: Write `README.md`**

Open with the standing rule in bold: **the console is forbidden for the duration of this lab.** Then prerequisites — `labs/foundation/` applied, `labs/day01/` applied, at least one successful build so ECR holds an image.

Then **twelve drills, `D1`–`D12`**, in four ascending groups of three, each drill stated as an English question followed by a **Hint:** line. No answers here — they live in `SOLUTION.md`.

- **D1–D3 — WHO.** Which identity and region will an un-flagged command use, and prove it. Which file did each resolved value come from. What is the account number, without opening the console.
- **D4–D6 — single calls.** Which images does the repository hold. What is the digest behind a given tag. Which subnets does the VPC have.
- **D7–D9 — projections.** List images as a two-column table of tag and push time, newest first. Show only subnets that auto-assign public IPs, as tag/CIDR pairs. Count the CodeBuild builds that failed.
- **D10–D12 — chains and proofs.** Establish, with `simulate-principal-policy` rather than by reading the policy hopefully, whether the Day 1 CodeBuild role can `ecr:PutImage` to the repository. Reconstruct commit → build → image → digest in one composed command. Prove a named resource is genuinely absent, and state which verb you used and why that matters (F13).

Then `## Break it / Fix it`, four sub-steps, each stating the failure to induce and instructing the reader to **name the error family before reading the fix**: (1) unset `AWS_DEFAULT_REGION` and clear any profile region; (2) point at a profile that does not exist; (3) write a profile into `~/.aws/config` with a `[NAME]` header instead of `[profile NAME]` and watch it be ignored; (4) let an SSO token expire (or corrupt the cached token) and read the error. Then the pagination lesson: run a `list-`/`describe-` with `--max-items` small plus a `--query` filter over a list long enough to be truncated, get a confident wrong answer, and then get the right one.

Close with `## Success signal` and a pointer to `teardown.md`.

- [ ] **Step 2: Write `SOLUTION.md`**

One section per drill `D1`–`D12`, each with: the worked command (single-quoted `--query`, F19), the **shape** of the expected output (never invented real values — use `123456789012`, `sha256:<64 hex>`-style placeholders, `vpc-0abc...`), and one or two sentences on *why that command* rather than an alternative. Then a section for each Break-it step giving the error family and the fix.

- [ ] **Step 3: Write `teardown.md`**

State that this lab creates nothing. Leave `labs/foundation/` standing. If `labs/day01/` was re-applied for this lab, destroy it per `labs/day01/teardown.md`. Run `labs/verify-teardown.sh` and expect zero unexpected resources.

- [ ] **Step 4: Verify — drill numbering is complete and mirrored**

```bash
for i in $(seq 1 12); do
  grep -q "D$i" labs/dayA1/README.md || echo "README missing D$i"
  grep -q "D$i" labs/dayA1/SOLUTION.md || echo "SOLUTION missing D$i"
done
```

Expected: no output.

- [ ] **Step 5: Verify — every drill in README carries a hint**

```bash
d=$(/usr/bin/grep -cE '^#+ D[0-9]+' labs/dayA1/README.md)
h=$(/usr/bin/grep -cE '\*\*Hint:\*\*' labs/dayA1/README.md)
echo "drills=$d hints=$h"
[ "$d" -ge 12 ] && [ "$h" -ge 12 ] || echo "FAIL: need >=12 drills and >=12 hints"
```

Expected: `hints=12` or more, no FAIL.

- [ ] **Step 6: Verify — quoting, and no invented account data**

```bash
grep -n -- '--query' labs/dayA1/*.md | grep -v "query '" | grep -v 'query "' | grep -vF 'query \' || echo "OK: quoted"
grep -rnE '[0-9]{12}|AKIA[0-9A-Z]{16}' labs/dayA1/ | grep -v '123456789012'
```

Expected: `OK: quoted`, then no output.

- [ ] **Step 7: Verify — no console instructions leaked in**

```bash
grep -niE 'open the console|aws console|click|navigate to.*console' labs/dayA1/README.md
```

Expected: no output, **except** a match on the line stating the console is forbidden. Inspect each hit; a hit that instructs the reader to use the console is a failure.

---

### Task 5: `labs/dayA2/` — the operation cycles

**Files:**
- Create: `labs/dayA2/README.md`
- Create: `labs/dayA2/SOLUTION.md`
- Create: `labs/dayA2/teardown.md`
- Read first (do not modify): `content/dayA2.md`, `labs/dayA2/main.tf`, `labs/dayA2/outputs.tf`, `labs/day03/README.md`, `labs/day03/teardown.md`

**Interfaces:**
- Consumes: Task 1's outputs (`cluster_name`, `service_name`, `task_family`, `alarm_name`, `log_group_name`) and its resource names verbatim. Task 3's three bucket names.
- Produces: cycle numbering `C1`–`C5`, cited by `SOLUTION.md`.

- [ ] **Step 1: Write `README.md`**

Prerequisites: `labs/foundation/` applied; a Day 1 image in ECR; `terraform.tfvars` created from the example with a real `image_tag`; `terraform init && terraform apply` in this directory.

State the standing shape of every cycle in bold up front: **predict → capture → execute → verify → revert.** Then the five cycles, each with those five labelled sub-steps and a **Hint:** line:

- **C1 — Retag an ECR image.** Attempt to move an existing tag in the immutable repository. It fails (F17). Read the exception name out of the error and write it down. The predict step must ask the reader to commit to an outcome *before* running it. Tie back to Day 1.
- **C2 — Scale to zero and back.** `aws ecs update-service --desired-count 0`, then `aws ecs wait services-stable` (F15), then back to 1. Check the waiter's exit status explicitly.
- **C3 — The alarm trap.** Capture the alarm to a file first. Change only the threshold with `put-metric-alarm`, restating *only* threshold-related arguments. Re-read the alarm and diff it against the captured copy. Discover what F14 dropped — `alarm_description`, `datapoints_to_alarm`, `treat_missing_data`. Then restore it properly from the captured copy.
- **C4 — Task definition revision and rollback.** Register a new revision, update the service to it, wait, then roll back with F20. Note that the old revision still exists — that is what makes this bucket two, not bucket three.
- **C5 — The drift hunt.** Make a CLI change (desired count, or a tag), run `terraform plan`, read the drift out loud, then decide: revert the CLI change or codify it. Both answers are defensible; the requirement is to justify the one chosen. Note that this cycle works only because `main.tf` deliberately omits `ignore_changes`.

Then `## Break it / Fix it`: (1) delete the log group `/ecs/awsdevops-cli` and try to get the logs back — this is bucket three, and it is meant to be felt rather than read; (2) run a multi-step script whose credentials expire partway through, and inspect the half-applied state. For (2), give the reader a short script that performs three sequential mutations *without* `set -e` and ask them to identify what a mid-script failure leaves behind, then fix the script.

Close with `## Success signal`: every cycle reverted, `terraform plan` reports no changes, `verify-teardown.sh` is clean after teardown.

- [ ] **Step 2: Write `SOLUTION.md`**

One section per cycle `C1`–`C5` with the worked commands for all five sub-steps including the revert, plus expected output shapes with placeholder values only. A section per break-it step. For C3, show the actual `describe-alarms` diff the reader should see and name the three dropped fields explicitly. For the break-it script, give the corrected version with `set -euo pipefail` and explicit exit-code checks.

- [ ] **Step 3: Write `teardown.md`**

`terraform destroy` in `labs/dayA2/`, then `labs/verify-teardown.sh`. Follow `labs/day03/teardown.md`'s structure. State the specific leak risks: an ECS service left at desiredCount > 0, and a running Fargate task. **Do not claim a task start can recreate the log group** — `labs/dayA2/main.tf` sets no `awslogs-create-group` option, so a task start fails on log-driver initialization instead of recreating it. The only supported route back is `terraform apply` in this directory. State that `verify-teardown.sh` already covers all three under the `awsdevops` prefix without needing flags, and that `labs/foundation/` must be left standing.

- [ ] **Step 4: Verify — cycles complete and mirrored**

```bash
for i in 1 2 3 4 5; do
  grep -q "C$i" labs/dayA2/README.md || echo "README missing C$i"
  grep -q "C$i" labs/dayA2/SOLUTION.md || echo "SOLUTION missing C$i"
done
for s in predict capture execute verify revert; do
  grep -qi -- "$s" labs/dayA2/README.md || echo "MISSING step label: $s"
done
```

Expected: no output.

- [ ] **Step 5: Verify — names match Task 1, and the trap fields are named**

```bash
for s in awsdevops-cli-cluster awsdevops-cli-service awsdevops-cli-task awsdevops-cli-cpu-high /ecs/awsdevops-cli; do
  grep -rq -- "$s" labs/dayA2/README.md labs/dayA2/SOLUTION.md || echo "MISSING NAME: $s"
done
for s in alarm_description datapoints_to_alarm treat_missing_data; do
  grep -q -- "$s" labs/dayA2/SOLUTION.md || echo "MISSING dropped-field: $s"
done
```

Expected: no output.

- [ ] **Step 6: Verify — the corrected script is actually correct, and quoting holds**

```bash
grep -q 'set -euo pipefail' labs/dayA2/SOLUTION.md || echo "MISSING: corrected script hardening"
python3 - <<'PYEOF'
import re, subprocess, tempfile, os
s = open('labs/dayA2/SOLUTION.md').read()
blocks = re.findall(r'```(?:bash|sh)\n(.*?)```', s, re.S)
print('extracted', len(blocks), 'shell blocks')
for i, b in enumerate(blocks, 1):
    with tempfile.NamedTemporaryFile('w', suffix='.sh', delete=False) as fh:
        fh.write(b); path = fh.name
    r = subprocess.run(['bash', '-n', path], capture_output=True, text=True)
    if r.returncode != 0:
        print('--- block %d does not parse ---' % i)
        print(b.strip()[:400])
        print(r.stderr.strip())
    os.unlink(path)
PYEOF
```

Expected: the extracted count, and no "does not parse" sections. Each block is checked **individually** — concatenating them would produce spurious failures from blocks that are deliberate fragments. A block that fails to parse is usually a real defect (an unbalanced quote), but inspect it: a block that is illustrative output rather than runnable commands should be fenced as `text` or `json`, not `bash`. Nothing here is ever executed.

- [ ] **Step 7: Verify — no secrets, no forbidden infra**

```bash
grep -rnE '[0-9]{12}|AKIA[0-9A-Z]{16}' labs/dayA2/*.md | grep -v '123456789012'
grep -rniE 'nat gateway|load balancer|elbv2 create|eks create' labs/dayA2/*.md
```

Expected: no output from the first. The second may match only where the text explains that this stack deliberately has none — inspect each hit.

---

### Task 6: `CLI-MASTERY.md`

**Files:**
- Create: `CLI-MASTERY.md` (path root, beside `COST.md` and `STRATEGY.md`)
- Read first (do not modify): `content/dayA1.md`, `content/dayA2.md`, `labs/dayA1/README.md`

**Interfaces:**
- Consumes: every Pinned Fact; Task 3's three bucket names verbatim; Day A1's four labels.
- Produces: nothing downstream except a link target for Task 7.

- [ ] **Step 1: Write the file**

Open with a two-sentence statement of what this file is and is not: a lookup reference, read out of order and repeatedly; the teaching lives in `content/dayA1.md` and `content/dayA2.md`. Then five sections, in this order — ordered for lookup speed, not for learning:

1. `## Identity triage` — a symptom → discriminating-command table. Rows for: "which account am I in", "why is this denied", "it worked yesterday", "my profile is ignored", "token expired". Each row gives the command and what its output rules out.
2. `## JMESPath recipes` — a table of about twelve expressions covering: filter a list by field value, select and rename fields, sort by a field, take the newest, count, join to a string, test prefix/substring, flatten nested lists, pipe a projection into a function. Every expression single-quoted (F19). One column must be "what question this answers" phrased in English.
3. `## One-liners by question` — grouped by service, each entry phrased as the English question first and the command second. Cover EC2, S3, IAM, ECS, ECR, CloudWatch Logs, CloudWatch, plus this path's CodeBuild / CodePipeline / CodeDeploy. Reuse commands that already appear in `content/day01.md`–`day05.md` where they fit, so the file doubles as an index into the path.
4. `## Reversibility` — the three-bucket table from `content/dayA2.md`, reproduced with the exact bucket names, scannable in five seconds.
5. `## Error decoder` — a table: message fragment → family → what it rules out → next command. Must include `ExpiredToken`, `InvalidClientTokenId`, `AccessDenied`, `UnauthorizedOperation`, `DryRunOperation`, a `...NotFoundException`, and `zsh: no matches found`.

Close with a short `## Safety rules` block: read-only by default in accounts you do not own; check identity before any mutation; capture state before a `put-`; know your bucket before pressing enter.

- [ ] **Step 2: Verify — sections present**

```bash
for h in '^## Identity triage' '^## JMESPath recipes' '^## One-liners by question' '^## Reversibility' '^## Error decoder' '^## Safety rules'; do
  grep -qE "$h" CLI-MASTERY.md || echo "MISSING SECTION: $h"
done
```

Expected: no output.

- [ ] **Step 3: Verify — coverage**

```bash
for s in ExpiredToken InvalidClientTokenId AccessDenied UnauthorizedOperation DryRunOperation NotFoundException 'no matches found'; do
  grep -q -- "$s" CLI-MASTERY.md || echo "MISSING error: $s"
done
for s in 'trivially reversible' 'reversible with effort' 'irreversible'; do
  grep -qi -- "$s" CLI-MASTERY.md || echo "MISSING bucket: $s"
done
for s in ' ec2 ' ' s3 ' ' iam ' ' ecs ' ' ecr ' ' logs ' ' cloudwatch ' ' codebuild ' ' codepipeline ' ' deploy '; do
  grep -qi -- "aws$s" CLI-MASTERY.md || echo "MISSING service: $s"
done
n=$(grep -cE "query '" CLI-MASTERY.md); echo "quoted-query examples: $n"; [ "$n" -ge 12 ] || echo "FAIL: fewer than 12 JMESPath examples"
```

Expected: no MISSING or FAIL lines.

- [ ] **Step 4: Verify — quoting and secrets**

```bash
grep -n -- '--query' CLI-MASTERY.md | grep -v "query '" | grep -v 'query "' | grep -vF 'query \' || echo "OK: quoted"
grep -nE '[0-9]{12}|AKIA[0-9A-Z]{16}' CLI-MASTERY.md | grep -v '123456789012'
```

Expected: `OK: quoted`, then no output.

---

### Task 7: Integration — index, cost, strategy, glossary

**Files:**
- Modify: `README.md`
- Modify: `COST.md`
- Modify: `STRATEGY.md`
- Modify: `content/GLOSSARY.md`
- Verify only, do **not** modify: `labs/verify-teardown.sh`

**Interfaces:**
- Consumes: everything produced by Tasks 1–6.
- Produces: the final learner-facing entry points.

- [ ] **Step 1: `README.md` — day index rows**

Add two rows to the existing `## Day index` table, after Day 5, keeping the existing column set (`Day | Chain link | Title | What you can do after | ~Cost`):

```markdown
| A1 | (appendix) | Interrogate: what is actually there? | Answer any question about an account by CLI, console closed | ~$0.02 |
| A2 | (appendix) | Operate: changing things you can undo | Make a change you can predict, verify, and reverse | ~$0.03 |
```

- [ ] **Step 2: `README.md` — appendix section**

Add a `## Appendix — AWS CLI mastery` section after the `## Day index` table. It must say: two days, ~7h, dependent on Days 1–3 because the labs interrogate and mutate those stacks; A1 creates nothing and A2 adds one ALB-less ECS stack; and that `CLI-MASTERY.md` is a standalone lookup reference usable immediately, before or without the labs. Link `content/dayA1.md`, `content/dayA2.md`, `labs/dayA1/README.md`, `labs/dayA2/README.md`, `CLI-MASTERY.md`.

Also add one line to the `## Prerequisites` list noting the appendix assumes AWS CLI **v2** specifically, and that its examples are quoted for `zsh`.

- [ ] **Step 3: `COST.md` — per-lab rows and the week total**

Add two rows to the `## Cost per lab` table:

```markdown
| A1 | CodeBuild reruns (`ARM_SMALL`, ~6 build-min), existing ECR storage | ~$0.02 | ~$0.02 (no hourly meter) | $0.00 |
| A2 | One Fargate task (0.25 vCPU / 0.5 GB, arm64), CloudWatch alarms (under the 10 free), 1-day-retention logs | ~$0.03 | ~$0.24 (24h × $0.0099/h) | $0.00 |
```

Add a short worked-math paragraph after the existing Day 3 / Day 5 one: A2 running is Fargate `2h × $0.0099/h ≈ $0.02` plus a handful of build-minutes and effectively-free alarms and logs; left a full 24h it is `24h × $0.0099 ≈ $0.24`. State that A2 has no ALB, which is why its overnight figure is a fraction of Day 3's.

Then update **every** stated week total from `~$0.74` to `~$0.79`. Because this is a path-wide claim, the check in Step 7 sweeps the whole tree, not just `COST.md`.

- [ ] **Step 4: `STRATEGY.md` — one trap row**

Add one row to the `## What the 80% waste time on` table:

```markdown
| Treating the AWS CLI as a list of incantations to copy | Produces someone who can rerun this path's commands and cannot write a new one. The CLI is four things — an identity, an operation, a response, and a projection — and every confusion is a mislocation of which one broke. See the appendix. |
```

- [ ] **Step 5: `content/GLOSSARY.md` — seven terms**

Add these, each 2–4 sentences in the file's existing voice, **placed alphabetically** among the existing entries (the file is alphabetical — do not append them in a block at the end):

`Credential provider chain` · `Drift` · `JMESPath` · `Paginator` · `Service model` · `SSO session` · `Waiter`

Each must say what it is and why it matters, following the existing entries' pattern. Update the file's opening line if it says the glossary covers "Days 1–5", so it covers the appendix too.

- [ ] **Step 6: Verify `labs/verify-teardown.sh` covers the appendix — without changing it**

```bash
grep -n 'PREFIX}\*' labs/verify-teardown.sh
grep -n 'alarm-name-prefix' labs/verify-teardown.sh
bash -n labs/verify-teardown.sh && echo "OK: script parses"
```

Expected: the ECS loops filter clusters on `*"${PREFIX}"*` and the alarm check passes `--alarm-name-prefix "${PREFIX}"`. Since `awsdevops-cli-cluster` and `awsdevops-cli-cpu-high` both contain `awsdevops`, the existing checks already cover the appendix. **Make no change to this file.** Record the two line numbers in your report as evidence.

- [ ] **Step 7: Verify — path-wide consistency sweeps**

The week-total claim appears in more than one file, so this check is `-r` over the whole path, matching the rule's scope:

```bash
grep -rn '0\.74' . --exclude-dir=.git --exclude-dir=docs && echo "FAIL: stale week total remains"
grep -rn '0\.79' . --exclude-dir=.git --exclude-dir=docs | head
```

Expected: no FAIL line; at least `README.md` and `COST.md` carry `~$0.79`.

`docs/` is excluded deliberately, not carelessly: the spec and this plan both quote the old
`~$0.74` figure while describing the change to `~$0.79`, and they are correct to. Narrowing the
sweep to learner-facing files is what makes this check match the rule it enforces — the rule is
"no learner-facing file states a stale week total", not "the string never appears".

```bash
for f in content/dayA1.md content/dayA2.md CLI-MASTERY.md labs/dayA1/README.md labs/dayA2/README.md; do
  grep -qF "$f" README.md || echo "README does not link $f"
done
for t in 'Credential provider chain' Drift JMESPath Paginator 'Service model' 'SSO session' Waiter; do
  grep -q "^## $t" content/GLOSSARY.md || echo "GLOSSARY missing: $t"
done
```

Expected: no output.

- [ ] **Step 8: Verify — no credentials anywhere in the appendix, path-wide**

The rule is "no real credentials in any file", so the check sweeps the whole path:

```bash
grep -rnE 'AKIA[0-9A-Z]{16}|aws_secret_access_key *= *[A-Za-z0-9/+]{20,}' . --exclude-dir=.git
grep -rnE '\b[0-9]{12}\b' . --exclude-dir=.git | grep -v '123456789012'
```

Expected: no output from either.

- [ ] **Step 9: Report**

Report: the two `verify-teardown.sh` line numbers from Step 6; every file modified; and confirmation that the `0.74` sweep came back empty.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: Purpose/Success Criteria → Tasks 2, 3 (content) and 4, 5 (labs); Constraints → Global Constraints + Task 1's cost-shaped stack; Strategy's two spines → Tasks 2 and 3 explicitly; Curriculum Day A1 → Tasks 2, 4; Day A2 → Tasks 3, 5; `CLI-MASTERY.md` → Task 6; Directory Layout → Tasks 1, 4, 5 (creates) and 7 (edits); Content Day Skeleton → enforced by the structure checks in Tasks 2 and 3.

**Placeholder scan.** No "TBD", no "similar to Task N", no "add appropriate error handling". Every code block is literal. The one place a task is told *not* to assert a value — waiter interval/attempt counts (F15) and the ECR exception name (F17) — is deliberate: the reader is instructed to look it up, which is both accurate and the habit being taught.

**Name consistency.** The eight `awsdevops-cli-*` resource names and five Terraform output names are declared once in Task 1's Interfaces block and checked verbatim in Tasks 3 and 5. The three reversibility bucket names are declared in Task 3 and checked in Tasks 5 and 6. Day A1's four labels are declared in Task 2 and reused by name in Tasks 3 and 6. Drill IDs `D1`–`D12` and cycle IDs `C1`–`C5` are checked mirrored across each lab's README and SOLUTION.

**Check-scope audit** (the failure mode `skill.md` names): the two path-wide rules — no credentials anywhere, and the `$0.74` → `$0.79` week total — are checked with `grep -r` over the whole tree in Task 7, not over a subdirectory. The `--query` quoting checks grep for the distinctive fragment `--query '` rather than for a full command line no file may contain on one line.
