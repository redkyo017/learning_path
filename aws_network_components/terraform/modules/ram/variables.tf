variable "name" {
  type = string
}

variable "subnet_arns" {
  type        = list(string)
  description = "ARNs of subnets to share"
}

variable "tgw_arn" {
  type        = string
  description = "ARN of the Transit Gateway to share"
}

variable "account_b_id" {
  type        = string
  description = "AWS account ID for account B"
}

variable "allow_external_principals" {
  type        = bool
  default     = true
  description = "True when account B is outside this AWS Organization"
}
