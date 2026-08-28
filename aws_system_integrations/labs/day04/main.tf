###############################################################################
# Day 4 Lab — Service-to-Service Patterns
# Scenario: Order Lambda calls Payment Lambda mock via internal ALB (sync).
#           Order Lambda publishes audit events to SQS (async).
#           Consumer Lambda reads from SQS; DLQ catches failures after
#           maxReceiveCount=3 receive attempts.
#
# NEVER run terraform apply against a production account.
# NEVER commit real credentials to version control.
# All account IDs and access keys must be placeholders — see terraform.tfvars.example.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Credentials: set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars,
  # or use AWS SSO (`aws sso login`). Never hardcode here.
}

###############################################################################
# DATA SOURCES
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# VPC
# Single VPC. Internal ALB and all Lambdas live here.
# No Internet Gateway (Lambdas invoked via Lambda API, not HTTP from internet).
# A VPC Endpoint for Lambda is required for Lambda → Lambda calls within VPC.
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.4.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Two private subnets — internal ALB requires at least two AZs
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.4.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.environment}-private-a"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.4.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.environment}-private-b"
    Environment = var.environment
  }
}

# Route table for private subnets — no NAT GW, no IGW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

###############################################################################
# VPC ENDPOINTS
# Lambdas in private subnets need to reach SQS and Lambda API without NAT GW.
###############################################################################

# Security group for VPC Endpoints — allow HTTPS from within the VPC
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment}-vpc-endpoints-sg"
  description = "Allow HTTPS inbound from VPC for interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-vpc-endpoints-sg"
    Environment = var.environment
  }
}

# SQS Interface Endpoint — Order Lambda → SQS without NAT GW
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.environment}-sqs-endpoint"
    Environment = var.environment
  }
}

# Lambda Interface Endpoint — Order Lambda can invoke Payment Lambda via API
resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.environment}-lambda-endpoint"
    Environment = var.environment
  }
}

###############################################################################
# SECURITY GROUPS
###############################################################################

# ALB security group — allow HTTP from within VPC only (internal ALB)
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Internal ALB — allow HTTP from VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTP from within VPC only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# Lambda security group — allow outbound to ALB and VPC endpoints
resource "aws_security_group" "lambda" {
  name        = "${var.environment}-lambda-sg"
  description = "Lambda functions — outbound to ALB and VPC endpoints"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-lambda-sg"
    Environment = var.environment
  }
}

###############################################################################
# SQS QUEUES — Audit DLQ + Audit Queue
# DLQ defined first (audit_queue redrive_policy references DLQ ARN).
###############################################################################

resource "aws_sqs_queue" "audit_dlq" {
  name                       = "${var.environment}-audit-dlq"
  message_retention_seconds  = 1209600  # 14 days — enough to investigate weekend outages
  visibility_timeout_seconds = 30

  tags = {
    Environment = var.environment
    Purpose     = "DLQ for audit-queue"
  }
}

resource "aws_sqs_queue" "audit_queue" {
  name                       = "${var.environment}-audit-queue"
  visibility_timeout_seconds = 180  # 6x the Consumer Lambda timeout (30s)
  message_retention_seconds  = 345600  # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.audit_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Purpose     = "Audit event queue — order events"
  }
}

# CloudWatch alarm on DLQ depth — fires when any message lands in DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.environment}-audit-dlq-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Messages in audit DLQ — investigate unprocessable audit events"

  dimensions = {
    QueueName = aws_sqs_queue.audit_dlq.name
  }

  treat_missing_data = "notBreaching"
}

###############################################################################
# IAM — LAMBDA EXECUTION ROLES
###############################################################################

# Payment Lambda role — no SQS, no special permissions
resource "aws_iam_role" "payment_lambda" {
  name = "${var.environment}-payment-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "payment_lambda_logs" {
  role       = aws_iam_role.payment_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Order Lambda role — needs SQS SendMessage
resource "aws_iam_role" "order_lambda" {
  name = "${var.environment}-order-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "order_lambda_logs" {
  role       = aws_iam_role.order_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "order_lambda_sqs" {
  name = "${var.environment}-order-sqs-policy"
  role = aws_iam_role.order_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.audit_queue.arn
    }]
  })
}

