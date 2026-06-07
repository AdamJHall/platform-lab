output "repository_url" {
  description = "URL of the ECR repo."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repo."
  value       = aws_ecr_repository.this.arn
}

output "push_role_arn" {
  description = "ARN of the IAM role that can push images to this repo."
  value       = local.create_push_role ? aws_iam_role.push[0].arn : null
}