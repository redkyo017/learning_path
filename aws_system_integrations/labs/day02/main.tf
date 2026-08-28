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
}

# ---------------------------------------------------------------------------
# Data — Amazon Linux 2 latest AMI (avoids hardcoded AMI IDs)
# ---------------------------------------------------------------------------

data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Networking — use the account's default VPC and its subnets
# ---------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Allow inbound HTTP to ALB from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
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

resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Allow inbound HTTP from ALB security group only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-ec2-sg"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# EC2 instance — v1 mock payments API server
# Responds with {"version":"v1",...} on port 80 via a minimal Python HTTP server
# ---------------------------------------------------------------------------

resource "aws_instance" "api_v1" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = <<-SHELL
    #!/bin/bash
    yum install -y python3
    cat > /tmp/server.py <<'PYEOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({
            "version": "v1",
            "message": "payments API v1",
            "status": "ok"
        })
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Served-By", "api-v1")
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        pass  # suppress access log noise in instance console

HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
PYEOF
    nohup python3 /tmp/server.py > /var/log/api-server.log 2>&1 &
  SHELL

  tags = {
    Name        = "${var.environment}-api-v1"
    Environment = var.environment
    Version     = "v1"
  }
}

# ---------------------------------------------------------------------------
# EC2 instance — v2 mock payments API server
# Responds with {"version":"v2",...} — simulates the new version with
# enhanced fraud signal fields
# ---------------------------------------------------------------------------

resource "aws_instance" "api_v2" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[1]
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = <<-SHELL
    #!/bin/bash
    yum install -y python3
    cat > /tmp/server.py <<'PYEOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({
            "version": "v2",
            "message": "payments API v2 — enhanced fraud signals",
            "fraud_score_enabled": True,
            "status": "ok"
        })
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("X-Served-By", "api-v2")
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        pass

HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
PYEOF
    nohup python3 /tmp/server.py > /var/log/api-server.log 2>&1 &
  SHELL

  tags = {
    Name        = "${var.environment}-api-v2"
    Environment = var.environment
    Version     = "v2"
  }
}

# ---------------------------------------------------------------------------
# Target groups
# ---------------------------------------------------------------------------

resource "aws_lb_target_group" "v1" {
  name     = "${var.environment}-v1-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${var.environment}-v1-tg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "v2" {
  name     = "${var.environment}-v2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "${var.environment}-v2-tg"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# Target group attachments — register EC2 instances into their target groups
# ---------------------------------------------------------------------------

resource "aws_lb_target_group_attachment" "v1" {
  target_group_arn = aws_lb_target_group.v1.arn
  target_id        = aws_instance.api_v1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "v2" {
  target_group_arn = aws_lb_target_group.v2.arn
  target_id        = aws_instance.api_v2.id
  port             = 80
}

# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
  }
}

# ---------------------------------------------------------------------------
# Listener — port 80
# Default action: weighted canary forward (v1: 100-v2_weight, v2: v2_weight)
# This is the fallback when no explicit listener rule matches the request.
# ---------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.v1.arn
        weight = 100 - var.v2_weight
      }

      target_group {
        arn    = aws_lb_target_group.v2.arn
        weight = var.v2_weight
      }

      stickiness {
        enabled  = false
        duration = 1  # irrelevant when stickiness is disabled
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Listener rule — header-based routing (priority 1)
#
# Requests with the HTTP header "x-api-version: v2" are always forwarded
# to v2-tg, regardless of the canary weight in the default action.
# Priority 1 means this rule is evaluated BEFORE any other rule and before
# the default action. Lower number = higher priority in ALB rule evaluation.
#
# Use case: QA team sends this header to pin to v2; production clients send
# no such header and get the weighted split.
# ---------------------------------------------------------------------------

resource "aws_lb_listener_rule" "header_v2" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1  # must be lower number than any other rule (higher priority)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.v2.arn
  }

  condition {
    http_header {
      http_header_name = "x-api-version"
      values           = ["v2"]
    }
  }
}

# ---------------------------------------------------------------------------
# WAF Web ACL — rate-based rule to demonstrate fraud-signal blocking
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "banking_api_waf" {
  name        = "${var.environment}-banking-waf"
  description = "WAF for core banking API — rate limiting + custom fraud header rule"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Count requests with suspicious fraud-signal header
  rule {
    name     = "FraudSignalHeaderCount"
    priority = 1

    action {
      count {}
    }

    statement {
      byte_match_statement {
        field_to_match {
          single_header {
            name = "x-fraud-signal"
          }
        }
        positional_constraint = "EXACTLY"
        search_string         = "high-risk"
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "FraudSignalHeader"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Rate-based rule — block IPs exceeding 100 req/5min
  rule {
    name     = "RateLimitPerIP"
    priority = 2

    action {
      count {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIP"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-banking-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Environment = var.environment
  }
}

# Associate WAF with the ALB
resource "aws_wafv2_web_acl_association" "alb_waf" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.banking_api_waf.arn
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "alb_dns_name" {
  description = "ALB DNS name — use this as the base URL for curl tests"
  value       = aws_lb.main.dns_name
}

output "v1_instance_id" {
  description = "EC2 instance ID for the v1 mock server (for Break it exercise)"
  value       = aws_instance.api_v1.id
}

output "v2_instance_id" {
  description = "EC2 instance ID for the v2 mock server (for Break it exercise)"
  value       = aws_instance.api_v2.id
}

output "v1_target_group_arn" {
  description = "ARN of the v1 target group"
  value       = aws_lb_target_group.v1.arn
}

output "v2_target_group_arn" {
  description = "ARN of the v2 target group (use in Break it exercise)"
  value       = aws_lb_target_group.v2.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN associated with the ALB"
  value       = aws_wafv2_web_acl.banking_api_waf.arn
}
