# ---------------------------------------------------------------------------
# VPC, 2 AZs, public + private subnets.
#
# COST/DESIGN DECISION — NAT-FREE:
# There is no NAT Gateway in this workload. A NAT Gateway costs ~$0.045/hr
# (~$32/mo if left running) plus data processing, which is disproportionate
# for a lab that is torn down daily. Instead:
#   - The ALB and the ECS Fargate task ENIs live in the PUBLIC subnets, with
#     `assign_public_ip = true` on the task so it can pull its image and make
#     outbound calls (AWS APIs, and the SSRF-lab fetch target) directly via
#     the Internet Gateway.
#   - Inbound exposure is controlled entirely by security groups: the task
#     security group only accepts traffic from the ALB security group, so
#     giving the task ENI a public IP does not open it to the internet.
#   - PRIVATE subnets are still created (and exported as `private_subnet_ids`)
#     so later day-labs that want genuinely private placement (e.g. an RDS
#     instance, VPC interface endpoints) have somewhere to put it. They have
#     no default route to the internet — add a NAT Gateway or endpoint
#     yourself in that day's module if you need one.
#   - A free S3 gateway endpoint is attached to both route tables so
#     anything in either subnet tier can reach S3 without a NAT Gateway.
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-public-${count.index + 1}", Tier = "public" })
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-private-${count.index + 1}", Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table intentionally has NO 0.0.0.0/0 route (no NAT). Local
# VPC routing only, plus the S3 gateway endpoint route added below.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Free gateway endpoint — lets resources in either tier reach S3 without a NAT.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-s3-endpoint" })
}
