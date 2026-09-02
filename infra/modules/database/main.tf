resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*+-=?"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet${var.name_suffix_physical}"
  subnet_ids = var.subnet_ids
  tags = {
    Name = "${var.project_name}-db-subnet${var.name_suffix_tag}"
  }
}

resource "aws_db_instance" "this" {
  identifier                      = "${var.project_name}-rds${var.name_suffix_physical}"
  engine                          = "mysql"
  engine_version                  = var.engine_version
  instance_class                  = var.instance_class
  allocated_storage               = var.allocated_storage
  max_allocated_storage           = var.allocated_storage * 2
  storage_type                    = "gp3"
  storage_encrypted               = true
  db_name                         = var.db_name
  username                        = var.db_username
  password                        = random_password.master.result
  port                            = 3306
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [var.security_group_id]
  publicly_accessible             = false
  multi_az                        = var.multi_az
  backup_retention_period         = var.backup_retention_days
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = true
  apply_immediately               = true
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  performance_insights_enabled    = false
  copy_tags_to_snapshot           = true
  tags = {
    Name = "${var.project_name}-rds${var.name_suffix_tag}"
  }
}

resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.project_name}/database${var.name_suffix_tag}"
  description             = "Application database connection information"
  recovery_window_in_days = 0
  tags = {
    Name = "${var.project_name}-database-secret${var.name_suffix_tag}"
  }
}

# 値はコードやUser Dataに埋め込まず、EC2が実行時にこのSecretだけを取得する。
resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.master.result

  })
}
