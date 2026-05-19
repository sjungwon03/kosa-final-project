output "record_fqdn" {
  value = aws_route53_record.this.fqdn
}

output "zone_id" {
  value = data.aws_route53_zone.this.zone_id
}