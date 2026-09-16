# Day 40 Outputs
output "cluster_arn" {
  value = aws_ecs_cluster.wso2.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.wso2.name
}

output "cp_task_def_arn" {
  value = aws_ecs_task_definition.cp.arn
}

output "cp_task_def_family" {
  value = aws_ecs_task_definition.cp.family
}

output "is_task_def_arn" {
  value = aws_ecs_task_definition.is.arn
}

output "is_task_def_family" {
  value = aws_ecs_task_definition.is.family
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "cp_log_group" {
  value = aws_cloudwatch_log_group.cp.name
}

output "is_log_group" {
  value = aws_cloudwatch_log_group.is.name
}

# Day 41 Outputs
output "gw_task_def_arn" {
  value = aws_ecs_task_definition.gw.arn
}

output "gw_task_def_family" {
  value = aws_ecs_task_definition.gw.family
}

output "tm_task_def_arn" {
  value = aws_ecs_task_definition.tm.arn
}

output "tm_task_def_family" {
  value = aws_ecs_task_definition.tm.family
}

output "gw_log_group" {
  value = aws_cloudwatch_log_group.gw.name
}

output "tm_log_group" {
  value = aws_cloudwatch_log_group.tm.name
}

output "alb_arn" {
  value = aws_lb.gw.arn
}

output "alb_dns_name" {
  value = aws_lb.gw.dns_name
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "gw_target_group_arn" {
  value = aws_lb_target_group.gw.arn
}

output "gw_listener_arn" {
  value = aws_lb_listener.gw_https.arn
}

# Day 42 Outputs
output "gw_security_group_id" {
  value = aws_security_group.gw.id
}

output "cp_security_group_id" {
  value = aws_security_group.cp.id
}

output "is_security_group_id" {
  value = aws_security_group.is.id
}

output "tm_security_group_id" {
  value = aws_security_group.tm.id
}

output "gw_autoscaling_target_arn" {
  value = aws_appautoscaling_target.gw.resource_id
}

output "gw_autoscaling_policy_arn" {
  value = aws_appautoscaling_policy.gw_cpu.arn
}

output "tm_autoscaling_target_arn" {
  value = aws_appautoscaling_target.tm.resource_id
}

output "tm_autoscaling_policy_arn" {
  value = aws_appautoscaling_policy.tm_cpu.arn
}
