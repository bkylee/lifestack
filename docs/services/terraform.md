# Terraform

## What it is

Infrastructure-as-code tool. Declarative HCL config files describe the desired state of Azure resources; `terraform plan` shows what changes are needed to reach that state from current; `terraform apply` makes them. State (the source of truth for "what's currently provisioned") lives in Azure Storage and is read/written via AAD-authenticated blob operations.

## Why we use it

- **Reproducible, reviewable infra changes.** Every Azure resource in the project comes from a config file in git; nothing is created via portal clicks.
- **Cross-cloud transferability.** Terraform skills carry to AWS, GCP, and on-prem; Azure-specific DSLs (Bicep, ARM) don't.
- **Foundation for multi-env.** v1 only deploys prod, but the layout supports adding `dev/` and `staging/` later by copying `environments/prod/` and changing variables.

See ADR-0005 for the single-env-in-v1 decision.

## How it's configured here

**Versions:** Terraform 1.15.x, AzureRM provider `~> 4.0`, Random provider `~> 3.6` — declared in `infra/environments/prod/versions.tf` and locked to exact versions in `.terraform.lock.hcl`.

**Layout:**

```
infra/
  modules/                     # reusable modules — populated in Step 2.3+
  environments/
    prod/                      # the only env deployed in v1
      versions.tf              # required versions + providers
      backend.tf               # state backend config (Azure Storage, AAD auth)
      main.tf                  # provider config block
      variables.tf             # input variable declarations
      terraform.tfvars         # input values (committed; no secrets)
      .terraform.lock.hcl      # pinned provider versions (committed)
    dev/                       # structured but not provisioned in v1
    staging/                   # structured but not provisioned in v1
  .gitignore                   # ignores .terraform/, *.tfstate, *.tfplan
```

**State backend:** Storage Account `stlifestack9k3l` (Standard_LRS, East US, in `rg-lifestack-tfstate`), container `tfstate`, blob key `prod.tfstate`.

The state SA is locked down from creation:

| Setting | Value | Why |
|---|---|---|
| HTTPS-only | `true` | No plaintext blob ops |
| Min TLS | `1.2` | No legacy crypto |
| Public blob access | `false` | No anonymous reads at any scope |
| Shared-key auth | `false` | RBAC + AAD only — `use_azuread_auth = true` in backend.tf |
| Blob versioning | enabled | Every state-modifying apply creates a recoverable version |
| Soft delete (containers/blobs) | 7 days | Accidentally destroying state is recoverable for a week |
| Data-plane RBAC | "Storage Blob Data Contributor" on the user's OID | Owner-on-the-sub does NOT include data plane access — control plane and data plane are separate roles |

**Auth flow (local dev):** `az login` → AzureRM provider auto-detects CLI auth → state backend uses the same identity for AAD blob ops.

**Auth flow (CI, Phase 2.x):** GitHub Actions → workload identity / OIDC federation → AzureRM provider with no static credentials. Documented when CI lands.

## Naming convention

Following the [Microsoft Cloud Adoption Framework abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations):

| Resource | Pattern | Example (v1 prod) |
|---|---|---|
| Resource Group | `rg-lifestack-{purpose}` | `rg-lifestack-prod`, `rg-lifestack-tfstate` |
| Virtual Network | `vnet-lifestack-{env}` | `vnet-lifestack-prod` |
| Subnet | `snet-{purpose}-{env}` | `snet-aca-prod`, `snet-pg-prod`, `snet-pe-prod` |
| NSG | `nsg-{purpose}-{env}` | `nsg-aca-prod` |
| Postgres Flex Server | `psql-lifestack-{env}` | `psql-lifestack-prod` |
| Storage Account | `stlifestack{purpose}{rand}` | `stlifestackimagesa3f9`, `stlifestack9k3l` (state) |
| Container Registry | `crlifestack{rand}` | `crlifestacka3f9` |
| Container Apps Env | `cae-lifestack-{env}` | `cae-lifestack-prod` |
| Container App | `ca-lifestack-{role}-{env}` | `ca-lifestack-web-prod` |
| Key Vault | `kv-lifestack-{env}-{rand}` | `kv-lifestack-prod-a3f9` |
| Front Door profile | `afd-lifestack-{env}` | `afd-lifestack-prod` |
| App Insights | `appi-lifestack-{env}` | `appi-lifestack-prod` |
| Log Analytics | `log-lifestack-{env}` | `log-lifestack-prod` |
| Managed Identity | `id-lifestack-{role}-{env}` | `id-lifestack-web-prod` |

`{rand}` is a 4-char lowercase alphanumeric suffix from a `random_string` resource — required only on resources whose names are globally unique across all of Azure (storage accounts, ACR, Key Vault, Front Door endpoint).

The two storage accounts in v1 (`stlifestack9k3l` for state, plus future `stlifestackimages...` for blob image storage) used different generation paths: the state SA was hand-bootstrapped before Terraform existed, so its suffix was generated with `tr -dc 'a-z0-9' < /dev/urandom`. Future SAs created via Terraform use `random_string` so the value is stable across applies via state.

## Mental model

1. **State is the single source of truth.** Terraform reads the remote state file to know what already exists. A machine without backend access can't run *any* Terraform command — `init`/`plan`/`apply` all need to read state. AAD failure → no access. Backups: blob versioning + 7-day soft delete.

