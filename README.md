# platform-lab

A personal sandbox for learning Terraform and Kubernetes, using Terragrunt to manage multi-environment AWS infrastructure.

## Structure

```
terraform/
├── catalog/
│   ├── modules/    # Raw Terraform modules
│   ├── units/      # Terragrunt wrappers around modules
│   └── stacks/     # Compositions of units
└── environments/
    └── dev/        # Environment-specific stack instantiations
```

## Prerequisites

Install tools with [mise](https://mise.jdx.dev): `mise install`

## Commands

```bash
task plan:dev      # plan all units in dev
task apply:dev     # apply all units in dev
task destroy:dev   # destroy all units in dev
```
