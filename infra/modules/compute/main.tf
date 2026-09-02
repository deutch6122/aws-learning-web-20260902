data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_partition" "current" {}

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role${var.name_suffix_physical}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Name = "${var.project_name}-ec2-role${var.name_suffix_tag}"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "app" {
  name = "${var.project_name}-ec2-app-policy${var.name_suffix_physical}"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "ReadOnlyTheApplicationSecret", Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.secret_arn
      },
      {
        Sid = "ReadCodeDeployArtifacts", Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"], Resource = [var.artifact_bucket_arn_prefix, "${var.artifact_bucket_arn_prefix}/*", "arn:${data.aws_partition.current.partition}:s3:::aws-codedeploy-${var.aws_region}", "arn:${data.aws_partition.current.partition}:s3:::aws-codedeploy-${var.aws_region}/*"]
      }
    ]

  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-profile${var.name_suffix_physical}"
  role = aws_iam_role.ec2.name
  tags = {
    Name = "${var.project_name}-instance-profile${var.name_suffix_tag}"
  }
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.project_name}-lt${var.name_suffix_physical}-"
  image_id               = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  update_default_version = true
  vpc_security_group_ids = [var.app_security_group_id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  monitoring {
    enabled = true
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted             = true
      volume_size           = 12
      volume_type           = "gp3"
      delete_on_termination = true
    }

  }
  user_data = base64encode(templatefile("${path.root}/../user_data/al2023_setup.sh", {
    aws_region      = var.aws_region
    secret_arn      = var.secret_arn
    app_version     = var.app_version
    project_name    = var.project_name
    name_suffix_tag = var.name_suffix_tag

  }))
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-ec2${var.name_suffix_tag}", DeployGroup = "app${var.name_suffix_tag}", PatchGroup = "app${var.name_suffix_tag}"
    }

  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-app-volume${var.name_suffix_tag}"
    }
  }
  tags = {
    Name = "${var.project_name}-launch-template${var.name_suffix_tag}"
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-asg${var.name_suffix_physical}"
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  vpc_zone_identifier       = var.private_app_subnet_ids
  target_group_arns         = var.target_group_arns
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 300
  enabled_metrics           = ["GroupDesiredCapacity", "GroupInServiceInstances"]
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 300
    }
  }
  dynamic "tag" {
    for_each = {
      Name = "${var.project_name}-app-ec2${var.name_suffix_tag}", DeployGroup = "app${var.name_suffix_tag}", PatchGroup = "app${var.name_suffix_tag}"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }

  }
  lifecycle {
    create_before_destroy = true
  }
}
