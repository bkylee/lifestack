# Module 3, Step 1 — Key Vault

**File you will write:** `infra/environments/prod/keyvault.tf` (from scratch, using the provider docs)
**Decisions in this step:** [D1] RG placement, [D2] SKU, [D3] authorization model, [D4] network access model, [D5] purge protection + soft-delete retention.

---

## What we're building this module

The secrets store for the whole platform: one Key Vault, locked to private network access via a **private endpoint** in the `pe` subnet (wired to the `kv` private DNS zone you already created in Module 2), using **RBAC** for data-plane authorization, plus a role assignment so *you* (the Terraform deployer) can write secrets into it in later modules.

After this module: the vault exists, resolves privately, and is ready to hold the secrets that Modules 4–8 will produce (Postgres admin password, ACR not-really — it uses managed identity, OAuth client secrets, Resend API key, etc.). No secret values go in yet — Module 3 builds the container, not its contents.

This is the **first private endpoint in the project**, so it's also where you learn the PE wiring pattern (private_service_connection + private_dns_zone_group) that Postgres, ACR, and Blob will all reuse.

## Why Key Vault comes this early in the sequence

Everything downstream needs somewhere to put secrets the moment it's created. If you stand up Postgres first, the admin password has nowhere to live except Terraform state (bad) or a `.tfvars` file (worse). Build the vault before the things that generate secrets, and every later module can write its secret as it goes.

---

## What doesn't need a decision (already settled)

**Soft delete is always on.** In azurerm v4 you cannot create a vault with soft delete disabled — Azure removed the option. A deleted vault sits in a recoverable state for the retention window before it can be purged. The only knob is the retention *length* ([D5]).

**`tenant_id` comes from a data source, not a hardcoded GUID.** Add a `data "azurerm_client_config" "current" {}` block and reference `data.azurerm_client_config.current.tenant_id`. Same data source gives you `.object_id` — the principal running Terraform — which you need for the role assignment. Never paste a tenant GUID as a literal.

**The features block is already configured.** `main.tf` has `key_vault { purge_soft_delete_on_destroy = false }`. That means when you `terraform destroy` a vault, Terraform will *not* try to permanently purge it — it leaves it in soft-deleted recoverable state. Leave that as-is; it interacts with [D5].

**Global name uniqueness.** Vault names share a global DNS namespace (`<name>.vault.azure.net`), so `kv-lifestack-prod` must be unique across *all of Azure*, not just your subscription — exactly like the `stlifestack9k3l` storage account got a random suffix. You'll add a short random suffix (see Resources to write). Vault names are 3–24 chars, alphanumeric + hyphens, must start with a letter.

**Subresource name for the PE is `"vault"`.** When you wire the private endpoint, the `subresource_names` for a Key Vault is the literal string `["vault"]`. Each Azure service has its own subresource group ID; Key Vault's is `vault`. Wrong value = the PE fails to connect.

---

## Decisions

### [D1] Resource group placement

- **Textbook:** "Group resources by lifecycle and ownership."
- **Production reality:** You have four RGs (`network`, `data`, `app`, `observability`). Key Vault doesn't fit cleanly into one — secrets are cross-cutting. The realistic options:
  - **`app`** — the vault primarily serves the application (OAuth secrets, Resend key, DB connection string the app reads at startup). Co-locating it with the workload that consumes it is a defensible "lifecycle follows consumer" argument.
  - **`data`** — "secrets are sensitive data, put them with the data tier." Reasonable but the data RG is really about the database itself.
  - **A dedicated `security` RG** — cleanest in a large org with a separate security team owning the vault's RBAC. Overkill at four RGs for a solo project, and you'd have to add the key to `locals.rg_names`.
- **Recommendation:** **`app`.** The vault's consumer is the app; keeping it in `rg-lifestack-app-prod` keeps the "who reads this" story simple. If this were a multi-team org I'd carve a security RG, but that's ceremony you don't need yet.

### [D2] SKU

- **Textbook:** "Choose Standard or Premium."
- **Production reality:** The only difference is **Premium adds HSM-backed keys** (FIPS 140-2 Level 2 hardware security modules for cryptographic *keys*). Secrets (which is all we store — strings) are protected identically in both tiers. Premium costs more per key operation and you'd only pick it if you had a compliance requirement for HSM-backed *keys* (not secrets).
  - **Standard** — software-protected keys + secrets. Everything we need.
  - **Premium** — HSM-backed keys. We store zero keys, only secrets. No benefit.
