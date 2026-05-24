output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.this.arn
}

output "cloudfront_url" {
  value = "https://${var.domain_name}"
}