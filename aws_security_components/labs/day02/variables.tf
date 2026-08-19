# ---------------------------------------------------------------------------
# Day 2 variables. No secrets, no account IDs baked in — account-specific
# values either come from the base remote state or (assumer_principal_arn)
# are supplied by you in terraform.tfvars, which is gitignored.
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region. Must match labs/base's region (same account, same region)."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name/prefix for this day's resources. Keep distinct from base's project name so role/policy names don't collide."
  type        = string
  default     = "aws-sec-lab-day02"
}

variable "base_state_path" {
  description = "Path to labs/base's local state file, relative to this module. Base must be applied first."
  type        = string
  default     = "../base/terraform.tfstate"
}

variable "assumer_principal_arn" {
  description = <<-EOT
    ARN of the IAM user or role you will use to `sts:AssumeRole` into
    low_priv for this lab (e.g. your own admin user/role ARN in this
    sandbox account). NOT a secret, but still account-specific — set it in
    terraform.tfvars (gitignored), never in this file. No default: the
    module intentionally fails to plan until you supply one, rather than
    silently trusting something overly broad (e.g. account root).
  EOT
  type = string
}

variable "permission_boundary_enabled" {
  description = <<-EOT
    THE BREAK/HARDEN TOGGLE.
      false (default) = BREAK phase: low_priv role has NO permission boundary.
        Its mis-scoped iam:PassRole (Resource "*") lets it pass the high_priv
        role to a new ECS task it registers and runs, and that task inherits
        high_priv's permissions — privilege escalation lands.
      true = HARDEN phase: a permission boundary is attached to low_priv that
        does not include iam:PassRole at all. The same escalation attempt now
        fails with AccessDenied, even though low_priv's own identity policy
        was never edited.
    Flip this to true and re-apply for the harden half of the lab; see
    README.md "THE HARDEN".
  EOT
  type    = bool
  default = false
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
