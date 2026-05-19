output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  value = aws_subnet.public[*].cidr_block
}

output "availability_zones" {
  value = aws_subnet.public[*].availability_zone
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}