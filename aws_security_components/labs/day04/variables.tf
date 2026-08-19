variable "region" {
  description = "AWS region. Must match the region labs/base was applied with."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Must match labs/base's var.project exactly — used to resolve the base CMK's alias (alias/${project}-app-data) and to name this day's resources."
  type        = string
  default     = "aws-sec-lab"
}

variable "break_key_policy" {
  description = <<-EOT
    The break/harden toggle. false (default) = the LOCKED key policy
    (kms:ViaService-scoped decrypt for the simulated task-role principal).
    true = the BROKEN key policy — same statement, its Condition block
    removed. Flip this, `terraform apply`, and re-run the decrypt test —
    see README "THE BREAK" / "THE HARDEN".
  EOT
  type        = bool
  default     = false
}

variable "test_object_key" {
  description = "S3 key of the small SSE-KMS test object created in the base app-data bucket, used to prove the legitimate via-S3 decrypt path still works."
  type        = string
  default     = "day04/exfil-test.txt"
}

variable "tags" {
  description = "Extra tags merged onto every resource this day creates."
  type        = map(string)
  default     = {}
}
