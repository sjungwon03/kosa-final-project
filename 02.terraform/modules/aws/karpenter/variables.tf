variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Karpenter nodes"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for nodes"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}