- **Recommendation:** **Standard.** We store secrets, not cryptographic keys; Premium buys us nothing.

### [D3] Authorization model — RBAC vs access policies

- **Textbook:** "Control access to the vault."
- **Production reality:** Two mutually exclusive models for the **data plane** (who can read/write secrets):
  - **Access policies (legacy)** — a list baked into the vault resource mapping a principal → allowed operations (get/list/set secrets). Vault-local, doesn't show up in Azure's central RBAC view, can't be assigned at management-group scope, and is the older pattern Microsoft now steers away from.
  - **RBAC (`enable_rbac_authorization = true`)** — data-plane access granted via standard Azure role assignments (`Key Vault Secrets User` to read, `Key Vault Secrets Officer` to read/write, `Key Vault Administrator` for full control). Same RBAC system as everything else, auditable centrally, assignable at any scope.
- **Why it matters for us:** Container Apps will read secrets via its managed identity (Module 7). With RBAC that's a one-line `Key Vault Secrets User` role assignment on the identity. With access policies you'd be maintaining a parallel access list. RBAC is also the only model that composes cleanly with the rest of our identity story.
- **Recommendation:** **RBAC.** Set `enable_rbac_authorization = true`. It's the modern default and matches how the managed-identity reads will work. **Consequence:** the moment RBAC is on, *nobody* — not even you, the vault creator — can touch secrets without an explicit role assignment. That's why [Resources] includes a role assignment for yourself.

### [D4] Network access model — the important one

- **Textbook:** "Restrict network access to the vault."
- **Production reality:** This is the decision with the sharpest production gotcha, because of a **control-plane vs data-plane split**:
  - *Control plane* (creating the vault, setting properties, doing role assignments) always goes through Azure Resource Manager and is **unaffected** by the vault's network rules. So Terraform can always *create and configure* the vault.
  - *Data plane* (reading/writing the actual secret *values*) honors the network rules. So if you lock the vault to private-endpoint-only, then any secret-write from outside the VNet — including `terraform apply` running on your laptop in Module 6 to store the Postgres password — **fails with a 403 Forbidden**, even though the apply that creates the vault succeeds.
- **The three shapes:**
  - **Public open** (`public_network_access_enabled = true`, no ACLs) — easy, but the vault is reachable from anywhere on the internet (still auth-gated, but exposed). Not acceptable for our posture.
  - **Private-endpoint-only** (`public_network_access_enabled = false` + PE) — most locked-down, what a real prod vault looks like. But then *every* secret write must originate inside the VNet (a self-hosted CI runner on the network, or a jumpbox). You don't have that yet, so you'd be unable to populate secrets from your laptop in later modules.
  - **Public-with-firewall + PE** (`public_network_access_enabled = true`, `network_acls { default_action = "Deny", bypass = "AzureServices", ip_rules = [your public IP] }`, *plus* the private endpoint) — the vault denies the world by default, allows your specific public IP for laptop/CI secret-writes, and the PE gives Container Apps a private path at runtime. The pragmatic middle ground for a solo operator.
- **Recommendation:** **Public-with-firewall + PE.** `default_action = "Deny"`, `bypass = "AzureServices"`, `ip_rules` set to *your current public IP as a `/32`*. Keep `public_network_access_enabled = true` (it must be `true` for `ip_rules` to have any effect — set it `false` and ACLs are ignored, only the PE works). Add the private endpoint as well.
  - **The honest tradeoff to write in the changelog:** a real prod shop runs secret-writes from inside the network and sets `public_network_access_enabled = false`. We're allowing one IP through the front door so a laptop/CI apply can write secrets without a VNet-resident runner. The gotcha to remember: **your home IP changes**, and when it does, secret-writes start 403'ing until you update `ip_rules`. That's the cost of not having in-VNet CI yet. Note it as a known v2 hardening: flip to PE-only once CI runs inside the network.

### [D5] Purge protection + soft-delete retention

