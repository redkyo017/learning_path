output "quarantine_lambda_arn" {
  description = "ARN of the auto-quarantine Lambda."
  value       = aws_lambda_function.quarantine.arn
}

output "quarantine_lambda_log_group" {
  description = "CloudWatch Logs group to tail for the containment record (see SOLUTION.md)."
  value       = aws_cloudwatch_log_group.quarantine_lambda.name
}

output "guardduty_rule_arn" {
  description = "ARN of the EventBridge rule matching High-or-above-severity GuardDuty findings."
  value       = aws_cloudwatch_event_rule.guardduty_high_severity.arn
}

output "quarantine_boundary_arn" {
  description = "ARN of the deny-all permission boundary the Lambda attaches to the compromised task role."
  value       = aws_iam_policy.quarantine_boundary.arn
}

output "config_rule_name" {
  description = "Name of the AWS Config rule flagging public S3 buckets."
  value       = aws_config_config_rule.s3_public_read_prohibited.name
}

output "config_demo_bucket_name" {
  description = "Name of the throwaway public-bucket demo target for the Config rule/remediation."
  value       = aws_s3_bucket.config_demo.bucket
}

output "config_delivery_bucket_name" {
  description = "Name of the AWS Config delivery-channel bucket (Config's own log storage, not app data)."
  value       = aws_s3_bucket.config_delivery.bucket
}

output "remediation_automation_role_arn" {
  description = "ARN of the SSM Automation execution role used by the Config auto-remediation."
  value       = aws_iam_role.remediation_automation.arn
}
