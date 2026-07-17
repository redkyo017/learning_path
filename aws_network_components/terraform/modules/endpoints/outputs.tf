output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "endpoint_service_name" {
  value = aws_vpc_endpoint_service.this.service_name
}

output "endpoint_service_id" {
  value = aws_vpc_endpoint_service.this.id
}
