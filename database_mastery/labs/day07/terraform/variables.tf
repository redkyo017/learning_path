# labs/day07/terraform/variables.tf
#
# Four inputs. Three carry no secret and get a placeholder default's worth
# of documentation in terraform.tfvars.example; db_password carries the
# one genuine secret in this file set and has no default at all -- a
# default would be a real password checked into source control the moment
# anyone forgot to override it, which defeats the entire point of a
# variable for a secret.

variable "region" {
  description = "AWS region to create the dbm-lab-pg instance in. Pick one close to you; the cost estimate in README.md assumes a single-region, single-AZ-pair Multi-AZ deployment in any commercial region."
  type        = string
}

variable "db_password" {
  description = "Master password for the dbm-lab-pg RDS instance. No default on purpose -- generate one with a password manager and put it only in terraform.tfvars (git-ignored), never in this file, never in a commit."
  type        = string
  sensitive   = true
}

variable "my_ip_cidr" {
  description = "Your current public IP, as a /32 CIDR (e.g. 203.0.113.4/32 -- find yours with 'curl -s https://checkip.amazonaws.com'). Used as the only inbound source the security group allows on 5432."
  type        = string
}

variable "publicly_accessible" {
  description = "Whether dbm-lab-pg gets a public IP at all. Defaults to false: the instance sits in the default VPC's subnets and you reach it by running psql/pgbench from a host already inside that VPC, or by setting this to true and relying on the security group's CIDR restriction as the only gate. Leave it false unless you have a specific reason to flip it."
  type        = bool
  default     = false
}
