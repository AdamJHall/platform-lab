locals {
  create_push_role = var.oidc_provider_arn != null
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.mutable ? "MUTABLE" : "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = var.image_scanning_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode(
    {
      rules = [
        {
          rulePriority = 1
          description  = "Keep the last 10 tagged releases."
          selection = {
            tagStatus      = "tagged"
            tagPatternList = ["v*"]
            countType      = "imageCountMoreThan"
            countNumber    = 10
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Purge untagged images after 7 days"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = 7
          }
          action = {
            type = "expire"
          }
        }
      ]
    }
  )
}

data "aws_iam_policy_document" "push_trust_policy" {
  count = local.create_push_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

resource "aws_iam_role" "push" {
  count              = local.create_push_role ? 1 : 0
  name               = "github-push-${replace(var.name, "/", "-")}-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.push_trust_policy[0].json
}

data "aws_iam_policy_document" "push" {
  count = local.create_push_role ? 1 : 0

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_iam_policy" "push" {
  count  = local.create_push_role ? 1 : 0
  name   = "github-push-${replace(var.name, "/", "-")}-${var.environment}"
  policy = data.aws_iam_policy_document.push[0].json
}

resource "aws_iam_role_policy_attachment" "push" {
  count      = local.create_push_role ? 1 : 0
  role       = aws_iam_role.push[0].name
  policy_arn = aws_iam_policy.push[0].arn
}