variable "vpc_id" {
  description = "VPC ID for VPN gateway"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "onprem_cidr" {
  description = "On-premises CIDR block"
  type        = string
  default     = "172.16.0.0/16"
}

variable "customer_gateway_ip" {
  description = "Public IP of customer gateway (pfSense WAN)"
  type        = string
  default     = ""
}

variable "vpn_name" {
  description = "Name prefix for VPN resources"
  type        = string
}

variable "route_table_id" {
  description = "Route table ID for VPN route (single)"
  type        = string
  default     = ""
}

variable "route_table_ids" {
  description = "Route table IDs for VPN route propagation (multiple)"
  type        = list(string)
  default     = []
}

variable "create_vpn_route_propagation" {
  description = "Whether to enable VPN route propagation on route table"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for VPN resources"
  type        = map(string)
  default     = {}
}