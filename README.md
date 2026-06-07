# platform-lab

A personal sandbox for learning Terraform and Kubernetes, using Terragrunt to manage multi-environment AWS infrastructure.

## Structure

```
terraform/
├── modules/        # Raw OpenTofu modules
└── environments/
    └── dev/        # Environment-specific Terragrunt units
```

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
