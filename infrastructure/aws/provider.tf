terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"

  backend "s3" {
    bucket  = "kosa-terraform-state"
    key     = "aws/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "kosa-eks"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "db_password" {
  description = "Database Password"
  type        = string
  sensitive   = true
}

variable "frontend_bucket_name" {
  description = "S3 Bucket Name for Frontend"
  type        = string
  default     = "kosa-frontend-bucket"
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront"
  type        = string
  default     = ""
}

variable "onprem_cidr" {
  description = "On-premise network CIDR"
  type        = string
  default     = "10.0.0.0/8"
}

variable "onprem_vpn_gateway" {
  description = "On-premise VPN Gateway IP"
  type        = string
  default     = "10.0.1.1"
}