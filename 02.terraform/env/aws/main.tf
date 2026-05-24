terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "keypair" {
  source = "../../modules/aws/keypair"

  key_name = "${var.name}-key"
  tags     = var.tags
}

module "vpc" {
  source = "../../modules/aws/vpc"

  name                 = var.name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  region               = var.aws_region
  create_nat_gateway   = var.create_nat_gateway
  nat_gateway_per_az   = var.nat_gateway_per_az
  create_s3_endpoint   = var.create_s3_endpoint
  tags                 = var.tags
}

module "ec2" {
  source = "../../modules/aws/ec2"

  name            = "${var.name}-haproxy"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  instance_type   = var.instance_type
  key_name        = module.keypair.key_name
  user_data       = var.user_data
  allowed_cidrs   = var.allowed_cidrs
  onprem_cidr     = var.onprem_cidr_block
  create_ssm_role = false
  tags            = var.tags
}

module "nlb" {
  source = "../../modules/aws/nlb"

  name                = "${var.name}-nlb"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  target_instance_ids = module.ec2.instance_ids
  cross_zone_enabled  = true
  certificate_arn     = var.enable_tls ? aws_acm_certificate_validation.nlb[0].certificate_arn : ""
  tags                = var.tags

  depends_on = [aws_acm_certificate_validation.nlb]
}

module "route53" {
  source = "../../modules/aws/route53"

  domain_name       = var.domain_name
  record_name       = var.record_name
  lb_dns_name       = module.nlb.nlb_dns_name
  lb_zone_id        = module.nlb.nlb_zone_id
  create_zone       = var.route53_create_zone
  create_www_record = var.create_www_record
  enabled           = var.route53_enabled
  tags              = var.tags
}

resource "aws_acm_certificate" "nlb" {
  count = var.enable_tls ? 1 : 0

  domain_name       = var.record_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "cert_validation_nlb" {
  count = var.enable_tls ? 1 : 0

  allow_overwrite = true
  name            = tolist(aws_acm_certificate.nlb[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.nlb[0].domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.nlb[0].domain_validation_options)[0].resource_record_type
  zone_id         = module.route53.zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "nlb" {
  count = var.enable_tls ? 1 : 0

  certificate_arn         = aws_acm_certificate.nlb[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation_nlb[0].fqdn]
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Cluster API"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = []
    cidr_blocks     = [var.vpc_cidr]
  }

  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "On-prem access via VPN"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.onprem_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-eks-nodes-sg"
  })
}

module "eks" {
  source = "../../modules/aws/eks"

  cluster_name              = "${var.name}-eks"
  cluster_version           = var.eks_version
  subnet_ids               = module.vpc.private_subnet_ids
  allowed_cidrs            = var.allowed_cidrs
  create_addons             = var.eks_create_addons
  create_node_group         = var.eks_create_node_group
  node_group_instance_types = var.eks_node_instance_types
  node_group_desired_size   = var.eks_node_desired_size
  node_group_min_size       = var.eks_node_min_size
  node_group_max_size       = var.eks_node_max_size
  tags                     = var.tags
}

module "karpenter" {
  source = "../../modules/aws/karpenter"

  cluster_name       = "${var.name}-eks"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_id  = aws_security_group.eks_nodes.id
  tags               = var.tags

  depends_on = [module.eks]
}

module "site_to_site_vpn" {
  source = "../../modules/aws/site_to_site_vpn"

  vpc_id                     = module.vpc.vpc_id
  vpc_cidr                   = var.vpc_cidr
  onprem_cidr                = var.onprem_cidr_block
  customer_gateway_ip        = var.customer_gateway_ip
  vpn_name                   = "${var.name}-vpn"
  route_table_ids            = module.vpc.private_route_table_ids
  create_vpn_route_propagation = true
  tags                       = var.tags
}