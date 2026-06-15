 What it is — One paragraph: the VNet is the private L3 boundary for the whole prod stack; everything (ACA, Postgres, private endpoints) lives inside it. Position it as the tier all other modules attach to.
- We created the Layer 3 boundary for the entire tech stack. All the services will reside inside this network. We divided the network into different subnets for each service. 

We created the L3 

  Why we use it — Why a custom VNet at all vs. letting services sit on public networking: you want private-only data plane (Postgres + PEs never exposed publicly), NSG control, and private DNS resolution. Tie it to the
  security-must-haves posture.

  We use a vnet as we don't want our services to be reachable over the public internet. For security purposes, private DNS resolution, NSG, private endpoints, db (Postgres). 

  How it's configured here — The meat. Hit each:
  - VNet 10.0.0.0/16 and the addressing plan.
  - The 3 subnets, their CIDRs, and purpose: aca (/24, delegated to Microsoft.App/environments), pg (/28, delegated to Microsoft.DBforPostgreSQL/flexibleServers), pe (/27, private_endpoint_network_policies = 
  "Disabled").
  - Why two subnets are delegated and what delegation actually does (hands the subnet to the service's control plane; you can't put arbitrary resources there).
  - 3 NSGs, one per subnet, currently default rules — note they're placeholders for later modules.
  - 4 private DNS zones + their VNet links, and the names (privatelink.postgres…, .azurecr.io, .blob…, .vaultcore…) — i.e. which future service each zone serves.
  - File location: infra/environments/prod/network.tf, with the DNS-zone map in locals.tf.

- network is configured over address range 10.0.0.0/16. 
- 1 subnet for aca = /24. We delegated the subnet to Microsoft.App/environments
- 1 subnet for pg = /28. We delegated the subnet to Microsft.DBforPostgreSQL/flexibleServers 
- 1 subnet for pe = /27. We set private_endpoint_network_policies = "Disabled"
- Delegations are used to give the subnet to the service's control plane. Can't add resources there ourselves. 
- We created 4 private DNS zones and Vnet links for the future service that they will serve. 
- all files stored in infra/environments/prod/network.tf. DNS-zone maps in locals.tf 

  Mental model — The 2-3 things to hold in your head. Suggest: (1) VNet = address space, subnets = carved segments with a job; (2) delegation vs. NSG vs. private DNS are three independent concerns layered on a subnet;
  (3) a private DNS zone is inert until linked to the VNet.



  Alternatives considered — Flat single-subnet vs. per-tier subnets (you chose per-tier for blast-radius/NSG granularity); Azure-managed VNet integration for some services vs. your own explicit VNet; public networking +
  firewall rules vs. private endpoints.

  Common operations — Adding a subnet later, resizing (and the gotcha that in-use delegated subnets can't be resized — pull this from the changelog), adding NSG rules in later modules, adding a new private DNS zone when
  a new PE-backed service arrives.

  Gotchas — The good ones, several you already hit: DNS zone does nothing without the VNet link; private_endpoint_network_policies = "Disabled" means the PE-subnet NSG is currently inert; delegated subnets reject
  non-delegated resources; Azure reserves 5 IPs per subnet (the 16 − 5 = 11 math).

  Cost characteristics — Short and honest: VNet, subnets, NSGs, and private DNS zones are effectively free; cost shows up later with private endpoints (~per-endpoint/hr + data processing) and any future VNet
  peering/gateways. Note nothing in this module bills meaningfully.

  Authoritative docs — Links: azurerm virtual_network, subnet, network_security_group, private_dns_zone, private_dns_zone_virtual_network_link provider pages, plus the Azure "private endpoint DNS" concepts doc.