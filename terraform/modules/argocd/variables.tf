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

variable "acm_certificate_arn" {
  description = "ARN of the validated ACM certificate for the ArgoCD domain"
  type        = string
}

variable "argocd_domain" {
  description = "Hostname for the ArgoCD server (e.g. argocd.cluster-dev.adamjhall.dev)"
  type        = string
}

variable "name" {
  description = "Name used for the ALB group and ArgoCD cluster registration secret"
  type        = string
}

variable "environment" {
  description = "Environment label applied to the ArgoCD cluster registration secret"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
