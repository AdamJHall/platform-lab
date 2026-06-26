module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name         = var.cluster_name
  enable_inline_policy = true

  node_iam_role_name            = "${var.name}-karpenter-node"
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

data "aws_ecrpublic_authorization_token" "token" {
  region = "us-east-1"
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.12.0"
  wait                = false

  values = [templatefile("${path.module}/values/karpenter.yaml", {
    cluster_name       = var.cluster_name
    cluster_endpoint   = var.cluster_endpoint
    interruption_queue = module.karpenter.queue_name
  })]
}
