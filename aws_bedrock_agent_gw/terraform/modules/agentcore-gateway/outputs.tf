output "agent_id" {
  description = "Bedrock Agent ID"
  value       = aws_bedrockagent_agent.this.agent_id
}

output "agent_alias_id" {
  description = "Bedrock Agent alias ID"
  value       = aws_bedrockagent_agent_alias.this.agent_alias_id
}

output "execution_role_arn" {
  description = "ARN of the Gateway IAM execution role"
  value       = aws_iam_role.gateway_execution.arn
}

output "lambda_arns" {
  description = "Map of tool name to Lambda function ARN"
  value       = { for k, v in aws_lambda_function.tool : k => v.arn }
}

output "dashboard_url" {
  description = "CloudWatch dashboard console URL (available after monitoring.tf is applied)"
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${var.name_prefix}-gateway-ops"
}
