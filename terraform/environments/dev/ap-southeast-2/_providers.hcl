locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_name = local.account_vars.locals.account_name
  profile_args = get_env("CI", "false") == "true" ? "" : ", \"--profile\", \"${local.account_name}\""
}

generate "providers_helm" {
  path      = "providers_helm.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_region" "current" {}

provider "helm" {
  kubernetes {
    host                   = "${dependency.cluster.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.cluster.outputs.cluster_certificate_authority_data}")
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "${dependency.cluster.outputs.cluster_name}", "--region", data.aws_region.current.region${local.profile_args}]
    }
  }
}
EOF
}

generate "providers_k8s" {
  path      = "providers_k8s.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "kubernetes" {
  host                   = "${dependency.cluster.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.cluster.outputs.cluster_certificate_authority_data}")
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.cluster.outputs.cluster_name}", "--region", data.aws_region.current.region${local.profile_args}]
  }
}
EOF
}
