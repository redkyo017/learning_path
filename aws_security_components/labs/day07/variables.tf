variable "region" {
  description = "AWS region. Must match the region labs/base was applied in."
  type        = string
  default     = "us-east-1"
}

variable "base_state_path" {
  description = "Path to labs/base's local state file, relative to this module."
  type        = string
  default     = "../base/terraform.tfstate"
}

variable "allowed_client_cidr" {
  description = <<-EOT
    CIDR allowed to reach the Secrets Manager interface endpoint on 443.
    Defaults to the whole base VPC CIDR so both the public-subnet ECS task
    and anything else legitimately inside the VPC can use it. Narrow this
    to a specific security group reference (see README exercise) for a
    tighter production posture — kept as a CIDR here to keep the module
    self-contained without a second remote-state lookup of the task SG id.

    NOTE — duplicated literal, not derived: this repeats labs/base's
    vpc_cidr default (10.42.0.0/16) rather than reading it via
    terraform_remote_state, so a real VPC CIDR is available for the NACL
    rules' cidr_block (a NACL rule needs a literal CIDR, not a security
    group reference). If you change base's vpc_cidr, update this default
    to match, or the SG/NACL rules here will scope to the wrong range.
  EOT
  type        = string
  default     = "10.42.0.0/16"
}

variable "tags" {
  description = "Extra tags merged onto every resource this module creates."
  type        = map(string)
  default     = {}
}
