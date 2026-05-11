module "acr" {
  source = "../../modules/acr"

  resource_group_name = azurerm_resource_group.app.name
  location            = var.location
  tags                = local.base_tags

  # ACR names are alphanumeric-only and globally unique. The random suffix
  # from random_string.suffix provides global uniqueness across the azurecr.io
  # namespace.
  name = "cr${var.project}${random_string.suffix.result}"

  # Basic = $5/mo, 10 GB included. Sized for v1's ~10 image versions × ~400 MB.
  # Trigger to escalate: Private Endpoint requirement (Premium), or storage > 10 GB.
  sku = "Basic"
}
