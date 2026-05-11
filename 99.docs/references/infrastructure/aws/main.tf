module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  environment  = var.environment
  aws_region   = var.aws_region
  vpc_cidr     = var.vpc_cidr
}

module "eks" {
  source = "./modules/eks"

  cluster_name = var.cluster_name
  environment  = var.environment
  aws_region   = var.aws_region
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
}

module "vpn" {
  source = "./modules/vpn"

  cluster_name       = var.cluster_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  onprem_cidr        = var.onprem_cidr
  onprem_vpn_gateway = var.onprem_vpn_gateway
}

module "elasticache" {
  source = "./modules/elasticache"

  cluster_name    = var.cluster_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.database_subnet_ids
  security_group_ids = [module.eks.cluster_primary_security_group_id]
}

module "s3_cloudfront" {
  source = "./modules/s3-cloudfront"

  frontend_bucket_name = var.frontend_bucket_name
  environment          = var.environment
  acm_certificate_arn  = var.acm_certificate_arn
}

module "monitoring" {
  source = "./modules/monitoring"

  cluster_name         = var.cluster_name
  environment          = var.environment
  eks_cluster_name     = module.eks.cluster_name
  redis_cluster_id     = module.elasticache.cluster_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "vpn_connection_id" {
  value = module.vpn.connection_id
}

output "redis_endpoint" {
  value = module.elasticache.endpoint
}

output "cloudfront_domain_name" {
  value = module.s3_cloudfront.domain_name
}