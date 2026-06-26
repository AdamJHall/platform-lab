output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.this.name
}

output "zone_arn" {
  description = "Route53 hosted zone arn"
  value       = aws_route53_zone.this.arn
}

output "name_servers" {
  description = "Route53 name servers — add these as NS records in Cloudflare to delegate the subdomain"
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "ARN of the validated wildcard ACM certificate"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}
