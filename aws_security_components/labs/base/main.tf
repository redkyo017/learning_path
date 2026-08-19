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

# ---------------------------------------------------------------------------
# Shared data sources / locals used across network.tf, iam.tf, data.tf,
# ecs.tf and edge.tf.
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = var.project
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "base"
    },
    var.tags
  )
}
