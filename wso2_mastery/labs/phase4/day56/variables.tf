variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "ap-southeast-1"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for ECS task placement"
  default     = ["TODO_REPLACE_SUBNET_1", "TODO_REPLACE_SUBNET_2"]
}

variable "gw_sg_id" {
  type        = string
  description = "Security group ID for Gateway service"
  default     = "TODO_REPLACE_GW_SG_ID"
}

variable "tm_sg_id" {
  type        = string
  description = "Security group ID for Throttle Manager service"
  default     = "TODO_REPLACE_TM_SG_ID"
}

variable "cp_sg_id" {
  type        = string
  description = "Security group ID for Carbon Publisher service"
  default     = "TODO_REPLACE_CP_SG_ID"
}

variable "is_sg_id" {
  type        = string
  description = "Security group ID for Identity Server service"
  default     = "TODO_REPLACE_IS_SG_ID"
}

variable "sns_alert_arn" {
  type        = string
  description = "SNS topic ARN for CloudWatch alarms (e.g., PagerDuty integration)"
  default     = "TODO_REPLACE_SNS_ARN"
}
