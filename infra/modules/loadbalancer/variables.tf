variable "project_name" {
  type = string
}
variable "name_suffix_tag" {
  type = string
}
variable "name_suffix_physical" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnet_ids" {
  type = list(string)
}
variable "alb_security_group_id" {
  type = string
}
variable "acm_certificate_arn" {
  type = string
}
variable "hosted_zone_id" {
  type = string
}
variable "fqdn" {
  type = string
}
variable "create_route53_record" {
  type = bool
}
