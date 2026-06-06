output "repository_url" {
  description = "URL of the ECR repo."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repo."
  value       = aws_ecr_repository.this.arn
}