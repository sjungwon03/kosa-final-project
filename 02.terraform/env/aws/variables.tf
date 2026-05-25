variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "kosa-proxy"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "kosa"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.20.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type (Free Tier: t2.micro or t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "user_data" {
  description = "User data for HAProxy installation"
  type        = string
  default     = ""
}

variable "allowed_cidrs" {
  description = "Allowed CIDR blocks for SSH and HAProxy stats"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_nat_gateway" {
  description = "Whether to create NAT Gateway"
  type        = bool
  default     = true
}

variable "nat_gateway_per_az" {
  description = "Whether to create NAT Gateway per AZ (HA, costs 2x)"
  type        = bool
  default     = true
}

variable "create_s3_endpoint" {
  description = "Whether to create S3 Gateway Endpoint"
  type        = bool
  default     = true
}

variable "create_ssm_role" {
  description = "Whether to create SSM IAM role for EC2"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name (must be hosted in Route53)"
  type        = string
}

variable "record_name" {
  description = "Record name for the NLB"
  type        = string
}

variable "create_www_record" {
  description = "Create www subdomain record"
  type        = bool
  default     = true
}

variable "route53_enabled" {
  description = "Whether to create Route53 records"
  type        = bool
  default     = true
}

variable "route53_create_zone" {
  description = "Whether to create Route53 hosted zone"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "kosa-final"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

variable "onprem_cidr_block" {
  description = "On-premises CIDR block to route through VPN"
  type        = string
  default     = "172.16.0.0/12"
}

variable "customer_gateway_ip" {
  description = "Public IP of customer gateway (pfSense WAN IP)"
  type        = string
  default     = ""
}

variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "eks_create_addons" {
  description = "Whether to create EKS addons (set to true after node group is created)"
  type        = bool
  default     = false
}

variable "eks_create_node_group" {
  description = "Whether to create a managed node group (set false for Fargate-only DR)"
  type        = bool
  default     = false
}

variable "eks_create_fargate" {
  description = "Whether to create Fargate profile for DR pods"
  type        = bool
  default     = true
}

variable "eks_fargate_namespace" {
  description = "Namespace for Fargate DR pods"
  type        = string
  default     = "kosa"
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 3
}

variable "eks_admin_user_arn" {
  description = "IAM user ARN for EKS cluster admin access"
  type        = string
  default     = "arn:aws:iam::945503455708:user/kosa"
}

variable "enable_cloudfront" {
  description = "Whether to enable CloudFront distribution"
  type        = bool
  default     = false
}

variable "enable_tls" {
  description = "Whether to enable TLS on NLB with ACM certificate"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_200"
}

variable "origin_protocol_policy" {
  description = "Origin protocol policy (http-only, https-only, match-viewer)"
  type        = string
  default     = "http-only"
}