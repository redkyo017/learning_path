## ANSWER KEY — Do not run this file directly.
## This is the fully assembled sandbox after all 8 days.
## Follow README.md to add module blocks day-by-day to main.tf instead.
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
## # Day 1 — VPC Anatomy
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
## # Day 2 — Security Layer
## module "shared_services_security" {
##   source = "../../modules/security"
##
##   name               = "shared-services"
##   vpc_id             = module.shared_services_vpc.vpc_id
##   vpc_cidr           = "10.0.0.0/16"
##   private_subnet_ids = module.shared_services_vpc.private_subnet_ids
## }
##
## # Day 3 — DNS
## module "shared_services_dns" {
##   source = "../../modules/dns"
##
##   name               = "shared-services"
##   vpc_id             = module.shared_services_vpc.vpc_id
##   private_subnet_ids = module.shared_services_vpc.private_subnet_ids
##   resolver_sg_id     = module.shared_services_security.resolver_sg_id
## }
##
## # Day 4 — Transit Gateway
## module "app_vpc" {
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
##   source = "../../modules/tgw"
##
##   name = "platform"
##
##   shared_services_vpc_id                  = module.shared_services_vpc.vpc_id
##   shared_services_private_subnet_ids      = module.shared_services_vpc.private_subnet_ids
##   shared_services_private_route_table_ids = module.shared_services_vpc.private_route_table_ids
##
##   app_vpc_id                  = module.app_vpc.vpc_id
##   app_private_subnet_ids      = module.app_vpc.private_subnet_ids
##   app_private_route_table_ids = module.app_vpc.private_route_table_ids
## }
##
## # Day 5 — VPC Endpoints + PrivateLink
## module "shared_services_endpoints" {
##   source = "../../modules/endpoints"
##
##   name                    = "shared-services"
##   vpc_id                  = module.shared_services_vpc.vpc_id
##   region                  = var.region
##   private_subnet_ids      = module.shared_services_vpc.private_subnet_ids
##   private_route_table_ids = module.shared_services_vpc.private_route_table_ids
##   isolated_route_table_id = module.shared_services_vpc.isolated_route_table_id
##   endpoint_sg_id          = module.shared_services_security.endpoint_sg_id
##   nlb_arn                 = var.privatelink_nlb_arn
##   allowed_principal_arns  = var.allowed_principal_arns
## }
##
## # Day 6 — Site-to-Site VPN
## module "vpn" {
##   source = "../../modules/vpn"
##
##   name                                    = "onprem-sim"
##   tgw_id                                  = module.tgw.tgw_id
##   tgw_shared_services_route_table_id      = module.tgw.shared_services_route_table_id
##   customer_gateway_ip                     = var.customer_gateway_ip
##   shared_services_private_route_table_ids = module.shared_services_vpc.private_route_table_ids
## }
##
## # Day 7 — Multi-Account (RAM)
## data "aws_caller_identity" "current" {}
##
## module "ram" {
##   source = "../../modules/ram"
##
##   name         = "platform"
##   account_b_id = var.account_b_id
##   tgw_arn      = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:transit-gateway/${module.tgw.tgw_id}"
##   subnet_arns  = [
##     for id in module.shared_services_vpc.private_subnet_ids :
##     "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"
##   ]
## }
##
## # Day 8 — Reachability Analyzer
## resource "aws_ec2_network_insights_path" "a_to_b" {
##   source           = var.ec2_a_id
##   destination      = var.ec2_b_id
##   protocol         = "tcp"
##   destination_port = 8080
##   tags             = { Name = "ec2-a-to-ec2-b-8080" }
## }
##
## resource "aws_ec2_network_insights_analysis" "a_to_b" {
##   network_insights_path_id = aws_ec2_network_insights_path.a_to_b.id
##   tags                     = { Name = "ec2-a-to-b-analysis" }
## }
