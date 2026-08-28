###############################################################################
# Day 3 Lab — Egress + VPC Boundary Patterns
# Scenario: Payment processor Lambda (private subnet, no NAT GW) reaching
# S3 via Gateway Endpoint, SQS via Interface Endpoint, and a mock card vault
# service via PrivateLink (NLB-backed VPC Endpoint Service in provider VPC).
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

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Availability zones in the region (need at least 2 for multi-AZ endpoints)
data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# CONSUMER VPC
# Represents the payment processor environment.
# No NAT Gateway. No Internet Gateway.
# Lambda can only reach external services via VPC Endpoints.
###############################################################################

resource "aws_vpc" "consumer" {
  cidr_block           = var.consumer_vpc_cidr
  enable_dns_support   = true  # required for Interface Endpoint private DNS
  enable_dns_hostnames = true  # required for Interface Endpoint private DNS

  tags = {
    Name        = "${var.environment}-consumer-vpc"
    Environment = var.environment
    Purpose     = "payment-processor"
  }
}

# Two private subnets across two AZs for multi-AZ endpoint coverage
resource "aws_subnet" "consumer_private_a" {
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = cidrsubnet(var.consumer_vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.environment}-consumer-private-a"
  }
}

resource "aws_subnet" "consumer_private_b" {
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = cidrsubnet(var.consumer_vpc_cidr, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.environment}-consumer-private-b"
  }
}

# Route table for private subnets — no default route to NAT or internet
resource "aws_route_table" "consumer_private" {
  vpc_id = aws_vpc.consumer.id

  tags = {
    Name = "${var.environment}-consumer-private-rt"
  }
}

resource "aws_route_table_association" "consumer_private_a" {
  subnet_id      = aws_subnet.consumer_private_a.id
  route_table_id = aws_route_table.consumer_private.id
}

resource "aws_route_table_association" "consumer_private_b" {
  subnet_id      = aws_subnet.consumer_private_b.id
  route_table_id = aws_route_table.consumer_private.id
}

###############################################################################
# S3 GATEWAY ENDPOINT
# Free. Adds prefix-list routes to the route table automatically.
# Lambda calls s3.amazonaws.com — packet is routed via the endpoint,
# never through NAT or internet.
###############################################################################

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.consumer.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.consumer_private.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBucketAccessFromEndpoint"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.transaction_logs.arn,
          "${aws_s3_bucket.transaction_logs.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "${var.environment}-s3-gateway-endpoint"
  }
}

###############################################################################
# SQS INTERFACE ENDPOINT
# Creates an ENI in each private subnet.
# private_dns_enabled = true: sqs.region.amazonaws.com resolves to private IP
# inside this VPC. No code change required in Lambda.
###############################################################################

resource "aws_security_group" "sqs_endpoint" {
  name        = "${var.environment}-sqs-endpoint-sg"
  description = "Allow HTTPS from Lambda to SQS Interface Endpoint"
  vpc_id      = aws_vpc.consumer.id

  ingress {
    description     = "HTTPS from Lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-sqs-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.consumer.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true  # overrides public DNS inside this VPC

  subnet_ids = [
    aws_subnet.consumer_private_a.id,
    aws_subnet.consumer_private_b.id,
  ]

  security_group_ids = [aws_security_group.sqs_endpoint.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSQSFromLambdaRole"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.lambda_exec.arn }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.audit_queue.arn
      }
    ]
  })

  tags = {
    Name = "${var.environment}-sqs-interface-endpoint"
  }
}

###############################################################################
# S3 BUCKET — Transaction logs
###############################################################################

