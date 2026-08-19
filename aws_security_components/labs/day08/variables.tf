variable "region" {
  description = "AWS region. MUST match the region labs/base was applied in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name/prefix. MUST match labs/base's `project` value so remote_state and naming line up."
  type        = string
  default     = "aws-sec-lab"
}

variable "trail_log_retention_days" {
  description = "Lifecycle expiration for the CloudTrail log bucket. Keep short — this is a lab, not a compliance archive."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
