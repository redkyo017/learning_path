variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Short environment label (e.g. dev, staging). Used in resource names."
  type        = string
  default     = "day03lab"
}

variable "consumer_vpc_cidr" {
  description = "CIDR block for the consumer VPC (payment processor). Must not overlap with provider_vpc_cidr."
  type        = string
  default     = "10.0.0.0/16"
}

variable "provider_vpc_cidr" {
  description = "CIDR block for the provider VPC (card vault). Must not overlap with consumer_vpc_cidr."
  type        = string
  default     = "10.1.0.0/16"
}
