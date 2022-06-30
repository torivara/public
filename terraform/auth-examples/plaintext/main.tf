# Assumes no environment variables. No partial configuration.

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
    key                  = "plaintext.terraform.tfstate"

    subscription_id = "00000000-0000-0000-0000-000000000000"
    tenant_id       = "00000000-0000-0000-0000-000000000000"
    client_id       = "00000000-0000-0000-0000-000000000000"
    # THIS IS NOT BEST PRACTICE!
    client_secret = "!234u23054ubnazocbnweortw4tf=)(&/%%/¤)"

    # If you must, source the client_secret from a variable like below
    # client_secret = var.client_secret
  }
}

variable "client_secret" {
  type      = string
  sensitive = true
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  client_id       = "00000000-0000-0000-0000-000000000000"
  # THIS IS NOT BEST PRACTICE
  client_secret = "!234u23054ubnazocbnweortw4tf=)(&/%%/¤)"

  # If you must, source the client_secret from a variable like below
  # client_secret = var.client_secret
}

resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "example"
}
