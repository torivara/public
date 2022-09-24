terraform {
  # This is kind of important because feature is only supported from 1.3
  required_version = "~> 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "example-rg"

}

resource "azurerm_storage_account" "storeacc" {
  name                            = "simplestoragetorivar"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = "norwayeast"
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

moved {
  from = azurerm_storage_account.storeacc
  to   = module.storage_account
}

module "storage_account" {
  source = "../optional-testing"

  input = {
    "stg1" = {
      name                = "simplestoragetorivar"
      resource_group_name = azurerm_resource_group.rg.name
      location            = "norwayeast"
    }
  }
}
