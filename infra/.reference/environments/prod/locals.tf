locals {
  base_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }

  # Naming convention from docs/services/terraform.md.
  # Per "split-tier RG" decision: one resource group per architectural concern.
  rg_names = {
    network       = "rg-${var.project}-network-${var.environment}"
    data          = "rg-${var.project}-data-${var.environment}"
    app           = "rg-${var.project}-app-${var.environment}"
    observability = "rg-${var.project}-observability-${var.environment}"
  }

  network_names = {
    vnet       = "vnet-${var.project}-${var.environment}"
    subnet_aca = "snet-aca-${var.environment}"
    subnet_pg  = "snet-pg-${var.environment}"
    subnet_pe  = "snet-pe-${var.environment}"
    nsg_aca    = "nsg-aca-${var.environment}"
    nsg_pg     = "nsg-pg-${var.environment}"
    nsg_pe     = "nsg-pe-${var.environment}"
  }
}
