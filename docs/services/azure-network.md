 What it is 
- We created the Layer 3 boundary for the entire tech stack. All the services will reside inside this network. We divided the network into different subnets for each service. 

  Why we use it 
- We use a vnet as we don't want our services to be reachable over the public internet. For security purposes, private DNS resolution, NSG, private endpoints, db (Postgres). 


  How it's configured here 
- network is configured over address range 10.0.0.0/16. 
- 1 subnet for aca = /24. We delegated the subnet to Microsoft.App/environments
- 1 subnet for pg = /28. We delegated the subnet to Microsoft.DBforPostgreSQL/flexibleServers 
- 1 subnet for pe = /27. We set private_endpoint_network_policies = "Disabled"
- Delegations are used to give the subnet to the service's control plane. Can't add resources there ourselves. 
- 3 NSGs, one per subnet (aca, pg, pe), each bound to its subnet via a subnet-NSG association. Default rules only for now — placeholders for rules we add in later modules. 
- We created 4 private DNS zones and Vnet links for the future service that they will serve. 
- all files stored in infra/environments/prod/network.tf. DNS-zone maps in locals.tf 

  Mental model — 

- 1 = vnet address space and subnets. 
- 2 = delegation, NSG, and private DNS are three independent concerns layered on the same subnet — not the same thing 
- 3 = private DNS zone needs to be linked to the vnet 


  Alternatives considered 
- flat single subnet. Having tiered subnets reduces blast-radius and increases NSG granularity. Private Endpoints allows us to not have to configure firewall rules for each service that we add 
- azure-managed vnet integration vs explicit vnet. If we don't specify our own network for services like Azure Container Apps, Microsoft will create a private internal network to manage the service for us. We created our own vnet, subnets, delegations, NSGs, DNS, and then handed the subnet over to the service to use instead. ACA and Postgres require these delegations or else implicit networking is done. 
- This explicit network allows us to have a private L3 boundary for all services to be connected to. The cost is that we manage subnets, delegations, NSGs, zones, links via the network.tf file. If not, services can be publicly available. 
- Public + FW = keeps services public and grants access using the access list in the FW. Cheap solution but potential attack surface and requires maintaining the allowlist 
- PE = Azure creates a private NIC for services into our subnets. This allows us to remove public access. We then use name resolution through privatelink private DNS zones 

  Common operations 
- Creating subnets and resizing subnets (not for delegated subnets). 
- Add NSG rules later modules 
- New private DNS zones when new PE-backed services are deployed 

  Gotchas 
- DNS zones aren't functional without Vnet links
- private_endpoint_network_policies = "Disabled" = PE subnet NSG is inactive. 
- Delegated subnets are dedicated for delegated services only. Cannot add any resources to the subnet. 
- Azure reserves 5 IPs per subnet (ex. 16 - 5 = 11)
- snet-aca is /24. ACA enforces a minimum subnet size that differs by environment type — workload profiles needs /27, consumption-only needs /23. Our /24 satisfies workload profiles but not consumption-only; confirm the floor against current docs when we pick the ACA environment type in Module 7.

  Cost characteristics — 
- All services we created in this terraform file are currently not incurring costs. Later when PE are processing traffic and gateways are used will costs incur. 

  Authoritative docs
- [azurerm_virtual_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
- [azurerm_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)
- [azurerm_subnet_network_security_group_association](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association)
- [azurerm_network_security_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
- [azurerm_private_dns_zone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone)
- [azurerm_private_dns_zone_virtual_network_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link)
- [Azure Private Endpoint DNS configuration](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)