# labs/day07/terraform/rds.tf
#
# COST: a db.t4g.micro Multi-AZ PostgreSQL instance runs roughly
# $0.032/hr for the primary (us-east-1 on-demand list price at time of
# writing; other regions vary) with Multi-AZ doubling the compute charge
# for the standby, plus 20 GB of gp3 storage (a few cents/day) and
# Performance Insights at the free 7-day retention tier used below (no
# extra charge). All in, expect on the order of $0.07-0.09/hr while the
# instance is up. A lab session of a few hours costs well under $1; a
# full calendar day left running costs a few dollars -- which is where
# this day's README.md $2-5 estimate comes from, combined with the Atlas
# M10 cluster's own hourly charge. Leave either one running for more than
# a day and the estimate no longer holds.
#
# skip_final_snapshot = true is set deliberately. Without it, `terraform
# destroy` either fails outright (no final_snapshot_identifier given) or
# leaves a manual snapshot behind that AWS bills for indefinitely until
# someone deletes it by hand -- exactly the kind of leftover
# labs/verify-teardown.sh checks for under the dbm-lab- prefix. Skipping
# the final snapshot means a plain `terraform destroy` is already a
# complete, billing-free teardown, with nothing extra to remember.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# The default VPC and its subnets are used rather than provisioning a new
# VPC -- this lab is about RDS and Performance Insights, not VPC design,
# and every commercial AWS account still has a default VPC unless someone
# has explicitly deleted it.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "dbm_lab" {
  name       = "dbm-lab-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "dbm-lab-subnet-group"
  }
}

# Inbound Postgres traffic only from the one CIDR you supplied -- your own
# /32, not 0.0.0.0/0. This is the actual access control; publicly_accessible
# below only decides whether the instance gets a public IP to be restricted
# against in the first place.
resource "aws_security_group" "dbm_lab_pg" {
  name        = "dbm-lab-pg-sg"
  description = "dbm-lab: allow Postgres from the learner's own IP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Postgres from my_ip_cidr"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dbm-lab-pg-sg"
  }
}

# shared_preload_libraries is static (needs a reboot to take effect, the
# same "locked until restart" behavior day07.md's parameter-group exercise
# asks you to distinguish from a genuinely locked parameter);
# log_min_duration_statement applies without a reboot. Both are set here
# so Performance Insights' top-SQL panel and pg_stat_statements are ready
# to read the moment pgbench starts, instead of after a mid-lab reboot.
resource "aws_db_parameter_group" "dbm_lab_pg16" {
  name        = "dbm-lab-pg16"
  family      = "postgres16"
  description = "dbm-lab: pg_stat_statements preloaded, slow-statement logging on"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }

  tags = {
    Name = "dbm-lab-pg16"
  }
}

resource "aws_db_instance" "dbm_lab_pg" {
  identifier = "dbm-lab-pg"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "dbmlab"
  username = "dbmlab_admin"
  password = var.db_password

  multi_az             = true
  publicly_accessible  = var.publicly_accessible
  db_subnet_group_name = aws_db_subnet_group.dbm_lab.name
  vpc_security_group_ids = [
    aws_security_group.dbm_lab_pg.id,
  ]
  parameter_group_name = aws_db_parameter_group.dbm_lab_pg16.name

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  backup_retention_period = 1

  # See the cost comment at the top of this file for why this is set
  # deliberately, not left at the provider default.
  skip_final_snapshot = true
  deletion_protection = false

  apply_immediately = true

  tags = {
    Name = "dbm-lab-pg"
  }
}
