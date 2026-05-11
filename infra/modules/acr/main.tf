resource "azurerm_container_registry" "main" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku = var.sku

  # No admin user — all auth via AAD/managed identity. The admin user is a
  # shared password that bypasses RBAC; modern best practice is to disable it.
  admin_enabled = false

  # Every pull requires AAD auth. Default is false, but explicit for clarity.
  anonymous_pull_enabled = false

  # Basic SKU is public-only — no Private Endpoint support. Premium would
  # enable network isolation; deferred to v2. ADR-0010 captures the trade.
  public_network_access_enabled = true

  tags = var.tags
}
