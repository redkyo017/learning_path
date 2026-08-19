# ---------------------------------------------------------------------------
# Day 7 — VPC-only Secrets Manager access.
#
# Layers on top of labs/base (read-only via terraform_remote_state — this
# module never edits labs/base's own .tf files). Creates:
#   1. A security group for the new interface endpoint's ENIs.
#   2. A Secrets Manager INTERFACE VPC endpoint in base's PRIVATE subnets,
#      with a custom endpoint policy scoped to exactly the base secret.
#   3. A secret resource policy on the BASE secret that denies
#      GetSecretValue/DescribeSecret unless the request transited that
#      exact endpoint (aws:SourceVpce).
#   4. A custom NACL on base's private subnets, tightened to the traffic
#      this endpoint actually needs (443 in from the VPC, matching
#      ephemeral-port return traffic) — the "layer SG/NACL for least
#      exposure" half of the brief, and the subject of Exercise 1.
#
# COST NOTE: an interface endpoint bills ~$0.01/hr per AZ (two AZs here,
# since base's private_subnet_ids spans 2 AZs) plus per-GB data processing.
# Tear this module down the same day — see README "Teardown".
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = var.base_state_path
  }
}

locals {
  name_prefix = "aws-sec-lab-day07"
  common_tags = merge(
    {
      Project   = "aws-sec-lab"
      ManagedBy = "terraform"
      Layer     = "day07"
    },
    var.tags
  )

  vpc_id             = data.terraform_remote_state.base.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.base.outputs.private_subnet_ids
  secret_arn         = data.terraform_remote_state.base.outputs.secret_arn
}

# --- 1. Security group for the endpoint's ENIs -----------------------------
#
# EXERCISE 1 SET-UP: this SG is intentionally written to the CIDR-based
# `allowed_client_cidr` (the whole VPC CIDR by default) rather than to the
# base ECS task security group specifically, so the "SG vs NACL" exercise
# in the content file has a concrete, real gap to reason about (lateral
# reach from anything else in the VPC, not just the app). Tightening this
# to `referenced_security_group_id = <task sg id>` is the fix Exercise 1
# walks you to — left as an exercise rather than the shipped default so the
# gap is visible to reason about, not hidden.
resource "aws_security_group" "secretsmanager_endpoint" {
  name        = "${local.name_prefix}-secretsmanager-endpoint-sg"
  description = "Secrets Manager interface endpoint ENIs — inbound 443 from the VPC CIDR"
  vpc_id      = local.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name_prefix}-secretsmanager-endpoint-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_https" {
  security_group_id = aws_security_group.secretsmanager_endpoint.id
  cidr_ipv4          = var.allowed_client_cidr
  from_port          = 443
  to_port            = 443
  ip_protocol        = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "endpoint_all" {
  security_group_id = aws_security_group.secretsmanager_endpoint.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol        = "-1"
}

# --- 2. Secrets Manager interface endpoint ----------------------------------

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.private_subnet_ids
  security_group_ids  = [aws_security_group.secretsmanager_endpoint.id]
  private_dns_enabled = true

  # Endpoint policy: narrows what's reachable THROUGH this endpoint,
  # independent of the secret's own resource policy (added below). Scoped
  # to exactly the base app secret and exactly the two read actions the
  # app needs — this endpoint should never become a general-purpose
  # Secrets Manager door.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowReadOfAppSecretOnly"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [local.secret_arn]
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-secretsmanager-endpoint" })
}

# --- 3. Secret resource policy — the actual VPC-only enforcement -----------
#
# Explicit Deny beats any identity-based Allow (see content file "engine
# lens"). The base task role's existing ReadOwnSecret Allow (iam.tf) is
# untouched — this statement narrows WHO can act on that Allow, by WHERE
# the request came from, not by weakening the Allow itself.
resource "aws_secretsmanager_secret_policy" "app_secret_vpc_only" {
  secret_arn = local.secret_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyIfNotViaSecretsManagerEndpoint"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.secret_arn
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.secretsmanager.id
          }
        }
      }
    ]
  })
}

# --- 4. Custom NACL on base's private subnets — least-exposure backstop ----
#
# Stateless: both directions must be explicit. Allows 443 inbound from the
# VPC CIDR (matches the SG's intent, at subnet granularity) and the
# ephemeral-port return leg outbound; same pair mirrored for the reply path.
# See content file Exercise 1 for what this NACL does and does NOT
# compensate for.
resource "aws_network_acl" "secretsmanager_endpoint_subnets" {
  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-endpoint-subnet-nacl" })
}

resource "aws_network_acl_rule" "inbound_https" {
  network_acl_id = aws_network_acl.secretsmanager_endpoint_subnets.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.allowed_client_cidr
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "inbound_ephemeral_return" {
  network_acl_id = aws_network_acl.secretsmanager_endpoint_subnets.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.allowed_client_cidr
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "outbound_https" {
  network_acl_id = aws_network_acl.secretsmanager_endpoint_subnets.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.allowed_client_cidr
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "outbound_ephemeral_return" {
  network_acl_id = aws_network_acl.secretsmanager_endpoint_subnets.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.allowed_client_cidr
  from_port      = 1024
  to_port        = 65535
}
