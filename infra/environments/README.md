
# Environments

## Overview

'prod/', 'dev/', 'staging/' environments are all self-contained root modules for terraform. Only prod is being deployed in version one. Refer to docs/services/terraform-file-layout.md for per-file anatomy

## Why dev/ and staging/ exist but aren't deployed

It is faster to create 2 empty env directories now vs later. Later, if this project expands further enough, we have proactively set up scalability vs having to retrofit later and grep-replacing hardcoded prod lines across every module.

## Activation triggers

We will only use 'terraform init' in dev/ and staging/ when we are testing a migration or change scary enough we need a separate env to test.

## What differs between environments

Label, state key (storage), and naming. All others are staying the same. There are only 2 lines different in each directory (backend.tf key, locals.tf environment)

## DRY pattern: light duplication

Light duplication = each env has its own full copy of every file. The values differ. Chose this as a shared root module would be premature for this little amount of HCL lines and Terragrunt adds an unnecessary variable to learning. Currently every env is a 'root' module (run terraform inside) that declares resources directly. Therefore each one has its own copies of resource code. We could pull the resource code into one reusable child module in 'infra/modules/' and turn each env directory into a thin caller of that module (using main.tf in each env folder). backend.tf cannot live inside a child module, it must be in the root. It also cannot take variables, so each key will have to be hand-written per env. Shared modules trade duplication for indirection. One place to change, impossible to drift between envs. If per-env HCL grows past ~80-150 lines, extract the shared resources into infra/modules/foundation and reduce each env to a thin caller.

## Activating an environment

cd into the env directory, 'terraform init', 'terraform plan', 'terraform apply'

## See also

- ADR-0005 — multi-env strategy (formal decision record)
- `docs/mentor/m1-s3-multi-env-scaffolding.md` — the scaffolding step's mentor message
- `docs/services/terraform-file-layout.md` — per-file anatomy of an environment directory
- `docs/services/terraform.md` — the Terraform service doc
