variable "project_name" {
  type = string
}
variable "name_suffix_tag" {
  type = string
}
variable "name_suffix_physical" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "security_group_id" {
  type = string
}
variable "engine_version" {
  type     = string
  nullable = true
}
variable "instance_class" {
  type = string
}
variable "allocated_storage" {
  type = number
}
variable "multi_az" {
  type = bool
}
variable "deletion_protection" {
  type = bool
}
variable "backup_retention_days" {
  type = number
}
variable "db_name" {
  type = string
}
variable "db_username" {
  type      = string
  sensitive = true
}
