# Module 2, Step 1 — network

**File you will write:** `infra/environments/prod/network.tf` (from scratch, using the provider docs)
**Decisions in this step:** [D1] VNet CIDR, [D2] ACA subnet prefix, [D3] PG subnet prefix, [D4] PE subnet prefix.

---

## What we're building this module

The private network that everything else sits inside: one VNet, three subnets (Container Apps, Postgres, Private Endpoints), an NSG per subnet, four private DNS zones, and VNet links for each zone. After this module, the Azure subscription has a complete network layer — no resources deployed into it yet, but the plumbing is ready for Modules 3–8.

## Why this comes before everything else

Every later module will reference outputs from this one: subnet IDs for Container Apps and Postgres, the VNet ID for Key Vault private endpoints, the DNS zone names for ACR and Blob. Build the network once, reference it everywhere. Build it last and you're retrofitting.

---

## What doesn't need a decision (already settled)

**Subnet names** use the `snet-{project}-{tier}-{env}` pattern, consistent with how RGs were named. CAF abbreviation for subnet is `snet`.

**NSG strategy** — default Azure rules only for now, one NSG per subnet. Tier-specific rules (e.g. allow port 5432 inbound to the PG subnet from the ACA subnet only) are added in the module that deploys that tier's resources. Reason: we don't know the exact IP ranges or service tags we need yet, and an NSG with wrong rules is worse than an NSG with defaults. The association is wired now; rules are filled in later.

**Private DNS zones** — all four created now (postgres, acr, blob, keyvault), even though only postgres is deployed this phase. Reason: private DNS zones are free, and creating them all now means Modules 4–8 don't need to touch `network.tf` again just to add a zone. If we created them one-at-a-time, we'd be running `terraform apply` on network.tf in every module — unnecessary churn.

**Delegation on ACA and PG subnets** — not optional. Container Apps in workload-profiles mode and Postgres Flexible Server with VNet integration both require subnet delegation to their respective service principals. You cannot remove delegation after resources are deployed.

**`private_endpoint_network_policies = "Disabled"` on the PE subnet** — not optional. Azure requires this for PE NICs to function. The setting name is misleading (sounds like it disables security); what it actually disables is the UDR/NSG enforcement on the PE's NIC specifically, while leaving the subnet-level NSG intact for everything else.

---

## Decisions

### [D1] VNet address space

