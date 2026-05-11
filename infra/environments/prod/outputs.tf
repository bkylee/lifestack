output "resource_group_names" {
  value       = local.rg_names
  description = "Names of the four Terraform-managed resource groups."
}

output "global_unique_suffix" {
  value       = random_string.suffix.result
  description = "4-char suffix appended to globally-unique resource names (storage accounts, ACR, Key Vault, Front Door)."
}

output "vnet_id" {
  value       = module.network.vnet_id
  description = "Virtual network resource ID."
}

output "subnet_ids" {
  value = {
    aca = module.network.subnet_aca_id
    pg  = module.network.subnet_pg_id
    pe  = module.network.subnet_pe_id
  }
  description = "Subnet resource IDs keyed by tier alias."
}

output "private_dns_zone_ids" {
  value       = module.network.private_dns_zone_ids
  description = "Private DNS zone IDs keyed by short alias (postgres/acr/blob/kv)."
}

# --- Postgres ---

output "postgres_fqdn" {
  value       = module.postgres.fqdn
  description = "Postgres server FQDN. Resolves to private IP inside the VNet."
}

output "postgres_database_name" {
  value       = module.postgres.database_name
  description = "Application database name on the Postgres server."
}

output "postgres_admin_username" {
  value       = module.postgres.admin_username
  description = "Postgres admin username."
}

output "postgres_admin_password" {
  value       = module.postgres.admin_password
  sensitive   = true
  description = "Postgres admin password. Retrieve with `terraform output -raw postgres_admin_password`. Will be migrated to Key Vault in a later step."
}

output "postgres_connection_string" {
  value       = module.postgres.connection_string
  sensitive   = true
  description = "Full postgresql:// connection string. Retrieve with `terraform output -raw postgres_connection_string`."
}
