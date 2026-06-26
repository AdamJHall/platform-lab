# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal sandbox for learning Terraform and Kubernetes. Uses **OpenTofu** (not Terraform CLI) and **Terragrunt** to manage multi-environment AWS infrastructure. All tools are managed via `mise`.

## Setup

```bash
task install   # mise install + pre-commit install
```

## Common Commands

```bash
# Infrastructure
task tf:plan:dev      # plan all units in dev
task tf:apply:dev     # apply all units in dev
task tf:destroy:dev   # destroy all units in dev

# Terraform
task tf:fmt           # format all .tf files (uses `tofu fmt`)
task tf:validate      # init + validate each module in modules/
task tf:clean         # remove .terraform, .terragrunt-cache, .terragrunt-stack dirs

# Linting
task lint             # yamllint + actionlint + zizmor (all three)
```

Pre-commit hooks run `tofu fmt -check`, `tofu validate`, `yamllint`, `actionlint`, and `zizmor` on relevant file types.

## Architecture

### Terraform layer model

```
terraform/
├── modules/        # Raw OpenTofu modules (vpc, github-oidc, ecr)
└── environments/
    └── dev/
        ├── account.hcl                     # account_name + aws_account_id
        └── ap-southeast-2/
            ├── region.hcl                  # aws_region
            ├── github-oidc/terragrunt.hcl
            ├── hello-world-ecr/terragrunt.hcl
            └── network/terragrunt.hcl
```

`root.hcl` (at `terraform/environments/`) is included by every unit. It generates the AWS provider and S3 remote state backend. In CI (`CI=true`), it uses OIDC credentials from environment variables instead of a named AWS profile.

### How a change flows

1. **modules/** — pure Terraform: resources, variables, outputs, no Terragrunt awareness.
2. **environments/dev/\*/terragrunt.hcl** — thin Terragrunt unit that `include`s `root.hcl`, points `terraform.source` at a module, and sets environment-specific inputs (CIDRs, names, flags, etc.).

### CI/CD

- **Plan** (`terragrunt-plan.yml`): triggers on PRs to `main` that touch `terraform/**`. Detects which environments changed; if any `modules/` path changed, plans all environments. Posts a collapsible plan comment to the PR, replacing any previous comment for that environment.
- **Apply** (`terragrunt-apply.yml`): triggers on merge to `main`. Runs sequentially (not cancellable) to avoid state conflicts.
- GitHub OIDC: `github-plan` role gets `ReadOnlyAccess` + state bucket access. `github-apply-<env>` role gets `AdministratorAccess` and is scoped to the GitHub Environment (not just a branch).

### Modules summary

| Module | Purpose |
|---|---|
| `vpc` | Full VPC with public / private / private-with-egress subnets, NAT (spot instances supported), optional VPC flow logs, subnet tags for EKS load-balancer discovery |
| `github-oidc` | Creates OIDC provider + `github-plan` and `github-apply-<env>` IAM roles |
| `ecr` | ECR repo with lifecycle policy (keep 10 tagged `v*`, purge untagged after 7d) + optional OIDC push role |

### Applications

`applications/hello-world/` — static nginx container (Dockerfile + nginx.conf + index.html). Placeholder for future EKS workloads.
