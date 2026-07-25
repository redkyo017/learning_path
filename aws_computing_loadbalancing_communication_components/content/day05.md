# Day 5 — ECS, Fargate, and ECR

Read this before starting the lab. Budget: 30 minutes.

---

## Learning objectives

By the end of today you should be able to:
- Explain each field in a task definition (CPU, memory, network mode, container definitions)
  and describe what `awsvpc` networking mode means for security groups
- Distinguish the task execution role from the task role and name the failure each one
  produces when misconfigured
- Describe what the ECS service maintains and how `health_check_grace_period_seconds`
  prevents premature task termination
- Trace the ECR image pull path from Fargate task launch to container start
- Explain what Fargate abstracts away and what you still own
- Identify valid Fargate CPU and memory combinations for a given workload requirement

---

## The scheduler mental model

Before memorising any ECS concept, internalise the framework that explains every
ECS behaviour you will encounter:

> **ECS is a scheduler that decides WHERE tasks run and WHEN to replace them. Fargate
> removes the WHERE question entirely — you specify what the task needs (CPU, memory,
> image) and Fargate provides the hardware. You still own everything above the hardware:
> the task definition, the service, the VPC, the security groups.**

Everything that confuses people about ECS traces back to forgetting what the boundary
is. When a Fargate task cannot connect to RDS, the hardware is not the problem —
the security group on the task's ENI is. When a container fails to start, the hardware
is not the problem — the execution role or the image is. Fargate manages the host;
you manage everything the host runs.

---

## Task definition anatomy

A task definition is a versioned blueprint for how to run one or more containers as
a unit. Each time you update a task definition, ECS creates a new revision — the family
name stays the same, the revision number increments.

| Field | Purpose | Example value |
|---|---|---|
| `family` | Versioned name (family:revision) | `api-service:7` |
| `requires_compatibilities` | Launch type this definition supports | `["FARGATE"]` |
| `network_mode` | Networking model for the task | `awsvpc` (required for Fargate) |
| `cpu` | Task-level CPU allocation in units | `1024` (1 vCPU) |
| `memory` | Task-level memory in MB | `2048` |
| `execution_role_arn` | Role used by the ECS agent (image pull, logs) | ARN of execution role |
| `task_role_arn` | Role assumed by your running container code | ARN of task role |
| `container_definitions` | List of containers, one per logical process | see below |

**Container definition fields (inside `container_definitions`):**
- `name` — container name referenced by service and CloudWatch Logs
- `image` — ECR URI or public image (`123456789.dkr.ecr.us-east-1.amazonaws.com/api:1.2.3`)
- `portMappings` — `containerPort` exposed (Fargate ignores `hostPort`; use `containerPort` only)
- `logConfiguration` — `awslogs` driver with `awslogs-group`, `awslogs-region`, `awslogs-stream-prefix`
- `environment` — non-sensitive key-value pairs injected as environment variables
- `secrets` — sensitive values pulled from Secrets Manager or SSM Parameter Store at task start

**Valid Fargate CPU and memory combinations:**

| CPU units | vCPU | Valid memory range (MB) |
|---|---|---|
| 256 | 0.25 | 512, 1024, 2048 |
| 512 | 0.5 | 1024, 2048, 3072, 4096 |
| 1024 | 1 | 2048–8192 (1024 MB increments) |
| 2048 | 2 | 4096–16384 (1024 MB increments) |
| 4096 | 4 | 8192–30720 (1024 MB increments) |
| 8192 | 8 | 16384–61440 (4096 MB increments) |
| 16384 | 16 | 32768–122880 (8192 MB increments) |

If you request a combination that is not in this table, the ECS API returns a validation
error at task registration time — the task never launches.

---

## awsvpc networking

`awsvpc` is the most important ECS networking concept and the one that most commonly causes
debugging confusion.

**What awsvpc means:**
In `awsvpc` mode, each task gets its own Elastic Network Interface (ENI) — not the host's
ENI, not a port mapping on the host. The task is a first-class VPC citizen with its own
private IP address from the subnet's CIDR range. The security group is attached to the
task's ENI, not to any EC2 instance.

**Why this changes debugging:**
1. You can restrict traffic per-task, not per-host. Two tasks running on the same Fargate
   hardware can have completely different security groups.
