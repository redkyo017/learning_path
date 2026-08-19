variable "region" {
  description = "AWS region. Must match the region labs/base was applied in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name/prefix used in resource names and tags. Must match the `project` value labs/base was applied with (used only to build this module's own resource names, not to look anything up)."
  type        = string
  default     = "aws-sec-lab"
}

variable "rate_limit" {
  description = "Requests per evaluation_window_sec from a single aggregation key before the rate-based rule blocks it. 100 is the AWS-enforced minimum for a rate-based rule; kept low deliberately so the lab's own curl-loop test can trip it in well under a minute."
  type        = number
  default     = 100
}

variable "rate_evaluation_window_sec" {
  description = "Rolling window (seconds) the rate-based rule counts requests over. Valid values: 60, 120, 300, 600."
  type        = number
  default     = 300
}

variable "tune_generic_rfi_false_positive" {
  description = <<-EOT
    Controls whether the GenericRFI_QUERYARGUMENTS sub-rule inside
    AWSManagedRulesCommonRuleSet is overridden to Count instead of Block.
    Ships as `false` on purpose: your FIRST apply attaches the Web ACL
    with the managed group's default behavior, which false-positives on
    this app's own legitimate /fetch?url=<target> traffic (see
    content/day06-waf-edge.md exercise 4 and SOLUTION.md). Flip to `true`
    and re-apply to fix it — that second apply is the "tune one false
    positive" step of today's lab.
  EOT
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the WAF logging configuration. Short by default — this is a same-day lab, not a persistent audit trail."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
