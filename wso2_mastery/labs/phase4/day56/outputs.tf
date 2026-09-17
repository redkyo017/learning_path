output "gw_autoscaling_policy_arn" {
  value       = aws_appautoscaling_policy.gw_cpu.arn
  description = "ARN of the GW CPU target tracking autoscaling policy"
}

output "tm_autoscaling_policy_arn" {
  value       = aws_appautoscaling_policy.tm_cpu.arn
  description = "ARN of the TM CPU target tracking autoscaling policy"
}

output "gw_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.gw_cpu_high.arn
  description = "ARN of the CloudWatch alarm for GW CPU > 80%"
}

output "gw_service_name" {
  value       = aws_ecs_service.gw.name
  description = "ECS service name for Gateway"
}

output "tm_service_name" {
  value       = aws_ecs_service.tm.name
  description = "ECS service name for Throttle Manager"
}

output "cp_service_name" {
  value       = aws_ecs_service.cp.name
  description = "ECS service name for Carbon Publisher (fixed replica)"
}

output "is_service_name" {
  value       = aws_ecs_service.is.name
  description = "ECS service name for Identity Server (fixed replica)"
}

output "cluster_name" {
  value       = aws_ecs_cluster.wso2.name
  description = "ECS cluster name"
}
