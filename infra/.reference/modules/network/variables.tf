variable "resource_group_name" {
  type        = string
  description = "Resource group all network resources are deployed into."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources created by this module."
}

# --- VNet ---

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network."
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.10.0.0/16"]
  description = "VNet address space. Default 10.10.0.0/16 avoids common conflicts (Docker bridges, default Azure 10.0.0.0 ranges, home networks on 192.168.x)."
}

# --- Subnets ---

variable "subnet_aca_name" {
  type        = string
  description = "Name of the Container Apps subnet (delegated to Microsoft.App/environments)."
}

variable "subnet_aca_prefix" {
  type        = string
  default     = "10.10.0.0/23"
  description = "Address prefix for the Container Apps subnet. /23 is the minimum for the workload-profiles environment type."
}

variable "subnet_pg_name" {
  type        = string
  description = "Name of the Postgres Flex subnet (delegated to Microsoft.DBforPostgreSQL/flexibleServers)."
}

variable "subnet_pg_prefix" {
  type        = string
  default     = "10.10.2.0/24"
  description = "Address prefix for the Postgres subnet. /28 is Azure's minimum; /24 leaves headroom for replicas."
}

variable "subnet_pe_name" {
  type        = string
  description = "Name of the private endpoints subnet."
}

variable "subnet_pe_prefix" {
  type        = string
  default     = "10.10.3.0/27"
  description = "Address prefix for the private endpoints subnet. /27 = 32 addresses; one IP per private endpoint NIC."
}

# --- NSGs ---

variable "nsg_aca_name" {
  type        = string
  description = "Name of the Container Apps subnet NSG. Default Azure rules only in this module; tier-specific allows for ACA control-plane traffic are added in the ACA step."
}

variable "nsg_pg_name" {
  type        = string
  description = "Name of the Postgres subnet NSG."
}

variable "nsg_pe_name" {
  type        = string
  description = "Name of the private endpoints subnet NSG."
}
