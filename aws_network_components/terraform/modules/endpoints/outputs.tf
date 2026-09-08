output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

# one() yields null rather than erroring when the service is disabled
output "endpoint_service_name" {
  value = one(aws_vpc_endpoint_service.this[*].service_name)
}

output "endpoint_service_id" {
  value = one(aws_vpc_endpoint_service.this[*].id)
}
