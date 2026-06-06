locals {
  units_path = "${get_repo_root()}/terraform/catalog/units"
}

unit "vpc" {
  source = "${local.units_path}/vpc"
  path   = "vpc"

  values = {
    name                   = values.name
    cidr_block             = values.cidr_block
    az_count               = values.az_count
    subnet_cidrs           = values.subnet_cidrs
    enable_flow_logs       = values.enable_flow_logs
    nat_use_spot_instances = values.nat_use_spot_instances
    nat_instance_type      = values.nat_instance_type
    environment            = values.environment
    subnet_tags            = values.subnet_tags
  }
}
