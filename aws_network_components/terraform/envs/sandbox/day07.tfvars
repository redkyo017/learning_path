# Day 7 - Multi-account. RAM shares the subnets, the TGW, and the Day 3
# Resolver rule; the DNS layer also gets a cross-account PHZ association
# authorization (Terraform) that account B completes from their side (CLI).
# enable_dns is required here -- see the ram_requires_dns check in main.tf.
# WARNING: this pulls in the Day 3 Resolver endpoint cost, ~$0.50/hr.
# Test instances are launched from account B, not here.
enable_security  = true
enable_dns       = true
enable_app_vpc   = true
enable_tgw       = true
enable_endpoints = true
enable_ram       = true
