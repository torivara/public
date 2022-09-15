terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "tf-testing-${random_string.unique.result}-rg"
}

resource "azurerm_service_plan" "plan" {
  location            = azurerm_resource_group.rg.location
  name                = "tf-testing-${random_string.unique.result}-asp"
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "F1"
}

resource "azurerm_virtual_network" "vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  name                = "tf-testing-vnet"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet1" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_static_site" "site" {
  location            = "westeurope"
  name                = "tf-testing-${random_string.unique.result}-swa"
  resource_group_name = azurerm_resource_group.rg.name
}
