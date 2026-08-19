variable "region" {
  description = "AWS region — MUST match the region labs/base was applied in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name/prefix for day10-created resources. Keep it aligned with labs/base's `project` var for consistency, but it does not have to match exactly."
  type        = string
  default     = "aws-sec-lab"
}

variable "demo_role_name" {
  description = "Name of the demo IAM role used to prove the ABAC + permission-boundary intersection."
  type        = string
  default     = "aws-sec-lab-day10-abac-demo"
}

variable "abac_project_tag" {
  description = "ABAC tag scheme — Project value. Applied to the demo role AND (via the tagging script) onto base-workload resources, so the ABAC Condition has a real match to key on."
  type        = string
  default     = "aws-sec-lab"
}

variable "abac_environment_tag" {
  description = "ABAC tag scheme — Environment value."
  type        = string
  default     = "sandbox"
}

variable "abac_classification_tag" {
  description = "ABAC tag scheme — DataClassification value."
  type        = string
  default     = "internal"
}

variable "enable_org_resources" {
  description = <<-EOT
    Set true ONLY if you are running this from an AWS Organizations
    MANAGEMENT account and want to actually attach the SCP. Defaults to
    false so `terraform plan`/`apply` never attempts an Organizations API
    call for a single-account learner — the SCP JSON/resource is still
    fully readable and plan-able with this at false, `apply` just skips
    creating it (count = 0).
  EOT
  type    = bool
  default = false
}

variable "org_scp_target_id" {
  description = "Org root ID, OU ID, or account ID to attach the SCP to. Only used when enable_org_resources = true. Leave blank otherwise."
  type        = string
  default     = ""
}
