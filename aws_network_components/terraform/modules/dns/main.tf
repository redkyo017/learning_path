resource "aws_route53_zone" "private" {
  name = var.private_hosted_zone_name
  vpc {
    vpc_id = var.vpc_id
  }
  tags = { Name = "${var.name}-phz" }
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api.${var.private_hosted_zone_name}"
  type    = "A"
  ttl     = 300
  records = ["10.0.2.10"]
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name               = "${var.name}-resolver-inbound"
  direction          = "INBOUND"
  security_group_ids = [var.resolver_sg_id]

  dynamic "ip_address" {
    for_each = var.private_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = { Name = "${var.name}-resolver-inbound" }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "${var.name}-resolver-outbound"
  direction          = "OUTBOUND"
  security_group_ids = [var.resolver_sg_id]

  dynamic "ip_address" {
    for_each = var.private_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = { Name = "${var.name}-resolver-outbound" }
}

resource "aws_route53_resolver_rule" "corp_internal" {
  name                 = "forward-corp-internal"
  domain_name          = "corp.internal"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = var.onprem_dns_ip
  }

  tags = { Name = "${var.name}-corp-internal-rule" }
}

resource "aws_route53_resolver_rule_association" "corp_internal" {
  vpc_id           = var.vpc_id
  resolver_rule_id = aws_route53_resolver_rule.corp_internal.id
}

# Day 7: authorizes account B's VPC to associate with this account's PHZ.
# Empty account_b_vpc_id (the Day 3 standalone case) skips this entirely --
# the authorization alone does nothing until account B runs the matching
# associate-vpc-with-hosted-zone call on their side.
resource "aws_route53_vpc_association_authorization" "account_b" {
  count   = var.account_b_vpc_id != "" ? 1 : 0
  zone_id = aws_route53_zone.private.zone_id
  vpc_id  = var.account_b_vpc_id
}
