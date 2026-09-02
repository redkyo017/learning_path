variable "aws_region" {
  description = "AWS region for all resources in this path."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to every resource name so teardown verification can find them."
  type        = string
  default     = "awsdevops"
}
