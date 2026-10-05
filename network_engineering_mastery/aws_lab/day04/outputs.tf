output "ec2_a_instance_id" {
  value = module.ec2_a.instance_ids[0]
}

output "ec2_a_private_ip" {
  value = module.ec2_a.private_ips[0]
}

output "ec2_b_instance_id" {
  value = module.ec2_b.instance_ids[0]
}

output "ec2_b_private_ip" {
  value = module.ec2_b.private_ips[0]
}

output "firewall_instance_ids" {
  value = aws_instance.fw[*].id
}

output "appliance_mode" {
  value = var.appliance_mode
}