# Consumer Lambda role — needs SQS ReceiveMessage, DeleteMessage, GetQueueAttributes
resource "aws_iam_role" "consumer_lambda" {
  name = "${var.environment}-consumer-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "consumer_lambda_logs" {
  role       = aws_iam_role.consumer_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "consumer_lambda_sqs" {
  name = "${var.environment}-consumer-sqs-policy"
  role = aws_iam_role.consumer_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ]
      Resource = aws_sqs_queue.audit_queue.arn
    }]
  })
}

###############################################################################
# LAMBDA FUNCTIONS — Inline Python code via archive_file
###############################################################################

# ── Payment Lambda (mock) ─────────────────────────────────────────────────────
# Returns 200 normally; returns 500 when PAYMENT_ERROR_RATE env var is set.
# Designed for ALB invocation — returns statusCode + body in ALB format.
locals {
  payment_lambda_code = <<-PYTHON
import os
import json
import random

def handler(event, context):
    # Health check path — always returns 200 (ALB needs this to register target)
    path = event.get("path", "/")
    if path == "/health":
        return {"statusCode": 200, "body": json.dumps({"status": "healthy"})}

    error_rate = int(os.environ.get("PAYMENT_ERROR_RATE", "0"))
    if error_rate >= 100 or random.randint(1, 100) <= error_rate:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "payment service simulated failure"})
        }

    order_id = json.loads(event.get("body", "{}")).get("order_id", "unknown")
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"order_id": order_id, "status": "payment_accepted"})
    }
PYTHON

  # ── Order Lambda ─────────────────────────────────────────────────────────────
  # Calls internal ALB synchronously, then publishes audit event to SQS.
  order_lambda_code = <<-PYTHON
import os
import json
import urllib.request
import urllib.error
import boto3

def handler(event, context):
    alb_url = os.environ["ALB_URL"]
    queue_url = os.environ["AUDIT_QUEUE_URL"]
    region = os.environ["AWS_REGION"]

    order_id = event.get("order_id", "unknown")
    amount = event.get("amount", 0.0)

    # Synchronous call to payment service via internal ALB
    payment_result = {"status": "unknown", "status_code": 0}
    try:
        payload = json.dumps({"order_id": order_id, "amount": amount}).encode()
        req = urllib.request.Request(
            f"{alb_url}/charge",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            payment_result["status_code"] = resp.status
            body = json.loads(resp.read())
            payment_result["status"] = body.get("status", "success")
    except urllib.error.HTTPError as e:
        payment_result["status_code"] = e.code
        payment_result["status"] = "error"
    except Exception as ex:
        payment_result["status"] = f"error: {str(ex)}"

    # Async publish to SQS (audit event — fire and forget)
    sqs = boto3.client("sqs", region_name=region)
    audit_sent = False
    try:
        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps({
                "order_id": order_id,
                "amount": amount,
                "payment_status": payment_result["status"],
                "payment_status_code": payment_result["status_code"]
            })
        )
        audit_sent = True
    except Exception as ex:
        # In production: use outbox pattern — do not swallow this silently
        print(f"WARN: audit SQS publish failed: {ex}")

    return {
        "order_id": order_id,
        "payment_status": payment_result["status"],
        "alb_status_code": payment_result["status_code"],
        "audit_sent": audit_sent
    }
PYTHON

  # ── Consumer Lambda (mock) ────────────────────────────────────────────────────
  # Processes audit events from SQS.
  # Throws an exception when CONSUMER_BROKEN=true — triggers DLQ redrive.
  consumer_lambda_code = <<-PYTHON
import os
import json

def handler(event, context):
    broken = os.environ.get("CONSUMER_BROKEN", "false").lower() == "true"
    if broken:
        # Simulate unprocessable message — SQS will retry until maxReceiveCount
        raise RuntimeError("Consumer broken — simulating unprocessable message")

    for record in event.get("Records", []):
        body = json.loads(record["body"])
        print(f"Audit record processed: order_id={body.get('order_id')}, "
              f"payment_status={body.get('payment_status')}")
    return {"processed": len(event.get("Records", []))}
PYTHON
}

# Archive files for each Lambda
data "archive_file" "payment_lambda" {
  type        = "zip"
  output_path = "${path.module}/.lambda_build/payment_lambda.zip"
  source {
    content  = local.payment_lambda_code
    filename = "handler.py"
  }
}

