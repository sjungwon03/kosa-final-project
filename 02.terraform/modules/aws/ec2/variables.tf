variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EC2 instances (one per AZ)"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "user_data" {
  description = "User data script for EC2"
  type        = string
  default     = ""
}

variable "allowed_cidrs" {
  description = "Allowed CIDR blocks for SSH and stats access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_ssm_role" {
  description = "Whether to create SSM IAM role for EC2"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "onprem_cidr" {
  description = "On-premises CIDR block for VPN access"
  type        = string
  default     = "172.16.0.0/12"
}