include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/modules/ecr"
}

dependency "github_oidc" {
  config_path = "../github-oidc"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  name              = "hello-world"
  environment       = "dev"
  oidc_provider_arn = dependency.github_oidc.outputs.oidc_provider_arn
  github_repository = "AdamJHall/platform-lab"
}
