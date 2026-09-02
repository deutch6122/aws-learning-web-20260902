variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}
variable "project_name" {
  type    = string
  default = "aws-learning-web"
}
variable "environment" {
  type    = string
  default = "commercial-learning"
}
variable "name_suffix_tag" {
  type    = string
  default = "_20260902"
}
variable "name_suffix_physical" {
  type    = string
  default = "-20260902"
}
variable "vpc_cidr" {
  type    = string
  default = "20.0.0.0/16"
}
variable "domain_name" {
  type    = string
  default = "filanza-aws.com"
}
variable "hosted_zone_id" {
  type    = string
  default = "Z10320622XUBBC9Y04KQI"
}
variable "app_subdomain" {
  type    = string
  default = "app"
}
variable "create_route53_record" {
  type    = bool
  default = true
}
variable "acm_certificate_arn" {
  type    = string
  default = ""
}
variable "alarm_email" {
  type    = string
  default = ""
}
variable "rds_engine_version" {
  type     = string
  default  = null
  nullable = true
}
variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "rds_allocated_storage" {
  type    = number
  default = 20
}
variable "rds_multi_az" {
  type    = bool
  default = false
}
variable "rds_deletion_protection" {
  type    = bool
  default = false
}
variable "rds_backup_retention_days" {
  type    = number
  default = 1
}
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_username" {
  type      = string
  default   = "appadmin"
  sensitive = true
}
variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}
variable "asg_min_size" {
  type    = number
  default = 1
}
variable "asg_desired_capacity" {
  type    = number
  default = 1
}
variable "asg_max_size" {
  type    = number
  default = 2
}
variable "enable_nat_gateway" {
  type    = bool
  default = true
}
variable "enable_vpc_endpoints" {
  type    = bool
  default = false
}
variable "enable_manual_approval" {
  type    = bool
  default = false
}
variable "github_owner" {
  type    = string
  default = ""
}
variable "github_repo" {
  type    = string
  default = ""
}
variable "github_branch" {
  type    = string
  default = "main"
}
variable "codestar_connection_arn" {
  type    = string
  default = ""
}
variable "cloudwatch_log_retention_days" {
  type    = number
  default = 7
}
variable "app_version" {
  type    = string
  default = "1.0.0"
}
