locals {
  stacks_path = "${get_repo_root()}/terraform/catalog/stacks"
  environment = "dev"
}

stack "dev-oidc" {
  source = "${local.stacks_path}/github-oidc"
  path   = "dev/oidc"

  values = {
    github_org   = "AdamJHall"
    github_repo  = "platform-lab"
    environment  = local.environment
  }
}