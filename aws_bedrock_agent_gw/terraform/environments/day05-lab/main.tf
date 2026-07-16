terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }

  # Uncomment and configure for shared team use:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "ai-infra/day05-lab/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
    }
  }
}

module "day05_gateway" {
  source = "../../modules/agentcore-gateway"

  name_prefix      = var.name_prefix
  foundation_model = var.foundation_model
  tool_configs     = var.tool_configs
  tags             = var.tags
}

output "agent_id" {
  value = module.day05_gateway.agent_id
}

output "agent_alias_id" {
  value = module.day05_gateway.agent_alias_id
}

output "execution_role_arn" {
  value = module.day05_gateway.execution_role_arn
}

output "lambda_arns" {
  value = module.day05_gateway.lambda_arns
}

output "dashboard_url" {
  value = module.day05_gateway.dashboard_url
}