2. **Plan before apply, always.** `terraform plan` is read-only: it computes the diff between desired (HCL) and actual (state). No production change should happen without the plan reviewed first. CI pipelines will surface the plan as a PR comment.

3. **State locking prevents concurrent applies.** Azure Storage uses a blob lease as the lock. If a plan or apply hangs and crashes mid-flight, the lease may persist for up to 60 seconds — wait it out, or break manually with `terraform force-unlock <lock-id>`.

## Alternatives considered

**Bicep:** Microsoft's first-party IaC for Azure. Cleaner Azure-specific syntax, no provider versioning to think about. Ruled out because the architect career goal benefits from cross-cloud fluency, and locking into a single-cloud DSL closes that door.

**Pulumi:** IaC in real programming languages (TypeScript, Python). More expressive, but smaller ecosystem and more decision fatigue per resource (which language? which package?). Ruled out — Terraform's HCL is read-once-write-many, which is the right balance for infra config.

**ARM templates:** First-class on Azure but verbose and brittle. Bicep replaces them. Ruled out for the same reason as Bicep, plus it's worse-of-both-worlds — vendor-locked AND ugly.

**Manual portal clicks:** Not even an option. The whole point is reproducibility.

## Common operations

```bash
# Run all commands from infra/environments/prod
cd infra/environments/prod

# First-time setup or after backend/provider changes
terraform init

# Show what would change (read-only, safe to run anywhere)
terraform plan

# Apply with manual confirmation prompt
terraform apply

# Apply non-interactively (CI pipelines)
terraform apply -auto-approve

# Destroy a specific resource (for surgical cleanup)
terraform destroy -target=module.<name>

# Recover state if a lock is stuck after a crash
terraform force-unlock <lock-id>

# Show what's currently in state
terraform state list
terraform state show <resource-address>

# Refresh state to reflect drift detected outside Terraform
terraform plan -refresh-only

# Format files (run before commit)
terraform fmt -recursive

# Upgrade providers within their version constraints
terraform init -upgrade
```

## Gotchas

- **Declaration blocks are plural; reference prefixes are singular.** You *declare* values in a `locals { }` block (plural) but *read* them as `local.x` (singular). Same split for variables: `variable "x" { }` declares, `var.x` references. Writing `locals.location` or `variables.subscription_id` in a reference is always wrong. The reference prefixes are a fixed, short list, all singular: `local.`, `var.`, `each.` (the key/value inside a `for_each`), plus `module.`, `data.`, `path.`, `self.`. The file name (`locals.tf`) and the block keyword (`locals {}`) being plural is correct and unrelated — only the *reference* is singular. `terraform validate` catches this with a misleading error — it reads `locals.location` as a reference to a *resource* of type `locals`, so you'll see something like `A managed resource "locals" "location" has not been declared`. Mental model: you declare *into* the plural bucket, you read *from* the singular namespace Terraform builds by merging all the blocks.
- **A resource's logical name ≠ its Azure `name`.** Every `type.LOGICAL_NAME.attr` reference must match the second quoted string in `resource "type" "LOGICAL_NAME" {}`, not the `name =` argument value. If you rename the logical name (e.g. `"vnet-lifestack-prod"` → `"main"`), every reference to it (`azurerm_virtual_network.main.id`) must be updated too — `validate` reports these as undeclared-reference errors.
- **`use_azuread_auth = true` is required** in `backend.tf` because we disabled shared-key auth on the state SA. Without it, `terraform init` fails with a 403 from the storage backend.
- **RBAC propagation can take 1–5 minutes.** When you grant a new team member "Storage Blob Data Contributor" on the state SA, they may see auth errors for a few minutes after the role assignment.
- **Owner ≠ data-plane access.** Subscription Owner is a control-plane role only. To read/write blobs via AAD auth (which is how the state backend works), you need an explicit Storage Blob Data role assignment. This catches people because Owner *can* regenerate shared keys and use those — but with shared-key auth disabled, the only path is the data-plane role.
- **`.terraform.lock.hcl` is committed.** It pins exact provider versions across the team and CI. Update it deliberately via `terraform init -upgrade`.
- **`terraform.tfvars` is committed.** It contains the subscription ID, which is not a secret per Microsoft guidance. Real secrets (DB passwords, API keys) belong in Key Vault and are read by the deployed app at runtime — never as Terraform inputs.
- **`prevent_deletion_if_contains_resources = true`** in the provider features block protects against accidentally `terraform destroy`-ing a non-empty resource group. To force-delete, flip the flag temporarily.
- **The state file contains all resource attributes including any secrets passed as Terraform inputs.** Remote backend keeps it encrypted at rest in Azure Storage; never `terraform state pull > local.tfstate` and forget to delete the file.

## Cost characteristics

- State SA (Standard_LRS, ~KB-sized state files): ~$0.02/month
- AzureRM and Random providers: free
- Bottom line: Terraform itself contributes essentially $0 to the monthly bill. The cost story is entirely about what Terraform provisions.

## Authoritative docs

- https://developer.hashicorp.com/terraform/language
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- https://developer.hashicorp.com/terraform/language/backend/azurerm
- https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
