include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/modules/cluster-dns"
}

inputs = {
  zone_name = "cluster-dev.adamjhall.dev"
  tags = {
    Environment = "dev"
  }
}
