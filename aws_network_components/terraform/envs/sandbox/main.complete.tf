## ANSWER KEY - Do not run this file directly.
## This is the fully assembled sandbox after all 8 days.
## Follow README.md to add module blocks day-by-day to main.tf instead.
##
## Every module except the VPC is gated behind an enable_* flag, and each
## dayNN.tfvars turns on exactly what that day needs - so any single day can
## be run on its own:
##
##   terraform apply   -var-file=day05.tfvars -auto-approve
##   terraform destroy -var-file=day05.tfvars -auto-approve
##
## Always pass the same -var-file to destroy that you passed to apply.
##
## terraform {
##   required_version = ">= 1.6"
##   required_providers {
##     aws = {
##       source  = "hashicorp/aws"
##       version = ">= 5.0"
##     }
##   }
## }
##
## provider "aws" {
##   region  = var.region
##   profile = var.aws_profile
## }
##
## data "aws_caller_identity" "current" {}
##
## locals {
##   # TGW attaches app-vpc, and the VPN attaches to the TGW, so each implies
##   # the one below it. Deriving this here keeps the dayNN.tfvars files honest.
##   tgw_enabled     = var.enable_tgw || var.enable_vpn
##   app_vpc_enabled = var.enable_app_vpc || local.tgw_enabled
## }
##
## check "vpn_requires_tgw" {
##   assert {
##     condition     = !var.enable_vpn || local.tgw_enabled
##     error_message = "enable_vpn requires enable_tgw."
##   }
## }
##
## # Day 1 - VPC Anatomy. Unconditional: every day needs it.
## module "shared_services_vpc" {
##   source = "../../modules/vpc"
##
##   name                  = "shared-services"
##   cidr_block            = "10.0.0.0/16"
##   azs                   = ["${var.region}a", "${var.region}b"]
##   public_subnet_cidrs   = ["10.0.0.0/24", "10.0.1.0/24"]
##   private_subnet_cidrs  = ["10.0.2.0/24", "10.0.3.0/24"]
##   isolated_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24"]
## }
##
## # Day 2 - Security Layer
## module "shared_services_security" {
##   count  = var.enable_security ? 1 : 0
##   source = "../../modules/security"
##
##   name               = "shared-services"
##   vpc_id             = module.shared_services_vpc.vpc_id
##   vpc_cidr           = "10.0.0.0/16"
##   private_subnet_ids = module.shared_services_vpc.private_subnet_ids
## }
##
## # Day 3 - DNS
## module "shared_services_dns" {
##   count  = var.enable_dns ? 1 : 0
##   source = "../../modules/dns"
##
##   name               = "shared-services"
##   vpc_id             = module.shared_services_vpc.vpc_id
##   private_subnet_ids = module.shared_services_vpc.private_subnet_ids
##   resolver_sg_id     = one(module.shared_services_security[*].resolver_sg_id)
## }
##
## # Day 4 - Transit Gateway
## module "app_vpc" {
##   count  = local.app_vpc_enabled ? 1 : 0
##   source = "../../modules/vpc"
##
##   name                  = "app"
##   cidr_block            = "10.1.0.0/16"
##   azs                   = ["${var.region}a", "${var.region}b"]
##   public_subnet_cidrs   = ["10.1.0.0/24", "10.1.1.0/24"]
##   private_subnet_cidrs  = ["10.1.2.0/24", "10.1.3.0/24"]
##   isolated_subnet_cidrs = ["10.1.4.0/24", "10.1.5.0/24"]
## }
##
## module "tgw" {
##   count  = local.tgw_enabled ? 1 : 0
##   source = "../../modules/tgw"
##
##   name = "platform"
##
##   shared_services_vpc_id                  = module.shared_services_vpc.vpc_id
##   shared_services_private_subnet_ids      = module.shared_services_vpc.private_subnet_ids
##   shared_services_private_route_table_ids = module.shared_services_vpc.private_route_table_ids
##
##   app_vpc_id                  = one(module.app_vpc[*].vpc_id)
##   app_private_subnet_ids      = one(module.app_vpc[*].private_subnet_ids)
##   app_private_route_table_ids = one(module.app_vpc[*].private_route_table_ids)
## }
##
## # Day 5 - VPC Endpoints + PrivateLink
## module "shared_services_endpoints" {
##   count  = var.enable_endpoints ? 1 : 0
##   source = "../../modules/endpoints"
##
##   name                    = "shared-services"
##   vpc_id                  = module.shared_services_vpc.vpc_id
##   region                  = var.region
##   private_subnet_ids      = module.shared_services_vpc.private_subnet_ids
##   private_route_table_ids = module.shared_services_vpc.private_route_table_ids
##   isolated_route_table_id = module.shared_services_vpc.isolated_route_table_id
##   endpoint_sg_id          = one(module.shared_services_security[*].endpoint_sg_id)
##   nlb_arn                 = var.privatelink_nlb_arn
##   allowed_principal_arns  = var.allowed_principal_arns
## }
##
## # Day 6 - Site-to-Site VPN
## module "vpn" {
##   count  = var.enable_vpn ? 1 : 0
##   source = "../../modules/vpn"
##
##   name                                    = "onprem-sim"
##   tgw_id                                  = one(module.tgw[*].tgw_id)
##   tgw_shared_services_route_table_id      = one(module.tgw[*].shared_services_route_table_id)
##   customer_gateway_ip                     = var.customer_gateway_ip
##   shared_services_private_route_table_ids = module.shared_services_vpc.private_route_table_ids
## }
##
## # Day 7 - Multi-Account (RAM)
## module "ram" {
##   count  = var.enable_ram ? 1 : 0
##   source = "../../modules/ram"
##
##   name                      = "platform"
##   account_b_id              = var.account_b_id
##   allow_external_principals = var.allow_external_principals
##   tgw_arn                   = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:transit-gateway/${one(module.tgw[*].tgw_id)}"
##   subnet_arns = [
##     for id in module.shared_services_vpc.private_subnet_ids :
##     "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"
##   ]
## }
##
## # Harness - SSM-managed test instances (Days 2-8)
## module "ec2_test_shared_services" {
##   count  = var.enable_ec2_test ? 1 : 0
##   source = "../../modules/ec2_test"
##
##   name         = "shared-services"
##   vpc_id       = module.shared_services_vpc.vpc_id
##   subnet_ids   = module.shared_services_vpc.private_subnet_ids
##   allowed_cidr = "10.0.0.0/8"
## }
##
## module "ec2_test_app" {
##   count  = var.enable_ec2_test && local.app_vpc_enabled ? 1 : 0
##   source = "../../modules/ec2_test"
##
##   name         = "app"
##   vpc_id       = one(module.app_vpc[*].vpc_id)
##   subnet_ids   = one(module.app_vpc[*].private_subnet_ids)
##   allowed_cidr = "10.0.0.0/8"
## }
##
## # Day 8 - Reachability Analyzer path as code.
## # Note: the analysis runs once at create time. After breaking something,
## # force a re-run with:
## #   terraform apply -var-file=day08.tfvars \
## #     -replace='aws_ec2_network_insights_analysis.a_to_b[0]' -auto-approve
## resource "aws_ec2_network_insights_path" "a_to_b" {
##   count            = var.enable_ec2_test && local.app_vpc_enabled ? 1 : 0
##   source           = one(module.ec2_test_shared_services[*].instance_ids)[0]
##   destination      = one(module.ec2_test_app[*].instance_ids)[0]
##   protocol         = "tcp"
##   destination_port = 8080
##   tags             = { Name = "ec2-a-to-ec2-b-8080" }
## }
##
## resource "aws_ec2_network_insights_analysis" "a_to_b" {
##   count                    = var.enable_ec2_test && local.app_vpc_enabled ? 1 : 0
##   network_insights_path_id = aws_ec2_network_insights_path.a_to_b[0].id
##   tags                     = { Name = "ec2-a-to-b-analysis" }
## }
##
