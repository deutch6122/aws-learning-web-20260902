# Pipelineで既定値以外を使う場合、このファイルを pipeline.auto.tfvars にコピーしてcommitします。
# passwordやAccess Keyは絶対に記載しません。
alarm_email             = "****.****@icloud.com"
acm_certificate_arn     = ""
rds_multi_az            = false
rds_deletion_protection = false
enable_nat_gateway      = true
enable_vpc_endpoints    = false
create_route53_record   = true
