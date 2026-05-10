# 4-char lowercase alphanumeric suffix for resources whose names must be globally
# unique across all of Azure (storage accounts, ACR, Key Vault, Front Door endpoint).
# Generated once and persisted in state — stable across applies.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}
