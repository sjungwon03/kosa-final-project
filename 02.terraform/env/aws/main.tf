terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  name                = var.name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  tags                = var.tags
}

module "ec2" {
  source = "../../modules/aws/ec2"

  name          = "${var.name}-haproxy"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.public_subnet_ids
  instance_type = var.instance_type
  key_name      = module.keypair.key_name
  user_data     = var.user_data
  allowed_cidrs = var.allowed_cidrs
  tags          = var.tags
}

module "nlb" {
  source = "../../modules/aws/nlb"

  name               = "${var.name}-nlb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  target_instance_ids = module.ec2.instance_ids
  cross_zone_enabled = true
  tags               = var.tags
}

module "route53" {
  source = "../../modules/aws/route53"

  domain_name       = var.domain_name
  record_name       = var.record_name
  lb_dns_name       = module.nlb.nlb_dns_name
  lb_zone_id        = module.nlb.nlb_zone_id
  create_www_record = var.create_www_record
  tags              = var.tags
}

module "wireguard" {
  source = "../../modules/aws/wireguard"

  name          = "${var.name}-vpn"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  instance_type = var.instance_type
  key_name      = module.keypair.key_name
  allowed_cidrs = var.allowed_cidrs
  tags          = var.tags
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

  cluster_name    = "${var.name}-eks"
  cluster_version = var.eks_version
  subnet_ids      = module.vpc.public_subnet_ids
  allowed_cidrs   = var.allowed_cidrs
  tags            = var.tags
}

module "karpenter" {
  source = "../../modules/aws/karpenter"

  cluster_name       = "${var.name}-eks"
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_id  = aws_security_group.eks_nodes.id
  tags               = var.tags
}