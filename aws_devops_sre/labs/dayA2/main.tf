# Day A2 — AWS CLI mastery appendix: a small ECS Fargate stack for CLI drills.
#
# Deliberately ALB-less and NAT-less: nothing in this day's drills routes
# traffic, so there is no load balancer, and tasks run in the foundation's
# public subnets with a public IP instead of paying for a NAT gateway.
# Cost while this stack is up: ~$0.0099/h for one arm64 Fargate task
# (0.25 vCPU / 0.5 GB), plus the CloudWatch alarm (10 free) and whatever
# this stack's own log group ingests.
#
# It also deliberately omits `lifecycle { ignore_changes = ... }` on the
# ECS service below, unlike `labs/day03/ecs.tf`. Day A2's drift-hunt drill
# has the learner mutate the running service by CLI and then run
# `terraform plan` to see that drift reported — an `ignore_changes` block
# would silently swallow exactly the change the drill depends on seeing.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.name_prefix
      ManagedBy = "terraform"
      Path      = "aws_devops_sre"
    }
  }
}

# Read the VPC, public subnets, and ECR repository built once in Day 1 and
# shared by every lab in this path. This stack creates no networking of its
# own beyond a security group — the VPC and subnets are borrowed.
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = "../foundation/terraform.tfstate"
  }
}

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

# --- IAM: execution role vs. task role -----------------------------------
#
# Two different roles, two different jobs, and two different failure modes:
#   - EXECUTION role: assumed by the ECS agent BEFORE your application code
#     runs, to pull the container image from ECR and ship logs to
#     CloudWatch. If a task fails to START with an image-pull error, this
#     role (or its AmazonECSTaskExecutionRolePolicy attachment) is wrong.
#   - TASK role: assumed by YOUR application code at runtime, to call other
#     AWS APIs (S3, DynamoDB, Secrets Manager, ...). If your code itself
#     gets an AccessDenied calling AWS, this role is wrong — never the
#     execution role.
# This sample app calls no AWS APIs, so the task role below is deliberately
# left with no policies attached — it exists to show the shape of the
# distinction, not because this particular app needs any permissions yet.

resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-cli-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name_prefix}-cli-ecs-execution"
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-cli-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  # No policies attached. Attach here — never on the execution role above —
  # the moment this app's code needs to call an AWS API of its own.

  tags = {
    Name = "${var.name_prefix}-cli-ecs-task"
  }
}

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
