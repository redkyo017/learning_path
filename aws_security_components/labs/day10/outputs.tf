output "abac_demo_role_arn" {
  description = "ARN of the demo IAM role — assume it to test the ABAC + permission-boundary intersection."
  value       = aws_iam_role.abac_demo_role.arn
}

output "abac_boundary_policy_arn" {
  description = "ARN of the ABAC-conditioned permission boundary policy attached to the demo role."
  value       = aws_iam_policy.abac_boundary.arn
}

output "abac_tags_applied" {
  description = "The tag scheme applied to the demo role and (via the tagging script) to base-workload resources."
  value       = local.abac_tags
}

output "scp_policy_id" {
  description = "ID of the CloudTrail-tamper-deny SCP, if enable_org_resources = true. Empty string otherwise (plan-only for single-account learners)."
  value       = var.enable_org_resources ? aws_organizations_policy.deny_cloudtrail_tamper[0].id : ""
}

output "scp_policy_json" {
  description = "The SCP's JSON content — readable/reviewable regardless of enable_org_resources, since this is a data source, not a created resource."
  value       = data.aws_iam_policy_document.deny_cloudtrail_tamper.json
}

output "tagged_base_resources" {
  description = "The base-workload ARNs/names the tagging script applies the ABAC scheme onto."
  value = {
    task_role_name = local.task_role_name
    bucket_name    = local.app_bucket_name
    secret_arn     = local.secret_arn
    dynamodb_table = local.dynamodb_table_arn
  }
}
