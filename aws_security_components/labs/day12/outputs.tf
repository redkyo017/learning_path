output "leaked_user_name" {
  description = "Name of the leaked-credential fixture IAM user (null if create_leaked_user_fixture = false)."
  value       = var.create_leaked_user_fixture ? aws_iam_user.leaked[0].name : null
}

output "leaked_access_key_id" {
  description = "Access key ID (not sensitive by itself — the secret half is) of the leaked-credential fixture. Use this in CONTAIN Step 1's CLI commands."
  value       = var.create_leaked_user_fixture ? aws_iam_access_key.leaked[0].id : null
}

output "leaked_secret_access_key" {
  description = "SENSITIVE. Secret half of the leaked-credential fixture. Never print, log, screenshot, or commit this. Retrieve locally only: terraform output -raw leaked_secret_access_key"
  value       = var.create_leaked_user_fixture ? aws_iam_access_key.leaked[0].secret : null
  sensitive   = true
}

output "eradicate_policy_name" {
  description = "Name of the explicit-Deny tightening policy attached to the base task role."
  value       = aws_iam_role_policy.eradicate_tighten.name
}

output "task_role_name" {
  description = "Name of the base task role this module layers the Deny policy onto (looked up from base's task_role_arn output)."
  value       = local.task_role_name
}

output "web_acl_arn" {
  description = "ARN of the Day 12 defend Web ACL blocking SSRF-to-metadata payloads at the ALB."
  value       = aws_wafv2_web_acl.capstone_defend.arn
}

output "web_acl_id" {
  description = "ID of the Day 12 defend Web ACL (needed for teardown: dissociate before/during destroy)."
  value       = aws_wafv2_web_acl.capstone_defend.id
}