2. The task's IP is a real VPC IP. Other services in the VPC can reach the task directly
   without NAT.
3. Target groups register the task IP directly. This is why `target_type = "ip"` is required
   for Fargate — there is no EC2 instance ID to register.
4. When a Fargate task is replaced (on deploy or failure), the new task gets a new ENI with
   a new IP. The ALB target group is the mechanism that tracks which IPs are currently active.

**The debugging rule:**
If a Fargate task cannot connect to RDS, check the security group on the **task's ENI**
(visible in the ECS task detail page → Network section) — not on any EC2 instance. If the
RDS security group does not allow inbound from the task's security group, the connection
fails even though no EC2 is involved.

---

## IAM roles — execution role vs task role

ECS uses two distinct IAM roles per task definition. Confusing them is the most common
ECS IAM mistake.

**Execution role** — used by the ECS agent (not your application code). The ECS control
plane assumes this role to perform the setup steps that run before your container starts:

- Pull the container image from ECR (`ecr:GetAuthorizationToken`, `ecr:BatchGetImage`,
  `ecr:GetDownloadUrlForLayer`)
- Create the CloudWatch Logs log stream (`logs:CreateLogStream`, `logs:PutLogEvents`)
- Fetch secret values from Secrets Manager or SSM at startup

The AWS-managed policy `AmazonECSTaskExecutionRolePolicy` grants all of these. Never
add application permissions to the execution role.

**Task role** — assumed by your running application code inside the container. Use this
role to grant the container access to AWS services: reading from S3, writing to SQS,
querying DynamoDB, calling other AWS APIs. The task role is the equivalent of an EC2
instance profile for containers.

**The two failure modes:**

| Symptom | Root cause |
|---|---|
| `CannotPullContainerError` on task start | Execution role missing ECR pull permissions |
| App crashes with `AccessDeniedException` for S3/SQS/etc. | Task role missing the required service permission |

If the container won't start: check the execution role.
If the container runs but your code fails on an AWS API call: check the task role.

---

## ECS service

The ECS service is the persistent control loop that keeps your tasks running.

**What the service maintains:**
- `desired_count` — the number of tasks the service ensures are running at all times.
  If a task stops (for any reason), the service launches a replacement automatically.
- `launch_type` — `FARGATE` or `EC2`. On FARGATE, ECS provisions the hardware.
- `health_check_grace_period_seconds` — how long to ignore unhealthy status from the
  ALB target group after a task starts. Set this to at least the application's full startup
  time. If it is zero: ECS stops the task before the app finishes starting, launches a
  replacement, which also fails — an endless stop/start cycle.
- `deployment_configuration` — controls rolling update behaviour. Defaults:
  `minimum_healthy_percent = 100`, `maximum_percent = 200`. With `desired_count = 3`:
  ECS launches 3 new tasks before stopping any old ones, briefly running 6 tasks
  simultaneously. Set `minimum_healthy_percent = 50` for faster deploys with less headroom.

**What happens during a deploy:**
1. ECS launches new tasks with the updated task definition.
2. New tasks register with the ALB target group; health checks begin.
3. After the new tasks pass health checks, ECS starts draining old tasks.
4. Old tasks are deregistered from the target group; ALB waits `deregistration_delay`
   seconds before stopping the task.
5. Old tasks are stopped.

---

## ECR and image lifecycle

ECR (Elastic Container Registry) is a private Docker registry in your AWS account.
Fargate always pulls from ECR in the same region (no data transfer charge).

**Image tag mutability:**
- `MUTABLE` (default) — the same tag (e.g. `:latest`) can be overwritten by a new push.
  This simplifies CI/CD but means `:latest` on Monday may be a different image than
  `:latest` on Tuesday. Acceptable for development; dangerous in production.
- `IMMUTABLE` — once a tag is pushed, it cannot be overwritten. A deploy always uses
  exactly the image that was tested. Use IMMUTABLE in production.

**Scan on push:**
ECR can automatically scan images for known CVEs using Amazon Inspector when they are
pushed. Findings appear in the ECR console. Enable this on every production repository.

**Lifecycle policies:**
Rules that expire old images automatically (e.g. keep only the last 30 untagged images).
Without a lifecycle policy, a busy CI/CD pipeline fills a repository with thousands of
images; storage costs accumulate and unreviewed old images remain accessible.

