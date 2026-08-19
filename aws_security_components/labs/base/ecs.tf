# ---------------------------------------------------------------------------
# ECS Fargate: cluster, task definition, service.
#
# COMPUTE/IMAGE DECISION:
# The app image must expose a server-side URL-fetch endpoint so the Day
# 8/11 SSRF lab can steal task-role credentials from the Fargate task
# metadata endpoint via the app itself. No suitable off-the-shelf public
# image does that safely, so the base workload ships its own minimal
# source at labs/base/app/ (Flask, ~40 lines: GET /fetch?url=<url> makes a
# server-side request and returns it verbatim — deliberately vulnerable by
# design, for use against your OWN deployed workload only). Build and push
# it to your own ECR repo once, then point `app_image` at it — see README
# "Build and push the app image". Until you do, `app_image` defaults to a
# placeholder URI that will fail to pull; every other resource in this
# workload still applies cleanly.
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  # Container Insights left at the provider default (disabled) to avoid the
  # extra CloudWatch metrics cost — not needed for this lab's teaching goals.

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name_prefix}-app"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# Task security group: inbound ONLY from the ALB security group (see
# edge.tf), egress open (needed for image pull, AWS API calls, and the
# SSRF-lab fetch target). A public IP on this ENI (network_configuration
# below) does not by itself expose the task — the SG is what gates inbound.
resource "aws_security_group" "task" {
  name        = "${local.name_prefix}-task-sg"
  description = "ECS task ENI — inbound from ALB only"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.common_tags, { Name = "${local.name_prefix}-task-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_container_port
  to_port                      = var.app_container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "task_all" {
  security_group_id = aws_security_group.task.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "-1"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.app_image
      essential = true
      portMappings = [
        {
          containerPort = var.app_container_port
          protocol      = "tcp"
        }
      ]
      # Non-secret pointers only — no secret material here. The task role
      # IS permitted to read the secret (secretsmanager:GetSecretValue, see
      # iam.tf), reachable via the AWS CLI/ECS Exec using this role's
      # credentials, but the app itself (app/app.py) never calls
      # GetSecretValue at runtime — /whoami only echoes this ARN string.
      environment = [
        { name = "APP_BUCKET", value = aws_s3_bucket.app_data.bucket },
        { name = "APP_TABLE", value = aws_dynamodb_table.app_data.name },
        { name = "APP_SECRET_ARN", value = aws_secretsmanager_secret.app_secret.arn },
        { name = "AWS_REGION", value = var.region }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "app" {
  name                   = "${local.name_prefix}-app-svc"
  cluster                = aws_ecs_cluster.this.arn
  task_definition        = aws_ecs_task_definition.app.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true # ECS Exec — needed by Day 7/8 labs; requires the ssmmessages:* grant on the task role in iam.tf

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true # NAT-free design — see network.tf
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name    = "app"
    container_port    = var.app_container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
}
