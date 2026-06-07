
locals {
  project = "lifestack"

  environment = "prod"

  location = "eastus2"

  base_tags = {
    project     = local.project
    environment = local.environment
    managed_by  = "terraform"
  }

  rg_names = {
    network       = "rg-${local.project}-network-${local.environment}"
    data          = "rg-${local.project}-data-${local.environment}"
    app           = "rg-${local.project}-app-${local.environment}"
    observability = "rg-${local.project}-observability-${local.environment}"
  }

  private_dns_zones = {
    pg   = "privatelink.postgres.database.azure.com"
    acr  = "privatelink.azurecr.io"
    blob = "privatelink.blob.core.windows.net"
    kv   = "privatelink.vaultcore.azure.net"
  }
}
