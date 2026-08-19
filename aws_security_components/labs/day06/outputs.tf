output "web_acl_id" {
  description = "ID of the Day 6 Web ACL."
  value       = aws_wafv2_web_acl.day06.id
}

output "web_acl_arn" {
  description = "ARN of the Day 6 Web ACL — the resource_arn the association and logging configuration both point at."
  value       = aws_wafv2_web_acl.day06.arn
}

output "log_group_name" {
  description = "CloudWatch Logs log group receiving WAF inspection logs. Query this to see which rule matched a given request (see SOLUTION.md)."
  value       = aws_cloudwatch_log_group.waf.name
}

output "alb_dns_name" {
  description = "Convenience passthrough of the base ALB's DNS name — this is the target for every curl test in README.md (bypasses CloudFront; see content 'Rate-based rules' gotcha)."
  value       = data.terraform_remote_state.base.outputs.alb_dns_name
}
