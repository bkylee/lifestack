variable "resource_group_name" {
  type        = string
  description = "Resource group for the registry (typically the app tier RG, since ACR's lifecycle is tied to the app's deploy pipeline)."
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

variable "name" {
  type        = string
  description = "Registry name. Must be globally unique within azurecr.io, 5-50 chars, alphanumeric only (no hyphens, no underscores). Becomes <name>.azurecr.io."

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.name))
    error_message = "Registry name must be 5-50 alphanumeric characters only."
  }
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "Registry SKU. Basic ($5/mo, 10 GB) for v1. Standard ($20/mo, 100 GB) for higher throughput. Premium ($50/mo, 500 GB) unlocks Private Endpoint, geo-replication, content trust, scope tokens, and retention policies."

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be one of: Basic, Standard, Premium."
  }
}
