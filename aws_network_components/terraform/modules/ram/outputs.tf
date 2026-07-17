output "subnet_share_arn" {
  value = aws_ram_resource_share.subnets.arn
}

output "tgw_share_arn" {
  value = aws_ram_resource_share.tgw.arn
}
