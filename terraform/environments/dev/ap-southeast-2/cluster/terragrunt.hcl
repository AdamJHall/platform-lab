include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_id   = local.account_vars.locals.aws_account_id
  account_name = local.account_vars.locals.account_name
}

terraform {
  source = "${get_repo_root()}//terraform/modules/cluster"
}

dependency "network" {
  config_path = "../network"
}

inputs = {
  name               = "dev-cluster"
  kubernetes_version = "1.36"

  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = values(dependency.network.outputs.private_with_egress_subnet_ids)

  endpoint_public_access = true

  additional_admin_role_arns = [
    "arn:aws:iam::${local.account_id}:role/github-apply-${local.account_name}",
  ]

  eks_managed_node_groups = {
    system = {
      instance_types = ["t4g.medium"]
      ami_type       = "AL2023_ARM_64_STANDARD"
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      labels = {
        "karpenter.sh/controller" = "true"
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}
