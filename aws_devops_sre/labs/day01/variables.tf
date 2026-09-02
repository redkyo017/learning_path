variable "aws_region" {
  description = "AWS region for all resources in this lab."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to every resource name so teardown verification can find them."
  type        = string
  default     = "awsdevops"
}

variable "github_repo_url" {
  description = <<-EOT
    HTTPS URL of your own copy of the sample app repo (the fork or copy you
    created in Day 0, step 7). Example:
    https://github.com/<YOUR_GITHUB_USERNAME>/<YOUR_REPO>
    Not a secret, but personal to you — that's why it has no default.
  EOT
  type        = string
}
