resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.project}-${local.environment}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_names["network"].name
  address_space       = ["10.0.0.0/16"]
  tags                = local.base_tags
}


#subnets
resource "azurerm_subnet" "aca" {
  name                 = "snet-${local.project}-aca-${local.environment}"
  resource_group_name  = azurerm_resource_group.rg_names["network"].name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]

  delegation {
    name = "aca"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "pg" {
  name                 = "snet-${local.project}-pg-${local.environment}"
  resource_group_name  = azurerm_resource_group.rg_names["network"].name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/28"]

  delegation {
    name = "pg"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "pe" {
  name                              = "snet-${local.project}-pe-${local.environment}"
  resource_group_name               = azurerm_resource_group.rg_names["network"].name
  virtual_network_name              = azurerm_virtual_network.main.name
  address_prefixes                  = ["10.0.2.0/27"]
  private_endpoint_network_policies = "Disabled"
}


#NSGs
resource "azurerm_network_security_group" "aca" {
  name                = "nsg-${local.project}-aca-${local.environment}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_names["network"].name
  tags                = local.base_tags
}

resource "azurerm_network_security_group" "pg" {
  name                = "nsg-${local.project}-pg-${local.environment}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_names["network"].name
  tags                = local.base_tags
}

resource "azurerm_network_security_group" "pe" {
  name                = "nsg-${local.project}-pe-${local.environment}"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg_names["network"].name
  tags                = local.base_tags
}

#NSG-subnet associations
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

#DNS Zones for PE 
resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.rg_names["network"].name
  tags                = local.base_tags

}


resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.private_dns_zones
  name                  = "${each.key}-vnet-link"
  resource_group_name   = azurerm_resource_group.rg_names["network"].name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = local.base_tags
}