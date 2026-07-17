variable "name" {
  type = string
}

variable "tgw_id" {
  type = string
}

variable "tgw_shared_services_route_table_id" {
  type = string
}

variable "customer_gateway_ip" {
  type        = string
  description = "Elastic IP of the strongSwan EC2"
}

variable "shared_services_private_route_table_ids" {
  type = list(string)
}
