variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for the v1 prod environment."
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "Primary Azure region for all v1 resources. eastus2 chosen over eastus because eastus is at capacity for Postgres Flex on PAYG subscriptions (LocationIsOfferRestricted)."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name. v1 only deploys prod; dev and staging are structured but not provisioned."
}

variable "project" {
  type        = string
  default     = "lifestack"
  description = "Project name. Drives naming conventions across all resources."
}
