resource "azurerm_virtual_network" "integration-vnet" {
  count               = var.vnet_integration_enabled == true && var.vnet_integration_subnet_id == null ? 1 : 0
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.fa-rg.location
  name                = "${local.resource_prefix}-integration-vnet"
  resource_group_name = azurerm_resource_group.fa-rg.name
}

resource "azurerm_subnet" "integration-subnet" {
  count                = var.vnet_integration_enabled == true && var.vnet_integration_subnet_id == null ? 1 : 0
  address_prefixes     = ["10.0.0.0/25"]
  name                 = "integrationSubnet"
  resource_group_name  = azurerm_resource_group.fa-rg.name
  virtual_network_name = azurerm_virtual_network.integration-vnet[0].name
}
