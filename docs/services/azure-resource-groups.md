# Azure Resource Groups

## What it is

Resource groups are logical containers for Azure resources. Each group holds a set of related resources, shares their lifecycle (deleting the group deletes everything in it), and acts as a boundary for RBAC and cost reporting. We created the four prod resource groups in Module 1; subsequent modules deploy their resources into them.

## Why we use it

We split resources into four groups by function — network, data, app, and observability — rather than putting everything in one group. The split gives us:

- **Lifecycle isolation:** tearing down or redeploying one tier doesn't touch the others.
- **Cost reporting per tier:** Azure Cost Management rolls up by resource group, so we can see what the network layer costs vs. the app layer.
- **Scoped RBAC:** in a team environment, you'd grant a DBA access to the data RG only. We're solo now, but the pattern is production-realistic.

The goal is to replicate real-world production structure, not minimize resource count. Learning value over operational simplicity for this project.

## How it's configured here

Four RGs for prod: `rg-lifestack-network-prod`, `rg-lifestack-data-prod`, `rg-lifestack-app-prod`, `rg-lifestack-observability-prod`. Pattern: `rg-{project}-{tier}-{environment}`.

Created using a single `azurerm_resource_group` block with `for_each = local.rg_names` in `infra/environments/prod/resource_groups.tf`, driven by the `rg_names` map in `locals.tf`. `for_each` over a map rather than `count` over a list — map keys give stable state addresses; list indices don't. Renaming an entry in a list shifts all downstream indices; renaming a map key only affects that key. See `docs/mentor/m1-s2-resource-groups.md` for the full reasoning.

Region: all four in `eastus2` (`local.location`). Tags: every RG gets `local.base_tags` — `project`, `environment`, `managed_by = terraform` (the signal that a resource is IaC-managed, not portal-created).

The provider `features` block in `main.tf` sets `resource_group { prevent_deletion_if_contains_resources = true }`. This makes Terraform refuse to destroy a non-empty resource group — a guardrail against accidentally wiping a tier.

One RG is **not** managed here: `rg-lifestack-tfstate`, which holds the Terraform state storage account. It was bootstrapped by hand before Terraform existed and lives outside this config intentionally.

## Mental model

Three things resource groups do simultaneously:

1. **Lifecycle boundary** — delete the RG, delete everything in it. This is how you cleanly remove a whole tier.
2. **RBAC boundary** — roles assigned at RG scope apply to all resources in it. Tier-split = scoped access control.
3. **Cost rollup** — Cost Management aggregates by RG by default. Tier-split = per-tier cost visibility.

`local.rg_names` is the single source of truth for which RGs exist. Adding a tier is a one-line map edit, not a new resource block.

The `for_each` key is the state address: `azurerm_resource_group.rg_names["network"]`. Renaming a key is a destroy-and-recreate in Terraform's eyes, not a rename — the old resource disappears and a new one appears.

## Alternatives considered

**Flat single RG** — simpler (one RBAC grant covers everything, one blast-radius boundary), but lumps all costs together and forecloses tier-scoped access control. Ruled out because the split is low-cost to add now and matches how real production environments are structured.

**One RG per resource** — too granular; no practical benefit and significant management overhead.

**Group by lifecycle/churn rate** (e.g., stable infra together, frequently-updated app resources together) — a real pattern, but tier-grouping maps better to how this project's modules are organized and how team ownership would be assigned.

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

The `location` on a resource group is metadata only — it does not constrain where resources inside it are deployed. Resources in a group can live in any region regardless of the group's location field.

## Cost characteristics

Resource groups are free. Their value is in cost *visibility*: Cost Management rolls up by RG, so the tier split lets us see what each layer costs without additional tagging queries.

## Authoritative docs

- [Azure Resource Manager — resource groups overview](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview)
- [Manage resource groups (Azure CLI / portal)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal)
- [Cloud Adoption Framework — resource abbreviations](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [Terraform — `azurerm_resource_group`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
- [Terraform — `for_each` meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
