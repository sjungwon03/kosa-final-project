resource "aws_customer_gateway" "this" {
  count = var.customer_gateway_ip != "" ? 1 : 0

  bgp_asn    = 65000
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = merge(var.tags, {
    Name = "${var.vpn_name}-cgw"
  })
}

resource "aws_vpn_gateway" "this" {
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.vpn_name}-vgw"
  })
}

resource "aws_vpn_connection" "this" {
  count = var.customer_gateway_ip != "" ? 1 : 0

  vpn_gateway_id      = aws_vpn_gateway.this.id
  customer_gateway_id = aws_customer_gateway.this[0].id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_phase1_encryption_algorithms = ["AES128-GCM-16"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase2_encryption_algorithms = ["AES128-GCM-16"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]

  tunnel2_phase1_encryption_algorithms = ["AES128-GCM-16"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase2_encryption_algorithms = ["AES128-GCM-16"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = merge(var.tags, {
    Name = "${var.vpn_name}-connection"
  })
}

resource "aws_vpn_connection_route" "this" {
  count = var.customer_gateway_ip != "" ? 1 : 0

  vpn_connection_id      = aws_vpn_connection.this[0].id
  destination_cidr_block = var.onprem_cidr
}

resource "aws_vpn_gateway_route_propagation" "this" {
  count = var.customer_gateway_ip != "" && var.create_vpn_route_propagation ? (
    length(var.route_table_ids) > 0 ? length(var.route_table_ids) : 1
  ) : 0

  vpn_gateway_id = aws_vpn_gateway.this.id
  route_table_id = length(var.route_table_ids) > 0 ? var.route_table_ids[count.index] : var.route_table_id
}

resource "aws_route" "vpn_route" {
  count = var.customer_gateway_ip != "" ? (
    length(var.route_table_ids) > 0 ? length(var.route_table_ids) : 1
  ) : 0

  route_table_id         = length(var.route_table_ids) > 0 ? var.route_table_ids[count.index] : var.route_table_id
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.this.id
}