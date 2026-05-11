variable "cluster_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "onprem_cidr" {
  type = string
}

variable "onprem_vpn_gateway" {
  type = string
}

resource "aws_vpn_gateway" "kosa_vpn_gw" {
  vpc_id = var.vpc_id

  tags = {
    Name        = "${var.cluster_name}-vpn-gateway"
    Environment = var.environment
    Project     = "kosa"
  }
}

resource "aws_customer_gateway" "onprem_gw" {
  bgp_asn    = 65000
  ip_address = var.onprem_vpn_gateway
  type       = "ipsec.1"

  tags = {
    Name        = "${var.cluster_name}-customer-gateway"
    Environment = var.environment
    Project     = "kosa"
  }
}

resource "aws_vpn_connection" "kosa_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.kosa_vpn_gw.id
  customer_gateway_id = aws_customer_gateway.onprem_gw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name        = "${var.cluster_name}-vpn-connection"
    Environment = var.environment
    Project     = "kosa"
  }
}

resource "aws_vpn_connection_route" "onprem_route" {
  vpn_connection_id = aws_vpn_connection.kosa_vpn.id
  destination_cidr_block = var.onprem_cidr
}

resource "aws_route" "vpn_route" {
  count                  = length(var.subnet_ids)
  route_table_id         = aws_vpn_gateway.kosa_vpn_gw.vpc_id
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.kosa_vpn_gw.id
}

output "connection_id" {
  value = aws_vpn_connection.kosa_vpn.id
}

output "vpn_gateway_id" {
  value = aws_vpn_gateway.kosa_vpn_gw.id
}

output "customer_gateway_ip" {
  value = aws_customer_gateway.onprem_gw.ip_address
}