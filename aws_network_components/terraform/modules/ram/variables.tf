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

variable "resolver_rule_arn" {
  type        = string
  description = "ARN of the Route 53 Resolver rule to share (Day 7 DNS flow)"
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
