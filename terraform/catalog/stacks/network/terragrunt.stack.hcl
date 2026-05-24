locals {
  units_path = "${get_repo_root()}/terraform/catalog/units"
}

unit "vpc" {
  source = "${local.units_path}/vpc"
  path   = "vpc"

  values = {
    name        = values.name
    cidr_block  = values.cidr_block
    environment = values.environment
  }
}