- **Textbook:** "Enable purge protection for production vaults."
- **Production reality:** Two settings:
  - **`soft_delete_retention_days`** — how long a deleted vault (and its secrets) stays recoverable before it can be purged. Range 7–90, default 90.
  - **`purge_protection_enabled`** — when `true`, *nobody* can permanently purge the vault (or its secrets) during the retention window, even with full admin rights. **This is irreversible — once you turn purge protection on, you cannot turn it off**, and you cannot fully delete the vault until the retention window elapses.
- **The learning-project wrinkle:** You torched 29 resources to restart Phase 2. If this vault had purge protection on and a 90-day retention, a future teardown would leave an unpurgeable vault — and its globally-unique name — locked up for 90 days, blocking you from recreating `kv-lifestack-prod-xxxx`. For a project you're deliberately iterating on, that's friction.
- **Recommendation:** **Purge protection OFF, `soft_delete_retention_days = 7`.** Off so teardown/rebuild stays clean while you're learning; 7 (the minimum) so even soft-deleted vaults clear quickly. **Write in the doc that this is a deliberate learning-environment choice and the production default is the opposite** — real prod vaults run purge protection ON with 90-day retention. Being able to articulate *why you'd flip it in prod* is the interview-defensible part.

---

## Resources to write

Write these in `infra/environments/prod/keyvault.tf`. Look up exact argument names in the provider docs — don't trust memory.

### 1. Client config data source

- **Block:** `data "azurerm_client_config" "current" {}`
- Gives you `.tenant_id` (for the vault) and `.object_id` (the deploying principal, for the role assignment). No arguments.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config

### 2. Random suffix for the global-unique name

- **Resource:** `random_string`
- **Logical name:** `kv_suffix`
- **Args:** `length = 4`, `special = false`, `upper = false`, `numeric = true` (lowercase letters + digits). Reference it as `random_string.kv_suffix.result`.
- **Why:** vault names live in a global DNS namespace; the suffix guarantees uniqueness the same way `stlifestack9k3l` does for the state storage account.
- **Doc:** https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string

### 3. The Key Vault

- **Resource:** `azurerm_key_vault`
- **Logical name:** `main`
- **Required args:**
  - `name` — `"kv-${local.project}-${local.environment}-${random_string.kv_suffix.result}"` (keep an eye on the 24-char limit: `kv-lifestack-prod-` is 18 + 4 suffix = 22, fits).
  - `location` — `local.location`
  - `resource_group_name` — `azurerm_resource_group.rg_names["app"].name` (your [D1])
  - `tenant_id` — `data.azurerm_client_config.current.tenant_id`
  - `sku_name` — your [D2], lowercase (`"standard"`)
  - `tags` — `local.base_tags`
- **Behavioral args:**
  - `enable_rbac_authorization` — `true` ([D3])
  - `purge_protection_enabled` — `false` ([D5])
  - `soft_delete_retention_days` — `7` ([D5])
  - `public_network_access_enabled` — `true` ([D4] — required for ip_rules to work)
