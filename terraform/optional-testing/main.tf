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

resource "azurerm_resource_group" "example1" {
  location = "norwayeast"
  name     = "example1-rg"
}

resource "azurerm_resource_group" "example2" {
  location = "norwayeast"
  name     = "example2-rg"
}

module "storage_accounts" {
  source = "./modules/storage"

  input = {
    "stg1" = {
      location = "westeurope"
      name     = "tiateststoragewe"
    },
    "stg2" = {
      location            = "northeurope"
      name                = "tiateststoragene"
      resource_group_name = azurerm_resource_group.example1.name
    },
    "stg3" = {
      location                 = "westeurope"
      name                     = "tiateststoragewegrs"
      account_replication_type = "GRS"
      resource_group_name      = azurerm_resource_group.example1.name
    },
    "stg4" = {
      location                        = "westeurope"
      name                            = "tiateststorageunsafe"
      min_tls_version                 = "TLS1_0"
      allow_nested_items_to_be_public = true
      enable_https_traffic_only       = false
      resource_group_name             = azurerm_resource_group.example2.name
    },
    "stg5" = {
      location                 = "westeurope"
      name                     = "tiateststorageprod"
      account_tier             = "Premium"
      account_replication_type = "RAGZRS"
      resource_group_name      = azurerm_resource_group.example2.name
    }
  }
}
