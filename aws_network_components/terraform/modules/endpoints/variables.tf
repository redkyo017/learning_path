variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_route_table_ids" {
  type = list(string)
}

variable "isolated_route_table_id" {
  type = string
}

variable "endpoint_sg_id" {
  type = string
}

variable "nlb_arn" {
  type        = string
  description = "ARN of the NLB fronting the PrivateLink service"
}

variable "allowed_principal_arns" {
  type        = list(string)
  description = "Account/IAM ARNs allowed to create endpoints for this service"
  default     = []
}
