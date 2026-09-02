output "asg_name" {
  value = aws_autoscaling_group.this.name
}
output "instance_role_arn" {
  value = aws_iam_role.ec2.arn
}
