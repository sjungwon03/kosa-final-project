variable "domain_name" {
  description = "Domain name (e.g., example.com)"
  type        = string
}

variable "record_name" {
  description = "Record name (e.g., app.example.com)"
  type        = string
}

variable "lb_dns_name" {
  description = "Load balancer DNS name"
  type        = string
}

variable "lb_zone_id" {
  description = "Load balancer hosted zone ID"
  type        = string
}

variable "create_zone" {
  description = "Whether to create Route53 hosted zone"
  type        = bool
  default     = true
}

variable "create_www_record" {
  description = "Create www subdomain record"
  type        = bool
  default     = false
}

variable "enabled" {
  description = "Whether to create Route53 records"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}