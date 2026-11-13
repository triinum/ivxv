variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "name_prefix" {
  type    = string
  default = "ivxv"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["eu-north-1a"]
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}
