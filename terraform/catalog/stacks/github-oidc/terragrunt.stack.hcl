locals {
  units_path = "${get_repo_root()}/terraform/catalog/units"
}

unit "github-oidc" {
  source = "${local.units_path}/github-oidc"
  path   = "github-oidc"

  values = {
    github_org   = values.github_org
    github_repo  = values.github_repo
    environment  = values.environment
  }
}
