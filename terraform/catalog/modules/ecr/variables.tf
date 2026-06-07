variable "name" {
  description = "Name of the ECR Repo"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "image_scanning_on_push" {
  description = "Enable / Disable image scanning on push to the repo."
  type        = bool
  default     = true
}

variable "mutable" {
  description = ""
  type        = bool
  default     = false
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