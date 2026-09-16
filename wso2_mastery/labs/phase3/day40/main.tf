# Day 40 Lab — ECS Cluster + Control Plane + IS Task Definitions
# AUTHORED LAB — do NOT run terraform apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── ECS Cluster with Container Insights ──────────────────────────────────────

resource "aws_ecs_cluster" "wso2" {
  name = "${var.environment}-wso2"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "wso2" {
  cluster_name       = aws_ecs_cluster.wso2.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── IAM Roles ────────────────────────────────────────────────────────────────

# Execution role: for ECS agent to pull images and write logs
resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-wso2-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution_basic" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: for container runtime AWS permissions (Secrets Manager, etc.)
resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-wso2-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Task role policy: allow reading WSO2 secrets
resource "aws_iam_role_policy" "task_secrets" {
  name = "wso2-secrets-read"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.environment}/wso2/*"
      # TODO: replace var.aws_account_id with your account ID in variables.tf
    }]
  })
}

# ── CloudWatch Log Groups ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "cp" {
  name              = "/ecs/${var.environment}/wso2-cp"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "is" {
  name              = "/ecs/${var.environment}/wso2-is"
  retention_in_days = 7
}

# ── Control Plane Task Definition ────────────────────────────────────────────

resource "aws_ecs_task_definition" "cp" {
  family                   = "${var.environment}-wso2-cp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-cp"
    image     = var.image_uri_cp
    essential = true
    portMappings = [
      { containerPort = 9443, protocol = "tcp" },
      { containerPort = 9611, protocol = "tcp" },
      { containerPort = 9711, protocol = "tcp" }
    ]
    environment = [
      { name = "WSO2_ENV", value = var.environment }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.cp.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf https://localhost:9443/services/Version || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 120
    }
  }])
}

# ── Identity Server Task Definition ──────────────────────────────────────────

resource "aws_ecs_task_definition" "is" {
  family                   = "${var.environment}-wso2-is"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-is"
    image     = var.image_uri_is
    essential = true
    portMappings = [
      { containerPort = 9443, protocol = "tcp" },
      { containerPort = 9763, protocol = "tcp" }
    ]
    environment = [
      { name = "WSO2_ENV", value = var.environment }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.is.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf -X HEAD https://localhost:9443/oauth2/token || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 120
    }
  }])
}
