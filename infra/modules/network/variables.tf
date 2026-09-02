variable "aws_region" {
  type = string
}
variable "project_name" {
  type = string
}
variable "name_suffix_tag" {
  type = string
}
variable "name_suffix_physical" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "enable_nat_gateway" {
  type = bool
}
variable "enable_vpc_endpoints" {
  type = bool
}
