output "cluster_name" {
  description = "Pass to --cluster in every ECS CLI drill on Day A2."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Pass to --services / --service in every ECS CLI drill on Day A2."
  value       = aws_ecs_service.this.name
}

output "task_family" {
  description = "Task definition family. Revisions are addressed as FAMILY:N."
  value       = aws_ecs_task_definition.this.family
}

output "alarm_name" {
  description = "The alarm Day A2's put-metric-alarm drill mutates and reverts."
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "log_group_name" {
  description = "Deleted on purpose in Day A2's break-it step. It does not come back."
  value       = aws_cloudwatch_log_group.ecs.name
}
