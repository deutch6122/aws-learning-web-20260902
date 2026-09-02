output "log_group_names" {
  value = {
    for k, v in aws_cloudwatch_log_group.app : k => v.name
  }
}
output "sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}
