include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/modules/github-oidc"
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  state_bucket = "terragrunt-tf-state-${local.account_vars.locals.account_name}-${local.region_vars.locals.aws_region}"
}

inputs = {
  github_org   = "AdamJHall"
  github_repo  = "platform-lab"
  environment  = "dev"
  state_bucket = local.state_bucket
}
