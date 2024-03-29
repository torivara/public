# Assumes you have authenticated with Azure CLI before running Terraform

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
    key                  = "azcli.terraform.tfstate"

    subscription_id = "00000000-0000-0000-0000-000000000000"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  subscription_id = "00000000-0000-0000-0000-000000000000"
}

resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "example"
}
