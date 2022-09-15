resource "azurerm_virtual_network" "test" {
  name                = var.virtual_network_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.virtual_network_address_prefix]

  tags = var.tags
}
resource "azurerm_subnet" "kubesubnet" {
  name                 = var.aks_subnet_name
  address_prefixes     = [var.aks_subnet_address_prefix]
  virtual_network_name = azurerm_virtual_network.test.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "appgwsubnet" {
  name                 = "appgwsubnet"
  address_prefixes     = [var.app_gateway_subnet_address_prefix]
  virtual_network_name = azurerm_virtual_network.test.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "mgmtsubnet" {
  name                 = "mgmtsubnet"
  address_prefixes     = ["192.168.2.0/24"]
  virtual_network_name = azurerm_virtual_network.test.name
  resource_group_name  = azurerm_resource_group.rg.name
}
