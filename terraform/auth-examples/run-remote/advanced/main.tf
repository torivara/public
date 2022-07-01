# AzureRM provider pinned to 3.11.0
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.11.0"
    }
  }
  # Your Terraform state will be stored in this storage account
  backend "azurerm" {
    resource_group_name  = "tf-example-rg"
    storage_account_name = "tfstatesa1234"
    container_name       = "tfstate"
    key                  = "advanced.terraform.tfstate"
    use_oidc             = true

    subscription_id = "00000000-0000-0000-0000-000000000000"
  }
}

# Configure the Microsoft Azure default Provider
provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

provider "azurerm" {
  alias = "management"
  features {}
  use_oidc        = true
  subscription_id = "11111111-1111-1111-1111-111111111111"
}

provider "azurerm" {
  alias = "connectivity"
  features {}
  use_oidc        = true
  subscription_id = "22222222-2222-2222-2222-222222222222"
}

resource "azurerm_resource_group" "rg-network" {
  location = "norwayeast"
  name     = "network-rg"

  provider = azurerm.connectivity
}

resource "azurerm_resource_group" "rg-mgmt" {
  location = "norwayeast"
  name     = "management-rg"

  provider = azurerm.management
}

resource "azurerm_resource_group" "rg-default" {
  location = "norwayeast"
  name     = "default-rg"
}
