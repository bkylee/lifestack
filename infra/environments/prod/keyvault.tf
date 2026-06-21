#client config data source. Used to et the tenant and object IDs for role assignments 
data "azurerm_client_config" "current" {}

#random suffix generator for the keyvault name
resource "random_string" "kv_suffix" {
    length = 4
    special = false
    upper = false
    numeric = true 
}

#keyvault 
resource "azurerm_key_vault" "main" {
    name = "kv-${local.project}-${local.environment}-${random_string.kv_suffix.result}"
    location = local.location 
    resource_group_name = azurerm_resource_group.rg_names["app"].name 
    tenant_id = data.azurerm_client_config.current.tenant_id
    sku_name = "Standard"
    tags = local.base_tags
    #behavioural tags 
    enable_rbac_authorization = true
    purge_protection_enabled = false #for learning purposes so we can easily delete and recreate the keyvault. In production, this should be true to prevent accidental deletion of secrets.
    soft_delete_retention_days = 7 #minimum value so soft-deleted vaults will clear quickly 

    #network_acls
    network_acls { 
       default_action = "Deny"
       bypass = "AzureServices" 
       ip_rules = [${var.home_ip}] # will fill in my with home IP address
    }
}

resource "azurerm_role_assignment" "deployer_secrets" {
    scope = azurerm_key_vault.main.id
    role_definition_name = "Key Vault Secrets Officer" 
    principal_id = data.azurerm_client_config.current.object_id
}

resource "azurerm_private_endpoint" "kv" { 
    name = "pe-kv-${local.project}-${local.environment}"
    location = local.location 
    resource_group_name = azurerm_resource_group.rg_names["app"].name
    subnet_id = azurerm_subnet.pe.id
    
}