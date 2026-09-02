terraform {
  backend "s3" {
    # CodeBuildでは buildspec の -backend-config で実値を注入する。
    key          = "infra/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true

  }
}
