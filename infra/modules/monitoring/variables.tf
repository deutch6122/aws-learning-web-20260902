variable "project_name" {
  type = string
}
variable "name_suffix_tag" {
  type = string
}
variable "name_suffix_physical" {
  type = string
}
variable "log_retention_days" {
  type = number
}
variable "alarm_email" {
  type = string
}
variable "alb_arn_suffix" {
  type = string
}
variable "target_group_arn_suffix" {
  type = string
}
variable "asg_name" {
  type = string
}
variable "rds_identifier" {
  type = string
}
