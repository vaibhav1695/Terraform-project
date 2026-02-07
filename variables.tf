variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "lab"
}

variable "cost_center" {
  type    = string
  default = "practice"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "name_prefix" {
  type    = string
  default = ""
  description = "Optional extra prefix for resource names."
}
