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

locals {
  default_resource_group_name             = azurerm_resource_group.default.name
  default_location                        = "norwayeast"
  default_account_kind                    = "StorageV2"
  default_account_tier                    = "Standard"
  default_account_replication_type        = "LRS"
  default_enable_https_traffic_only       = true
  default_allow_nested_items_to_be_public = false
  default_min_tls_version                 = "TLS1_1"
}

resource "azurerm_resource_group" "default" {
  location = "norwayeast"
  name     = "example-default-rg"
}

variable "input" {
  type = map(
    object({
      name                            = string,
      resource_group_name             = optional(string),
      location                        = optional(string),
      account_kind                    = optional(string),
      account_tier                    = optional(string),
      account_replication_type        = optional(string),
      enable_https_traffic_only       = optional(bool),
      allow_nested_items_to_be_public = optional(bool),
      min_tls_version                 = optional(string)
    })
  )
}

resource "azurerm_storage_account" "storeacc" {
  for_each                        = var.input
  name                            = each.value.name
  resource_group_name             = each.value.resource_group_name != null ? each.value.resource_group_name : local.default_resource_group_name
  location                        = each.value.location != null ? each.value.location : local.default_location
  account_kind                    = each.value.account_kind != null ? each.value.account_kind : local.default_account_kind
  account_tier                    = each.value.account_tier != null ? each.value.account_tier : local.default_account_tier
  account_replication_type        = each.value.account_replication_type != null ? each.value.account_replication_type : local.default_account_replication_type
  enable_https_traffic_only       = each.value.enable_https_traffic_only != null ? each.value.enable_https_traffic_only : local.default_enable_https_traffic_only
  allow_nested_items_to_be_public = each.value.allow_nested_items_to_be_public != null ? each.value.allow_nested_items_to_be_public : local.default_allow_nested_items_to_be_public
  min_tls_version                 = each.value.min_tls_version != null ? each.value.min_tls_version : local.default_min_tls_version
}
