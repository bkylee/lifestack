resource "azurerm_resource_group" "rg_names" {
  for_each = local.rg_names
  name     = each.value
  location = local.location
  tags = local.base_tags
}