resource "aws_s3_bucket" "transaction_logs" {
  bucket        = "${var.environment}-transaction-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true  # Automatically empties bucket on terraform destroy (versioning enabled)

  tags = {
    Name        = "${var.environment}-transaction-logs"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "transaction_logs" {
  bucket = aws_s3_bucket.transaction_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transaction_logs" {
  bucket = aws_s3_bucket.transaction_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Restrict bucket to VPC endpoint only (enforce private path)
resource "aws_s3_bucket_policy" "transaction_logs" {
  bucket = aws_s3_bucket.transaction_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonVpcEndpointAccess"
        Effect = "Deny"
        Principal = "*"
        Action = ["s3:GetObject", "s3:PutObject"]
        Resource = [
          aws_s3_bucket.transaction_logs.arn,
          "${aws_s3_bucket.transaction_logs.arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.s3_gateway.id
          }
        }
      },
      {
        Sid    = "AllowLambdaViaEndpoint"
        Effect = "Allow"
        Principal = { AWS = aws_iam_role.lambda_exec.arn }
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.transaction_logs.arn}/*"
      }
    ]
  })
}

###############################################################################
# SQS QUEUE — Audit events
###############################################################################

resource "aws_sqs_queue" "audit_queue" {
  name                      = "${var.environment}-audit-queue"
  message_retention_seconds = 86400  # 1 day for lab purposes

  tags = {
    Name        = "${var.environment}-audit-queue"
    Environment = var.environment
  }
}

# Restrict queue to VPC endpoint
resource "aws_sqs_queue_policy" "audit_queue" {
  queue_url = aws_sqs_queue.audit_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowFromVpcEndpointOnly"
        Effect = "Allow"
        Principal = { AWS = aws_iam_role.lambda_exec.arn }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.audit_queue.arn
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.sqs.id
          }
        }
      }
    ]
  })
}

###############################################################################
# LAMBDA — Payment processor
# Runs in private subnet. No NAT GW. Must reach S3 + SQS via endpoints only.
###############################################################################

resource "aws_security_group" "lambda" {
  name        = "${var.environment}-lambda-sg"
  description = "Lambda payment processor security group"
  vpc_id      = aws_vpc.consumer.id

  egress {
    description = "Allow all outbound (endpoints, not internet)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-lambda-sg"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-payment-processor-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.environment}-lambda-role"
  }
}

resource "aws_iam_role_policy" "lambda_exec" {
  name = "${var.environment}-payment-processor-lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.transaction_logs.arn}/*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.audit_queue.arn
      },
      {
        Sid    = "VaultServiceAccess"
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "ENIForVpc"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# Inline Lambda code — writes a test record to S3 and publishes a message to SQS
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/payment_processor.zip"

  source {
    content  = <<-PYTHON
import boto3
import json
import os
import datetime

def handler(event, context):
    region     = os.environ['AWS_REGION']
    bucket     = os.environ['S3_BUCKET']
    queue_url  = os.environ['SQS_QUEUE_URL']
    vault_url  = os.environ.get('VAULT_ENDPOINT_URL', '')

    s3  = boto3.client('s3',  region_name=region)
    sqs = boto3.client('sqs', region_name=region)

    # Write transaction log to S3 via Gateway Endpoint
    key  = f"logs/{datetime.datetime.utcnow().isoformat()}.json"
    body = json.dumps({"event": "payment_processed", "amount": 100.00})
    s3.put_object(Bucket=bucket, Key=key, Body=body)
    print(f"S3 write OK: s3://{bucket}/{key}")

    # Send audit event to SQS via Interface Endpoint
    sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps({"event": "audit", "key": key})
    )
    print("SQS publish OK")

    return {"statusCode": 200, "body": "Payment processor invoked successfully"}
PYTHON
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "payment_processor" {
  function_name    = "${var.environment}-payment-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  vpc_config {
    subnet_ids         = [aws_subnet.consumer_private_a.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET          = aws_s3_bucket.transaction_logs.bucket
      SQS_QUEUE_URL      = aws_sqs_queue.audit_queue.url
      VAULT_ENDPOINT_URL = "https://${aws_vpc_endpoint.vault_service.dns_entry[0].dns_name}"
    }
  }

  tags = {
    Name = "${var.environment}-payment-processor"
  }

  depends_on = [
    aws_vpc_endpoint.s3_gateway,
    aws_vpc_endpoint.sqs,
    aws_vpc_endpoint.vault_service,
    aws_iam_role_policy.lambda_exec,
  ]
}

###############################################################################
# VPC FLOW LOGS — Consumer VPC
# Used in the Break it exercise: observe traffic dropping when endpoint deleted.
###############################################################################

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/flow-logs/${var.environment}-consumer"
  retention_in_days = 3  # short retention for lab cost control

  tags = {
    Name = "${var.environment}-consumer-vpc-flow-logs"
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "consumer" {
  vpc_id          = aws_vpc.consumer.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = {
    Name = "${var.environment}-consumer-flow-log"
  }
}

###############################################################################
# PROVIDER VPC
# Represents the card vault service (PCI account simulation).
# Contains: NLB, mock EC2 vault service, VPC Endpoint Service (PrivateLink).
###############################################################################

resource "aws_vpc" "provider" {
  cidr_block           = var.provider_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-provider-vpc"
    Environment = var.environment
    Purpose     = "card-vault"
  }
}

resource "aws_subnet" "provider_private_a" {
  vpc_id            = aws_vpc.provider.id
  cidr_block        = cidrsubnet(var.provider_vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.environment}-provider-private-a"
  }
}

resource "aws_subnet" "provider_private_b" {
  vpc_id            = aws_vpc.provider.id
  cidr_block        = cidrsubnet(var.provider_vpc_cidr, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.environment}-provider-private-b"
  }
}

resource "aws_route_table" "provider_private" {
  vpc_id = aws_vpc.provider.id

  tags = {
    Name = "${var.environment}-provider-private-rt"
  }
}

resource "aws_route_table_association" "provider_private_a" {
  subnet_id      = aws_subnet.provider_private_a.id
  route_table_id = aws_route_table.provider_private.id
}

resource "aws_route_table_association" "provider_private_b" {
  subnet_id      = aws_subnet.provider_private_b.id
  route_table_id = aws_route_table.provider_private.id
}

###############################################################################
# MOCK CARD VAULT — EC2 instance (provider VPC)
# A real lab would run the actual vault service. This mock runs a simple
# HTTP server for connectivity testing purposes.
###############################################################################

resource "aws_security_group" "vault_ec2" {
  name        = "${var.environment}-vault-ec2-sg"
  description = "Card vault EC2 security group"
  vpc_id      = aws_vpc.provider.id

  ingress {
    description     = "HTTPS from NLB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = []
    cidr_blocks     = [var.provider_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-vault-ec2-sg"
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_instance_profile" "vault_ec2" {
  name = "${var.environment}-vault-ec2-profile"
  role = aws_iam_role.vault_ec2.name
}

resource "aws_iam_role" "vault_ec2" {
  name = "${var.environment}-vault-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vault_ec2_ssm" {
  role       = aws_iam_role.vault_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "vault" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.provider_private_a.id
  vpc_security_group_ids = [aws_security_group.vault_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.vault_ec2.name

  # Mock vault: run a simple HTTPS-capable Python HTTP server
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    # AL2023 ships python3 — no package install needed
    # Note: no internet access in this VPC; SSM requires Interface Endpoints (not provisioned to keep cost down)
    # To access this instance: set up SSM endpoints or use EC2 Instance Connect Endpoint
    openssl req -x509 -newkey rsa:2048 -keyout /tmp/key.pem -out /tmp/cert.pem \
      -days 1 -nodes -subj '/CN=vault-mock'
    python3 -c "
import ssl, http.server
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain('/tmp/cert.pem', '/tmp/key.pem')
httpd = http.server.HTTPServer(('0.0.0.0', 443), http.server.BaseHTTPRequestHandler)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
httpd.serve_forever()
" &
  USERDATA
  )

  tags = {
    Name = "${var.environment}-card-vault-mock"
  }
}

###############################################################################
# NLB — Provider VPC
# Required for VPC Endpoint Service (PrivateLink requires NLB or GWLB).
###############################################################################

resource "aws_lb" "vault_nlb" {
  name               = "${var.environment}-vault-nlb"
  internal           = true
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id = aws_subnet.provider_private_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.provider_private_b.id
  }

  enable_deletion_protection        = false
  enable_cross_zone_load_balancing  = true

  tags = {
    Name = "${var.environment}-vault-nlb"
  }
}

resource "aws_lb_target_group" "vault" {
  name        = "${var.environment}-vault-tg"
  port        = 443
  protocol    = "TCP"
  vpc_id      = aws_vpc.provider.id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "vault" {
  target_group_arn = aws_lb_target_group.vault.arn
  target_id        = aws_instance.vault.id
  port             = 443
}

resource "aws_lb_listener" "vault" {
  load_balancer_arn = aws_lb.vault_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}

###############################################################################
# VPC ENDPOINT SERVICE — Provider VPC (PrivateLink)
# Backed by the NLB. Consumer VPCs create Interface Endpoints pointing here.
# acceptance_required = false for single-account lab simplicity.
###############################################################################

resource "aws_vpc_endpoint_service" "vault" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.vault_nlb.arn]

  tags = {
    Name = "${var.environment}-vault-endpoint-service"
  }
}

###############################################################################
# INTERFACE ENDPOINT — Consumer VPC → Provider VPC Endpoint Service
# This is the PrivateLink consumer side.
###############################################################################

resource "aws_security_group" "vault_endpoint" {
  name        = "${var.environment}-vault-endpoint-sg"
  description = "Allow HTTPS from Lambda to vault Interface Endpoint"
  vpc_id      = aws_vpc.consumer.id

  ingress {
    description     = "HTTPS from Lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-vault-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "vault_service" {
  vpc_id              = aws_vpc.consumer.id
  service_name        = aws_vpc_endpoint_service.vault.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false  # PrivateLink to custom service — DNS configured separately

  subnet_ids = [
    aws_subnet.consumer_private_a.id,
    aws_subnet.consumer_private_b.id,
  ]

  security_group_ids = [aws_security_group.vault_endpoint.id]

  tags = {
    Name = "${var.environment}-vault-interface-endpoint"
  }

  depends_on = [aws_vpc_endpoint_service.vault]
}

###############################################################################
# ROUTE 53 PRIVATE HOSTED ZONE — Split-horizon DNS
# vault.internal.example.com resolves to the Interface Endpoint inside consumer VPC.
# Outside the VPC: NXDOMAIN.
###############################################################################

resource "aws_route53_zone" "internal" {
  name = "internal.example.com"

  vpc {
    vpc_id = aws_vpc.consumer.id
  }

  tags = {
    Name = "${var.environment}-internal-phz"
  }
}

resource "aws_route53_record" "vault" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "vault.internal.example.com"
  type    = "CNAME"
  ttl     = 60
  records = [aws_vpc_endpoint.vault_service.dns_entry[0].dns_name]
}

###############################################################################
# OUTPUTS
###############################################################################

output "consumer_vpc_id" {
  description = "Consumer VPC ID (payment processor)"
  value       = aws_vpc.consumer.id
}

output "provider_vpc_id" {
  description = "Provider VPC ID (card vault)"
  value       = aws_vpc.provider.id
}

output "s3_gateway_endpoint_id" {
  description = "S3 Gateway Endpoint ID"
  value       = aws_vpc_endpoint.s3_gateway.id
}

output "sqs_interface_endpoint_id" {
  description = "SQS Interface Endpoint ID"
  value       = aws_vpc_endpoint.sqs.id
}

output "vault_endpoint_service_name" {
  description = "VPC Endpoint Service name (provider) — use this to create consumer endpoints"
  value       = aws_vpc_endpoint_service.vault.service_name
}

output "vault_interface_endpoint_dns" {
  description = "DNS name for the vault Interface Endpoint in consumer VPC"
  value       = aws_vpc_endpoint.vault_service.dns_entry[0].dns_name
}

output "transaction_logs_bucket" {
  description = "S3 bucket for transaction logs"
  value       = aws_s3_bucket.transaction_logs.bucket
}

output "audit_queue_url" {
  description = "SQS audit queue URL"
  value       = aws_sqs_queue.audit_queue.url
}

output "lambda_function_name" {
  description = "Lambda function name — invoke this to test the full path"
  value       = aws_lambda_function.payment_processor.function_name
}

output "flow_log_group" {
  description = "CloudWatch Log Group for VPC Flow Logs — check this during Break it exercise"
  value       = aws_cloudwatch_log_group.flow_logs.name
}

output "vault_private_dns" {
  description = "Private DNS name for vault (split-horizon) — resolves only inside consumer VPC"
  value       = "vault.internal.example.com"
}
