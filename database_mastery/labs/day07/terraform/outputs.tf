# labs/day07/terraform/outputs.tf
#
# Endpoint and port only. db_password is never output here, in any form --
# not even marked sensitive -- because a sensitive Terraform output is
# still stored in plaintext inside terraform.tfstate, and this file's job
# is to hand you what you need to connect (host, port), not to hand back
# the secret you already typed into terraform.tfvars.

output "db_endpoint" {
  description = "The dbm-lab-pg RDS instance's connection endpoint (hostname only, no port)."
  value       = aws_db_instance.dbm_lab_pg.address
}

output "db_port" {
  description = "The port dbm-lab-pg listens on."
  value       = aws_db_instance.dbm_lab_pg.port
}
