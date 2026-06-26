data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role" "efs_csi" {
  name               = "${var.name}-efs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

data "aws_iam_policy_document" "eks_admin_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_AdministratorAccess_*"]
    }
  }
}

resource "aws_iam_role" "eks_admin" {
  name               = "${var.name}-eks-admin"
  assume_role_policy = data.aws_iam_policy_document.eks_admin_trust.json
  tags               = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_public_access = var.endpoint_public_access
  authentication_mode    = "API"
  compute_config         = { enabled = false }

  enable_cluster_creator_admin_permissions = false

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.name
  }

  eks_managed_node_groups = var.eks_managed_node_groups

  addons = {
    coredns = {}
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
    aws-efs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.efs_csi.arn
        service_account = "efs-csi-controller-sa"
      }]
    }
    kube-proxy = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    vpc-cni = {
      before_compute = true
    }
  }

  access_entries = merge(
    {
      eks_admin = {
        principal_arn = aws_iam_role.eks_admin.arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
    { for i, arn in var.additional_admin_role_arns : "additional_admin_${i}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    } }
  )

  tags = var.tags
}
