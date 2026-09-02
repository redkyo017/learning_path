# --- Compute: cluster, log group, IAM roles, task definition, service ---

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 1 # lab log group — keep costs and clutter near zero

  tags = {
    Name = "${var.name_prefix}-ecs-logs"
  }
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
  name = "${var.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name_prefix}-ecs-execution"
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task"

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
    Name = "${var.name_prefix}-ecs-task"
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name_prefix}-task"
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
      name      = "${var.name_prefix}-app"
      image     = "${data.terraform_remote_state.foundation.outputs.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      # Safe defaults for the steady state. README.md's Break it / Fix it
      # flips these on a NEW task definition revision to exercise
      # CodeDeploy's health-check gate + DEPLOYMENT_FAILURE auto-rollback
      # (POISON=true — NOT the ECS deployment circuit breaker, which only
      # applies to the ECS rolling-update controller, not the CODE_DEPLOY
      # controller this service uses) and the rollback alarm
      # (BURN_RATE=0.5) — that revision-flip-and-redeploy IS the lab, not
      # a mistake to fix here.
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

  tags = {
    Name = "${var.name_prefix}-task"
  }
}

resource "aws_ecs_service" "this" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets         = data.terraform_remote_state.foundation.outputs.public_subnet_ids
    security_groups = [aws_security_group.tasks.id]

    # No NAT gateway anywhere in this path: tasks run directly in the
    # foundation's PUBLIC subnets and get a public IP so they can reach the
    # internet (ECR image pulls, CloudWatch Logs) without one. That is the
    # cost trade this whole path makes — see content/day03.md.
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "${var.name_prefix}-app"
    container_port   = 8080
  }

  lifecycle {
    # Once CodeDeploy owns this service (deployment_controller.type =
    # CODE_DEPLOY, above), it registers new task definition revisions,
    # flips which target group "load_balancer" points at, and can adjust
    # desired_count during a deployment — all outside Terraform. Ignoring
    # these three fields stops `terraform apply` from reading CodeDeploy's
    # in-flight or completed work as configuration drift and reverting it
    # back to whatever Terraform last applied.
    ignore_changes = [task_definition, load_balancer, desired_count]
  }

  tags = {
    Name = "${var.name_prefix}-service"
  }
}
