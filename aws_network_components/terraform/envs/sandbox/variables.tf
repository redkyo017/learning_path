variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_profile" {
  type    = string
  default = "sandbox"
}

variable "privatelink_nlb_arn" {
  type        = string
  description = "ARN of the NLB for the PrivateLink service (create manually first)"
  default     = ""
}

variable "allowed_principal_arns" {
  type    = list(string)
  default = []
}

variable "customer_gateway_ip" {
  type        = string
  description = "Elastic IP of the on-prem sim strongSwan EC2"
  default     = ""
}

variable "account_b_id" {
  type        = string
  description = "AWS account ID for account B"
  default     = ""
}

variable "ec2_a_id" {
  type    = string
  default = ""
}

variable "ec2_b_id" {
  type    = string
  default = ""
}
