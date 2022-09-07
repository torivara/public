data "azurerm_client_config" "current" {
}

module "functionapp-dev" {
  source                   = "./modules/app"
  name_prefix              = "dev"
  vnet_integration_enabled = false

}

module "functionapp-test" {
  source                   = "./modules/app"
  name_prefix              = "test"
  vnet_integration_enabled = false

}

resource "azurerm_role_assignment" "reader-dev" {
  principal_id         = module.functionapp-dev.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
}

resource "azurerm_role_assignment" "reader-test" {
  principal_id         = module.functionapp-test.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
}
