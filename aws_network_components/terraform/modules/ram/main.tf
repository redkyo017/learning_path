resource "aws_ram_resource_share" "subnets" {
  name                      = "${var.name}-subnet-share"
  allow_external_principals = false
  tags                      = { Name = "${var.name}-subnet-share" }
}

resource "aws_ram_resource_association" "subnets" {
  for_each           = toset(var.subnet_arns)
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

resource "aws_ram_principal_association" "account_b_subnets" {
  principal          = var.account_b_id
  resource_share_arn = aws_ram_resource_share.subnets.arn
}

resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name}-tgw-share"
  allow_external_principals = false
  tags                      = { Name = "${var.name}-tgw-share" }
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = var.tgw_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "account_b_tgw" {
  principal          = var.account_b_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

data "aws_caller_identity" "current" {}
