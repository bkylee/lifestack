# Generated server admin password. Persisted in Terraform state (encrypted in the
# state SA), surfaced as a sensitive output, and intended to be copied to Key Vault
# in a later step for app consumption via managed identity.
resource "random_password" "admin" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  version  = var.postgres_version
  sku_name = var.sku_name

  storage_mb = var.storage_mb

  administrator_login    = var.admin_username
  administrator_password = random_password.admin.result

  # VNet integration — Postgres lands a NIC with a private IP in the delegated
  # subnet. The provided private DNS zone gets an A record automatically so
  # the FQDN resolves to the private IP from anywhere in the VNet.
  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = false

  zone = var.availability_zone

  maintenance_window {
    day_of_week  = 0 # Sunday
    start_hour   = 2 # 02:00 UTC
    start_minute = 0
  }

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Server-level extension allowlist. CREATE EXTENSION at the database level still
# required afterward — this just permits which extensions can be loaded.
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = var.extensions_allowlist
}
