variable "domain_name" {
  description = "Domain name for CloudFront distribution"
  type        = string
}

variable "nlb_dns_name" {
  description = "NLB DNS name for origin"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

variable "origin_protocol_policy" {
  description = "Origin protocol policy (http-only, https-only, match-viewer)"
  type        = string
  default     = "http-only"
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_200"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}