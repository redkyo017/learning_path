# Day 56 Lab — ECS Fargate Autoscaling for GW and TM
# Includes all Day 42 task definitions + autoscaling resources
# AUTHORED LAB — do NOT run terraform apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = var.aws_region }

# ── ECS Cluster ──────────────────────────────────────────────────────────────

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

# ── IAM Roles and Policies ───────────────────────────────────────────────────

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

# ── ECS Task Definitions (Stubs from Day 42) ─────────────────────────────────

# Note: Full task definitions would include:
# - container_definitions with image URI, port mappings, logging
# - environment variables for JVM opts, WSO2 config
# - volume mounts for persistent config
# These are simplified stubs; in production, fetch from ECR and mount config from S3/secrets

resource "aws_ecs_task_definition" "gw" {
  family                   = "${var.environment}-wso2-gw"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "gw"
    image = "TODO_REPLACE_GW_IMAGE_URI"
    portMappings = [{
      containerPort = 8280
      hostPort      = 8280
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/wso2-gw"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    environment = [
      { name = "WSO2_GW_MAX_TASKS", value = "4" },
      { name = "JVM_MEM_OPTS", value = "-Xmx1024m -Xms512m" }
    ]
  }])
}

resource "aws_ecs_task_definition" "tm" {
  family                   = "${var.environment}-wso2-tm"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "tm"
    image = "TODO_REPLACE_TM_IMAGE_URI"
    portMappings = [
      { containerPort = 9611, hostPort = 9611, protocol = "tcp" },
      { containerPort = 9711, hostPort = 9711, protocol = "tcp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/wso2-tm"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    environment = [
      { name = "WSO2_TM_MAX_TASKS", value = "2" },
      { name = "JVM_MEM_OPTS", value = "-Xmx1024m -Xms512m" }
    ]
  }])
}

resource "aws_ecs_task_definition" "cp" {
  family                   = "${var.environment}-wso2-cp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "cp"
    image = "TODO_REPLACE_CP_IMAGE_URI"
    portMappings = [
      { containerPort = 9443, hostPort = 9443, protocol = "tcp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/wso2-cp"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    environment = [
      { name = "WSO2_CP_ROLE", value = "admin" },
      { name = "JVM_MEM_OPTS", value = "-Xmx1024m -Xms512m" }
    ]
  }])
}

resource "aws_ecs_task_definition" "is" {
  family                   = "${var.environment}-wso2-is"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "is"
    image = "TODO_REPLACE_IS_IMAGE_URI"
    portMappings = [
      { containerPort = 9443, hostPort = 9443, protocol = "tcp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/wso2-is"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    environment = [
      { name = "WSO2_IS_ROLE", value = "identity-server" },
      { name = "MAX_SESSIONS_PER_USER", value = "100" },
      { name = "JVM_MEM_OPTS", value = "-Xmx1024m -Xms512m" }
    ]
  }])
}

# ── ECS Services ─────────────────────────────────────────────────────────────

resource "aws_ecs_service" "gw" {
  name            = "${var.environment}-wso2-gw"
  cluster         = aws_ecs_cluster.wso2.id
  task_definition = aws_ecs_task_definition.gw.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.gw_sg_id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [desired_count]  # Autoscaling manages this
  }

  depends_on = [aws_ecs_task_definition.gw]
}

resource "aws_ecs_service" "tm" {
  name            = "${var.environment}-wso2-tm"
  cluster         = aws_ecs_cluster.wso2.id
  task_definition = aws_ecs_task_definition.tm.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.tm_sg_id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [desired_count]  # Autoscaling manages this
  }

  depends_on = [aws_ecs_task_definition.tm]
}

resource "aws_ecs_service" "cp" {
  name            = "${var.environment}-wso2-cp"
  cluster         = aws_ecs_cluster.wso2.id
  task_definition = aws_ecs_task_definition.cp.arn
  desired_count   = 1  # Fixed replica
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.cp_sg_id]
    assign_public_ip = false
  }

  depends_on = [aws_ecs_task_definition.cp]
}

resource "aws_ecs_service" "is" {
  name            = "${var.environment}-wso2-is"
  cluster         = aws_ecs_cluster.wso2.id
  task_definition = aws_ecs_task_definition.is.arn
  desired_count   = 1  # Fixed replica
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.is_sg_id]
    assign_public_ip = false
  }

  depends_on = [aws_ecs_task_definition.is]
}

# ── Autoscaling Targets ──────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.gw.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_target" "tm" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${aws_ecs_service.tm.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# ── Autoscaling Policies (Target Tracking) ──────────────────────────────────

resource "aws_appautoscaling_policy" "gw_cpu" {
  name               = "${var.environment}-gw-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 120  # GW startup ~90s; cooldown > startup

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "tm_cpu" {
  name               = "${var.environment}-tm-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.tm.resource_id
  scalable_dimension = aws_appautoscaling_target.tm.scalable_dimension
  service_namespace  = aws_appautoscaling_target.tm.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 120

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── CloudWatch Alarm: GW CPU High ────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "gw_cpu_high" {
  alarm_name          = "${var.environment}-gw-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "GW CPU above 80% — may indicate throttle misconfiguration or backend slowness"
  alarm_actions       = [var.sns_alert_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.wso2.name
    ServiceName = aws_ecs_service.gw.name
  }
}
