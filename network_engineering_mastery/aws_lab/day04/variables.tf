variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "Region for the lab. Two AZs (a and b) must exist in it."
}

variable "aws_profile" {
  type        = string
  default     = "sandbox"
  description = "Named AWS CLI profile of a sandbox account"
}

variable "appliance_mode" {
  type        = bool
  default     = false
  description = "Enable appliance mode on the inspection VPC's TGW attachment"
}
