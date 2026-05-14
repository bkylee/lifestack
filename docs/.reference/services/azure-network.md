# Azure Network (VNet, subnets, NSGs, private DNS)

## What it is

The VNet is the private network boundary for the Lifestack v1 architecture. Subnets inside the VNet host application compute (Container Apps), the database (Postgres Flex), and the NICs of private endpoints connecting to public Azure services (ACR, Blob, Key Vault). Private DNS zones linked to the VNet make `*.privatelink.*` FQDNs resolve to private IPs.

## Why we use it

- **Defense in depth.** The data tier (Postgres, Blob upload path, KV) is never reachable from the public internet. Only resources inside the VNet can route to it.
- **Stable identity.** Workloads in the VNet have predictable private IPs and DNS names. The app references `psql-lifestack-prod.privatelink.postgres.database.azure.com` regardless of the public IP behind it.
- **Foundation for future tiers.** v2 / v3 additions (jumphost, AKS, peered region, second env) plug into this VNet without re-architecting.

## How it's configured here

**VNet:** `vnet-lifestack-prod`, address space `10.10.0.0/16`, region `eastus2`, in `rg-lifestack-network-prod`.

**Subnets:**

| Name | CIDR | Purpose | Delegation | NSG |
|---|---|---|---|---|
| `snet-aca-prod` | `10.10.0.0/23` | Container Apps env (workload profiles) | `Microsoft.App/environments` | `nsg-aca-prod` |
| `snet-pg-prod` | `10.10.2.0/24` | Postgres Flex Server | `Microsoft.DBforPostgreSQL/flexibleServers` | `nsg-pg-prod` |
| `snet-pe-prod` | `10.10.3.0/27` | Private endpoint NICs | (none) | `nsg-pe-prod` |

The two delegated subnets are owned by their service — Azure manages the NICs, IPs, and connectivity. Putting an unrelated resource into a delegated subnet fails.

**Subnet sizing rationale:**

- ACA `/23` — workload-profiles ACA env requires `/23` minimum. 512 addresses; Azure reserves some for control plane.
- PG `/24` — Postgres Flex's stated minimum is `/28`, but `/24` leaves room for future read replicas or burst capacity. Subnet IPs are free; flexibility isn't.
- PE `/27` — 32 addresses; one IP per PE NIC. v1 has 3 PEs (ACR, Blob, KV) → plenty of headroom.

**Address-space rationale.** `10.10.0.0/16` avoids common conflicts:
- `192.168.0.0/16` is the typical home network range.
- `172.17.0.0/16` is the default Docker bridge.
- `10.0.0.0/16` is the canonical Azure quickstart range; reserving against it leaves space for future Lifestack envs to occupy `10.0.x.x` (dev), `10.1.x.x` (staging) and peer cleanly with prod.

**NSGs.** Three placeholder NSGs (`nsg-aca-prod`, `nsg-pg-prod`, `nsg-pe-prod`) attached to each subnet. No custom rules — only Azure's defaults (`AllowVnetInBound` / `AllowAzureLoadBalancerInBound` / `DenyAllInBound` / `AllowVnetOutBound` / `AllowInternetOutBound` / `DenyAllOutBound`). Tier-specific allow rules are added in the step that provisions resources for each tier (e.g., the workload-profiles ACA env requires explicit outbound allows to MCR and other service tags — added in Step 2.6).

**Private DNS zones, in `rg-lifestack-network-prod`, each linked to the VNet:**

| Zone | For | Step that adds the consumer |
|---|---|---|
| `privatelink.postgres.database.azure.com` | Postgres Flex | 2.4 |
| `privatelink.azurecr.io` | ACR | 2.5 |
| `privatelink.blob.core.windows.net` | Blob Storage | 2.7 |
| `privatelink.vaultcore.azure.net` | Key Vault | 2.8 |

Zone names are Microsoft-defined — you can't customize them. Linking each zone to the VNet means anything inside the VNet that resolves the corresponding privatelink FQDN gets the private IP back from the linked PE, not the public service IP.

## Mental model

1. **The VNet is a private network. Public Azure services don't live in it; private endpoints bridge them in.** ACR, Blob, and KV exist on the public Azure backbone; a private endpoint is a NIC in your VNet that proxies to one of those services. Without a PE, traffic to the service goes over the public internet.

2. **DNS is the trick that makes PEs transparent.** Without the linked privatelink zone, `mystorage.blob.core.windows.net` resolves to the public IP and traffic never goes through your PE. Linking the privatelink DNS zone to your VNet inserts CNAME records so the same name resolves to your PE's private IP — but only when queried from inside the VNet.

