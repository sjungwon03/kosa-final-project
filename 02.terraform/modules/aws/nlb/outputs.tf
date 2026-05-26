output "nlb_arn" {
  value = aws_lb.this.arn
}

output "nlb_dns_name" {
  value = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_http_arn" {
  value = aws_lb_target_group.http.arn
}

output "target_group_https_arn" {
  value = aws_lb_target_group.https.arn
}