include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "providers" {
  path = find_in_parent_folders("_providers.hcl")
}

terraform {
  source = "${get_repo_root()}//terraform/modules/external-dns"
}

dependency "cluster" {
  config_path = "../cluster"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock.example.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    eks_admin_role_arn                 = "arn:aws:iam::123456789012:role/mock-eks-admin"
  }
}

dependency "dns" {
  config_path = "../cluster-dns"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    certificate_arn = "arn:aws:acm:ap-southeast-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    zone_name       = "cluster-dev.adamjhall.dev"
    zone_arn        = "arn:aws:route53:::hostedzone/ZXXXXXXXXXXXX"
  }
}

inputs = {
  cluster_name                       = dependency.cluster.outputs.cluster_name
  cluster_endpoint                   = dependency.cluster.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.cluster.outputs.cluster_certificate_authority_data

  route53_zone_arn = dependency.dns.outputs.zone_arn
  name             = "dev-cluster"

  tags = {
    Environment = "dev"
  }
}
