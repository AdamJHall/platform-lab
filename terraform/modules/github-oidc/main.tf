data "aws_iam_policy_document" "state_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket}/*"
    ]
  }
}

resource "aws_iam_policy" "state_access_policy" {
  name        = "github-plan-state-access-policy"
  description = "Grant the plan role read/lock access to the state bucket."
  policy      = data.aws_iam_policy_document.state_access_policy.json
}

module "plan" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 2"

  create_oidc_provider = true
  create_oidc_role     = true

  role_name        = "github-plan"
  role_description = "Role used for planning changes."
  repositories     = ["${var.github_org}/${var.github_repo}"]
  oidc_role_attach_policies = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    aws_iam_policy.state_access_policy.arn,
  ]

  tags = {
    Environment = var.environment
  }
}


module "apply" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 2"

  create_oidc_provider = false
  oidc_provider_arn    = module.plan.oidc_provider_arn

  create_oidc_role = true
  role_name        = "github-apply-${var.environment}"
  role_description = "Role used for applying updates in Github workflows."
  repositories     = ["${var.github_org}/${var.github_repo}:environment:${var.environment}"]
  # TODO: Restrict to only resources required
  oidc_role_attach_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]

  tags = {
    Environment = var.environment
  }
}
