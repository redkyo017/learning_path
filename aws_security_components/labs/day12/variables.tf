variable "region" {
  description = "AWS region — MUST match the region labs/base was applied in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Same project prefix used by labs/base and every day module. Also used to derive the S3 bucket name, DynamoDB table name, and KMS alias this module looks up (see main.tf comments — these follow labs/base's documented naming convention, not a Terraform output)."
  type        = string
  default     = "aws-sec-lab"
}

variable "create_leaked_user_fixture" {
  description = <<-EOT
    Whether this module creates a short-lived throwaway IAM user that
    stands in for the Day 11 "leaked long-lived access key" initial-access
    identity. Day 11 deliberately did NOT create a real second IAM
    identity for this (see labs/capstone/attack-runbook.md's rationale —
    it narrated that step using the deployer's own credentials, to avoid
    its own instance of secret sprawl). Default true: this module creates
    one now, purely so CONTAIN Step 1 has a real key to deactivate/delete,
    and destroys it same-day in the final sweep. Set false only if you've
    separately created a real stand-in identity you want to operate
    against instead (set leaked_user_name to its exact name).
  EOT
  type    = bool
  default = true
}

variable "leaked_user_name" {
  description = "Name for the leaked-credential fixture IAM user (created only if create_leaked_user_fixture = true)."
  type        = string
  default     = "aws-sec-lab-ci-leaked"
}

variable "app_object_prefix" {
  description = "The single S3 key prefix the app actually needs — MUST match Day 1's lab's own `app_object_prefix` variable (default \"app-data\", no trailing slash) so both days' Deny overlays enforce the exact same boundary. Used to build the eradication Deny/NotResource boundary — everything outside this prefix stays denied even though the base workload's original grant is bucket-wide."
  type        = string
  default     = "app-data"
}

variable "waf_metadata_block_patterns" {
  description = "Substrings to block (CONTAINS match, URL-decoded first) in the /fetch?url= query string — AWS/ECS link-local metadata and credential-endpoint markers. Extend this list if your app exposes other SSRF-reachable parameters. MUST contain at least 2 entries: main.tf wires this into a WAFv2 or_statement, which WAFv2 rejects with fewer than 2 nested statements — if you only want to block one pattern, don't shrink this list, write a plain byte_match_statement directly instead."
  type        = list(string)
  default = [
    "169.254.169.254",
    "169.254.170.2",
    "/latest/meta-data",
    "/v2/credentials",
  ]

  validation {
    condition     = length(var.waf_metadata_block_patterns) >= 2
    error_message = "waf_metadata_block_patterns must have at least 2 entries — main.tf's or_statement requires >=2 nested statements; WAFv2 rejects an or_statement with only 1."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
