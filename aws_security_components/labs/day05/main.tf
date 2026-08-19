# ---------------------------------------------------------------------------
# Day 5 — Secrets & certificates. Layers on labs/base via remote state.
# Does NOT edit any labs/base resource or file -- every resource below is
# either a standalone resource (own family/name), or an ADDITIVE resource
# attached to a base-owned resource by ARN/name (a new IAM inline policy on
# base's execution role, a new listener rule on base's HTTP listener, a new
# resource policy + rotation on base's secret). See README "How this layers
# on base without editing it" for the full list and why each one is safe.
#
# TWO INDEPENDENT STATES, TOGGLED BY var.harden:
#   harden = false (default) -> THE BREAK: a standalone task-definition
#     family with a placeholder secret leaked into a plaintext env var.
#   harden = true             -> THE HARDEN: the same family's next
#     revision pulls the secret via the ECS `secrets` block, base's real
#     secret gets rotation + a resource policy, and base's ALB gets an
#     HTTPS listener (ACM cert) + HTTP->HTTPS redirect.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../base/terraform.tfstate"
  }
}

# Read-only lookup of base's live HTTP listener so we can forward the new
# HTTPS listener to the SAME target group base's real ECS service is
# already registered in -- without needing a target-group ARN in base's
# outputs contract, and without editing/importing base's listener resource.
data "aws_lb_listener" "http" {
  arn = data.terraform_remote_state.base.outputs.alb_listener_arn
}

locals {
  name_prefix     = "${var.project}-day05"
  use_public_cert = var.domain_name != "" && var.route53_zone_id != ""

  # base's execution/task roles have no path prefix (see labs/base/iam.tf),
  # so an ARN split on "/" reliably yields the bare role name.
  task_execution_role_name = split("/", data.terraform_remote_state.base.outputs.task_execution_role_arn)[1]

  # Whichever cert branch actually exists (harden=false -> neither exists
  # -> null). Nested try() avoids a Terraform "invalid index" error from
  # referencing [0] on a resource whose count is 0 in the untaken branch --
  # this is the documented, recommended pattern for optional resources.
  cert_arn = try(
    aws_acm_certificate_validation.public[0].certificate_arn,
    try(aws_acm_certificate.imported[0].arn, null)
  )

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "day05"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# Shared log group for the demo family -- created unconditionally (its name
# doesn't depend on var.harden) so toggling harden never tries to create and
# destroy a same-named CloudWatch log group in the same apply.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "demo" {
  name              = "/ecs/${local.name_prefix}-app"
  retention_in_days = 3
  tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# THE BREAK (harden = false): a standalone task-definition family showing
# the mistake -- a placeholder secret leaked straight into a plaintext env
# var. Registering a task definition costs nothing and needs no running
# service; `aws ecs describe-task-definition` is enough to find the leak.
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "leaky_demo" {
  count                    = var.harden ? 0 : 1
  family                   = "${local.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.terraform_remote_state.base.outputs.task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.base.outputs.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "REPLACE_ME.dkr.ecr.${var.region}.amazonaws.com/aws-sec-lab-app:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      # *** THE PLANTED BREAK ***
      # A teammate "temporarily" hardcoded the app's API key straight into
      # the task definition as a plaintext env var instead of pulling it
      # from Secrets Manager. PLACEHOLDER STRING ONLY -- never a real
      # credential. But `aws ecs describe-task-definition` on this family
      # shows it in the clear to anyone holding ecs:DescribeTaskDefinition,
      # which is a far larger blast radius than "who has
      # secretsmanager:GetSecretValue on one ARN" -- see ANTIPATTERNS.md #10.
      environment = [
        { name = "APP_BUCKET", value = data.terraform_remote_state.base.outputs.app_bucket_name },
        { name = "AWS_REGION", value = var.region },
        { name = "APP_API_KEY", value = "REPLACE_ME_LEAKED_PLACEHOLDER_NOT_A_REAL_SECRET" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${local.name_prefix}-app"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.demo]
}

# ---------------------------------------------------------------------------
# THE HARDEN, part 1 (harden = true): the same family's next revision --
# the secret is resolved by the ECS agent at launch (via the TASK EXECUTION
# role) and injected as an env var; it is never written into the task
# definition JSON, never in `describe-task-definition` output, and never in
# Terraform state as plaintext. Base's own real app task definition already
# does the OTHER valid pattern (app calls GetSecretValue itself, using the
# TASK role + the ARN pointer already in base/ecs.tf) -- see content file
# "two ways ECS gets a secret into a container" for the contrast.
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "hardened_demo" {
  count                    = var.harden ? 1 : 0
  family                   = "${local.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.terraform_remote_state.base.outputs.task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.base.outputs.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "REPLACE_ME.dkr.ecr.${var.region}.amazonaws.com/aws-sec-lab-app:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "APP_BUCKET", value = data.terraform_remote_state.base.outputs.app_bucket_name },
        { name = "AWS_REGION", value = var.region }
      ]
      # THE FIX: valueFrom an ARN, not a value. Requires the execution
      # role to be able to resolve it -- see aws_iam_role_policy.task_execution_secrets
      # below; without that grant this task fails to start with a
      # ResourceInitializationError, which is itself a useful signal that
      # this wiring is real, not decorative.
      secrets = [
        { name = "APP_API_KEY", valueFrom = data.terraform_remote_state.base.outputs.secret_arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${local.name_prefix}-app"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.demo]
}

# Additive inline policy on base's TASK EXECUTION role (not the task role --
# `secrets` valueFrom is resolved by the execution role at launch, not by
# the app at runtime). A new aws_iam_role_policy resource in DAY05's own
# state, attached by name to a role base created; this does not touch or
# require editing labs/base/iam.tf.
resource "aws_iam_role_policy" "task_execution_secrets" {
  count = var.harden ? 1 : 0
  name  = "${local.name_prefix}-exec-secrets-access"
  role  = local.task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ExecutionRoleResolvesAppSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [data.terraform_remote_state.base.outputs.secret_arn]
      },
      {
        # base's secret has no CMK (default aws/secretsmanager AWS-managed
        # key) -- Resource "*" scoped by kms:ViaService is AWS's own
        # documented pattern for this case; there is no per-key ARN to
        # scope to for an AWS-managed key.
        Sid      = "DecryptViaSecretsManagerOnly"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = ["*"]
        Condition = {
          StringEquals = { "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com" }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# THE HARDEN, part 2 (harden = true): rotation for base's real secret.
# aws_secretsmanager_secret_rotation + aws_secretsmanager_secret_policy
# both take a secret ARN/ID directly -- neither requires owning the
# aws_secretsmanager_secret resource itself, so both live safely in DAY05's
# own state pointed at base's secret by ARN.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  count = var.harden ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rotation_lambda" {
  count              = var.harden ? 1 : 0
  name               = "${local.name_prefix}-rotation-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "rotation_lambda" {
  count = var.harden ? 1 : 0
  name  = "${local.name_prefix}-rotation-lambda-policy"
  role  = aws_iam_role.rotation_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RotateOwnSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [data.terraform_remote_state.base.outputs.secret_arn]
      },
      {
        Sid      = "GetRandomPassword"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetRandomPassword"]
        Resource = ["*"]
      },
      {
        Sid    = "LambdaLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${local.name_prefix}-rotate-app-secret:*"
        ]
      }
    ]
  })
}

