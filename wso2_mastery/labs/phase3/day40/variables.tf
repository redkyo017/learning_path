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
