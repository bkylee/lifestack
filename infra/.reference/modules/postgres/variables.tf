variable "resource_group_name" {
  type        = string
  description = "Resource group for the Postgres server (typically the data tier RG)."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources."
}

variable "server_name" {
  type        = string
  description = "Name of the Postgres Flexible Server. Must be globally unique within Azure (used as the FQDN prefix)."
}

variable "database_name" {
  type        = string
  description = "Name of the application database created on the server."
}

variable "admin_username" {
  type        = string
  default     = "psqladmin"
  description = "Server admin username. Reserved by Azure: 'admin', 'azure_pg_admin', 'azure_superuser', 'guest', 'public', anything starting with 'pg_'."
}

variable "delegated_subnet_id" {
  type        = string
  description = "Resource ID of the subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers. Postgres gets a private IP directly in this subnet (VNet integration, not Private Endpoint)."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Resource ID of the privatelink.postgres.database.azure.com private DNS zone. Must already be linked to the VNet of the delegated subnet so name resolution works from inside the VNet."
}

variable "postgres_version" {
  type        = string
  default     = "16"
  description = "Postgres major version. 16 matches the local Docker dev environment for dev/prod parity."
}

variable "sku_name" {
  type        = string
  default     = "B_Standard_B1ms"
  description = "Server SKU. B_Standard_B1ms = Burstable, 1 vCore, 2 GiB RAM. Burstable tier is the cheapest line; bursts to baseline on demand."
}

variable "storage_mb" {
  type        = number
  default     = 32768
  description = "Server storage in MB. 32768 = 32 GB (Postgres Flex's documented minimum)."
}

variable "backup_retention_days" {
  type        = number
  default     = 14
  description = "Backup retention in days. Backups are free up to the provisioned storage size; 14 days gives a generous recovery window without geo-redundancy."
}

variable "extensions_allowlist" {
  type        = string
  default     = "vector"
  description = "Comma-separated lowercase list of Postgres extensions allowed at the server level via azure.extensions. See the full list of allowed values in the Azure error message if an invalid name is supplied. CREATE EXTENSION is still required at the database level once an extension is allowlisted here."
}

variable "availability_zone" {
  type        = string
  default     = "1"
  description = "Availability zone (1/2/3 in regions that support them). Specifying a fixed zone keeps the server's location predictable across applies."
}
