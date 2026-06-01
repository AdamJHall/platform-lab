module "plan" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 2"

  create_oidc_provider = true
  create_oidc_role     = true

  role_name                 = "github-plan"
  role_description          = "Role used for planning changes."
  repositories              = ["${var.github_org}/${var.github_repo}"]
  oidc_role_attach_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

  tags = {
    Environment = var.environment
  }
}


module "apply" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 2"

  create_oidc_provider = false
  oidc_provider_arn    = module.plan.oidc_provider_arn

  create_oidc_role          = true
  role_name                 = "github-apply-${var.environment}"
  role_description          = "Role used for applying updates in Github workflows."
  repositories              = ["${var.github_org}/${var.github_repo}"]
  # TODO: Restrict to only resources required
  oidc_role_attach_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]

  tags = {
    Environment = var.environment
  }
}
