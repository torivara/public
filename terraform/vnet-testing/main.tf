resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "tf-test-vnet-rg"

}

resource "azurerm_virtual_network" "vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = "norwayeast"
  name                = "tf-test-vnet1"
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_subnet" "subnet1" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies  = false

}

resource "azurerm_subnet" "subnet2" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  private_endpoint_network_policies_enabled     = false
  private_link_service_network_policies_enabled = true

}
