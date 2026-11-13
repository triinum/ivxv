variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "azs" {
  description = "Availability zones (skeleton: wire to real subnets later)"
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
