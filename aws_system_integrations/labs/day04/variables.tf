variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Short environment label (e.g. dev, day04lab). Used in resource names."
  type        = string
  default     = "day04lab"
}

variable "payment_error_rate" {
  description = "Set to 100 to simulate payment service always failing — used for circuit breaker simulation. Range: 0 (never fail) to 100 (always fail)."
  type        = number
  default     = 0
}

variable "consumer_broken" {
  description = "Set to true to simulate a broken consumer Lambda — triggers DLQ redrive after maxReceiveCount=3 attempts."
  type        = bool
  default     = false
}
