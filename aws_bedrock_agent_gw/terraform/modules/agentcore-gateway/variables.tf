variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names. Must start with 'bgw'."
  validation {
    condition     = startswith(var.name_prefix, "bgw")
    error_message = "name_prefix must start with 'bgw'."
  }
}

variable "foundation_model" {
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
  description = "Bedrock foundation model ID for the agent."
}

variable "tool_configs" {
  type = list(object({
    name        = string
    lambda_zip  = string
    handler     = string
    description = string
  }))
  description = "One entry per tool. Each becomes a Lambda function and a Bedrock action group."
}

variable "cfn_stack_name" {
  type        = string
  default     = ""
  description = "Optional. Name of an existing CloudFormation stack. Pulls KmsKeyArn output when present."
}

variable "alarm_sns_arn" {
  type        = string
  default     = ""
  description = "Optional. SNS topic ARN for CloudWatch alarm notifications. No alarms created when empty."
}

variable "monthly_cost_threshold_usd" {
  type        = number
  default     = 0
  description = "Optional. If > 0, creates a CloudWatch billing alarm at this USD threshold per month."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources. Recommended keys: project, team, cost-center."
}
