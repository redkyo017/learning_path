# Day 3 — REVERSE: blue/green deploy to ECS Fargate with alarm-triggered
# automatic rollback.
#
# Split across four files by boundary, because this is the largest lab in
# the path and one file per concern keeps each of them readable:
#   - alb.tf         network edge: security groups, ALB, target groups, listener
#   - ecs.tf         compute: cluster, log group, IAM roles, task definition, service
#   - codedeploy.tf  deployment control: CodeDeploy app/group, rollback alarm
#
# Cost while this stack is up for a lab session: ~$1.50, ALB-dominated.
# This is also the most important teardown in the path — see teardown.md.
# It is destroyed at the end of Day 3 and RE-APPLIED at the start of Day 5,
# because Day 5's alarms and canary observe this exact stack.

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
# own beyond security groups and an ALB — the VPC and subnets are borrowed.
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = "../foundation/terraform.tfstate"
  }
}
