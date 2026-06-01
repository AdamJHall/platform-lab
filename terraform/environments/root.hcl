locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.aws_account_id
  aws_region   = local.region_vars.locals.aws_region

  # In CI, credentials come from the OIDC-assumed role via environment variables.
  # Emitting `profile = null` tells the AWS provider to use the default credential
  # chain, which picks up AWS_ACCESS_KEY_ID / AWS_SESSION_TOKEN set by the runner.
  profile_value = get_env("CI", "false") == "true" ? "null" : "\"${local.account_name}\""
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "${local.aws_region}"
  profile = ${local.profile_value}

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.account_id}"]
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt      = true
    bucket       = "terragrunt-tf-state-${local.account_name}-${local.aws_region}"
    key          = "${path_relative_to_include()}/tf.tfstate"
    region       = local.aws_region
    use_lockfile = true
    profile      = get_env("CI", "false") == "true" ? null : local.account_name
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}