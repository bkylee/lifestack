resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Container Apps subnet — workload-profiles env requires delegation to Microsoft.App
resource "azurerm_subnet" "aca" {
  name                 = var.subnet_aca_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_aca_prefix]

  delegation {
    name = "aca"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Postgres Flex subnet — VNet integration requires delegation to Microsoft.DBforPostgreSQL
resource "azurerm_subnet" "pg" {
  name                 = var.subnet_pg_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_pg_prefix]

  delegation {
    name = "pg"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Private endpoints subnet — Azure requires PE network policies disabled so PE NICs work
resource "azurerm_subnet" "pe" {
  name                              = var.subnet_pe_name
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = [var.subnet_pe_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Placeholder NSGs — default Azure rules only (AllowVnetInBound, DenyAllInBound, etc).
# Tier-specific rules are added in the step that provisions resources of that tier.
resource "azurerm_network_security_group" "aca" {
  name                = var.nsg_aca_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_group" "pg" {
  name                = var.nsg_pg_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_group" "pe" {
  name                = var.nsg_pe_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aca" {
  subnet_id                 = azurerm_subnet.aca.id
  network_security_group_id = azurerm_network_security_group.aca.id
}

resource "azurerm_subnet_network_security_group_association" "pg" {
  subnet_id                 = azurerm_subnet.pg.id
  network_security_group_id = azurerm_network_security_group.pg.id
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

# Private DNS zones — keyed by short alias for ergonomic outputs.
# Names themselves are Microsoft-defined privatelink FQDNs; can't be customized.
locals {
  private_dns_zones = {
    postgres = "privatelink.postgres.database.azure.com"
    acr      = "privatelink.azurecr.io"
    blob     = "privatelink.blob.core.windows.net"
    kv       = "privatelink.vaultcore.azure.net"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link each zone to the VNet so resources inside the VNet resolve privatelink names
# to the private endpoint IP, not the public service IP
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.private_dns_zones
  name                  = "${each.key}-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = var.tags
}
