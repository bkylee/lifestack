output "vnet_id" {
  value       = azurerm_virtual_network.main.id
  description = "Virtual network resource ID."
}

output "vnet_name" {
  value       = azurerm_virtual_network.main.name
  description = "Virtual network name."
}

output "subnet_aca_id" {
  value       = azurerm_subnet.aca.id
  description = "Container Apps subnet resource ID (delegated to Microsoft.App/environments)."
}

output "subnet_pg_id" {
  value       = azurerm_subnet.pg.id
  description = "Postgres subnet resource ID (delegated to Microsoft.DBforPostgreSQL/flexibleServers)."
}

output "subnet_pe_id" {
  value       = azurerm_subnet.pe.id
  description = "Private endpoints subnet resource ID."
}

output "private_dns_zone_ids" {
  value       = { for k, z in azurerm_private_dns_zone.zones : k => z.id }
  description = "Map of short zone alias (postgres/acr/blob/kv) to the privatelink DNS zone resource ID. Consumed by downstream modules when wiring private endpoints."
}

output "private_dns_zone_names" {
  value       = { for k, z in azurerm_private_dns_zone.zones : k => z.name }
  description = "Map of short zone alias to the actual privatelink FQDN. Useful for ad-hoc lookup; downstream modules typically take the ID."
}
