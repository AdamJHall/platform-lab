output "apply_role_arn" {
  description = "ARN of the apply role for this environment."
  value       = module.apply.oidc_role
}

output "plan_role_arn" {
  description = "ARN of the plan role for this environment."
  value       = module.plan.oidc_role
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider."
  value       = module.plan.oidc_provider_arn
}