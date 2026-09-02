variable "project_name" {
  type = string
}
variable "name_suffix_tag" {
  type = string
}
variable "name_suffix_physical" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "private_app_subnet_ids" {
  type = list(string)
}
variable "app_security_group_id" {
  type = string
}
variable "target_group_arns" {
  type = list(string)
}
variable "secret_arn" {
  type      = string
  sensitive = true
}
variable "artifact_bucket_arn_prefix" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "min_size" {
  type = number
}
variable "desired_capacity" {
  type = number
}
variable "max_size" {
  type = number
}
variable "app_version" {
  type = string
}
