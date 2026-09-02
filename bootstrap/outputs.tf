output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.id
}
output "terraform_lock_table" {
  value = aws_dynamodb_table.terraform_lock.name
}
output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.id
}
output "pipeline_name" {
  value = aws_codepipeline.main.name
}
output "codedeploy_application" {
  value = aws_codedeploy_app.app.name
}
output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.app.deployment_group_name
}
