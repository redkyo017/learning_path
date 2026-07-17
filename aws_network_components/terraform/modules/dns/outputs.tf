output "hosted_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "resolver_inbound_endpoint_id" {
  value = aws_route53_resolver_endpoint.inbound.id
}

output "resolver_outbound_endpoint_id" {
  value = aws_route53_resolver_endpoint.outbound.id
}
