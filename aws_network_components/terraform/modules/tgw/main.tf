resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} Transit Gateway"
  amazon_side_asn                 = 64512
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  tags                            = { Name = "${var.name}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "shared_services" {
  vpc_id             = var.shared_services_vpc_id
  subnet_ids         = var.shared_services_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "shared-services-attachment" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  vpc_id             = var.app_vpc_id
  subnet_ids         = var.app_private_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "app-attachment" }
}

resource "aws_ec2_transit_gateway_route_table" "shared_services" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "shared-services-rt" }
}

resource "aws_ec2_transit_gateway_route_table" "app" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "app-rt" }
}

resource "aws_ec2_transit_gateway_route_table_association" "shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_association" "app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# shared-services-rt propagates routes from both attachments
resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_from_ss" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "shared_services_from_app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared_services.id
}

# app-rt only propagates from shared-services (app cannot reach other app VPCs)
resource "aws_ec2_transit_gateway_route_table_propagation" "app_from_shared_services" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# VPC route table entries to send cross-VPC traffic via TGW
resource "aws_route" "shared_services_to_app" {
  count                  = length(var.shared_services_private_route_table_ids)
  route_table_id         = var.shared_services_private_route_table_ids[count.index]
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.shared_services]
}

resource "aws_route" "app_to_shared_services" {
  count                  = length(var.app_private_route_table_ids)
  route_table_id         = var.app_private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.app]
}