data "archive_file" "order_lambda" {
  type        = "zip"
  output_path = "${path.module}/.lambda_build/order_lambda.zip"
  source {
    content  = local.order_lambda_code
    filename = "handler.py"
  }
}

data "archive_file" "consumer_lambda" {
  type        = "zip"
  output_path = "${path.module}/.lambda_build/consumer_lambda.zip"
  source {
    content  = local.consumer_lambda_code
    filename = "handler.py"
  }
}

# Payment Lambda
resource "aws_lambda_function" "payment" {
  function_name    = "${var.environment}-payment-mock"
  role             = aws_iam_role.payment_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.payment_lambda.output_path
  source_code_hash = data.archive_file.payment_lambda.output_base64sha256

  environment {
    variables = {
      PAYMENT_ERROR_RATE = tostring(var.payment_error_rate)
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Environment = var.environment
  }
}

# ALB permission to invoke Payment Lambda
resource "aws_lambda_permission" "alb_invoke_payment" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.payment.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.payment.arn
}

# Order Lambda
resource "aws_lambda_function" "order" {
  function_name    = "${var.environment}-order-mock"
  role             = aws_iam_role.order_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.order_lambda.output_path
  source_code_hash = data.archive_file.order_lambda.output_base64sha256

  environment {
    variables = {
      ALB_URL          = "http://${aws_lb.internal.dns_name}"
      AUDIT_QUEUE_URL  = aws_sqs_queue.audit_queue.url
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Environment = var.environment
  }
}

# Consumer Lambda
resource "aws_lambda_function" "consumer" {
  function_name    = "${var.environment}-audit-consumer-mock"
  role             = aws_iam_role.consumer_lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.consumer_lambda.output_path
  source_code_hash = data.archive_file.consumer_lambda.output_base64sha256

  environment {
    variables = {
      CONSUMER_BROKEN = tostring(var.consumer_broken)
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Environment = var.environment
  }
}

# SQS event source mapping — Consumer Lambda reads from audit-queue
resource "aws_lambda_event_source_mapping" "consumer_sqs" {
  event_source_arn                   = aws_sqs_queue.audit_queue.arn
  function_name                      = aws_lambda_function.consumer.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  enabled                            = true
}

###############################################################################
# INTERNAL APPLICATION LOAD BALANCER
# scheme = "internal" — no public IP, only reachable within VPC.
###############################################################################

resource "aws_lb" "internal" {
  name               = "${var.environment}-payment-alb"
  internal           = true   # scheme=internal — key difference from public ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  # Access logs disabled for lab — enable in production
  # access_logs { ... }

  tags = {
    Environment = var.environment
    Purpose     = "Internal ALB routing to payment Lambda mock"
  }
}

# Target group — Lambda target type
resource "aws_lb_target_group" "payment" {
  name        = "${var.environment}-payment-tg"
  target_type = "lambda"

  health_check {
    enabled             = true
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Environment = var.environment
  }
}

# Register Payment Lambda as the ALB target
resource "aws_lb_target_group_attachment" "payment" {
  target_group_arn = aws_lb_target_group.payment.arn
  target_id        = aws_lambda_function.payment.arn
  depends_on       = [aws_lambda_permission.alb_invoke_payment]
}

# ALB Listener on port 80 — forward all traffic to payment target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payment.arn
  }
}

###############################################################################
# OUTPUTS
###############################################################################

output "alb_dns_name" {
  description = "Internal ALB DNS name — only reachable from within the VPC."
  value       = aws_lb.internal.dns_name
}

output "audit_queue_url" {
  description = "SQS audit queue URL."
  value       = aws_sqs_queue.audit_queue.url
}

output "audit_dlq_url" {
  description = "SQS audit DLQ URL."
  value       = aws_sqs_queue.audit_dlq.url
}

output "order_lambda_name" {
  description = "Order Lambda function name — use for aws lambda invoke."
  value       = aws_lambda_function.order.function_name
}

output "payment_lambda_name" {
  description = "Payment Lambda function name."
  value       = aws_lambda_function.payment.function_name
}

output "consumer_lambda_name" {
  description = "Consumer Lambda function name."
  value       = aws_lambda_function.consumer.function_name
}
