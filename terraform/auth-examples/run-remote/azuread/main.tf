# Assumes ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, and ARM_TENANT_ID environment variables are set to relevant values.

# AzureRM provider pinned to 3.11.0
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.11.0"
    }
  }
  # Your Terraform state will be stored in this storage account
  # Service principal needs permission storage blob data owner
  backend "azurerm" {
    storage_account_name = "tfstatesa1234"
    container_name       = "tfstate"
    key                  = "azuread.terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "example"
}
