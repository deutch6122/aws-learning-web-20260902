locals {
  name_suffix_tag      = var.name_suffix_tag
  name_suffix_physical = var.name_suffix_physical
  account_id           = data.aws_caller_identity.current.account_id
  physical_prefix      = "${var.project_name}${local.name_suffix_physical}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "self"
    ManagedBy   = "terraform"

  }
}
