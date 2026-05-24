locals {
  stacks_path = "${get_repo_root()}/terraform/catalog/stacks"
  environment = "dev"
}

stack "dev-network" {
  source = "${local.stacks_path}/network"
  path   = "dev/network"

  values = {
    name        = "dev-network"
    cidr_block  = "10.0.0.0/16"
    environment = local.environment
  }
}