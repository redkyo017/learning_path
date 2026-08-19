# ---------------------------------------------------------------------------
# Two ECS roles, per AWS convention:
#   - task_execution: used BY ECS/Fargate itself to pull the image and ship
#     logs. Standard managed policy, nothing lab-specific.
#   - task: used BY the app code at runtime (this is the role Day 8/11's
#     SSRF -> credential-theft lab steals via the task metadata endpoint).
#     One statement in the task role is INTENTIONALLY broad WITHIN this
#     workload's own S3 bucket (never account-wide) — see the marked block
#     below. Day 1's break->harden lab tightens it.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Task execution role (pull image, ship logs) ---------------------------

resource "aws_iam_role" "task_execution" {
  name               = "${local.name_prefix}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Task role (the app's runtime identity) --------------------------------

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "task" {
  name = "${local.name_prefix}-task-policy"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ****************************************************************
        # INTENTIONALLY BROAD (WITHIN THIS WORKLOAD) — DO NOT "FIX" THIS
        # BEFORE DAY 1, but do NOT widen it to account-wide either.
        #
        # Scope: this statement's Resource is deliberately limited to THIS
        # workload's own bucket (app_data) — never account-wide "*". The
        # app's /fetch endpoint is a deliberate SSRF hole, so an
        # account-wide S3 grant on a role reachable through it would put
        # every other bucket in the account one SSRF request away from
        # exposure. That risk is unacceptable regardless of the Day 1
        # lesson, so the ceiling here is "this bucket, over-broadly" not
        # "everything".
        #
        # What's still broad (and what Day 1 tightens): the app only
        # actually needs Get/Put on a single object prefix, but this grants
        # Get/Put/Delete/List across the ENTIRE bucket (all prefixes, plus
        # Delete which the app never calls). Day 1's break->harden lab
        # observes that over-grant, then tightens Action/Resource down to
        # exactly what the app uses and proves the difference with an
        # AccessDenied on an out-of-scope key/action.
        # ****************************************************************
        Sid    = "BroadButWorkloadScopedAppDataAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      },
      {
        Sid      = "ReadOwnSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.app_secret.arn]
      },
      {
        Sid    = "AppDataTable"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [aws_dynamodb_table.app_data.arn]
      },
      {
        Sid    = "DecryptAppDataKey"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.app_data.arn]
      },
      {
        # ECS Exec prerequisite (Day 7/8 labs use `aws ecs execute-command`
        # to get a shell in the task). This is a SEPARATE requirement from
        # the `enable_execute_command = true` flag on aws_ecs_service.app
        # (ecs.tf) — both are needed. These four SSM-messages actions do
        # not support resource-level scoping, so Resource must be "*"; this
        # is normal/expected for ECS Exec, not an over-grant to tighten.
        Sid    = "EcsExecSsmMessages"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}
