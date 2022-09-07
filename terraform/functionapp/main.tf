data "azurerm_client_config" "current" {
}

module "functionapp-dev" {
  source                   = "./modules/app"
  name_prefix              = "dev"
  vnet_integration_enabled = false

}

module "functionapp-test" {
  source                     = "./modules/app"
  name_prefix                = "test"
  vnet_integration_enabled   = false
  identity_type              = "UserAssigned"
  user_assigned_identity_ids = [azurerm_user_assigned_identity.identity.principal_id]

}

resource "azurerm_resource_group" "identity-rg" {
  location = "norwayeast"
  name     = "app-demoapp-test-identity-rg"

}

resource "azurerm_user_assigned_identity" "identity" {
  location            = azurerm_resource_group.identity-rg.location
  name                = "app-demoapp-test-msi"
  resource_group_name = azurerm_resource_group.identity-rg.name
}

resource "azurerm_role_assignment" "reader-dev" {
  principal_id         = module.functionapp-dev.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
}

resource "azurerm_role_assignment" "reader-test" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
}
