output "cmk_arn" {
  description = "ARN of the base app-data CMK, resolved via its alias (base does not export this directly — see main.tf comment)."
  value       = data.aws_kms_alias.app_data.target_key_arn
}

output "cmk_alias" {
  description = "Alias name used to resolve the base CMK."
  value       = data.aws_kms_alias.app_data.name
}

output "exfil_sim_role_arn" {
  description = "ARN of the role standing in for a stolen task-role credential. Assume this with your own AWS CLI identity for the break/harden tests — see README."
  value       = aws_iam_role.exfil_sim.arn
}

output "test_object_bucket" {
  description = "Name of the base app-data bucket the test object lives in (passthrough from base)."
  value       = data.terraform_remote_state.base.outputs.app_bucket_name
}

output "test_object_key" {
  description = "S3 key of the SSE-KMS test object used to prove the legitimate via-S3 decrypt path."
  value       = var.test_object_key
}

output "current_mode" {
  description = "Which key policy is currently applied, derived from var.break_key_policy — a quick sanity check before you run a test."
  value       = var.break_key_policy ? "BROKEN (AllowDecryptAnySource — no condition)" : "LOCKED (AllowDecryptViaServiceOnly — kms:ViaService condition)"
}
