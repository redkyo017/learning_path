output "day01_policy_name" {
  description = "Name of the explicit-Deny inline policy this lab layered onto the base task role."
  value       = aws_iam_role_policy.day01_tighten_app_data_access.name
}

output "task_role_arn" {
  description = "Pass-through of the base task role ARN this lab tightened. Use as --policy-source-arn in the simulator commands (see README)."
  value       = local.task_role_arn
}

output "app_bucket_arn" {
  description = "Pass-through of the base app_data bucket ARN. Use to build --resource-arns in the simulator commands (see README)."
  value       = local.app_bucket_arn
}

output "in_prefix_test_resource_arn" {
  description = "Example object ARN INSIDE the allowed prefix — should simulate as allowed for GetObject/PutObject both before and after harden."
  value       = "${local.app_bucket_arn}/${var.app_object_prefix}/example.txt"
}

output "out_of_prefix_test_resource_arn" {
  description = "Example object ARN OUTSIDE the allowed prefix — allowed before harden, explicitDeny after."
  value       = "${local.app_bucket_arn}/other-prefix/example.txt"
}
