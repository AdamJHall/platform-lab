locals {
  external_dns_service_account = "external-dns-sa"
}

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [var.route53_zone_arn]
  }

  statement {
    actions   = ["route53:ListTagsForResource"]
    resources = [var.route53_zone_arn]
  }

  statement {
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name   = "${var.name}-external-dns"
  policy = data.aws_iam_policy_document.external_dns.json
  tags   = var.tags
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = var.cluster_name
  namespace       = "external-dns"
  service_account = local.external_dns_service_account
  role_arn        = aws_iam_role.external_dns.arn
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.21.1"
  namespace        = "external-dns"
  create_namespace = true

  values = [templatefile("${path.module}/values/external-dns.yaml", {
    service_account = local.external_dns_service_account
  })]

  depends_on = [aws_eks_pod_identity_association.external_dns]
}
