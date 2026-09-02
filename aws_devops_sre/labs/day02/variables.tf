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

variable "codeconnection_arn" {
  description = <<-EOT
    ARN of the CodeConnections connection to GitHub, created once in Day 0
    (console-only OAuth handshake — see labs/day00/README.md step 4). No
    default on purpose: this value is per-account and per-connection, and
    there is no safe placeholder to fall back to.

    Looks like:
      arn:aws:codeconnections:us-east-1:123456789012:connection/<UUID>
  EOT
  type        = string
}

variable "github_owner" {
  description = "GitHub username or org that owns the sample app repo (from Day 0 step 7). Example: <YOUR_GITHUB_USERNAME>."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name containing app/ (from Day 0 step 7). Example: <YOUR_REPO>."
  type        = string
}

variable "github_branch" {
  description = "Branch the pipeline and the GitHub Actions OIDC role are scoped to."
  type        = string
  default     = "main"
}
