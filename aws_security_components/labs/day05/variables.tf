variable "region" {
  description = "AWS region. MUST match the region labs/base was applied in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "MUST match the `project` value labs/base was applied with (used to derive resource names via the remote state, not to reconstruct base's own resource names)."
  type        = string
  default     = "aws-sec-lab"
}

variable "harden" {
  description = <<-EOT
    false (default) = THE BREAK: registers a standalone task-definition
    family with a placeholder secret leaked into a plaintext env var, and
    creates nothing else (no HTTPS listener, no rotation).
    true = THE HARDEN: registers a fixed task-definition revision that
    pulls the secret via the ECS `secrets` block (Secrets Manager, never
    in the task def), turns on rotation for base's secret, and adds an
    ACM-certificate HTTPS listener + HTTP->HTTPS redirect on base's ALB.
  EOT
  type    = bool
  default = false
}

variable "domain_name" {
  description = <<-EOT
    A domain you actually own and control DNS for, e.g. "labs.example.com".
    Leave "" if you don't own one -- see README "ACM domain prerequisite".
    Required (together with route53_zone_id) to take the PUBLIC,
    DNS-validated ACM certificate path. A public ACM cert cannot be issued
    without a domain you control; there is no way around that, and this
    module does not pretend otherwise.
  EOT
  type    = string
  default = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for domain_name, IN THIS ACCOUNT. Leave \"\" if you don't own a domain or its zone isn't in Route53 here -- the module then falls back to an imported self-signed certificate (see README)."
  type        = string
  default     = ""
}

variable "fallback_common_name" {
  description = "Common Name used for the fallback self-signed certificate when domain_name/route53_zone_id are blank. Cosmetic only -- it is not a real, resolvable domain and browsers will show a trust warning against it regardless of what you put here."
  type        = string
  default     = "lab.internal.example"
}

variable "rotation_days" {
  description = "Secrets Manager automatic rotation interval, in days, for the harden step."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
