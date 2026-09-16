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
