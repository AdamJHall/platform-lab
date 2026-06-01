include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/catalog/modules/github-oidc"
}

inputs = {
  github_org   = values.github_org
  github_repo  = values.github_repo
  environment  = values.environment
  state_bucket = values.state_bucket
}
