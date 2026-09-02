module "network" {
  source               = "./modules/network"
  aws_region           = var.aws_region
  project_name         = var.project_name
  name_suffix_tag      = var.name_suffix_tag
  name_suffix_physical = var.name_suffix_physical
  vpc_cidr             = var.vpc_cidr
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_endpoints = var.enable_vpc_endpoints
}

module "security" {
  source               = "./modules/security"
  project_name         = var.project_name
  name_suffix_tag      = var.name_suffix_tag
  name_suffix_physical = var.name_suffix_physical
  vpc_id               = module.network.vpc_id
  enable_https         = var.acm_certificate_arn != ""
}

module "database" {
  source                = "./modules/database"
  project_name          = var.project_name
  name_suffix_tag       = var.name_suffix_tag
  name_suffix_physical  = var.name_suffix_physical
  subnet_ids            = module.network.private_db_subnet_ids
  security_group_id     = module.security.db_security_group_id
  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  multi_az              = var.rds_multi_az
  deletion_protection   = var.rds_deletion_protection
  backup_retention_days = var.rds_backup_retention_days
  db_name               = var.db_name
  db_username           = var.db_username
}

module "loadbalancer" {
  source                = "./modules/loadbalancer"
  project_name          = var.project_name
  name_suffix_tag       = var.name_suffix_tag
  name_suffix_physical  = var.name_suffix_physical
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  acm_certificate_arn   = var.acm_certificate_arn
  hosted_zone_id        = var.hosted_zone_id
  fqdn                  = local.fqdn
  create_route53_record = var.create_route53_record
}

module "compute" {
  source                     = "./modules/compute"
  project_name               = var.project_name
  name_suffix_tag            = var.name_suffix_tag
  name_suffix_physical       = var.name_suffix_physical
  aws_region                 = var.aws_region
  private_app_subnet_ids     = module.network.private_app_subnet_ids
  app_security_group_id      = module.security.app_security_group_id
  target_group_arns          = [module.loadbalancer.target_group_arn]
  secret_arn                 = module.database.secret_arn
  artifact_bucket_arn_prefix = "arn:aws:s3:::${var.project_name}-artifacts${var.name_suffix_physical}-*"
  instance_type              = var.ec2_instance_type
  min_size                   = var.asg_min_size
  desired_capacity           = var.asg_desired_capacity
  max_size                   = var.asg_max_size
  app_version                = var.app_version
}

module "monitoring" {
  source                  = "./modules/monitoring"
  project_name            = var.project_name
  name_suffix_tag         = var.name_suffix_tag
  name_suffix_physical    = var.name_suffix_physical
  log_retention_days      = var.cloudwatch_log_retention_days
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.loadbalancer.alb_arn_suffix
  target_group_arn_suffix = module.loadbalancer.target_group_arn_suffix
  asg_name                = module.compute.asg_name
  rds_identifier          = module.database.db_identifier
}

module "operations" {
  source               = "./modules/operations"
  project_name         = var.project_name
  name_suffix_tag      = var.name_suffix_tag
  name_suffix_physical = var.name_suffix_physical
  patch_group          = "app${var.name_suffix_tag}"
}
