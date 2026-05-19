variable "name" {
  description = "Name for the NLB"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the NLB"
  type        = list(string)
}

variable "target_instance_ids" {
  description = "Instance IDs to attach to target groups"
  type        = list(string)
}

variable "cross_zone_enabled" {
  description = "Enable cross-zone load balancing"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}