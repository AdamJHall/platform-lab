variable "github_org" {
  description = "GitHub organisation or username that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)."
  type        = string
}

variable "environment" {
  description = "Environment name used to name the apply role."
  type        = string
}

variable "state_bucket" {
  description = "Name of the S3 bucket used for Terragrunt remote state."
  type        = string
}
