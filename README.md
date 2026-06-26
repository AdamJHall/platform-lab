# platform-lab

A personal sandbox for learning Terraform and Kubernetes, using Terragrunt to manage multi-environment AWS infrastructure.

## Structure

```
terraform/
├── modules/        # Raw OpenTofu modules
└── environments/
    └── dev/        # Environment-specific Terragrunt units
```

## Architecture decisions

### Bootstrap addons are Terraform, not ArgoCD

Karpenter, LBC, ExternalDNS, and ArgoCD are managed as Terraform modules rather than ArgoCD-managed Helm charts because of bootstrapping order: ArgoCD needs LBC for its ingress, LBC needs a running cluster, and ExternalDNS must be up before ArgoCD's hostname resolves. ArgoCD can't manage the things required to make ArgoCD work.

Keeping them in Terraform means a new environment bootstraps from zero with a single `task tf:apply:dev` — Terragrunt's dependency graph (`network → cluster → karpenter/lbc/external-dns → argocd`) handles sequencing automatically, with no manual steps.

Once ArgoCD is running, all application workloads live in `cluster/` as ArgoCD `Application` manifests and are managed through GitOps as normal.

## Prerequisites

Install tools with [mise](https://mise.jdx.dev):

```bash
mise install
```

## Setup

Install tools and the pre-commit git hook:

```bash
task install
```

## Commands

### Infrastructure

```bash
task tf:plan:dev      # plan all units in dev
task tf:apply:dev     # apply all units in dev
task tf:destroy:dev   # destroy all units in dev
```

### Terraform

```bash
task tf:fmt           # format all Terraform files
task tf:validate      # validate all modules
task tf:clean         # remove local Terraform and Terragrunt caches
```

### Linting

```bash
task lint          # run all workflow linting checks (yamllint, actionlint, zizmor)
```
