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

output "route53_name_servers" {
  value = module.route53.name_servers
}

output "acm_certificate_arn" {
  value       = var.enable_tls ? aws_acm_certificate.nlb[0].arn : null
  description = "ACM Certificate ARN for NLB TLS"
}

output "nlb_tls_url" {
  value       = var.enable_tls ? "https://${var.record_name}" : null
  description = "NLB TLS URL"
}

output "vpn_connection_id" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.vpn_connection_id : null
  description = "AWS VPN Connection ID"
}

output "vpn_tunnel1_address" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.tunnel1_address : null
  description = "AWS Tunnel 1 Outside IP (pfSense Phase 1 Remote Gateway)"
}

output "vpn_tunnel2_address" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.tunnel2_address : null
  description = "AWS Tunnel 2 Outside IP (pfSense Phase 1 Remote Gateway)"
}

output "vpn_tunnel1_preshared_key" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.tunnel1_preshared_key : null
  sensitive   = true
  description = "AWS Tunnel 1 Pre-Shared Key (pfSense Phase 1 PSK)"
}

output "vpn_tunnel2_preshared_key" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.tunnel2_preshared_key : null
  sensitive   = true
  description = "AWS Tunnel 2 Pre-Shared Key (pfSense Phase 1 PSK)"
}

output "vpn_customer_gateway_configuration" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.customer_gateway_configuration : null
  sensitive   = true
  description = "AWS VPN Customer Gateway Configuration XML (contains all IKE/IPsec parameters)"
}

output "vpn_tunnel_outside_ips" {
  value = var.customer_gateway_ip != "" ? [
    module.site_to_site_vpn.tunnel1_address,
    module.site_to_site_vpn.tunnel2_address
  ] : null
  description = "AWS VPN tunnel outside IPs (for pfSense Phase 1 Remote Gateway)"
}

output "customer_gateway_id" {
  value       = var.customer_gateway_ip != "" ? module.site_to_site_vpn.customer_gateway_id : null
  description = "AWS Customer Gateway ID"
}

output "vgw_id" {
  value       = module.site_to_site_vpn.vgw_id
  description = "AWS Virtual Private Gateway ID"
}

output "aws_vpc_cidr" {
  value       = var.vpc_cidr
  description = "AWS VPC CIDR (pfSense Phase 2 Remote Network)"
}

output "onprem_cidr" {
  value       = var.onprem_cidr_block
  description = "On-Premises CIDR (pfSense Phase 2 Local Network)"
}

output "haproxy_instance_ids" {
  value       = module.ec2.instance_ids
  description = "HAProxy EC2 Instance IDs (for SSM Session Manager)"
}

output "ssh_key_name" {
  value = module.keypair.key_name
}

output "ssh_key_path" {
  value = "${path.module}/../../modules/aws/keypair/${module.keypair.key_name}.pem"
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