- **Textbook:** "Size your VNet large enough to accommodate future growth."
- **Production reality:** Once a VNet is created, you cannot change the primary address space without deleting and recreating it (you can *add* secondary CIDR blocks, but it's messy). Pick once, pick generously. The RFC 1918 private ranges are your options: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- **Common patterns:**
  - `10.0.0.0/16` — 65,534 usable IPs, enough for dozens of subnets, clean to read. The go-to for a single-VNet application.
  - `10.0.0.0/8` — overkill for one project; reserved for hub-and-spoke with many peered VNets.
  - `192.168.x.x` — fine technically, but conflicts with home/office router defaults, which matters if you ever set up VPN-based dev access.
- **Recommendation:** **`10.0.0.0/16`**. One VNet, plenty of room, no conflicts. We'll only use a tiny fraction of it but the rest costs nothing.

### [D2] Container Apps (ACA) subnet prefix

- **Textbook:** "Each subnet needs enough IPs for its workloads."
- **Production reality:** Container Apps in **workload-profiles mode** (what we're using) has a hard minimum of **/27** (32 IPs). Azure docs recommend /23 (2048 IPs) for production — Container Apps consumes IPs faster than expected because each replica and each internal load balancer takes one, plus Azure reserves several for infrastructure.
  - **/27** — bare minimum, will hit limits quickly if you scale or run multiple revisions.
  - **/24** — 256 IPs, comfortable for a small app running 2–5 replicas, leaves room to grow.
  - **/23** — Microsoft's production recommendation. Overkill for a solo project.
- **Recommendation:** **`10.0.0.0/24`**. 256 IPs is well more than enough for our scale.

### [D3] Postgres Flexible Server subnet prefix

- **Textbook:** "Postgres Flexible Server with VNet integration requires a dedicated delegated subnet."
- **Production reality:** Minimum is **/29** (8 IPs, 3 usable after Azure reserves 5). Practical minimum is **/28** (16 IPs) because HA mode — even if not enabled now — requires additional IPs for the standby. We're on B1ms, no HA in v1, but leave room.
  - **/29** — too tight. Works today but you can't enable HA later without recreating the subnet.
  - **/28** — 16 IPs, fits a single instance plus a future HA standby. Right-sized for v1 with a known upgrade path.
  - **/27** — unnecessary unless you're planning multiple PG instances.
- **Recommendation:** **`10.0.1.0/28`**. Fits our one instance with room for HA if we ever enable it.

### [D4] Private endpoints subnet prefix

- **Textbook:** "Private endpoints each consume one IP from their subnet."
- **Production reality:** We're planning four PEs (postgres, acr, blob, keyvault). Each PE takes one IP, plus Azure reserves a few. A /28 (16 IPs) covers our four PEs with headroom. If we add more services with PEs later (Service Bus, Event Hub), we'd want a bit more room.
  - **/29** — too tight for four PEs plus Azure reserves.
  - **/28** — 16 IPs, handles our four planned PEs and a few more.
  - **/27** — 32 IPs, room for any likely expansion.
- **Recommendation:** **`10.0.2.0/27`**. A bit more than /28 to avoid an awkward "the PE subnet is full" moment later.

---

## Resources to write

Write these in `infra/environments/prod/network.tf`, in roughly this order. For each resource, look up the exact argument names in the provider docs (links below) — don't trust memory for argument spelling, the azurerm provider has subtle inconsistencies (`address_space` vs `address_prefixes`, `name` vs `*_name`, etc.).

### 1. The VNet

- **Resource:** `azurerm_virtual_network`
- **Logical name:** `main`
- **Required args:** `name` (use the `vnet-{project}-{env}` pattern), `resource_group_name` (the network RG), `location` (`local.location`), `address_space` (a list — your [D1] CIDR wrapped in `[]`), `tags` (`local.base_tags`).
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network

### 2. Three subnets

- **Resource:** `azurerm_subnet`
- **Logical names:** `aca`, `pg`, `pe`
- **Common args** (all three): `name` (`snet-{project}-{tier}-{env}`), `resource_group_name`, `virtual_network_name` (reference the VNet by `.name`), `address_prefixes` (list).
- **`aca` only:** a `delegation` block with `name = "aca"` and a `service_delegation` block inside it:
  - `name = "Microsoft.App/environments"`
  - `actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]`
- **`pg` only:** same shape, with:
  - `name = "Microsoft.DBforPostgreSQL/flexibleServers"`
  - `actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]`
- **`pe` only:** `private_endpoint_network_policies = "Disabled"` (string, not bool — this argument was renamed in azurerm v4; older examples on the internet use `enforce_private_link_endpoint_network_policies` which is deprecated).
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet

### 3. Three NSGs

- **Resource:** `azurerm_network_security_group`
- **Logical names:** `aca`, `pg`, `pe`
- **Args:** `name` (`nsg-{project}-{tier}-{env}`), `resource_group_name`, `location`, `tags`. No `security_rule` blocks — defaults only for now.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group

### 4. Three NSG–subnet associations

- **Resource:** `azurerm_subnet_network_security_group_association`
- **Logical names:** `aca`, `pg`, `pe`
- **Args:** `subnet_id` (reference the subnet's `.id`), `network_security_group_id` (reference the NSG's `.id`).
- **Why a separate resource:** Azure models the association as its own object so the NSG and subnet can be created and destroyed independently. Don't put the NSG ID directly inside the subnet resource — it's a deprecated pattern that causes drift.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association

### 5. A `locals` block for the DNS zone names

- A map keyed by short alias (`postgres`, `acr`, `blob`, `kv`) → Microsoft's privatelink FQDN. The FQDNs:
  - `privatelink.postgres.database.azure.com`
  - `privatelink.azurecr.io`
  - `privatelink.blob.core.windows.net`
  - `privatelink.vaultcore.azure.net`
- These FQDNs are Microsoft-defined; you cannot change them. Wrong FQDN = DNS resolution silently breaks.

### 6. Private DNS zones (one resource block, `for_each` over the map)

- **Resource:** `azurerm_private_dns_zone`
- **Logical name:** `zones`
- **Args:** `for_each = local.private_dns_zones`, `name = each.value`, `resource_group_name`, `tags`.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone

### 7. VNet links for each zone (one resource block, `for_each`)

- **Resource:** `azurerm_private_dns_zone_virtual_network_link`
- **Logical name:** `links`
- **Args:** `for_each = local.private_dns_zones`, `name = "${each.key}-vnet-link"`, `resource_group_name`, `private_dns_zone_name` (reference the zone by `each.key` into the `azurerm_private_dns_zone.zones` map), `virtual_network_id` (the VNet's `.id`), `tags`.
- **Why this is critical:** the private DNS zone exists in Azure as a global resource; the VNet link is what makes resources *inside the VNet* resolve those zone FQDNs to the private endpoint IPs. Forget the link and DNS resolves to the public IP — defeating the entire point of private endpoints.
- **Doc:** https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link

---

---

## Deep dive: subnet delegation

The `delegation` block on the ACA and PG subnets is the kind of concept the textbook version doesn't really explain. Worth understanding properly because the same pattern shows up on many PaaS services (Container Instances, App Service VNet integration, NetApp Files, etc.).

### The conceptual problem it solves

Normally, you control everything in your subnet. You decide what NICs go in it, what NSG rules apply.

But Azure PaaS services like Container Apps and Postgres Flexible Server need to deploy **their own infrastructure** into your subnet — internal load balancers, NICs, routing rules — so they can offer their service from inside your VNet. For Microsoft to do that without breaking the "you own the network" model, you have to explicitly grant them permission to make changes in that subnet.

**Delegation is that permission grant.** When you delegate a subnet to `Microsoft.App/environments`, you're saying "I authorize the Container Apps service to deploy and modify resources here."

### What follows from that

- **A delegated subnet is single-purpose.** Once delegated to `Microsoft.DBforPostgreSQL/flexibleServers`, you cannot also use it for Container Apps, VMs, or anything else. That's why we have separate subnets per service — the delegation locks the subnet to one consumer.
- **You cannot un-delegate easily.** If you've deployed resources into a delegated subnet, you have to remove the resources first, then remove the delegation. Some delegations cannot be removed at all without recreating the subnet.
- **Delegation is enforced at create-time.** If you forget the delegation block and try to deploy Container Apps into the subnet, the ACA deployment fails with a confusing error. Adding delegation after-the-fact sometimes works and often doesn't.

### The structure of the block

The block has two levels: an outer `delegation` block (with a label) and an inner `service_delegation` block (with the actual Azure identifiers).

- **`delegation.name`** — A label *you* pick (we use `"aca"` and `"pg"`). Azure stores it but does not act on it. Don't agonize over it.
- **`service_delegation.name`** — The actual identifier Azure cares about. The namespace of the service you're granting permission to. Spelling matters:
  - `Microsoft.App/environments` — Container Apps
  - `Microsoft.DBforPostgreSQL/flexibleServers` — Postgres Flexible Server
  - `Microsoft.ContainerInstance/containerGroups` — Container Instances
  - `Microsoft.Web/serverFarms` — App Service VNet integration
- **`service_delegation.actions`** — The specific Azure RBAC actions Microsoft is allowed to perform. For both ACA and PG we use `["Microsoft.Network/virtualNetworks/subnets/join/action"]` — "join resources to this subnet." This is the standard action for almost every PaaS-service delegation; the service uses this permission to attach its internal endpoints.

### Why the PE subnet does NOT need delegation

This trips people up. Private endpoints look superficially like the same pattern (a NIC sitting in your subnet, owned by a service), but they are the **inverse**:

- **Delegated subnet:** *Microsoft deploys into your subnet*. You are hosting them.
- **PE subnet:** *You deploy a NIC that connects out to Microsoft's service*. They are hosting it.

Because PEs are NICs that *you own* (they just happen to forward traffic to a Microsoft-hosted service), there is nothing for Microsoft to deploy into your subnet — so no permission grant is required. Instead, the PE subnet uses `private_endpoint_network_policies = "Disabled"` because Azure historically applied NSGs to PE NICs in a way that broke things, and the "disabled" setting tells Azure to skip that broken behavior. The naming is awful — it sounds like "no network policies," but it really means "no broken legacy NSG enforcement specifically on PE NICs." Subnet-level NSGs still apply normally to other resources in the subnet.

### Where to verify when adding a new PaaS service later

When you later add a service that needs its own subnet (e.g. Service Bus Premium, NetApp Files, Azure Bastion), check the Microsoft docs for that service:

- Search "Microsoft Learn: subnet delegation for <service>"
- Or check the `Microsoft.Network/virtualNetworks/subnets/availableDelegations` API for the full list of services that support (or require) delegation in your subscription.

---

## What to do

1. Open the Terraform provider docs (links above) in a side tab. Reference them as you write.
2. Write `infra/environments/prod/network.tf` from scratch. Type every resource, every argument. The keystroke reps are the point.
3. Fill in [D1]–[D4] with your chosen CIDR values.
4. Run `terraform fmt` from the prod dir. If it reformats anything, read the diff — that's a hint about whitespace/argument-alignment conventions you'll absorb.
5. **Do not run `terraform plan` yet.** Send the file back for review first.

## Sanity-check before review

- All subnet prefixes are subsets of the VNet prefix (e.g. all start with `10.0.` if your VNet is `10.0.0.0/16`).
- No two subnet prefixes overlap.
- Resource counts: 1 VNet + 3 subnets + 3 NSGs + 3 NSG associations + 4 DNS zones + 4 VNet links = **18 resources**. `terraform plan` should show "18 to add" when you run it.

## Decisions Brian made

_(Fill this in after committing.)_

- [D1]
- [D2]
- [D3]
- [D4]
