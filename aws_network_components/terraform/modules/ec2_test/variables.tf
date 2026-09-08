variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "One instance is launched per subnet ID given"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR permitted to reach these instances on any port"
}

variable "extra_sg_ids" {
  type        = list(string)
  default     = []
  description = "Additional SGs to attach - used on Day 8 to test the tier SGs"
}
