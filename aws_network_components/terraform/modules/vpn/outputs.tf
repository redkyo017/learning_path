output "vpn_connection_id" {
  value = aws_vpn_connection.onprem_sim.id
}

output "tunnel1_address" {
  value     = aws_vpn_connection.onprem_sim.tunnel1_address
  sensitive = true
}

output "tunnel2_address" {
  value     = aws_vpn_connection.onprem_sim.tunnel2_address
  sensitive = true
}

output "tunnel1_psk" {
  value     = aws_vpn_connection.onprem_sim.tunnel1_preshared_key
  sensitive = true
}

output "tunnel2_psk" {
  value     = aws_vpn_connection.onprem_sim.tunnel2_preshared_key
  sensitive = true
}
