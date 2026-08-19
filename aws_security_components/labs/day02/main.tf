# ---------------------------------------------------------------------------
# Day 2 — Advanced identity. Layers on labs/base (read-only via remote
# state — this module never edits base). Builds:
#   - low_priv: the learner's starting identity. Its inline policy has a
#     MIS-SCOPED iam:PassRole (Resource "*") plus enough ECS/log permissions
#     to register and run a task — ANTIPATTERNS.md #6.
#   - high_priv: a "crown jewel" role that trusts ecs-tasks.amazonaws.com
#     (so ECS can assume it for a task) and can read the base app secret.
#     low_priv can never assume this directly; the escalation path is
#     PASSING it to a new ECS task, not assuming it via STS.
#   - low_priv_boundary: the permission-boundary policy that, once attached
#     (var.permission_boundary_enabled = true), caps low_priv's effective
#     permissions to a ceiling that does not include iam:PassRole at all,
#     closing the escalation without editing low_priv's identity policy.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = var.base_state_path
  }
}

locals {
  name_prefix = var.project

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "day02"
    },
    var.tags
  )

  base_vpc_id             = data.terraform_remote_state.base.outputs.vpc_id
  base_public_subnet_ids  = data.terraform_remote_state.base.outputs.public_subnet_ids
  base_ecs_cluster_arn    = data.terraform_remote_state.base.outputs.ecs_cluster_arn
  base_task_exec_role_arn = data.terraform_remote_state.base.outputs.task_execution_role_arn
  base_secret_arn         = data.terraform_remote_state.base.outputs.secret_arn
}

# ---------------------------------------------------------------------------
# The escalation target: a "high-priv" role that trusts ECS to assume it
# (same trust shape as base's task/task_execution roles) and can read the
# app secret that low_priv can never read directly. This models a
# genuinely more-privileged role sitting in the same account — the kind of
# role a real team creates for a "trusted" workload and then forgets is
# reachable by anything holding a broad iam:PassRole.
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

resource "aws_iam_role" "high_priv" {
  name               = "${local.name_prefix}-high-priv-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = merge(local.common_tags, { Name = "${local.name_prefix}-high-priv-role" })
}

resource "aws_iam_role_policy" "high_priv" {
  name = "${local.name_prefix}-high-priv-policy"
  role = aws_iam_role.high_priv.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # THE CROWN JEWEL. low_priv, tested directly, gets AccessDenied on
        # this same secret_arn (see README "THE BREAK" step 1). A task
        # running AS high_priv can read it — that read is the observable
        # proof the escalation landed.
        Sid      = "ReadBaseAppSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [local.base_secret_arn]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# The attacker's starting point: a low-privileged role the learner assumes
# to simulate holding a narrowly-scoped identity. Assumable only by the
# principal named in var.assumer_principal_arn (your own admin user/role —
# fill this in via terraform.tfvars; see terraform.tfvars.example).
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "low_priv_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.assumer_principal_arn]
    }
  }
}

resource "aws_iam_role" "low_priv" {
  name               = "${local.name_prefix}-low-priv-role"
  assume_role_policy = data.aws_iam_policy_document.low_priv_assume.json

  # THE HARDEN. null (var.permission_boundary_enabled = false) during the
  # BREAK phase; set to the boundary policy's ARN once you flip the
  # variable to true and re-apply. See README "THE HARDEN".
  permissions_boundary = var.permission_boundary_enabled ? aws_iam_policy.low_priv_boundary.arn : null

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-low-priv-role" })
}

resource "aws_iam_role_policy" "low_priv" {
  name = "${local.name_prefix}-low-priv-policy"
  role = aws_iam_role.low_priv.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ****************************************************************
        # THE BUG — ANTIPATTERNS.md #6 (iam:PassRole and wildcards as
        # silent privilege escalation). Resource "*" means low_priv can
        # pass ANY role in the account to a service that will assume it —
        # including high_priv, which it was never meant to reach. Nothing
        # about this statement looks dangerous read in isolation; it only
        # becomes an escalation path paired with the ECS permissions below.
        # DO NOT "fix" this before the BREAK phase — the harden in this lab
        # is the permission boundary, not narrowing this Resource.
        # ****************************************************************
        Sid      = "MisScopedPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = ["*"]
      },
      {
        # Task-definition actions carry no "ecs:cluster" request context
        # (a task definition isn't a cluster-scoped resource), so these
        # cannot be conditioned on the base cluster the way RunTask can be
        # below — Resource "*" for convenience, same posture as the
        # PassRole statement above.
        Sid    = "RegisterAndDescribeTaskDefinitions"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = ["*"]
      },
      {
        # These DO carry an "ecs:cluster" request context, so — unlike the
        # statement above — they're at least confined to base's own
        # cluster, not every cluster in the account.
        Sid    = "RunAndManageTasksInBaseCluster"
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask"
        ]
        Resource = ["*"]
        Condition = {
          ArnEquals = {
            "ecs:cluster" = local.base_ecs_cluster_arn
          }
        }
      },
      {
        # Legitimate, narrowly-scoped need: read back the escalation task's
        # own logs. Contrast with the two statements above — this is what
        # a properly-scoped grant looks like.
        Sid    = "ReadOwnEscalationLogs"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = ["${aws_cloudwatch_log_group.escalate.arn}:*"]
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# THE HARDEN. A permission-boundary policy for low_priv: an ALLOW-list
# ceiling that does not mention iam:PassRole, ecs:RegisterTaskDefinition, or
# ecs:RunTask at all. Effective permission = intersection(identity policy,
# boundary) — so once attached, low_priv's identity policy can keep
# granting the broad PassRole/RunTask statements above unchanged, and the
# escalation still fails, because the boundary never allowed those actions
# in the first place. This is the "ceiling caps the grant" mental model
# from the canonical evaluation order (see the "The engine lens" section of
# content/day02-advanced-identity.md).
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "low_priv_boundary" {
  name        = "${local.name_prefix}-low-priv-boundary"
  description = "Permission boundary ceiling for low_priv. Deliberately omits iam:PassRole, ecs:RegisterTaskDefinition, and ecs:RunTask so the escalation path is capped regardless of low_priv's own identity policy."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ObservabilityCeiling"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:StopTask",
          "logs:GetLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "sts:GetCallerIdentity"
        ]
        Resource = ["*"]
      }
    ]
  })
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Supporting resources for the escalation task itself: its own security
# group (egress-only — it needs to reach the ECS/Secrets Manager/logs API
# endpoints, nothing needs to reach it) and its own log group. Created by
# this module (not base) since base does not export a reusable task SG.
# ---------------------------------------------------------------------------

resource "aws_security_group" "escalate_task" {
  name        = "${local.name_prefix}-escalate-task-sg"
  description = "Day 2 escalation task ENI — egress only, no inbound needed"
  vpc_id      = local.base_vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name_prefix}-escalate-task-sg" })
}

resource "aws_vpc_security_group_egress_rule" "escalate_task_all" {
  security_group_id = aws_security_group.escalate_task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_cloudwatch_log_group" "escalate" {
  name              = "/ecs/${local.name_prefix}-escalate"
  retention_in_days = 3
  tags              = local.common_tags
}