- **`network_acls` block** ([D4]):
  - `default_action = "Deny"`
  - `bypass = "AzureServices"`
  - `ip_rules = ["<your-public-IP>/32"]` — find it with `curl -s ifconfig.me`. (Brittle on a dynamic home IP; that's the documented tradeoff.)
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault

### 4. Role assignment for the deployer

- **Resource:** `azurerm_role_assignment`
- **Logical name:** `deployer_secrets`
- **Args:**
  - `scope` — `azurerm_key_vault.main.id`
  - `role_definition_name` — `"Key Vault Secrets Officer"` (read + write secrets; pick Administrator only if you'll also manage keys/certs, which we won't)
  - `principal_id` — `data.azurerm_client_config.current.object_id`
- **Why it's here:** with RBAC on ([D3]), the vault creator has *no* data-plane access by default. Without this, your Module 6 `terraform apply` that writes the Postgres password gets a 403 — not a network 403, an *authorization* 403. This grants your principal the right to write secrets.
- **Permission note:** creating a role assignment requires *you* to have `Microsoft.Authorization/roleAssignments/write` (Owner or User Access Administrator on the scope). On a personal subscription you're almost certainly Owner, so this is fine. If the apply fails here with an authorization error, that's why.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment

### 5. The private endpoint (first PE in the project)

- **Resource:** `azurerm_private_endpoint`
- **Logical name:** `kv`
- **Args:**
  - `name` — `"pe-kv-${local.project}-${local.environment}"`
  - `location` — `local.location`
  - `resource_group_name` — the `app` RG (same as the vault; PEs commonly live with the resource they front, though some shops put all PEs in the network RG — either is defensible)
  - `subnet_id` — `azurerm_subnet.pe.id` (the PE subnet from Module 2)
  - `tags` — `local.base_tags`
  - a **`private_service_connection`** block:
    - `name` — e.g. `"psc-kv"`
    - `private_connection_resource_id` — `azurerm_key_vault.main.id`
    - `subresource_names` — `["vault"]` (the literal Key Vault subresource group ID)
    - `is_manual_connection` — `false` (auto-approved because you own both ends)
  - a **`private_dns_zone_group`** block:
    - `name` — e.g. `"pdzg-kv"`
    - `private_dns_zone_ids` — `[azurerm_private_dns_zone.zones["kv"].id]` (the `kv` zone from Module 2)
- **What the dns_zone_group does:** it auto-creates the A record (`<vault-name>.privatelink.vaultcore.azure.net` → the PE's private IP) inside the `kv` zone. Without it the PE exists but nothing resolves to it — the same "zone is inert without wiring" lesson from the VNet links, one layer down.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint

---

## Deep dive: why creating the vault works but writing a secret might not

This is the single most common Key Vault footgun, and it's worth holding clearly because it generalizes to almost every "private" Azure data service.

Azure splits every service into two planes:

- **Control plane (ARM):** create/configure/delete the resource, assign roles. Routed through `management.azure.com`. Governed by RBAC `Microsoft.KeyVault/*` actions. **Network rules on the vault do not apply here** — ARM is a separate front door.
- **Data plane:** the actual secrets at `https://<vault>.vault.azure.net`. Governed (with RBAC enabled) by the `Key Vault Secrets *` roles **and** by the vault's `network_acls` / `public_network_access_enabled`.

So a single `terraform apply` touches *both* planes and they fail independently:

1. Creating `azurerm_key_vault.main` → control plane → always works regardless of `network_acls`.
2. Writing an `azurerm_key_vault_secret` (later modules) → data plane → must satisfy **both** (a) an RBAC role granting write *and* (b) a network path the firewall allows.

That's why a lot of people hit "I deployed the vault fine, why can't Terraform write the secret?" — they locked it to PE-only (network fails) *or* they forgot the role assignment (auth fails), or both. Our [D4] (allow your IP) handles the network half; our role assignment ([Resources] #4) handles the auth half. Get one wrong and secret-writes 403 in a later module with an error that points here.

When you add Postgres in Module 6 and store its password, this is the machinery that has to be correct for the write to land.

---

## What to do

1. Open the provider docs (links above) in a side tab. Reference them as you type.
2. Get your public IP: `curl -s ifconfig.me`.
3. Write `infra/environments/prod/keyvault.tf` from scratch — every resource, every argument.
4. Fill in [D1]–[D5] with your chosen values.
5. Run `terraform fmt` from the prod dir.
6. **Do not run `terraform plan` yet.** Send the file back for review first.

## Sanity-check before review

- The vault `name` is ≤ 24 chars and starts with a letter.
- `enable_rbac_authorization = true` *and* there is a role assignment for your own `object_id` — these two go together; one without the other is a misconfiguration.
- `public_network_access_enabled = true` (not false) given you're using `ip_rules` — otherwise the ACL is silently ignored.
- The PE's `subresource_names` is exactly `["vault"]` and the `private_dns_zone_ids` points at `azurerm_private_dns_zone.zones["kv"]`, not one of the other three zones.
- Resource counts: 1 random_string + 1 key_vault + 1 role_assignment + 1 private_endpoint = **4 to add** (the `data` source doesn't appear in the plan's add count). `terraform plan` should print "Plan: 4 to add, 0 to change, 0 to destroy."

## Decisions Brian made

_(Chosen and reflected in the `keyvault.tf` draft. File still has open fixes — see Review status below.)_

- [D1] RG placement = **`app`** (`rg-lifestack-app-prod`)
- [D2] SKU = **standard**
- [D3] Authorization model = **RBAC** (`enable_rbac_authorization = true`) + deployer role assignment (`Key Vault Secrets Officer`)
- [D4] Network access model = **public-with-firewall + PE** (`default_action = "Deny"`, `bypass = "AzureServices"`, allow deployer IP `/32`, plus private endpoint)
- [D5] Purge protection / retention = **off**, `soft_delete_retention_days = 7`

## Review status — RESOLVED & APPLIED (2026-06-28)

**Module 3 is deployed.** `terraform apply` created all 4 resources clean (`Plan: 4 to add` → applied; a later re-apply reported `0 added, 0 changed, 0 destroyed`, confirming state matches config). Live facts:

- Vault: **`kv-lifestack-prod-tx9d`** (random suffix `tx9d`), in `rg-lifestack-app-prod`.
- Private endpoint `pe-kv-lifestack-prod` got private IP **`10.0.2.4`** (inside `snet-pe`, 10.0.2.0/27); the A record `kv-lifestack-prod-tx9d.privatelink.vaultcore.azure.net → 10.0.2.4` was auto-created in the `privatelink.vaultcore.azure.net` zone by the `private_dns_zone_group`. PE wiring verified end-to-end via `terraform state show`.
- Deployer role assignment (`Key Vault Secrets Officer`, principal `be7eec0a…`) present.

**Verification note:** from a host *outside* the VNet (e.g. the WSL dev box), `nslookup` of the vault FQDN returns a **public** IP, not `10.0.2.4` — the private DNS zone is only authoritative inside the VNet. Confirm the private IP via `terraform state show azurerm_private_endpoint.kv` (or from an in-VNet host at Module 7), not via `nslookup` from the laptop.

**All review items below were fixed before apply (kept as the historical record). Two extra fixes surfaced during `terraform validate` and were also applied:**

- **tfvars mismatch:** `terraform.tfvars` still set an empty `home_ip`, but the config reads `var.deployer_ip`. Renamed the key to `deployer_ip` and set it to the current public IP `99.233.21.112` (bare IP; `/32` appended in config).
- **Deprecation:** `enable_rbac_authorization` is deprecated (renamed to `rbac_authorization_enabled`, removed in azurerm v5.0). Switched to the new name; `validate` is now warning-free.

---

### Original review (2026-06-21) — items now resolved

`keyvault.tf` was drafted and reviewed. Decisions above are correct. These items were open at review time and have since been fixed:

**Blockers (would fail `validate`/`plan`):**

1. **Private endpoint is missing both nested blocks.** Only `name`/`location`/`resource_group_name`/`subnet_id` are present. Add:
   - `private_service_connection` (required block, else validate fails): `name` (e.g. `psc-kv`), `private_connection_resource_id = azurerm_key_vault.main.id`, `subresource_names = ["vault"]`, `is_manual_connection = false`.
   - `private_dns_zone_group`: `name` (e.g. `pdzg-kv`), `private_dns_zone_ids = [azurerm_private_dns_zone.zones["kv"].id]`.
2. **`ip_rules = [${var.home_ip}]`** is broken three ways: variable is named **`deployer_ip`** (not `home_ip`); `${...}` can't sit unquoted in the list (interpolation only inside a string); and the `/32` must be appended per the variable's contract → make it a one-element list of the `deployer_ip` value interpolated into a string with `/32`. (If apply later rejects `/32` on the ACL, retry with the bare IP.)
3. **`sku_name = "Standard"`** → lowercase **`"standard"`** (provider validation is case-sensitive here).

**Should-fix (not fatal):**

4. `public_network_access_enabled` is omitted — defaults to `true` so the ACL still works, but [D4] called for setting it explicitly. Add `= true`.
5. Private endpoint has no `tags` — add `local.base_tags` for consistency with every other resource.
6. Run `terraform fmt` — the draft is 4-space indented; fmt normalizes to 2-space + aligns `=`.

**Already correct:** client_config data source; `random_string.kv_suffix` (uses `numeric`, not deprecated `number`); vault name length (22 ≤ 24, starts with a letter); RG=`app`; RBAC + deployer role assignment present together; role assignment scope/role/principal; `network_acls` default_action/bypass; `subnet_id = azurerm_subnet.pe.id`.
