variable "region" {
  description = "AWS region. Must match the region labs/base was applied into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name/prefix. Must match labs/base's `project` value (used only to build this day's own resource names — not required to match structurally, but keeping it identical avoids confusion when reading resources side by side in the console)."
  type        = string
  default     = "aws-sec-lab"
}

variable "min_severity" {
  description = "Minimum GuardDuty severity (numeric, 0.1-8.9+) that both the EventBridge rule and the Lambda's own defensive re-check act on. 7 = the Medium/High boundary on GuardDuty's scale."
  type        = number
  default     = 7
}

variable "lambda_log_retention_days" {
  description = "CloudWatch Logs retention for the quarantine Lambda. Short by default to bound cost."
  type        = number
  default     = 3
}

variable "config_demo_bucket_force_destroy" {
  description = "Force-destroy the throwaway public-bucket Config demo target. Keep true — this bucket holds no real data and must not survive past today's teardown."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
