output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster API server"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_admin_role_arn" {
  description = "ARN of the IAM role that has cluster admin access via EKS access entries"
  value       = aws_iam_role.eks_admin.arn
}