3. **Subnet delegation transfers control of the subnet to a service.** Once `snet-pg-prod` is delegated to `Microsoft.DBforPostgreSQL/flexibleServers`, only Postgres can put resources there, and Postgres manages NICs/IPs autonomously. Generic VMs / app gateways / etc. are blocked.

## Alternatives considered

**Single flat subnet.** Simpler to think about. Ruled out because subnet delegations are required for both ACA workload profiles and Postgres Flex, and PE NICs need their own subnet with `private_endpoint_network_policies = Disabled` to work reliably. Three subnets is the minimum that respects all the constraints.

**`10.0.0.0/16` instead of `10.10.0.0/16`.** Marginally cheaper to type. Ruled out because it's the canonical sample range and would conflict with future Lifestack envs that want to peer here.

**Shared NSGs across subnets.** Less Terraform code. Ruled out because subnet-specific NSGs is the BP pattern — when a tier needs a rule (e.g., ACA's outbound allow list), you don't want it accidentally applying to the Postgres subnet too.

**No NSGs at all (just default Azure perimeter).** Smallest footprint. Ruled out because empty NSGs cost nothing and let us add rules in any step without a "do I need to also create an NSG?" detour.

## Common operations

```bash
# VNet + subnets summary
az network vnet show --resource-group rg-lifestack-network-prod --name vnet-lifestack-prod \
  --query '{name:name, addressSpace:addressSpace.addressPrefixes, subnets:subnets[].{name:name, prefix:addressPrefix, delegation:delegations[0].serviceName}}' -o json

# List subnets
az network vnet subnet list --resource-group rg-lifestack-network-prod --vnet-name vnet-lifestack-prod -o table

# NSG rules on a subnet
az network nsg show --resource-group rg-lifestack-network-prod --name nsg-aca-prod \
  --query 'securityRules' -o table
az network nsg show --resource-group rg-lifestack-network-prod --name nsg-aca-prod \
  --query 'defaultSecurityRules' -o table

# Private DNS zones + record counts (record sets accumulate as PEs are added)
az network private-dns zone list --resource-group rg-lifestack-network-prod \
  --query '[].{name:name, records:numberOfRecordSets, links:numberOfVirtualNetworkLinks}' -o table

# Show A records in a zone (populated by a PE registration)
az network private-dns record-set a list --resource-group rg-lifestack-network-prod \
  --zone-name privatelink.postgres.database.azure.com -o table

# Test private resolution from a workload inside the VNet (after we have an ACA app)
# nslookup <resource>.privatelink.<service> should return a 10.10.x.x address
```

## Gotchas

- **Subnet delegations can't be changed in place.** If we ever want to change the workload type owning a delegated subnet, the subnet must be deleted and recreated — and every resource in it goes with it. Get delegations right the first time.
- **PE subnet requires `private_endpoint_network_policies = "Disabled"`.** With it enabled, NSG rules apply to PE NICs and tend to break private-link traffic in non-obvious ways. Terraform sets this explicitly.
- **Private DNS zones don't auto-link.** A zone exists in a resource group; it doesn't apply to a VNet until you create the explicit `azurerm_private_dns_zone_virtual_network_link`. Forgetting the link silently makes resolution fall back to public IPs. Test with `nslookup` from inside the VNet before trusting that PEs are working.
- **Address space is hard to shrink.** Adding a new CIDR to a VNet is fine; shrinking or removing one isn't. Pick conservatively up front.
- **Default NSG rules can confuse.** The defaults (`DenyAllInBound`) only block traffic that isn't already covered by a higher-priority allow. Azure displays the default rules separately from custom rules; both apply.

## Cost characteristics

- VNet, subnets, NSGs, NSG rules: **free**
- Private DNS zones: $0.50/zone/month, but the **first 25 zones per subscription are free**. We have 4 → **$0**.
- DNS zone vnet links: free
- DNS query volume: first 1 billion queries/month free
- **Network module total: $0/month.** Cost arrives when downstream modules add Private Endpoints (~$7.30/PE/month) and provision the actual data/app resources.

## Authoritative docs

- https://learn.microsoft.com/en-us/azure/virtual-network/
- https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview
- https://learn.microsoft.com/en-us/azure/dns/private-dns-overview
- https://learn.microsoft.com/en-us/azure/container-apps/networking
- https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-networking
