variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "aws_account_id" {
  type    = string
  default = "TODO_REPLACE_WITH_YOUR_ACCOUNT_ID"
}

variable "image_uri_cp" {
  type    = string
  default = "TODO_REPLACE:wso2-cp:latest"
}

variable "image_uri_is" {
  type    = string
  default = "TODO_REPLACE:wso2-is:latest"
}

variable "image_uri_gw" {
  type    = string
  default = "TODO_REPLACE:wso2-gw:latest"
}

variable "image_uri_tm" {
  type    = string
  default = "TODO_REPLACE:wso2-tm:latest"
}

variable "vpc_id" {
  type    = string
  default = "TODO_REPLACE_WITH_YOUR_VPC_ID"
}

variable "public_subnet_ids" {
  type    = list(string)
  default = ["TODO_REPLACE_WITH_PUBLIC_SUBNET_IDS"]
}

variable "acm_certificate_arn" {
  type    = string
  default = "TODO_REPLACE_WITH_ACM_CERTIFICATE_ARN"
}
