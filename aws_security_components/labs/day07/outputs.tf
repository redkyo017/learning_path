output "secretsmanager_endpoint_id" {
  description = "ID of the day-07 Secrets Manager interface endpoint. This is the value the secret policy's aws:SourceVpce condition matches against — use it when constructing the in-VPC reachability test in SOLUTION.md."
  value       = aws_vpc_endpoint.secretsmanager.id
}

output "secretsmanager_endpoint_dns_names" {
  description = "Private DNS names for the endpoint's ENIs (one per AZ). With private_dns_enabled = true, anything inside the VPC resolving the standard secretsmanager.<region>.amazonaws.com name transparently gets routed here — no app code change required."
  value       = aws_vpc_endpoint.secretsmanager.dns_entry
}

output "endpoint_security_group_id" {
  description = "Security group attached to the endpoint's ENIs. See Exercise 1 (content file) for the gap left in its default rule."
  value       = aws_security_group.secretsmanager_endpoint.id
}

output "endpoint_subnet_nacl_id" {
  description = "Custom NACL associated with base's private subnets for this lab."
  value       = aws_network_acl.secretsmanager_endpoint_subnets.id
}

output "secret_arn" {
  description = "ARN of the base secret this lab is hardening (passthrough of labs/base's secret_arn output, for convenience)."
  value       = local.secret_arn
}
