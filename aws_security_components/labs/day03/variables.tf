variable "region" {
  description = "AWS region. Must match the region labs/base was applied into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Must match labs/base's `project` value exactly — used to resolve base's existing KMS alias (alias/${project}-app-data). It does not create anything named with this prefix itself."
  type        = string
  default     = "aws-sec-lab"
}

variable "learner_principal_arn" {
  description = <<-EOT
    ARN of YOUR OWN IAM user or role — the identity you already use to run
    the AWS CLI in this account. Used two ways in this module:
      1. Trusted principal on principal_a/b's trust policy, so you can
         `aws sts assume-role` into either one to run the break/harden tests.
      2. The key-administrator principal in the hardened key policy, so you
         retain the ability to manage/re-edit the key policy after hardening.
    No default — you must set this in terraform.tfvars. Never a real value
    in this repo; see terraform.tfvars.example.

    CAUTION: after hardening (enable_key_policy_hardening = true), the
    key's resource policy no longer delegates broadly to IAM — only this
    exact ARN (plus principal_a) can touch the key. If the identity you
    actually run `terraform apply`/`aws kms` commands as is DIFFERENT
    from this ARN, you can lock yourself out of managing the key
    afterward. Set this to the precise ARN you're authenticated as —
    check with `aws sts get-caller-identity` right before applying.
  EOT
  type        = string
}

variable "enable_key_policy_hardening" {
  description = "false = THE BREAK (base's default, IAM-delegating key policy stays in place; both test principals can decrypt). true = THE HARDEN (explicit key policy naming only principal_a for usage actions)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
