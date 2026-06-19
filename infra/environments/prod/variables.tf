variable "subscription_id" {
  type        = string
  description = "subscription ID for lifestack"
}

variable "deployer_ip" {
  type        = string
  description = "Public IP allowed through the Key Vault firewall (network_acls ip_rules). The /32 is appended in config. Value lives in terraform.tfvars (gitignored); see terraform.tfvars.example."
}