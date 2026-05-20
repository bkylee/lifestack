
locals {
  project = "lifestack"

  environment = "staging"

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
}
