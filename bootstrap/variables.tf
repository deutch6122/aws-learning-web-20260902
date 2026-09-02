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
variable "enable_manual_approval" {
  type    = bool
  default = false
}
variable "terraform_version" {
  type    = string
  default = "1.13.1"
}

variable "force_destroy_buckets" {
  description = "学習環境のdestroyを容易にする。重要データがある環境ではfalseにする。"
  type        = bool
  default     = true
}
