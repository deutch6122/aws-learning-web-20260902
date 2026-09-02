data "aws_partition" "current" {}

resource "aws_ssm_patch_baseline" "this" {
  name                                 = "${var.project_name}-baseline${var.name_suffix_tag}"
  description                          = "Amazon Linux 2023 monthly security patch baseline"
  operating_system                     = "AMAZON_LINUX_2023"
  approved_patches_enable_non_security = false
  approval_rule {
    approve_after_days = 7
    compliance_level   = "HIGH"
    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }
    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important", "Medium"]
    }

  }
  tags = {
    Name = "${var.project_name}-patch-baseline${var.name_suffix_tag}"
  }
}

resource "aws_ssm_patch_group" "this" {
  baseline_id = aws_ssm_patch_baseline.this.id
  patch_group = var.patch_group
}

resource "aws_ssm_maintenance_window" "this" {
  name                       = "${var.project_name}-maintenance${var.name_suffix_tag}"
  description                = "First Wednesday 11:00 JST monthly patching"
  schedule                   = "cron(0 11 ? * WED#1 *)"
  schedule_timezone          = "Asia/Tokyo"
  duration                   = 3
  cutoff                     = 1
  allow_unassociated_targets = false
  tags = {
    Name = "${var.project_name}-maintenance-window${var.name_suffix_tag}"
  }
}

resource "aws_ssm_maintenance_window_target" "this" {
  window_id     = aws_ssm_maintenance_window.this.id
  name          = "${var.project_name}-patch-target${var.name_suffix_tag}"
  description   = "Instances tagged for monthly patching"
  resource_type = "INSTANCE"
  targets {
    key    = "tag:PatchGroup"
    values = [var.patch_group]
  }
}

resource "aws_iam_role" "maintenance" {
  name = "${var.project_name}-maintenance-role${var.name_suffix_physical}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ssm.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Name = "${var.project_name}-maintenance-role${var.name_suffix_tag}"
  }
}

resource "aws_iam_role_policy" "maintenance" {
  name = "${var.project_name}-maintenance-policy${var.name_suffix_physical}"
  role = aws_iam_role.maintenance.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["ssm:SendCommand", "ssm:GetCommandInvocation", "ssm:ListCommands", "ssm:ListCommandInvocations"], Resource = "*"
      },
      {
        Effect = "Allow", Action = ["ec2:DescribeInstances"], Resource = "*"
      }
    ]
  })
}

resource "aws_ssm_maintenance_window_task" "patch" {
  window_id        = aws_ssm_maintenance_window.this.id
  name             = "${var.project_name}-run-patch${var.name_suffix_tag}"
  description      = "Install approved patches and reboot if needed"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  service_role_arn = aws_iam_role.maintenance.arn
  priority         = 1
  max_concurrency  = "1"
  max_errors       = "1"
  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.this.id]
  }
  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
      timeout_seconds = 7200

    }

  }
}
