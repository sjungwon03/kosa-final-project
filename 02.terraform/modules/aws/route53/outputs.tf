output "zone_id" {
  value = var.create_zone ? aws_route53_zone.this[0].zone_id : (var.enabled ? data.aws_route53_zone.existing[0].zone_id : null)
}

output "name_servers" {
  value = var.create_zone ? aws_route53_zone.this[0].name_servers : null
}

output "record_fqdn" {
  value = var.enabled ? aws_route53_record.this[0].fqdn : null
}