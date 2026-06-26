variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the EKS cluster API server"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  type        = string
}

variable "route53_zone_arn" {
  description = "ARN of the Route53 hosted zone external-dns is allowed to manage"
  type        = string
}

variable "name" {
  description = "Name prefix for IAM resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
