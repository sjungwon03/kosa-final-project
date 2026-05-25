output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "cluster_certificate_authority_data" {
  value     = aws_eks_cluster.this.certificate_authority[0].data
  sensitive = true
}

output "cluster_role_arn" {
  value = aws_iam_role.cluster.arn
}

output "fargate_profile_name" {
  value = var.create_fargate_profile ? aws_eks_fargate_profile.dr[0].fargate_profile_name : null
}

output "fargate_role_arn" {
  value = aws_iam_role.fargate.arn
}