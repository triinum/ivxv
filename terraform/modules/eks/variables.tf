variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the control plane / nodes (skeleton)"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
