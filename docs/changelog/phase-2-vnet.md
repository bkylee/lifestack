Commit: ba2f700 (corrected layer)

What was built: 

We built the network layer terraform that created the VNet, 3 subnets, 3 NSGs, subnet association, NSG associations and 4 DNS zones. These are added to the rg-lifestack-network-prod resource group 

Decisions: 

CIDR: 

vnet = 10.0.0.0/16. Standard IP range used. Grants a lot of IPs and avoids the generic home IP address range of 192.168.x.x for potential clashes with home networks when using VPN. 

ACA = 10.0.0.0/24. Generous size as mentor mentioned that IPs get burned through quickly 
PG = 10.0.1.0/28. We added an extra bit for hosts (16 - 5 = 11 hosts) for later potential use of HA redundancy without having to recreate the subnet. Subnets in use cannot be resized, so it's safer to have more bits allocated for hosts now. 
PE = 10.0.2.0/27. headroom for the planned private endpoints 

4 private DNS zones -> vnet links = dns zones need to be linked to a VNET or resources in the vnet won't resolve the private endpoints. 

config choices: 
- subnet delegation for ACA and PG
- created DNS zones for later deployment as they are free to generate and no need to edit network.tf later 
- NSGs have default rules, to be edited in later modules 
- private_endpoint_network_policies = "Disabled" is used on the PE subnet. It disabled NSG/UDR enforcement for private endpoints in the subnet. We may enable it later when we write real PE rules.

moved-block 
- renamed terraform logical address destroys and recreated the resource by default. We migrated the NSG associations in state with 0 Azure churn. 

What was verified: 
plan + apply was clean. 