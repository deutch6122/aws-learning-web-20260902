output "vpc_id" {
  value = module.network.vpc_id
}
output "alb_dns_name" {
  value = module.loadbalancer.alb_dns_name
}
output "target_group_arn" {
  value = module.loadbalancer.target_group_arn
}
output "asg_name" {
  value = module.compute.asg_name
}
output "rds_endpoint" {
  value     = module.database.endpoint
  sensitive = true
}
output "database_secret_arn" {
  value     = module.database.secret_arn
  sensitive = true
}
output "application_url" {
  value = "${var.acm_certificate_arn == "" ? "http" : "https"}://${local.fqdn}"
}
output "sns_topic_arn" {
  value = module.monitoring.sns_topic_arn
}
