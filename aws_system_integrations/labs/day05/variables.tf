variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Short environment label (e.g. dev, day05lab). Used in resource names."
  type        = string
  default     = "day05lab"
}
