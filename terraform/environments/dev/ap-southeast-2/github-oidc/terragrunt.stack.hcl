locals {
  stacks_path  = "${get_repo_root()}/terraform/catalog/stacks"
  environment  = "dev"
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  state_bucket = "terragrunt-tf-state-${local.account_vars.locals.account_name}-${local.region_vars.locals.aws_region}"
}

stack "dev-oidc" {
  source = "${local.stacks_path}/github-oidc"
  path   = "dev/oidc"

  values = {
    github_org   = "AdamJHall"
    github_repo  = "platform-lab"
    environment  = local.environment
    state_bucket = local.state_bucket
  }
}