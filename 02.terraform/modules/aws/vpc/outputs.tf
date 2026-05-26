output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  value = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "availability_zones" {
  value = aws_subnet.public[*].availability_zone
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = var.create_nat_gateway ? (
    var.nat_gateway_per_az ? aws_route_table.private[*].id : [aws_route_table.private[0].id]
  ) : []
}

output "nat_gateway_ids" {
  value = var.create_nat_gateway ? aws_nat_gateway.this[*].id : []
}

output "s3_endpoint_id" {
  value = var.create_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}