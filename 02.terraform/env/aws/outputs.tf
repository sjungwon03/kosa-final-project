output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ec2_private_ips" {
  value = module.ec2.private_ips
}

output "ec2_public_ips" {
  value = module.ec2.public_ips
}

output "nlb_dns_name" {
  value = module.nlb.nlb_dns_name
}

output "domain_record" {
  value = module.route53.record_fqdn
}

output "vpn_instance_public_ip" {
  value = module.wireguard.public_ip
}

output "vpn_instance_private_ip" {
  value = module.wireguard.private_ip
}

output "ssh_key_name" {
  value = module.keypair.key_name
}

output "ssh_key_path" {
  value = "${path.module}/../../modules/aws/keypair/${module.keypair.key_name}.pem"
}

output "ssh_connection_command" {
  value = "ssh -i ${path.module}/../../modules/aws/keypair/${module.keypair.key_name}.pem ec2-user@${module.ec2.public_ips[0]}"
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  value = module.eks.cluster_arn
}

output "karpenter_instance_profile" {
  value = module.karpenter.instance_profile_name
}

output "cloudburst_threshold" {
  value = var.cloudburst_threshold
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}