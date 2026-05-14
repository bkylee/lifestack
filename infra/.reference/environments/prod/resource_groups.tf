# Five RGs total in this subscription, but only four are managed by Terraform.
# The fifth (rg-lifestack-tfstate) was bootstrapped via az CLI before Terraform
# existed and lives outside the Terraform-managed estate by design.

resource "azurerm_resource_group" "network" {
  name     = local.rg_names.network
  location = var.location
  tags     = local.base_tags
}

resource "azurerm_resource_group" "data" {
  name     = local.rg_names.data
  location = var.location
  tags     = local.base_tags
}

resource "azurerm_resource_group" "app" {
  name     = local.rg_names.app
  location = var.location
  tags     = local.base_tags
}

resource "azurerm_resource_group" "observability" {
  name     = local.rg_names.observability
  location = var.location
  tags     = local.base_tags
}
