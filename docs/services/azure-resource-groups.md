 Azure Resource Groups

## What it is

> **Fill in** — One paragraph. Define an Azure Resource Group: a logical container / management boundary for resources, not a runtime construct. Cover that every Azure resource belongs to exactly one RG; that the RG itself has a region (metadata about where the RG's own record lives) which is independent of where the resources inside it run; and that an RG is simultaneously a lifecycle, RBAC, and billing boundary. Say where RGs sit in our stack — the foundation layer: Module 1 creates them and nothing else, Modules 2+ fill them.

Resource groups are logical containment of Azure resources. RG groups have meta data and can be used to lifecycle the collective resources together. We created them in module 1 and filled with Module 2 onward. 

## Why we use it

> **Fill in** — Why we deliberately split into **four** tier RGs (`network`, `data`, `app`, `observability`) rather than one flat RG. This is decision [D5] in `docs/mentor/m1-s1-locals.md`. The three reasons from that mentor message: (a) tier-level RBAC mirrors how real orgs scope access (DBAs → data RG, network team → network RG); (b) cost reporting rolls up per tier; (c) blast-radius isolation — destroy/recreate one tier without touching others. Be honest about the solo-project tension: you are every "team," so the RBAC benefit is latent, not active — frame it as structuring now for a story you can defend later.
We wanted to split up our resources into 4 groups based on function. Having tiers reflects RBAC (resource groups for specific teams), costs separated per tier, blast-radius isolation (easily destroy/ redeploy resources without touching all resources.). I want to replicate a production environment wherever possible as this is a project focused on learning rather than on full efficiency. 


## How it's configured here

We created 4 RG groups for prod: network, data, app, and obersvability. The naming pattern we are using is 'rg -{project}-{tier}'. 

We created these groups by using a terraform for each loop within a single 'azurerm_resource_group block in infra/environments/prod/resource_groups.tf. It uses the 'rb_names' map in locals.tf. Easier to manage than hardcoded files. 

We set the region to eastus2 for all (local.location) and base tags (local.base_tags) 

The provider 'features' block in main.tf is used to set behaviours for certain settings for services. We set prevent_deletion_if_contains_resources = true for resource_group. 

There is one RG that is not managed here 'rg-lifestack-tfstate' which contains the Terraform state storagge account. 

— The concrete setup:
> - The four RGs and their names: `rg-lifestack-network-prod`, `rg-lifestack-data-prod`, `rg-lifestack-app-prod`, `rg-lifestack-observability-prod` — pattern `rg-{project}-{tier}-{environment}`.
> - How they're created: a single `azurerm_resource_group` block with `for_each = local.rg_names` (`infra/environments/prod/resource_groups.tf`), driven by the `rg_names` map in `locals.tf`.
> - Why `for_each` over a map and not `count` — see `docs/mentor/m1-s2-resource-groups.md`; the short version is that map keys give stable state addresses, list indices don't.
> - Region: all four in `eastus2` (`local.location`). Tags: every RG gets `local.base_tags` (`project`, `environment`, `managed_by`).
> - The provider `features` block in `main.tf`: `resource_group { prevent_deletion_if_contains_resources = true }` — what it does.
> - The one RG **not** managed here: `rg-lifestack-tfstate` (holds the Terraform state storage account) was bootstrapped by hand before Terraform existed and lives outside this config.

## Mental model

Remember RGs are used for the following: 
- lifecycles
- RBAC
- Cost 

local.rg_names is the single source of truth for RGs. We edit one line in the map. 

for_each is part fo the state address 'azurerm_resource_group.rg_names["network"]. Renaming a key will destroy and re-create, not just rename. 
* — The 2–3 concepts to hold in your head:
> 1. An RG is a three-in-one boundary — lifecycle (delete the RG, delete its contents), RBAC (roles assigned at RG scope), and cost (Cost Management rolls up by RG).
> 2. `local.rg_names` is the single source of truth for which RGs exist — adding a tier is a one-line map edit, not a new resource block.
> 3. The `for_each` key becomes part of the state address (`azurerm_resource_group.rg_names["network"]`) — the key *is* identity, so renaming a key is a destroy-and-recreate, not a rename.

## Alternatives considered

Flat single RG. It's simpler but lumps all costs and resources together. I want to replicate close to real-world environments. 

 — The flat single-RG option, the other half of [D5]. Lift the FLAT-vs-SPLIT trade-off from `docs/mentor/m1-s1-locals.md`: flat is simpler (one RBAC grant = whole env, one blast-radius boundary) but lumps all cost together and forecloses tier-scoped RBAC. Briefly note the patterns not seriously considered and why — one RG per resource (far too granular, no benefit) and grouping by lifecycle/churn rate instead of by tier (a real pattern, but tier-grouping matches how this stack's modules are organized).

## Common operations

```bash
# Run Terraform commands from infra/environments/prod
cd infra/environments/prod

# --- List the resource groups ---
az group list -o table        # what Azure actually has
terraform state list          # what Terraform manages

# --- Inspect one resource group ---
terraform state show 'azurerm_resource_group.rg_names["data"]'   # Terraform's record
az group show -n rg-lifestack-data-prod                          # Azure's view

# --- Add a new tier RG ---
# Add a line to local.rg_names in locals.tf, then:
terraform plan                # expect "1 to add"
terraform apply

# --- Tear one down (rare) ---
# prevent_deletion_if_contains_resources = true (main.tf) blocks destroying a
# non-empty RG. To remove a populated one, set that flag false first, then:
terraform destroy -target='azurerm_resource_group.rg_names["app"]'
```

## Gotchas

> **Fill in** — The non-obvious things:
> - `prevent_deletion_if_contains_resources = true` makes Terraform refuse to delete a non-empty RG — flip the flag first to intentionally tear one down.
> - Renaming a `for_each` map key (e.g. `observability` → `monitoring`) destroys and recreates that RG, because the key is its state identity.
> - Deleting an RG is an irreversible cascade — everything inside goes with it.
> - An RG's `location` is metadata only; resources inside can sit in other regions (we keep everything in `eastus2` regardless).
> - RG names must be unique within the subscription, not globally.

## Cost characteristics

> **Fill in** — Short. Resource groups themselves are **free** — $0 on the bill. The four-way split exists for cost *attribution* (per-tier rollup in Azure Cost Management), not cost reduction. Note where you'd view per-RG spend (Cost Management → group/filter by resource group). The real cost story belongs to what the RGs contain — documented per-service from Module 2 on.

## Authoritative docs

- [Azure Resource Manager — resource groups overview](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview)
- [Manage resource groups (Azure CLI / portal)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal)
- [Cloud Adoption Framework — resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [Terraform — `azurerm_resource_group`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
- [Terraform — `for_each` meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
