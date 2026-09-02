output "alb_dns_name" {
  description = "Public DNS name of the ALB. curl this (or /readyz, /burn) to exercise the service."
  value       = aws_lb.this.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name. Used in aws ecs / aws deploy CLI calls and by Day 5."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name — CODE_DEPLOY-controlled, do not update it directly with aws ecs update-service."
  value       = aws_ecs_service.this.name
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name (compute_platform = ECS)."
  value       = aws_codedeploy_app.this.name
}

output "codedeploy_group_name" {
  description = "CodeDeploy deployment group name — pass this to aws deploy create-deployment."
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "rollback_alarm_name" {
  description = "CloudWatch alarm name wired as the CodeDeploy rollback trigger. Day 5 reads this to build its own dashboards/alarms alongside it."
  value       = aws_cloudwatch_metric_alarm.rollback.alarm_name
}
