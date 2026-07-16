variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "bgw"
}

variable "foundation_model" {
  type    = string
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "tool_configs" {
  type = list(object({
    name        = string
    lambda_zip  = string
    handler     = string
    description = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
