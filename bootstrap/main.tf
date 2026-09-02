resource "aws_s3_bucket" "terraform_state" {
  bucket        = "${var.project_name}-tfstate${local.name_suffix_physical}-${local.account_id}"
  force_destroy = var.force_destroy_buckets
  tags = {
    Name = "${var.project_name}-tfstate${local.name_suffix_tag}"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDBロックも作成する。infra/backend.tfはTerraform 1.10+のS3 native lockingを利用する。
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.project_name}-tf-lock${local.name_suffix_physical}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "${var.project_name}-tf-lock${local.name_suffix_tag}"
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-artifacts${local.name_suffix_physical}-${local.account_id}"
  force_destroy = var.force_destroy_buckets
  tags = {
    Name = "${var.project_name}-artifacts${local.name_suffix_tag}"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline-role${local.name_suffix_physical}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "codepipeline.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Name = "${var.project_name}-codepipeline-role${local.name_suffix_tag}"
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-codepipeline-policy${local.name_suffix_physical}"
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:GetBucketVersioning"], Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect = "Allow", Action = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"], Resource = "*"
      },
      {
        Effect = "Allow", Action = ["codedeploy:CreateDeployment", "codedeploy:GetApplicationRevision", "codedeploy:GetDeployment", "codedeploy:GetDeploymentConfig", "codedeploy:RegisterApplicationRevision"], Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codeconnections:UseConnection",
          "codestar-connections:UseConnection"
        ],
        Resource = var.codestar_connection_arn
      }
    ]

  })
}

resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role${local.name_suffix_physical}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "codebuild.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Name = "${var.project_name}-codebuild-role${local.name_suffix_tag}"
  }
}

# Terraform apply用の学習向け広域ポリシー。READMEに本番向け分割方針を記載する。
resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-terraform-runner${local.name_suffix_physical}"
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*"
      },
      {
        Effect = "Allow", Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation"], Resource = [aws_s3_bucket.terraform_state.arn, "${aws_s3_bucket.terraform_state.arn}/*", aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"], Resource = aws_dynamodb_table.terraform_lock.arn
      },
      {
        Effect = "Allow", Action = ["ec2:*", "elasticloadbalancing:*", "autoscaling:*", "rds:*", "secretsmanager:*", "kms:*", "iam:*", "logs:*", "cloudwatch:*", "sns:*", "ssm:*", "route53:*", "codedeploy:*"], Resource = "*"
      }
    ]

  })
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.project_name}-codedeploy-role${local.name_suffix_physical}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "codedeploy.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Name = "${var.project_name}-codedeploy-role${local.name_suffix_tag}"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = "${var.project_name}-app${local.name_suffix_physical}"
  tags = {
    Name = "${var.project_name}-codedeploy-app${local.name_suffix_tag}"
  }
}

resource "aws_codedeploy_deployment_group" "app" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.project_name}-dg${local.name_suffix_physical}"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }
  ec2_tag_filter {
    key   = "DeployGroup"
    type  = "KEY_AND_VALUE"
    value = "app${local.name_suffix_tag}"
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  tags = {
    Name = "${var.project_name}-deployment-group${local.name_suffix_tag}"
  }
}

resource "aws_codebuild_project" "projects" {
  for_each = {
    plan  = "buildspecs/buildspec-terraform-plan.yml"
    apply = "buildspecs/buildspec-terraform-apply.yml"
    wait  = "buildspecs/buildspec-wait-infra.yml"
    app   = "buildspecs/buildspec-app-deploy.yml"

  }

  name          = "${var.project_name}-${each.key}${local.name_suffix_physical}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = each.key == "wait" ? 30 : 60

  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = each.value
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }
    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = aws_s3_bucket.terraform_state.id
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
    environment_variable {
      name  = "NAME_SUFFIX_PHYSICAL"
      value = local.name_suffix_physical
    }

  }
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}${local.name_suffix_tag}"
      stream_name = each.key
    }
  }
  tags = {
    Name = "${var.project_name}-${each.key}-build${local.name_suffix_tag}"
  }
}

resource "aws_codepipeline" "main" {
  name          = "${var.project_name}-pipeline${local.name_suffix_physical}"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn = var.codestar_connection_arn, FullRepositoryId = "${var.github_owner}/${var.github_repo}", BranchName = var.github_branch, DetectChanges = "true"
      }

    }

  }

  stage {
    name = "Terraform_Plan"
    action {
      name             = "Validate_And_Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["PlanArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.projects["plan"].name
      }
    }

  }

  dynamic "stage" {
    for_each = var.enable_manual_approval ? [1] : []
    content {
      name = "Manual_Approval"
      action {
        name     = "Approve_Terraform_Apply"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
      }

    }

  }

  stage {
    name = "Terraform_Apply"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.projects["apply"].name
      }
    }

  }

  stage {
    name = "Wait_For_Infrastructure"
    action {
      name            = "Wait"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.projects["wait"].name
      }
    }

  }

  stage {
    name = "Build_Application"
    action {
      name             = "Build_And_Package"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["AppArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.projects["app"].name
      }
    }

  }

  stage {
    name = "Deploy_Application"
    action {
      name            = "CodeDeploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["AppArtifact"]
      configuration = {
        ApplicationName = aws_codedeploy_app.app.name, DeploymentGroupName = aws_codedeploy_deployment_group.app.deployment_group_name
      }
    }

  }

  tags = {
    Name = "${var.project_name}-pipeline${local.name_suffix_tag}"
  }
}
