output "principal_a_role_arn" {
  description = "The INTENDED reader. Assume this role to run the 'should succeed' side of the test."
  value       = aws_iam_role.principal_a.arn
}

output "principal_b_role_arn" {
  description = "The UNINTENDED reader (identical identity policy to A, by design). Assume this role to run the 'should be denied after hardening' side of the test."
  value       = aws_iam_role.principal_b.arn
}

output "cmk_arn" {
  description = "ARN of labs/base's existing CMK (aws_kms_key.app_data), resolved via its alias. Not created by this module."
  value       = local.cmk_arn
}

output "cmk_key_id" {
  description = "Key ID of labs/base's existing CMK. Use this for `aws kms put-key-policy --key-id` if you restore the default policy during teardown."
  value       = local.cmk_key_id
}

output "app_bucket_name" {
  description = "Passthrough of labs/base's app-data bucket name, for the S3 CLI commands in README.md."
  value       = local.bucket_name
}

output "test_object_key_prefix" {
  description = "S3 key prefix both test principals are scoped to (put/get test objects under this prefix only)."
  value       = local.test_prefix
}

output "key_policy_hardening_enabled" {
  description = "Echoes var.enable_key_policy_hardening so `terraform output` alone tells you which phase you're in."
  value       = var.enable_key_policy_hardening
}
