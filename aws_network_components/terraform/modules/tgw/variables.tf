variable "name" {
  type = string
}

variable "shared_services_vpc_id" {
  type = string
}

variable "shared_services_private_subnet_ids" {
  type = list(string)
}

variable "shared_services_private_route_table_ids" {
  type = list(string)
}

variable "app_vpc_id" {
  type = string
}

variable "app_private_subnet_ids" {
  type = list(string)
}

variable "app_private_route_table_ids" {
  type = list(string)
}
