# Day 42 Lab — All Day 41 resources PLUS Security Groups + Autoscaling
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

# ────────────────────────────────────────────────────────────────────────────
# DAY 40 AND DAY 41 RESOURCES (copied verbatim)
# ────────────────────────────────────────────────────────────────────────────

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

resource "aws_cloudwatch_log_group" "gw" {
  name              = "/ecs/${var.environment}/wso2-gw"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "tm" {
  name              = "/ecs/${var.environment}/wso2-tm"
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

# ── GW Task Definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "gw" {
  family                   = "${var.environment}-wso2-gw"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-gw"
    image     = var.image_uri_gw
    essential = true
    portMappings = [
      { containerPort = 8280, protocol = "tcp" },
      { containerPort = 8243, protocol = "tcp" }
    ]
    environment = [
      { name = "WSO2_CP_URL", value = "https://cp.wso2.internal:9443" },
      { name = "WSO2_IS_URL", value = "https://is.wso2.internal:9443" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.gw.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf https://localhost:8243/services/Version || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 90
    }
  }])
}

# ── TM Task Definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "tm" {
  family                   = "${var.environment}-wso2-tm"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "wso2-tm"
    image     = var.image_uri_tm
    essential = true
    portMappings = [
      { containerPort = 9611, protocol = "tcp" },
      { containerPort = 9711, protocol = "tcp" },
      { containerPort = 9443, protocol = "tcp" }
    ]
    environment = [
      { name = "WSO2_ENV", value = var.environment }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.tm.name
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

# ── ALB Security Group ───────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name   = "${var.environment}-wso2-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet (redirect to HTTPS)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# ── ALB for GW ───────────────────────────────────────────────────────────────

resource "aws_lb" "gw" {
  name               = "${var.environment}-wso2-gw"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

# ── ALB Target Group ─────────────────────────────────────────────────────────

resource "aws_lb_target_group" "gw" {
  name        = "${var.environment}-wso2-gw"
  port        = 8243
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/services/Version"
    protocol            = "HTTPS"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}

# ── ALB HTTPS Listener ───────────────────────────────────────────────────────

resource "aws_lb_listener" "gw_https" {
  load_balancer_arn = aws_lb.gw.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gw.arn
  }
}

# ── ALB HTTP Listener (redirect to HTTPS) ────────────────────────────────────

resource "aws_lb_listener" "gw_http" {
  load_balancer_arn = aws_lb.gw.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ────────────────────────────────────────────────────────────────────────────
# DAY 42 NEW RESOURCES: SECURITY GROUPS + AUTOSCALING
# ────────────────────────────────────────────────────────────────────────────

# ── GW Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "gw" {
  name   = "${var.environment}-wso2-gw"
  vpc_id = var.vpc_id

  # Allow ALB to call GW on HTTPS
  ingress {
    from_port       = 8243
    to_port         = 8243
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTPS from ALB"
  }

  # Allow ALB to call GW on HTTP (if used)
  ingress {
    from_port       = 8280
    to_port         = 8280
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
  }

  # Egress: allow GW to reach anywhere (CP, IS, TM, internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# ── CP Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "cp" {
  name   = "${var.environment}-wso2-cp"
  vpc_id = var.vpc_id

  # Allow GW to call CP on 9443
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.gw.id]
    description     = "API calls and event hub from GW"
  }

  # Allow TM to call CP on 9443 (for event hub)
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.tm.id]
    description     = "Event hub subscription from TM"
  }

  # Egress: allow CP to reach anywhere (internet, Secrets Manager)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# ── IS Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "is" {
  name   = "${var.environment}-wso2-is"
  vpc_id = var.vpc_id

  # Allow GW to call IS on 9443 (JWKS endpoint)
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.gw.id]
    description     = "JWKS endpoint from GW"
  }

  # Allow CP to call IS on 9443 (key manager config)
  ingress {
    from_port       = 9443
    to_port         = 9443
    protocol        = "tcp"
    security_groups = [aws_security_group.cp.id]
    description     = "Key manager config from CP"
  }

  # Egress: allow IS to reach anywhere (internet, databases)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# ── TM Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "tm" {
  name   = "${var.environment}-wso2-tm"
  vpc_id = var.vpc_id

  # Allow GW to call TM on 9611/9711 (throttle policy sync)
  ingress {
    from_port       = 9611
    to_port         = 9711
    protocol        = "tcp"
    security_groups = [aws_security_group.gw.id]
    description     = "Event hub from GW"
  }

  # Egress: allow TM to reach anywhere (CP for event hub)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# ── Auto Scaling for GW (stateless, can scale horizontally) ──────────────────

resource "aws_appautoscaling_target" "gw" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${var.environment}-wso2-gw"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "gw_cpu" {
  name               = "${var.environment}-wso2-gw-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.gw.resource_id
  scalable_dimension = aws_appautoscaling_target.gw.scalable_dimension
  service_namespace  = aws_appautoscaling_target.gw.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ── Auto Scaling for TM (stateless, can scale horizontally) ──────────────────

resource "aws_appautoscaling_target" "tm" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.wso2.name}/${var.environment}-wso2-tm"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "tm_cpu" {
  name               = "${var.environment}-wso2-tm-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.tm.resource_id
  scalable_dimension = aws_appautoscaling_target.tm.scalable_dimension
  service_namespace  = aws_appautoscaling_target.tm.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Note: CP and IS are intentionally NOT autoscaled (no aws_appautoscaling_target).
# They maintain state in-memory and require shared external storage (DB, Redis)
# for horizontal scaling. For this lab, they stay at fixed 1 replica.
