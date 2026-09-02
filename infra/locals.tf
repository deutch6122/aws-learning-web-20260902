locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = "self"
    ManagedBy   = "terraform"

  }
  name_tag      = "${var.project_name}${var.name_suffix_tag}"
  name_physical = "${var.project_name}${var.name_suffix_physical}"
  fqdn          = "${var.app_subdomain}.${var.domain_name}"
}
