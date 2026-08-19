# ---------------------------------------------------------------------------
# Day 2's own outputs, plus a few base pass-throughs so the CLI commands in
# README.md don't require juggling two `terraform output` invocations.
# ---------------------------------------------------------------------------

output "low_priv_role_arn" {
  description = "ARN of the low-privilege role you assume to run the escalation attempt."
  value       = aws_iam_role.low_priv.arn
}

output "high_priv_role_arn" {
  description = "ARN of the high-privilege 'crown jewel' role — the escalation target. Never assumable directly by low_priv; only reachable by passing it to ECS."
  value       = aws_iam_role.high_priv.arn
}

output "low_priv_boundary_policy_arn" {
  description = "ARN of the permission-boundary policy (attached to low_priv only when permission_boundary_enabled = true)."
  value       = aws_iam_policy.low_priv_boundary.arn
}

output "permission_boundary_enabled" {
  description = "Current value of the break/harden toggle — true means low_priv is capped."
  value       = var.permission_boundary_enabled
}

output "escalate_security_group_id" {
  description = "Security group ID to use for the escalation task's network_configuration."
  value       = aws_security_group.escalate_task.id
}

output "escalate_log_group_name" {
  description = "CloudWatch log group the escalation task definition should point its awslogs driver at."
  value       = aws_cloudwatch_log_group.escalate.name
}

output "region" {
  description = "The region this module was applied in — convenience for README CLI commands (awslogs-region, etc.)."
  value       = var.region
}

# --- Base pass-throughs -----------------------------------------------------

output "base_ecs_cluster_arn" {
  description = "Pass-through of labs/base's ECS cluster ARN — RunTask target."
  value       = local.base_ecs_cluster_arn
}

output "base_public_subnet_ids" {
  description = "Pass-through of labs/base's public subnet IDs — network_configuration for the escalation task."
  value       = local.base_public_subnet_ids
}

output "base_task_execution_role_arn" {
  description = "Pass-through of labs/base's task execution role ARN — use this as the escalation task definition's executionRoleArn (image pull + log shipping only; NOT the escalation target)."
  value       = local.base_task_exec_role_arn
}

output "base_secret_arn" {
  description = "Pass-through of labs/base's app secret ARN — the resource the escalation attempts to read."
  value       = local.base_secret_arn
}
