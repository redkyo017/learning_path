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

variable "notification_email" {
  description = <<-EOT
    Optional email address subscribed to this lab's SNS alert topic (the
    composite alarm's alarm_actions target). Left blank by default so this
    lab can be authored and `terraform fmt`-checked without a real address
    anywhere in the repo. Set it in your own terraform.tfvars (never
    committed) if you want the composite alarm to actually notify you.
  EOT
  type        = string
  default     = ""
}

variable "codeconnection_arn" {
  description = <<-EOT
    ARN of the CodeConnections connection to GitHub, created once in Day 0
    (console-only OAuth handshake — see labs/day00/README.md step 4). Same
    connection Day 2 used; CodeConnections is a per-account, per-provider
    handshake, not a per-pipeline one, so re-authorizing it isn't needed.
    No default on purpose: this value is per-account and per-connection,
    and there is no safe placeholder to fall back to.

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
  description = "Branch this lab's capstone pipeline is scoped to."
  type        = string
  default     = "main"
}

variable "canary_runtime_version" {
  description = <<-EOT
    Synthetics canary runtime, e.g. "syn-nodejs-puppeteer-9.1". Pin an exact
    version rather than "latest" for the same reason images are pinned by
    digest elsewhere in this path: reproducibility. CHECK THE CURRENT
    SUPPORTED VERSION before applying — AWS deprecates old canary runtimes
    on a schedule and an expired one fails to create.
    https://docs.aws.amazon.com/AmazonSynthetics/latest/APIReference/API_UpdateCanary.html
  EOT
  type        = string
  default     = "syn-nodejs-puppeteer-9.1"
}
