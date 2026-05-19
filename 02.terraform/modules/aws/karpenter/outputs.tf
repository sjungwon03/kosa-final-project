output "instance_profile_name" {
  value = aws_iam_instance_profile.karpenter.name
}

output "role_arn" {
  value = aws_iam_role.karpenter.arn
}

output "role_name" {
  value = aws_iam_role.karpenter.name
}