terraform {
  backend "azurerm" {
    resource_group_name  = "rg-lifestack-tfstate"
    storage_account_name = "stlifestack9k3l"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
    use_azuread_auth     = true
  }
}
