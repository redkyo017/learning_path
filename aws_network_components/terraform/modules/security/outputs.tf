output "web_sg_id" {
  value = aws_security_group.web.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "data_sg_id" {
  value = aws_security_group.data.id
}

output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow_logs.name
}

output "resolver_sg_id" {
  value = aws_security_group.resolver.id
}

output "endpoint_sg_id" {
  value = aws_security_group.endpoints.id
}
