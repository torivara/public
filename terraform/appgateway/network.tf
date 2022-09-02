locals {
  cidr_block = "10.254.0.0/16"
  subnets = {
    frontend = cidrsubnet(local.cidr_block, 8, 0)
  }
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West US"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = [local.cidr_block]
}

resource "azurerm_subnet" "example" {
  count                = length(keys(local.subnets))
  name                 = keys(local.subnets)[count.index]
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [local.subnets[keys(local.subnets)[count.index]]]
}
