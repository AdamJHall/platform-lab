include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/catalog/modules/vpc"
}

inputs = {
  name        = values.name
  cidr_block  = values.cidr_block
  environment = values.environment
}
