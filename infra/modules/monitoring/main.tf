locals {
  log_groups = toset(["messages", "cloud-init", "apache-access", "apache-error", "tomcat", "application", "codedeploy"])
  alarm_dimensions = {
    alb_5xx = {
      namespace = "AWS/ApplicationELB", metric = "HTTPCode_ELB_5XX_Count", statistic = "Sum", threshold = 1, period = 300, dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
    target_5xx = {
      namespace = "AWS/ApplicationELB", metric = "HTTPCode_Target_5XX_Count", statistic = "Sum", threshold = 1, period = 300, dimensions = {
        LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix
      }
    }
    response_time = {
      namespace = "AWS/ApplicationELB", metric = "TargetResponseTime", statistic = "Average", threshold = 2, period = 300, dimensions = {
        LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix
      }
    }
    unhealthy = {
      namespace = "AWS/ApplicationELB", metric = "UnHealthyHostCount", statistic = "Maximum", threshold = 1, period = 60, dimensions = {
        LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix
      }
    }
    ec2_cpu = {
      namespace = "AWS/EC2", metric = "CPUUtilization", statistic = "Average", threshold = 80, period = 300, dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
    ec2_status = {
      namespace = "AWS/EC2", metric = "StatusCheckFailed", statistic = "Maximum", threshold = 1, period = 60, dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
    asg_in_service = {
      namespace = "AWS/AutoScaling", metric = "GroupInServiceInstances", statistic = "Minimum", threshold = 1, period = 60, dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
    asg_desired = {
      namespace = "AWS/AutoScaling", metric = "GroupDesiredCapacity", statistic = "Minimum", threshold = 1, period = 60, dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
    memory = {
      namespace = "CWAgent", metric = "mem_used_percent", statistic = "Average", threshold = 80, period = 300, dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
    disk = {
      namespace = "CWAgent", metric = "disk_used_percent", statistic = "Average", threshold = 80, period = 300, dimensions = {
        AutoScalingGroupName = var.asg_name
      }
    }
    rds_cpu = {
      namespace = "AWS/RDS", metric = "CPUUtilization", statistic = "Average", threshold = 80, period = 300, dimensions = {
        DBInstanceIdentifier = var.rds_identifier
      }
    }
    rds_storage = {
      namespace = "AWS/RDS", metric = "FreeStorageSpace", statistic = "Average", threshold = 2147483648, period = 300, dimensions = {
        DBInstanceIdentifier = var.rds_identifier
      }
    }
    rds_memory = {
      namespace = "AWS/RDS", metric = "FreeableMemory", statistic = "Average", threshold = 134217728, period = 300, dimensions = {
        DBInstanceIdentifier = var.rds_identifier
      }
    }
    rds_connections = {
      namespace = "AWS/RDS", metric = "DatabaseConnections", statistic = "Average", threshold = 80, period = 300, dimensions = {
        DBInstanceIdentifier = var.rds_identifier
      }
    }
    rds_read_latency = {
      namespace = "AWS/RDS", metric = "ReadLatency", statistic = "Average", threshold = 0.2, period = 300, dimensions = {
        DBInstanceIdentifier = var.rds_identifier
      }
    }
    rds_write_latency = {
      namespace = "AWS/RDS", metric = "WriteLatency", statistic = "Average", threshold = 0.2, period = 300, dimensions = {
        DBInstanceIdentifier = var.rds_identifier
      }
    }

  }
}

resource "aws_cloudwatch_log_group" "app" {
  for_each          = local.log_groups
  name              = "/aws/ec2/${var.project_name}/${each.value}${var.name_suffix_tag}"
  retention_in_days = var.log_retention_days
  tags = {
    Name = "${var.project_name}-${each.value}-logs${var.name_suffix_tag}"
  }
}

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms${var.name_suffix_physical}"
  tags = {
    Name = "${var.project_name}-alarms${var.name_suffix_tag}"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "standard" {
  for_each            = local.alarm_dimensions
  alarm_name          = "${var.project_name}-${replace(each.key, "_", "-")}${var.name_suffix_physical}"
  alarm_description   = "Learning environment alarm: ${each.value.metric}"
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  period              = each.value.period
  evaluation_periods  = 1
  threshold           = each.value.threshold
  comparison_operator = contains(["rds_storage", "rds_memory", "asg_in_service", "asg_desired"], each.key) ? "LessThanThreshold" : "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = each.value.dimensions
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags = {
    Name = "${var.project_name}-${each.key}${var.name_suffix_tag}"
  }
}

resource "aws_cloudwatch_log_metric_filter" "errors" {
  for_each       = aws_cloudwatch_log_group.app
  name           = "${var.project_name}-${each.key}-errors${var.name_suffix_physical}"
  log_group_name = each.value.name
  pattern        = "?ERROR ?Exception ?OutOfMemory ?Failed"
  metric_transformation {
    name      = "${replace(title(each.key), "-", "")}ErrorCount"
    namespace = "${var.project_name}/LogErrors"
    value     = "1"

  }
}

resource "aws_cloudwatch_metric_alarm" "log_errors" {
  for_each            = aws_cloudwatch_log_metric_filter.errors
  alarm_name          = "${var.project_name}-${each.key}-log-errors${var.name_suffix_physical}"
  namespace           = "${var.project_name}/LogErrors"
  metric_name         = each.value.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  tags = {
    Name = "${var.project_name}-${each.key}-log-errors${var.name_suffix_tag}"
  }
}
