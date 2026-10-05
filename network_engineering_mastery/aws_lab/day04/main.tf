# Day 4 (optional AWS lab): centralized inspection across two AZs, with a toggle for
# Transit Gateway appliance mode. Cost is about $0.60 per hour while it runs.
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

locals {
  azs = ["${var.region}a", "${var.region}b"]
}

# ---------------------------------------------------------------------------
# VPCs: two spokes and the inspection VPC, two AZs each
# ---------------------------------------------------------------------------
module "spoke_a" {
  source = "../../../aws_network_components/terraform/modules/vpc"

  name                  = "d4-spoke-a"
  cidr_block            = "10.41.0.0/16"
  azs                   = local.azs
  public_subnet_cidrs   = ["10.41.0.0/24", "10.41.1.0/24"]
  private_subnet_cidrs  = ["10.41.2.0/24", "10.41.3.0/24"]
  isolated_subnet_cidrs = ["10.41.4.0/24", "10.41.5.0/24"]
}

module "spoke_b" {
  source = "../../../aws_network_components/terraform/modules/vpc"

  name                  = "d4-spoke-b"
  cidr_block            = "10.42.0.0/16"
  azs                   = local.azs
  public_subnet_cidrs   = ["10.42.0.0/24", "10.42.1.0/24"]
  private_subnet_cidrs  = ["10.42.2.0/24", "10.42.3.0/24"]
  isolated_subnet_cidrs = ["10.42.4.0/24", "10.42.5.0/24"]
}

module "inspection" {
  source = "../../../aws_network_components/terraform/modules/vpc"

  name                  = "d4-inspection"
  cidr_block            = "10.40.0.0/16"
  azs                   = local.azs
  public_subnet_cidrs   = ["10.40.0.0/24", "10.40.1.0/24"]
  private_subnet_cidrs  = ["10.40.2.0/24", "10.40.3.0/24"]
  isolated_subnet_cidrs = ["10.40.4.0/24", "10.40.5.0/24"]
}

# ---------------------------------------------------------------------------
# Transit Gateway: no default association or propagation, two route tables
# ---------------------------------------------------------------------------
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Day 4 inspection lab"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = { Name = "d4-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_a" {
  transit_gateway_id                              = aws_ec2_transit_gateway.this.id
  vpc_id                                          = module.spoke_a.vpc_id
  subnet_ids                                      = module.spoke_a.private_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags                                            = { Name = "d4-spoke-a" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_b" {
  transit_gateway_id                              = aws_ec2_transit_gateway.this.id
  vpc_id                                          = module.spoke_b.vpc_id
  subnet_ids                                      = module.spoke_b.private_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags                                            = { Name = "d4-spoke-b" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  transit_gateway_id                              = aws_ec2_transit_gateway.this.id
  vpc_id                                          = module.inspection.vpc_id
  subnet_ids                                      = module.inspection.private_subnet_ids
  appliance_mode_support                          = var.appliance_mode ? "enable" : "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags                                            = { Name = "d4-inspection" }
}

# spokes: both spokes associate here; the only route is "everything to inspection".
resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "d4-spokes" }
}

# inspection: the inspection attachment associates here; it learns both spokes.
resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "d4-inspection" }
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route" "spokes_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_a" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_b" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_b.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}

# ---------------------------------------------------------------------------
# VPC routes
# ---------------------------------------------------------------------------

# Spoke private subnets: all private address space goes to the TGW.
resource "aws_route" "spoke_a_to_tgw" {
  count                  = 2
  route_table_id         = module.spoke_a.private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.spoke_a]
}

resource "aws_route" "spoke_b_to_tgw" {
  count                  = 2
  route_table_id         = module.spoke_b.private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.spoke_b]
}

# Inspection: the TGW attachment lives in the private subnets, so traffic arriving from
# the TGW in AZ n is sent to the firewall in AZ n.
resource "aws_route" "inspection_to_fw" {
  count                  = 2
  route_table_id         = module.inspection.private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8"
  network_interface_id   = aws_instance.fw[count.index].primary_network_interface_id
}

# The firewalls sit in the public subnets (one shared route table). After inspecting a
# packet, a firewall sends it back to the TGW from its own subnet.
resource "aws_route" "inspection_fw_to_tgw" {
  route_table_id         = module.inspection.public_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.inspection]
}

# ---------------------------------------------------------------------------
# Firewalls: Linux routers with a stateful nftables forward policy
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "fw" {
  name = "d4-fw-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fw_ssm" {
  role       = aws_iam_role.fw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "fw" {
  name = "d4-fw-profile"
  role = aws_iam_role.fw.name
}

resource "aws_security_group" "fw" {
  name        = "d4-fw-sg"
  description = "Inspection firewalls - all traffic from private address space"
  vpc_id      = module.inspection.vpc_id
  tags        = { Name = "d4-fw-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "fw_from_private" {
  security_group_id = aws_security_group.fw.id
  cidr_ipv4         = "10.0.0.0/8"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "fw_all" {
  security_group_id = aws_security_group.fw.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "fw" {
  count                  = 2
  ami                    = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type          = "t3.micro"
  subnet_id              = module.inspection.public_subnet_ids[count.index]
  iam_instance_profile   = aws_iam_instance_profile.fw.name
  vpc_security_group_ids = [aws_security_group.fw.id]
  source_dest_check      = false

  # A public address only so the instance can reach SSM and the package repo through
  # the internet gateway. The security group admits nothing from the internet.
  associate_public_ip_address = true

  user_data                   = templatefile("${path.module}/user_data.sh.tftpl", {})
  user_data_replace_on_change = true

  tags = { Name = "d4-fw-${count.index == 0 ? "a" : "b"}" }
}

# ---------------------------------------------------------------------------
# Test instances: spoke A in AZ-a, spoke B in AZ-b, so the flow crosses AZs
# ---------------------------------------------------------------------------
module "ec2_a" {
  source = "../../../aws_network_components/terraform/modules/ec2_test"

  name         = "d4-spoke-a"
  vpc_id       = module.spoke_a.vpc_id
  subnet_ids   = [module.spoke_a.private_subnet_ids[0]]
  allowed_cidr = "10.0.0.0/8"
}

module "ec2_b" {
  source = "../../../aws_network_components/terraform/modules/ec2_test"

  name         = "d4-spoke-b"
  vpc_id       = module.spoke_b.vpc_id
  subnet_ids   = [module.spoke_b.private_subnet_ids[1]]
  allowed_cidr = "10.0.0.0/8"
}
