output "tgw_id" {
  value = aws_ec2_transit_gateway.this.id
}

output "shared_services_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
}

output "app_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.app.id
}

output "shared_services_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.shared_services.id
}

output "app_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.app.id
}
