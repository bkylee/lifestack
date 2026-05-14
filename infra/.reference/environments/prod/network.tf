module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.network.name
  location            = var.location
  tags                = local.base_tags

  vnet_name       = local.network_names.vnet
  subnet_aca_name = local.network_names.subnet_aca
  subnet_pg_name  = local.network_names.subnet_pg
  subnet_pe_name  = local.network_names.subnet_pe
  nsg_aca_name    = local.network_names.nsg_aca
  nsg_pg_name     = local.network_names.nsg_pg
  nsg_pe_name     = local.network_names.nsg_pe
}
