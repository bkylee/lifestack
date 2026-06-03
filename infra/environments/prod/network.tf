resource "azurerm_virtual_network" "vnet-lifestack-network-prod" {
  name                = "vnet-prod"
  location            = locals.location
  resource_group_name = azurerm_resource_group.rg_names.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet-lifestack-aca-prod" {
  name = "snet-lifestack-aca-prod"
  resource_group_name = azurerm_resource_group.rg_names.["network"]
  virtual_network_name = azurerm_virtual_network.vnet-lifestack-network-prod.name
  address_prefixes = ["10.0.0.0/24"]

  delegation {
    name = "aca"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}


resource "azurerm_subnet" "snet-lifestack-pg-prod" {
  name = "snet-lifestack-pg-prod"
  resource_group_name = azurerm_resource_group.rg_names.["network"]
  virtual_network_name = azurerm_virtual_network.vnet-lifestack-network-prod.name
  address_prefixes = ["10.0.0.1/28"]

  delegation {
    name = "pg"

    service_delegation {
      name = "Microsoft.DBforPostgrSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "snet-lifestack-pe-prod" {
  name = "snet-lifestack-pe-prod"
  resource_group_name = azurerm_resource_group.rg_names.["network"]
  virtual_network_name = azurerm_virtual_network.vnet-lifestack-network-prod.name
  address_prefixes = ["10.0.0.2/27"]
}

