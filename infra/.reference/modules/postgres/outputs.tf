output "server_id" {
  value       = azurerm_postgresql_flexible_server.main.id
  description = "Postgres Flex server resource ID."
}

output "server_name" {
  value       = azurerm_postgresql_flexible_server.main.name
  description = "Postgres Flex server name."
}

output "fqdn" {
  value       = azurerm_postgresql_flexible_server.main.fqdn
  description = "Server FQDN. Resolves via the linked privatelink DNS zone to the server's private IP inside the VNet."
}

output "database_name" {
  value       = azurerm_postgresql_flexible_server_database.app.name
  description = "Name of the application database."
}

output "admin_username" {
  value       = azurerm_postgresql_flexible_server.main.administrator_login
  description = "Server admin username."
}

output "admin_password" {
  value       = random_password.admin.result
  sensitive   = true
  description = "Server admin password. Migrated to Key Vault in a later step for app consumption via managed identity."
}

output "connection_string" {
  value       = "postgresql://${var.admin_username}:${random_password.admin.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.database_name}?sslmode=require"
  sensitive   = true
  description = "Full Postgres connection string with credentials. For app/Prisma consumption from inside the VNet."
}
