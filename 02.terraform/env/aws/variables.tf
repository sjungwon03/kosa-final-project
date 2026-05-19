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

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
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
  default     = "172.16.0.0/16"
}

variable "eks_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "cloudburst_threshold" {
  description = "CPU threshold for cloudbursting (percentage)"
  type        = number
  default     = 80
}