**Image pull sequence for a Fargate task:**
1. ECS agent assumes the execution role to get an ECR authorization token.
2. Agent uses the token to authenticate to the ECR registry endpoint.
3. Agent pulls the image layers to Fargate infrastructure (transparent to you).
4. Container starts from the pulled image.

If any step fails, the task stops with `CannotPullContainerError`. Check the execution
role first; check ECR repository permissions second.

---

## Fargate vs EC2 launch type

| Dimension | Fargate | EC2 launch type |
|---|---|---|
| Cluster management | None — AWS provisions hosts | You manage EC2 hosts, OS patching, ECS agent |
| EC2 to patch | No | Yes — your responsibility |
| Billing unit | Per vCPU-second and GB-second used by each task | Full EC2 instance hours regardless of task utilisation |
| Maximum task size | 16 vCPU / 120 GB | Limited by the largest EC2 instance type you run |
| GPU support | No | Yes (G and P instance families) |
| Spot capacity | Fargate Spot (equivalent savings, managed interruption) | EC2 Spot instances in the cluster |
| Startup latency | ~30–90 seconds (no EC2 boot) | Depends on cluster capacity; tasks start faster when instances already running |
| Networking | awsvpc always | awsvpc, bridge, or host mode |

**Decision rule:** Use Fargate by default. Use EC2 launch type only when you need GPU
instances, task sizes beyond the Fargate maximums, or need to run on specific hardware
that Fargate does not support.

---

## Best practices

1. Use `awsvpc` network mode always — even on EC2 launch type — to get per-task security
   groups and a clean networking model.
2. Set `health_check_grace_period_seconds` to at least the full application startup time —
   zero causes an endless stop/start cycle.
3. Use IMMUTABLE image tags in production; use a version tag (e.g. `:1.4.2` or the commit
   SHA) rather than `:latest` in task definitions.
4. Enable ECR image scanning on push for every repository used in production.
5. Use the task role (not the execution role) for all AWS permissions your application code
   needs — execution role is for ECS infrastructure tasks only.

---

## Common pitfalls

- **`CannotPullContainerError` diagnosed as a network problem.** It is almost always an
  execution role permission issue — `ecr:GetAuthorizationToken` or `ecr:BatchGetImage`
  missing. Check IAM before checking VPC connectivity.
- **"Essential container exited" diagnosed by reading ECS events.** ECS events tell you
  the container stopped; they do not tell you why. The application crash reason is in
  CloudWatch Logs for that task — that is always the first place to look.
- **Security group attached to the wrong resource.** In `awsvpc` mode the security group
  is on the task's ENI, not on an EC2 instance. Security group rules set on EC2 instances
  in the cluster have no effect on Fargate tasks.
- **`target_type = "instance"` used for Fargate targets.** Fargate tasks have no EC2
  instance ID. If the target group uses `target_type = "instance"`, ECS cannot register
  the task; the target group stays empty and every request returns 503.
- **`health_check_grace_period_seconds = 0` on the ECS service.** The ALB starts health
  checking immediately. If the application takes 20 seconds to start, ECS receives unhealthy
  status and stops the task before it is ready — the service never stabilises.

---

## Exercises

Answer before starting the lab:

1. Your Fargate task stops at launch with `CannotPullContainerError`. Is this an execution
   role or task role issue? What is the minimum IAM permission the role needs to pull an
   image from ECR?
2. A Fargate task runs fine but the application cannot write objects to an S3 bucket. Is
   this an execution role or task role issue? Which role do you add the S3 permission to?
3. You need a Fargate task with 2 vCPU and 8 GB memory. Is this a valid combination?
   State the exact CPU units and memory MB values you would set in the task definition.
4. Your ECS service has `desired_count = 3` but only 2 tasks are running. The third task
   stops immediately with "Essential container exited." Where do you look first, and what
   are you looking for?

## Lab reference

Follow Day 5 in the implementation plan:
`aws_computing_loadbalancing_communication_components/docs/superpowers/plans/2026-07-23-aws-compute-lb-communication-plan.md`
for the exact Console steps and Terraform code.

## Journal template

```
### Day 5 — ECS, Fargate, and ECR
Execution role vs task role — the difference in my own words: ...
What awsvpc mode means for security group placement: ...
Break-it exercise — CannotPullContainerError root cause and fix: ...
```
