output "endpoint" {
  value     = aws_db_instance.this.endpoint
  sensitive = true
}
output "secret_arn" {
  value     = aws_secretsmanager_secret.database.arn
  sensitive = true
}
output "db_identifier" {
  value = aws_db_instance.this.identifier
}
