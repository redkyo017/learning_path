variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment prefix for all resource names"
  type        = string
  default     = "lab-day01"
}