data "archive_file" "rotation_lambda" {
  count       = var.harden ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/rotation_lambda/rotate_app_secret.py"
  output_path = "${path.module}/rotation_lambda/rotate_app_secret.zip"
}

resource "aws_lambda_function" "rotate_app_secret" {
  count            = var.harden ? 1 : 0
  function_name    = "${local.name_prefix}-rotate-app-secret"
  filename         = data.archive_file.rotation_lambda[0].output_path
  source_code_hash = data.archive_file.rotation_lambda[0].output_base64sha256
  handler          = "rotate_app_secret.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.rotation_lambda[0].arn
  timeout          = 30
  tags             = local.common_tags
}

resource "aws_lambda_permission" "allow_secretsmanager" {
  count         = var.harden ? 1 : 0
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate_app_secret[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

resource "aws_secretsmanager_secret_rotation" "app_secret" {
  count               = var.harden ? 1 : 0
  secret_id           = data.terraform_remote_state.base.outputs.secret_arn
  rotation_lambda_arn = aws_lambda_function.rotate_app_secret[0].arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [aws_lambda_permission.allow_secretsmanager]
}

# Resource policy on base's secret -- THIS DAY'S "DOOR". Explicit Allows
# for exactly the two principals that legitimately need it -- SPLIT by
# least privilege, not a shared blanket grant: the task execution role
# only ever needs to READ the secret at task launch (see
# aws_iam_role_policy.task_execution_secrets above, which grants it
# nothing else), so it gets GetSecretValue + DescribeSecret only; the
# rotation Lambda is the one principal that actually needs to WRITE a new
# version, so it alone keeps PutSecretValue/UpdateSecretVersionStage --
# plus an explicit Deny backstop for everyone else's GetSecretValue.
# Because a resource policy is checked before identity-based policy in the
# evaluation order, this Deny holds even if some future identity policy
# elsewhere in the account tries to grant broader access to this secret.
# Note this only denies GetSecretValue, not PutSecretValue -- the
# out-of-band `aws secretsmanager put-secret-value` step documented in
# labs/base/README.md still works for whoever applied base.
# See labs/day05/SOLUTION.md "Resource-policy deny (test the deny path)"
# for the live test that exercises this Deny.
resource "aws_secretsmanager_secret_policy" "app_secret" {
  count      = var.harden ? 1 : 0
  secret_arn = data.terraform_remote_state.base.outputs.secret_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowTaskExecutionRoleReadOnly"
        Effect    = "Allow"
        Principal = { AWS = data.terraform_remote_state.base.outputs.task_execution_role_arn }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowRotationLambdaReadWrite"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.rotation_lambda[0].arn }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = "*"
      },
      {
        Sid       = "DenyGetSecretValueFromEverythingElse"
        Effect    = "Deny"
        Principal = "*"
        Action    = "secretsmanager:GetSecretValue"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              data.terraform_remote_state.base.outputs.task_execution_role_arn,
              aws_iam_role.rotation_lambda[0].arn
            ]
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# THE HARDEN, part 3 (harden = true): ACM certificate + HTTPS listener on
# base's ALB + HTTP->HTTPS redirect.
#
# ACM DOMAIN PREREQUISITE (read this before setting harden=true):
# A PUBLIC ACM certificate can only be ISSUED for a domain you actually
# control, proven via DNS validation. There is no way to skip this for a
# real public cert -- if var.domain_name/var.route53_zone_id are blank,
# this module does NOT pretend to issue one. Instead it falls back to
# IMPORTING a self-signed certificate into ACM (free, no domain needed,
# real TLS handshake on the listener -- browsers will show a trust
# warning, which is expected and explained in README). See content file
# "ACM domain prerequisite" section for the third option (ACM Private CA)
# and why it is discussed but never provisioned here.
# ---------------------------------------------------------------------------

# --- Path A: you own a domain + its Route53 zone -> real public cert -------

resource "aws_acm_certificate" "public" {
  count             = var.harden && local.use_public_cert ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = try(
    var.harden && local.use_public_cert ? {
      for dvo in aws_acm_certificate.public[0].domain_validation_options : dvo.domain_name => {
        name   = dvo.resource_record_name
        type   = dvo.resource_record_type
        record = dvo.resource_record_value
      }
    } : {},
    {}
  )

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "public" {
  count                   = var.harden && local.use_public_cert ? 1 : 0
  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# --- Path B (fallback): no domain -> import a self-signed cert -------------
# Free, no domain, no DNS validation wait. Teaches the TLS/listener
# plumbing end to end; the ONLY thing it can't teach is real public trust,
# which is exactly the prerequisite this module is honest about.

resource "tls_private_key" "selfsigned" {
  count     = var.harden && !local.use_public_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "selfsigned" {
  count           = var.harden && !local.use_public_cert ? 1 : 0
  private_key_pem = tls_private_key.selfsigned[0].private_key_pem

  subject {
    common_name  = var.fallback_common_name
    organization = "AWS Security Mastery Lab (self-signed -- no real domain)"
  }

  validity_period_hours = 24 * 30

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "imported" {
  count            = var.harden && !local.use_public_cert ? 1 : 0
  private_key      = tls_private_key.selfsigned[0].private_key_pem
  certificate_body = tls_self_signed_cert.selfsigned[0].cert_pem
  tags             = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# --- HTTPS listener + redirect (either cert path) ---------------------------

resource "aws_lb_listener" "https" {
  count             = var.harden ? 1 : 0
  load_balancer_arn = data.terraform_remote_state.base.outputs.alb_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.cert_arn

  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_listener.http.default_action[0].target_group_arn
  }

  tags = local.common_tags
}

# Additive rule on base's existing HTTP:80 listener (referenced by ARN, not
# owned/edited here) -- a wildcard redirect rule always wins over the
# listener's own default_action, so this achieves "HTTP->HTTPS redirect"
# without touching labs/base/edge.tf.
resource "aws_lb_listener_rule" "redirect_to_https" {
  count        = var.harden ? 1 : 0
  listener_arn = data.terraform_remote_state.base.outputs.alb_listener_arn
  priority     = 1

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
