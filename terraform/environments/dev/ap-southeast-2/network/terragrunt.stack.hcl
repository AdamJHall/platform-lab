locals {
  stacks_path = "${get_repo_root()}/terraform/catalog/stacks"
  environment = "dev"
}

stack "dev-network" {
  source = "${local.stacks_path}/network"
  path   = "dev/network"

  values = {
    name          = "dev-network"
    cidr_block    = "10.0.0.0/16"
    az_count      = 2
    subnet_cidrs  = {
      public              = ["10.0.0.0/20", "10.0.16.0/20"]
      private             = ["10.0.32.0/20", "10.0.48.0/20"]
      private_with_egress = ["10.0.64.0/20", "10.0.80.0/20"]
    }
    enable_flow_logs       = false
    nat_use_spot_instances = true
    nat_instance_type      = "t4g.nano"
    environment            = local.environment
  }
}
