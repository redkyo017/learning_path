variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "private_hosted_zone_name" {
  type    = string
  default = "internal.platform"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "resolver_sg_id" {
  type = string
}

variable "onprem_dns_ip" {
  type        = string
  description = "IP of the on-prem DNS server (used in Day 6)"
  default     = "192.168.1.2"
}
