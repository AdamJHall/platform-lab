variable "name" {
  description = "Name of the ECR Repo"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "image_scanning_on_push" {
  description = ""
  type        = bool
  default     = true
}

variable "mutability" {
  description = ""
  type        = string
  default     = "IMMUTABLE"
  validation {
    condition     = var.mutability == "MUTABLE" || var.mutability == "IMMUTABLE"
    error_message = "mutability must be either MUTABLE or IMMUTABLE"
  }
}

variable "oidc_provider_arn" {
  description = ""
  type        = string
  default     = null
}

variable "github_repository" {
  description = ""
  type        = string
  default     = null
}