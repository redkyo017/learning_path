variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment prefix for all resource names"
  type        = string
  default     = "lab-day02"
}

variable "v2_weight" {
  description = "Percentage of traffic to route to v2 target group (0–100). Remaining traffic goes to v1. Increase to promote the canary."
  type        = number
  default     = 10
}
