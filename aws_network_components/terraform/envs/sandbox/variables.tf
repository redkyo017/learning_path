variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_profile" {
  type    = string
  default = "sandbox"
}

# ---------------------------------------------------------------------------
# Per-day module toggles. Each dayNN.tfvars turns on exactly what that day's
# lab needs, so any day can be run on its own. The VPC is unconditional --
# every day needs it.
# ---------------------------------------------------------------------------

variable "enable_security" {
  type        = bool
  default     = false
  description = "Day 2+ : SGs, NACLs, Flow Logs"
}

variable "enable_dns" {
  type        = bool
  default     = false
  description = "Day 3 : PHZ + Resolver endpoints (~$0.50/hr -- most expensive)"
}

variable "enable_app_vpc" {
  type        = bool
  default     = false
  description = "Day 4+ : the second VPC"
}

variable "enable_tgw" {
  type        = bool
  default     = false
  description = "Day 4 : Transit Gateway (implies app_vpc)"
}

variable "enable_endpoints" {
  type        = bool
  default     = false
  description = "Day 5 : gateway + interface endpoints, PrivateLink service"
}

variable "enable_vpn" {
  type        = bool
  default     = false
  description = "Day 6 : Site-to-Site VPN (implies tgw)"
}

variable "enable_ram" {
  type        = bool
  default     = false
  description = "Day 7 : RAM shares"
}

variable "enable_ec2_test" {
  type        = bool
  default     = false
  description = "SSM-managed test instances, used from Day 2 onward"
}

# ---------------------------------------------------------------------------
# Values that must be supplied by hand for resources this config cannot create
# ---------------------------------------------------------------------------

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

variable "allow_external_principals" {
  type        = bool
  default     = true
  description = "True when account B is outside this AWS Organization. Set false ONLY for an in-Organization account -- left false for an external account the RAM share silently never appears."
}

# Note: ec2_a_id / ec2_b_id are gone. The Day 8 Reachability Analyzer path now
# reads instance IDs straight from the ec2_test module outputs, so the
# instances and the analysis are created and destroyed together.
