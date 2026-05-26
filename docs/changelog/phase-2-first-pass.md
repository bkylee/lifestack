# Phase 2: Infrastructure baseline (first pass)

> **Archived.** This was the Claude-driven first pass. On 2026-05-13 all 29 Azure resources were destroyed and the code was archived to `infra/.reference/` and `docs/.reference/`. The state backend storage account `stlifestack9k3l` survived. The restart is documented in [phase-2-restart.md](phase-2-restart.md).

Each sub-step provisions one slice of the architecture and ships with a corresponding service doc and ADR (where the decision is non-obvious). v1 deploys only the prod environment; dev and staging are structured into the Terraform layout but not provisioned.

---

### Step 2.1 — Subscription, provider registration
*Commit: `910f581`*

#### Why a dedicated subscription

The default Azure subscription on the user's account already had an unrelated personal project. Best-practice for any production-scoped workload — and especially for one we want clean cost reporting on — is a dedicated subscription per workload per environment. Reasons:

- **Blast radius isolation.** Accidental destroy operations only affect the project sub.
- **Cost reporting.** Per-subscription billing reports show real Lifestack monthly cost without filtering — enables Phase-12's `docs/operations/cost.md` deliverable.
- **Quota isolation.** Postgres, Container Apps, and Front Door regional quotas are per-subscription.
- **Career-goal alignment.** "One sub per workload per environment" is the standard enterprise topology — setting it up that way now is the concept-to-production bridge for the architect track.

The user already had two subscriptions visible. The non-default one ("Subscription 1") was audited via `az resource list` / `az group list` / `az role assignment list` and found completely empty — zero resource groups, zero resources, zero custom RBAC. It was renamed to `Lifestack` via the portal and adopted as the v1 prod target.

#### Subscription details

