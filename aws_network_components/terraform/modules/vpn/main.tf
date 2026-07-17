resource "aws_customer_gateway" "onprem_sim" {
  bgp_asn    = 65000
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"
  tags       = { Name = "${var.name}-cgw" }
}

resource "aws_vpn_connection" "onprem_sim" {
  customer_gateway_id   = aws_customer_gateway.onprem_sim.id
  transit_gateway_id    = var.tgw_id
  type                  = "ipsec.1"
  static_routes_only    = false
  tunnel1_inside_cidr   = "169.254.10.0/30"
  tunnel2_inside_cidr   = "169.254.10.4/30"
  tags                  = { Name = "${var.name}-vpn" }
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_to_shared_services" {
  transit_gateway_attachment_id  = aws_vpn_connection.onprem_sim.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.tgw_shared_services_route_table_id
}

resource "aws_route" "shared_services_to_onprem" {
  count                  = length(var.shared_services_private_route_table_ids)
  route_table_id         = var.shared_services_private_route_table_ids[count.index]
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = var.tgw_id
  depends_on             = [aws_vpn_connection.onprem_sim]
}
