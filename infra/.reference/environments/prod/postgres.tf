module "postgres" {
  source = "../../modules/postgres"

  resource_group_name = azurerm_resource_group.data.name
  location            = var.location
  tags                = local.base_tags

  server_name   = "psql-${var.project}-${var.environment}"
  database_name = var.project # "lifestack" — matches the local Docker DB name

  delegated_subnet_id = module.network.subnet_pg_id
  private_dns_zone_id = module.network.private_dns_zone_ids.postgres
}