- Name: `Lifestack`
- ID: `4bae3a60-95fa-468b-8088-95fd0d23311e`
- Tenant: `8f06ae15-e337-408c-abe2-da17244ad3a8`
- Type: pay-as-you-go (shared billing account with the user's other sub)

#### Resource providers registered

Azure resource providers must be registered in a subscription before you can create resources of those types. Most register on demand on first use, but registering up-front avoids a 2–3 minute wait on the first `terraform apply`. Nine providers registered (all completed in ~20 seconds):

- `Microsoft.App` — Container Apps
- `Microsoft.Cdn` — Front Door (Standard/Premium tier sits under Microsoft.Cdn)
- `Microsoft.ContainerRegistry` — ACR
- `Microsoft.DBforPostgreSQL` — Postgres Flexible Server
- `microsoft.insights` — Application Insights (lowercase namespace, an Azure naming oddity)
- `Microsoft.KeyVault` — Key Vault
- `Microsoft.Network` — VNet, NSG, Private Endpoint, Private DNS Zones
- `Microsoft.OperationalInsights` — Log Analytics
- `Microsoft.Storage` — Blob Storage

#### Verified

- `az account show --query name` → `Lifestack`
- All 9 providers in `Registered` state

---

### Step 2.2 — Terraform state backend, `infra/` skeleton
*Commit: `910f581`*

#### What was created

**State backend (bootstrapped via `az` CLI, not Terraform — chicken-and-egg):**

- Resource Group: `rg-lifestack-tfstate` (East US)
- Storage Account: `stlifestack9k3l` (Standard_LRS)
- Container: `tfstate`
- State blob key: `prod.tfstate`

**Why bootstrap via `az` CLI instead of Terraform.** Terraform needs a state backend to run. The state backend itself can't be Terraform-managed unless we provision it with local state and migrate (`terraform init -migrate-state`). Bootstrapping via `az` CLI is HashiCorp's documented pattern — the state SA is treated as one-time pre-Terraform infrastructure, outside the Terraform-managed estate. Cleaner, fewer steps, no dual-state to reconcile.

**Security posture on the state SA — locked down from creation:**

- `httpsOnly: true`, `minTls: TLS1_2` — no plaintext or weak crypto
- `allowBlobPublicAccess: false` — no anonymous reads at any scope
- `allowSharedKeyAccess: false` — no shared-key auth, AAD only
- Blob versioning enabled — every state-modifying apply creates a recoverable version
- 7-day soft delete on container and blob deletion — accidentally `terraform destroy`-ing the state is recoverable for a week
- "Storage Blob Data Contributor" role granted to the team member's user OID

The Owner-vs-data-plane subtlety bit immediately: subscription Owner is a control-plane role only. With shared-key auth disabled, the only way to read/write blobs is via AAD, which requires a Storage Blob Data role explicitly assigned. Owner-on-the-sub does *not* cover this — the role assignment was a required step, not a nicety.

**Terraform skeleton in `infra/environments/prod/`:**

- `versions.tf` — Terraform `~> 1.15`, AzureRM `~> 4.0`, Random `~> 3.6`
- `backend.tf` — AzureRM backend pinned to the state SA, with `use_azuread_auth = true` (mandatory because shared-key is disabled)
- `main.tf` — provider config block: `prevent_deletion_if_contains_resources = true` on RGs (safety against `terraform destroy` typos), `purge_soft_delete_on_destroy = false` and `recover_soft_deleted_key_vaults = true` on Key Vault (recoverability)
- `variables.tf` — `subscription_id`, `location`, `environment`, `project` inputs
- `terraform.tfvars` — sub ID committed (non-secret per Microsoft guidance)
- `infra/.gitignore` — ignores `.terraform/`, `*.tfstate*`, `*.tfplan`; explicitly notes `.terraform.lock.hcl` is committed

#### Naming convention locked in

Following the Microsoft Cloud Adoption Framework abbreviations. Documented in full in `docs/services/terraform.md`. Pattern: `<type>-lifestack-<purpose|env>` for resources that allow hyphens, `<type>lifestack<purpose>{rand}` for resources that don't (storage accounts, ACR). The 4-char `{rand}` suffix is needed for resources whose names are globally unique across all of Azure (storage accounts, ACR, Key Vault, Front Door endpoint).

#### Auth model

- **Local dev:** `az login` → AzureRM provider auto-detects CLI auth → state backend uses the same identity for AAD blob ops
- **CI (Phase 2.x, not yet wired):** GitHub Actions → workload identity / OIDC federation → AzureRM provider with no static credentials

#### Verified

- `terraform init` → providers downloaded (AzureRM 4.72.0, Random 3.8.1), backend connected, `.terraform.lock.hcl` generated
- `terraform validate` → "Success! The configuration is valid."
- `terraform plan` → "No changes. Your infrastructure matches the configuration." State lock acquired and released — confirms AAD auth and SA access work end-to-end
- `az storage container exists --auth-mode login` against the state SA → `true` (data-plane RBAC propagated correctly)

#### Cost so far

- State SA (Standard_LRS, KB-sized state files): ~$0.02/month
- No app-side resources provisioned yet

---

### Step 2.2.1 — Subscription budget (cost guardrail)
*Commit: `07012b5`*

#### What was created

A `$100/month` subscription-scoped budget (`lifestack-monthly`) with three alert thresholds:

| Threshold | Trigger | Why |
|---|---|---|
| 80% actual ($80) | `GreaterThan` | Yellow flag — getting close, intervene if trend continues |
| 100% actual ($100) | `GreaterThanOrEqualTo` | Already over — escalate |
| 100% forecasted | `GreaterThan` | Mid-month projection-based — fires earlier than actual when trajectory is bad, gives time to adjust before overrun |

All three notify `brian.ky.lee@outlook.com`. Time period: 2026-05-01 to 2030-05-01.

#### Important: budgets alert, they don't cap

Azure pay-as-you-go has no built-in "stop everything when threshold hit" feature — that exists only on free trial / MSDN / sponsorship subscriptions. For a hard cap, you'd need a custom Action Group plus Automation runbook to deallocate or stop resources when the alert fires. v1 stays alert-only; manual intervention is acceptable for a personally-monitored project. Documented as a deferred hardening item.

#### Why Terraform (not `az` CLI)

The state backend was bootstrapped via `az` CLI because of the Terraform chicken-and-egg. The budget has no such constraint — it's a normal subscription resource that fits cleanly into the Terraform-managed estate. Defining it via the `azurerm_consumption_budget_subscription` resource means:

- Future budget-threshold tweaks are PR-reviewable diffs
- The budget is recreated automatically if anyone deletes it via portal
- Naming/tagging stays consistent with the rest of the IaC

This is also the **first real Terraform apply** in the project — exercises the full IaC pipeline end-to-end: AzureRM provider auth via `az login`, state backend reads/writes via AAD, ARM API resource creation, state writeback to the backend SA. Everything green in 5 seconds.

#### Verified

- `terraform plan` → "1 to add, 0 to change, 0 to destroy"
- `terraform apply` → resource created in 5s, state writeback succeeded
- `az consumption budget list --query "[?name=='lifestack-monthly']"` → returns the budget with all three notifications populated, `currentSpend: $0.00`

#### Cost
- Budget itself: free
- Updated subscription cost so far: ~$0.02/month (still just the state SA)

---

### Step 2.3 — Network module: VNet, subnets, NSGs, private DNS zones
*Commit: `1da8c49`*

#### What was created

23 resources, all in `eastus`. First reusable Terraform module for the project.

**Four prod resource groups** (split-tier strategy chosen in the cost discussion):

| RG | Purpose |
|---|---|
| `rg-lifestack-network-prod` | VNet, subnets, NSGs, private DNS zones |
| `rg-lifestack-data-prod` | (empty) — Postgres, Blob, Key Vault land here in 2.4–2.8 |
| `rg-lifestack-app-prod` | (empty) — ACA env, ACA app, ACR land here in 2.5–2.6 |
| `rg-lifestack-observability-prod` | (empty) — Log Analytics, App Insights land here in 2.9 |

A fifth RG (`rg-lifestack-tfstate`) lives outside the Terraform-managed estate by design.

**Network module (`infra/modules/network/`):**

- VNet `vnet-lifestack-prod` · `10.10.0.0/16`
- 3 subnets:
  - `snet-aca-prod` · `10.10.0.0/23` · delegated to `Microsoft.App/environments` (workload profiles min size)
  - `snet-pg-prod` · `10.10.2.0/24` · delegated to `Microsoft.DBforPostgreSQL/flexibleServers`
  - `snet-pe-prod` · `10.10.3.0/27` · `private_endpoint_network_policies = Disabled` (Azure requirement for PE NICs)
- 3 NSGs (`nsg-aca-prod`, `nsg-pg-prod`, `nsg-pe-prod`) attached to their respective subnets — placeholders with default Azure rules only
- 4 private DNS zones, each linked to the VNet:
  - `privatelink.postgres.database.azure.com`
  - `privatelink.azurecr.io`
  - `privatelink.blob.core.windows.net`
  - `privatelink.vaultcore.azure.net`

**Env-level additions (`infra/environments/prod/`):**

- `random_string.suffix` — 4-char lowercase alphanumeric, persisted in state, used wherever a globally-unique resource name is required (storage accounts, ACR, Key Vault, Front Door endpoints). Resolved value: `21gg`.
- `locals.tf` — naming convention realized as a typed local map; the network module receives ready-made names rather than reconstructing them
- `outputs.tf` — surfaces the four RG names, the suffix, vnet ID, subnet IDs, and DNS zone IDs for ad-hoc lookup and downstream module consumption

#### Why placeholder NSGs

Each subnet has an NSG attached, but with no custom rules — only Azure's defaults apply. The reasoning:

- NSG-per-subnet is the BP pattern.
- Adding the NSG resource now means later steps (when ACA needs explicit outbound allows, etc.) just add rules — no "now I have to also create the NSG" detour.
- Defaults are safe for an empty subnet: cross-VNet traffic allowed, Azure load balancer health probes allowed, all other inbound denied; outbound permits VNet and internet by default.

The ACA NSG specifically will need explicit outbound allows for workload-profiles control-plane traffic (MCR, AzureFrontDoor.FirstParty, etc.) — added in Step 2.6 with the ACA env.

#### Why all four DNS zones up front

The alternative was creating each privatelink zone in the consuming module (Postgres zone in 2.4, ACR zone in 2.5, etc.) — every later step would have to touch the network module to link a zone to the VNet. Batching all four in 2.3:

- Zones are free (first 25 per subscription)
- Network module owns network resources cleanly — no later "the network module is now incomplete" surprises
- Each subsequent step just creates its PE and registers an A record, no zone wrangling

#### First terraform apply that creates infrastructure end-to-end

Step 2.2.1 (the budget) was a single subscription-scoped resource. This is the first multi-resource, multi-RG apply that exercises:

- The naming convention end to end
- Module composition (env config consumes a module)
- `for_each` over a map (the four DNS zones)
- Cross-resource references (subnet → NSG association → NSG)
- AAD-authenticated state writeback after a substantial diff

Apply duration: well under a minute for 23 resources.

#### Verified

- `terraform plan` → "23 to add, 0 to change, 0 to destroy"
- `terraform apply` → all 23 resources created
- `az group list` → 5 RGs (4 prod + 1 tfstate), all `Succeeded`
- `az network vnet show` → 3 subnets with correct prefixes and delegations (`Microsoft.App/environments`, `Microsoft.DBforPostgreSQL/flexibleServers`, none for PE)
- `az network private-dns zone list` → 4 zones, each with `numberOfVirtualNetworkLinks: 1`

#### Cost
- Network module itself: $0/month (everything in v1's network is free at this scale)
- Updated subscription cost so far: ~$0.02/month (still just the state SA)

---

### Step 2.4 — Postgres Flex module + region change from eastus to eastus2
*Commit: `d74330f`*

#### What this step produced

A reusable Terraform module at `infra/modules/postgres/` that provisions an Azure Database for PostgreSQL Flexible Server, its application database, and the server-level extension allowlist. Module wired into `infra/environments/prod/` via `postgres.tf`. Five new outputs surface the FQDN, database name, admin credentials, and connection string (the last two marked `sensitive`).

The server runs in `rg-lifestack-data-prod`. It has a NIC at `10.10.2.4` inside the delegated subnet `snet-pg-prod` — public network access is disabled, the FQDN resolves to that private IP via the existing `privatelink.postgres.database.azure.com` zone. From inside the VNet, `psql-lifestack-prod.postgres.database.azure.com` is a reachable database; from anywhere else, it's nothing.

#### The configuration choices, and what they mean

| Setting | Value | Meaning |
|---|---|---|
| Postgres version | `16` | Matches the local Docker dev environment for dev/prod parity. |
| SKU | `B_Standard_B1ms` | Burstable tier, 1 vCore, 2 GiB RAM. The cheapest line. Bursts above baseline by consuming CPU credits, falls back to baseline when credits run out. Right for v1 traffic. |
| Storage | `32 GB` Standard SSD | Postgres Flex's documented minimum. Auto-grow disabled to keep cost predictable. |
| Backup retention | `14 days` | Free up to provisioned storage size. Generous restore window. |
| Geo-redundant backup | `disabled` | Doubles backup cost. Region-pair failover is a v2 concern. |
| HA (zone-redundant) | `disabled` | Would double compute cost; v1 traffic doesn't justify it. |
| Availability zone | `1` (pinned) | If HA is disabled and you don't pin the zone, Azure picks one on first create and your plan diff shows the picked zone forever after. Pin so the config matches the runtime. |
| Maintenance window | Sunday 02:00 UTC | Off-peak. UTC because Azure's scheduler is UTC. |
| Public network access | **disabled** | Internet-unreachable from day one. |
| Network mode | Delegated subnet (VNet integration), not Private Endpoint | For Postgres Flex specifically, delegated-subnet integration lands a NIC directly in the VNet (no PE indirection, no PE cost). |
| `pgvector` allowlist | `azure.extensions = "vector"` | Server-level allowlist — the v3 taste-twin feature can `CREATE EXTENSION vector;` against the database when ready. |
| Admin password | 32-char URL-safe, generated by `random_password` | Stored in encrypted Terraform state for now. Migrates to Key Vault in Step 2.8. |

#### The region change (and why it's worth understanding)

**First apply blew up with `LocationIsOfferRestricted`.** Pay-as-you-go subscriptions are commonly blocked from provisioning Postgres Flex in `eastus` because the region is at capacity for that SKU family — Azure's documented escape hatch is a quota-increase ticket that doesn't actually get granted for PAYG. The fix is to deploy in a different region.

**Why this required moving everything, not just Postgres:** Postgres Flex VNet integration requires the delegated subnet's VNet to be in the same region as the server. We couldn't put Postgres in `eastus2` while leaving the network in `eastus`. So the move was: `terraform destroy` (25 resources, ~3 minutes), change `var.location` default from `"eastus"` to `"eastus2"`, `terraform apply` to rebuild.

**Pedagogical takeaway:** "Azure region" is two things at once — a physical location for compute resources and a constraint on which other resources can co-locate with them. The constraint propagates: choose a region for any one tier and you've chosen it for every tier that needs to talk to it privately. In retrospect, the right check before deciding on `eastus` was `az provider show -n Microsoft.DBforPostgreSQL --query "resourceTypes[?resourceType=='locations'].locations[]"` cross-referenced with quota — except Azure doesn't actually expose "PAYG-allowed PG Flex regions" cleanly, which is part of the operational reality.

#### Other gotchas this step taught

**Extension name is `vector`, not `PGVECTOR`.** Old docs and the legacy Single Server world used uppercase. Flex's `azure.extensions` parameter takes the lowercase, canonical Postgres extension identifier (which is what `CREATE EXTENSION` accepts). Apply errored on first try; corrected to `vector` and the variable description now documents the right convention.

**Azure consistency lag during a fresh re-deploy.** The eastus2 apply hit several transient `Root object was present, but now absent` errors and one `VirtualNetworkDoesNotExist` error mid-apply, even though the resources had just been created. This is Azure ARM's eventual-consistency edge: a resource exists, but a subsequent read inside the same apply returns 404 for a few seconds. Each error stranded a Terraform-managed resource in Azure without a corresponding state entry. Recovery procedure used:
1. `terraform state list` to identify which resources were missing from state.
2. `az` CLI to confirm which existed in Azure.
3. Either `terraform import <addr> <id>` to reconcile (used for orphaned PE subnet-NSG association and ACR DNS zone link), or `az` delete + re-apply (used for VNet and two NSGs that were cleanest to recreate).
4. Final `terraform plan` to confirm no drift.

This is a real production failure mode: half-applied Terraform from API flake. The recovery — read state, read reality, import or recreate — generalizes.

**Postgres Flex is the slowest single resource we'll provision.** ~8m30s for the server alone, plus ~15s each for the database and the extensions config. Worth knowing for future re-apply timing.

#### Files

- `infra/modules/postgres/versions.tf` — provider pins (`azurerm ~> 4.0`, `random ~> 3.6`).
- `infra/modules/postgres/variables.tf` — 12 module inputs with defaults (SKU, storage, version, retention, extensions, AZ, etc.).
- `infra/modules/postgres/main.tf` — `random_password.admin`, `azurerm_postgresql_flexible_server.main`, `_database.app`, `_configuration.extensions`.
- `infra/modules/postgres/outputs.tf` — 7 outputs (id, name, fqdn, database, username, password, connection string).
- `infra/environments/prod/postgres.tf` — module invocation.
- `infra/environments/prod/outputs.tf` — 5 new top-level outputs surfacing the module's outputs.
- `infra/environments/prod/variables.tf` — `location` default changed from `eastus` to `eastus2` (description records why).
- `docs/services/azure-postgres-flexible.md` — full service reference.
- `docs/services/azure-network.md` — region updated to `eastus2`.
- `docs/decisions/ADR-0009.md` — Azure-managed Postgres choice (formal record).
- `docs/architecture.md` — current-state diagram, current-vs-target table, and network-topology footnote all reflect Postgres deployed.

#### Verified

- `terraform plan` → clean (no drift) on final apply.
- `az postgres flexible-server show` → state `Ready`, version `16`, SKU `Standard_B1ms`, `publicAccess: Disabled`, delegated subnet wired, private DNS zone wired, AZ `1`.
- `az postgres flexible-server db show` → database `lifestack`, charset `UTF8`, collation `en_US.utf8`.
- `az postgres flexible-server parameter show -n azure.extensions` → value `vector`, listed in `allowedValues`.
- `az network private-dns record-set a list` on `privatelink.postgres.database.azure.com` → one A record pointing to `10.10.2.4`.

#### Cost
- Postgres Flex B1ms compute: ~$13/month (always-on).
- Storage (32 GB Standard SSD): ~$4/month.
- Backups (14-day): $0 (free up to provisioned storage size).
- Subscription total so far: ~$17/month (Postgres) + ~$0.02 (state SA) + $0 (everything else still free at this scale) = **~$17/month idle**.

---

### Step 2.5 — Container Registry (ACR Basic)
*Commit: `57b4427`*

#### What this step produced

A reusable Terraform module at `infra/modules/acr/` that provisions an Azure Container Registry. Wired into the prod env via `acr.tf`. Three new outputs (`acr_id`, `acr_name`, `acr_login_server`) surface the registry's identifiers.

The registry — `crlifestackehyp.azurecr.io` — lives in `rg-lifestack-app-prod`. It's empty: no images pushed yet. CI/CD in Step 2.6 will push the first Next.js image; Container Apps will pull from this registry on deploy.

#### Decisions worth understanding

**SKU = Basic.** ADR-0010 captures the trade in full. The short version: Premium ($50/mo) would unlock Private Endpoint, geo-replication, content trust, scope tokens, and retention policy. Basic ($5/mo) ships with none of those but keeps the v1 monthly cost under the $100 budget. Authentication posture is identical across tiers — admin user disabled, anonymous pulls disabled, every pull/push gated by AAD + RBAC. The defense-in-depth gap (public auth endpoint vs. PE-only) is the only meaningful difference.

The `privatelink.azurecr.io` private DNS zone we deployed in Step 2.3 is dormant — kept linked to the VNet so a future Premium upgrade is one resource away (the Private Endpoint), with no name resolution work to redo.

**Admin user disabled (`admin_enabled = false`).** ACR ships with an optional admin user that authenticates with a shared registry password. Disabling it forces every access through AAD identities. This is the modern best practice and is universally recommended; the admin user mainly exists for legacy compatibility with tools that don't know how to do AAD auth.

**Anonymous pull disabled.** Default, but explicit. Every pull requires a valid AAD token. Without this, the registry could serve images to anonymous clients — useful for public OSS images, terrible for app images.

**Public network access enabled.** Basic doesn't support Private Endpoint; this is the only mode available. AAD/RBAC is doing the work of access control. With Premium and a PE this would become `Disabled`, and the only path to the registry would be over the VNet.

**Network rule bypass = `AzureServices` (default).** Mostly cosmetic on Basic — there are no network rules to bypass. Becomes meaningful on Premium with a PE: it lets trusted Azure services (Container Apps, ACR Tasks) reach the registry even when the network ruleset would otherwise block them.

#### Naming gotcha

ACR names must be **alphanumeric only** — no hyphens, no underscores, 5–50 characters. This is a registry-specific constraint different from the CAF `kind-app-env` pattern. The pattern landed on:

```hcl
name = "cr${var.project}${random_string.suffix.result}"
# → crlifestackehyp
```

The suffix comes from the env's shared `random_string.suffix`, which regenerated during the Step 2.4 destroy-and-recreate cycle (from `21gg` to `ehyp`). The suffix exists for resources that must be globally unique within their Azure namespace (storage accounts, ACR, Key Vault, Front Door). Documented in `docs/services/terraform.md`.

#### What's NOT in this step (and why)

| Skipped | Reason |
|---|---|
| Private Endpoint | Basic SKU doesn't support it. Deferred under ADR-0010. |
| Retention policy | Premium-only feature. Manual or scripted cleanup will live in CI/CD. |
| Content trust / Notary signing | Premium-only. Not in v1 threat model. |
| Scope tokens (per-repo RBAC) | Premium-only. Not needed for a single-repo registry. |
| `AcrPull` role assignment for Container Apps managed identity | Container Apps' managed identity doesn't exist yet — created in Step 2.6 with the ACA env. The role assignment lives there. |

#### Files

- `infra/modules/acr/versions.tf` — provider pin (`azurerm ~> 4.0`).
- `infra/modules/acr/variables.tf` — 5 inputs with name + SKU validators.
- `infra/modules/acr/main.tf` — single `azurerm_container_registry` resource.
- `infra/modules/acr/outputs.tf` — `id`, `name`, `login_server`.
- `infra/environments/prod/acr.tf` — module invocation.
- `infra/environments/prod/outputs.tf` — 3 new top-level outputs.
- `docs/services/azure-container-registry.md` — full service reference.
- `docs/decisions/ADR-0010.md` — Basic vs Premium decision.
- `docs/architecture.md` — current-state diagram, current-vs-target table, target-state SKU label all updated.

#### Verified

- `terraform plan` → 1 to add, clean.
- `terraform apply` → registry created in ~10 seconds.
- `az acr show` → `provisioningState: Succeeded`, `sku: Basic`, `adminUserEnabled: false`, `anonymousPullEnabled: false`, `publicNetworkAccess: Enabled`, `loginServer: crlifestackehyp.azurecr.io`.
- `az acr repository list` → `[]` (empty registry, as expected).

#### Cost

- ACR Basic: ~$5/month (fixed; storage included up to 10 GB).
- Subscription total so far: ~$17 (Postgres) + ~$5 (ACR) + ~$0.02 (state SA) = **~$22/month idle**.
