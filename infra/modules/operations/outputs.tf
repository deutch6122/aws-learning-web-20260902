output "maintenance_window_id" {
  value = aws_ssm_maintenance_window.this.id
}
output "patch_baseline_id" {
  value = aws_ssm_patch_baseline.this.id
}
