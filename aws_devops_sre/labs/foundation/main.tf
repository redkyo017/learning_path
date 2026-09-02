# Foundation stack — VPC + ECR, shared by every lab in this path.
#
# Cost: approximately $0/month.
#   - VPC, Internet Gateway, subnets, and route tables are free.
#   - ECR storage for one ~15 MB image (plus a handful of old tags kept by the
#     lifecycle policy below) is a fraction of a cent per month.
#   - There is no NAT gateway anywhere in this stack (or this path) — that is
#     the single line item that would actually cost money, and it is
#     deliberately absent.
#
# This stack is intended to stay up for the entire week (Day 1 through
# Day 5). Do not destroy it between labs — see teardown.md for why, and for
# the correct end-of-week destroy order.

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

# default_tags above stamp every resource this provider creates with
# Project/ManagedBy/Path. That is what makes cost attribution in Cost
# Explorer possible: filter or group by the "Project" tag and every resource
# this path created — here and in every day lab — shows up together.

data "aws_availability_zones" "available" {
  state = "available"
}

# --- Networking -------------------------------------------------------
# Public subnets only. No NAT gateway, no private subnets, no VPC endpoints.
# Fargate tasks (Day 3) run directly in these public subnets with
# assign_public_ip = true, and Day 3's ALB lives here too — which is why
# there must be two subnets in two different AZs (an ALB refuses to create
# with only one).

resource "aws_vpc" "this" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.42.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Container registry ------------------------------------------------

resource "aws_ecr_repository" "sample" {
  name                 = "${var.name_prefix}-sample"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # force_delete = true is a LAB choice: it lets `terraform destroy` remove
  # this repository even if it still holds images, so teardown never wedges.
  # In production you would leave this false (or unset) so a repo full of
  # images can't be destroyed by accident.
  force_delete = true

  tags = {
    Name = "${var.name_prefix}-sample"
  }
}

resource "aws_ecr_lifecycle_policy" "sample" {
  repository = aws_ecr_repository.sample.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the 10 most recent images, expire the rest."
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
