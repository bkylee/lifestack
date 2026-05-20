# Glossary

Plain-language definitions of terms used across this project's infrastructure and docs. Grows as new concepts come up — add an entry whenever you hit something worth a second look. Alphabetical.

### Backend

Where Terraform stores its [state](#state-terraform-state). Ours is the `azurerm` backend — the `stlifestack9k3l` storage account — declared in each environment's `backend.tf`. A `backend` block must live in a [root module](#root-module) and cannot use variables.

### Blast radius

The scope of what a single change or failure can damage. Splitting infrastructure into per-tier resource groups (network / data / app / observability) shrinks blast radius — destroying or breaking one tier does not touch the others.

### Child module

A module called by another via a `module "name" { source = ... }` block — reusable, parameterized by input variables. Contrast [root module](#root-module). We have none yet; `infra/modules/` is reserved for them (e.g. the future `foundation` module — see [shared module](#shared-module)).

### Drift

When live infrastructure no longer matches Terraform's state and config — usually because someone changed it by hand (a portal click). The `managed_by = "terraform"` tag exists so a resource lacking it flags as drift. `terraform plan` detects it.

### DRY (Don't Repeat Yourself)

A software principle: every piece of knowledge should have one authoritative representation, so a change is made in one place, not N. Coined in *The Pragmatic Programmer* (1999). Caveat — pushed too far, DRY produces premature abstraction whose indirection costs more than the duplication it removed; the "rule of three" says tolerate duplication until the third instance. The [D1] decision in `m1-s3` is a DRY call: [light duplication](#light-duplication), [shared module](#shared-module), and [Terragrunt](#terragrunt) are three points on the DRY spectrum.

### for_each

A Terraform meta-argument that creates one instance of a resource per entry in a map or set. We use it in `resource_groups.tf` over `local.rg_names`. Each map *key* becomes a stable state address (`...rg_names["network"]`), so adding or removing entries does not disturb the others — the reason it is preferred over `count`, whose list-index addresses shift when the list changes.

### IaC (Infrastructure as Code)

Managing infrastructure through version-controlled config files rather than manual console actions. Terraform is our IaC tool.

### Light duplication

The multi-env [DRY](#dry-dont-repeat-yourself) pattern chosen for this project ([D1]). Each environment directory holds its own full copy of every file; values differ, structure matches. Chosen over a [shared module](#shared-module) and [Terragrunt](#terragrunt) because per-env HCL is small enough (~40 lines) that duplication is cheaper than abstraction. See `docs/services/terraform-file-layout.md`.

### moved block

A Terraform block that tells Terraform a resource's address changed (e.g. it moved into a module) so the change is treated as a relocation, not a destroy-and-recreate. Used during the [shared module](#shared-module) refactor. Available since Terraform 1.1.

### Provider

A Terraform plugin that knows how to talk to a specific API. We use `azurerm` (Azure) and `random`. Declared in `versions.tf`, configured in `main.tf`.

### Root module

The directory where you run `terraform`. Each of `environments/prod`, `dev`, and `staging` is a root module. One root module = one [state](#state-terraform-state) file. Contrast [child module](#child-module).

### Shared module

The refactor target for [light duplication](#light-duplication): extract the duplicated resource code into one reusable [child module](#child-module) (`infra/modules/foundation/`) that each thin environment root calls. Trades duplication for indirection. Triggered around Module 2 — see the "Refactor path" section of `docs/services/terraform-file-layout.md`.

### State (Terraform state)

Terraform's record of what it currently manages — the mapping between your config and the real Azure resources. The source of truth for `plan` and `apply`. Stored remotely in the [backend](#backend); never kept on disk.

### State key

The `key` field in `backend.tf` — the blob path identifying *this* environment's state file within the backend container (`prod.tfstate`, `dev.tfstate`, `staging.tfstate`). Two directories sharing a key corrupt each other's state.

### Terragrunt

A third-party wrapper around Terraform that solves multi-env DRY (templated backends, `dependency` graphs, `run-all`). Rejected for this project ([D1]) — it earns its keep at ~10+ environments or when backend config needs templating; we have 3 envs on one storage account.
