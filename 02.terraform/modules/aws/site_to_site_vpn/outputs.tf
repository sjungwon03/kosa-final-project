output "vpn_connection_id" {
  value = var.customer_gateway_ip != "" ? aws_vpn_connection.this[0].id : null
}

output "tunnel1_address" {
  value = var.customer_gateway_ip != "" ? aws_vpn_connection.this[0].tunnel1_address : null
}

output "tunnel2_address" {
  value = var.customer_gateway_ip != "" ? aws_vpn_connection.this[0].tunnel2_address : null
}

output "tunnel1_preshared_key" {
  value     = var.customer_gateway_ip != "" ? aws_vpn_connection.this[0].tunnel1_preshared_key : null
  sensitive = true
}

output "tunnel2_preshared_key" {
  value     = var.customer_gateway_ip != "" ? aws_vpn_connection.this[0].tunnel2_preshared_key : null
  sensitive = true
}

output "customer_gateway_id" {
  value = var.customer_gateway_ip != "" ? aws_customer_gateway.this[0].id : null
}

output "vgw_id" {
  value = aws_vpn_gateway.this.id
}

output "customer_gateway_configuration" {
  value = var.customer_gateway_ip != "" ? aws_vpn_connection.this[0].customer_gateway_configuration : null
}