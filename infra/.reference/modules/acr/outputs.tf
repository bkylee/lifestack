output "id" {
  value       = azurerm_container_registry.main.id
  description = "Registry resource ID. Needed when granting AcrPull to a managed identity in a later step."
}

output "name" {
  value       = azurerm_container_registry.main.name
  description = "Registry name (without the .azurecr.io suffix)."
}

output "login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "Registry FQDN — <name>.azurecr.io. Used as the image prefix in container references (e.g., crlifestack....azurecr.io/lifestack-web:latest)."
}
