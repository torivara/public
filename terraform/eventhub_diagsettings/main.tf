terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.18.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.27.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "siem-eventhub-rg"
  location = "norwayeast"
}

resource "azuread_group" "aad-evh-owner" {
  display_name     = "azure-sub-eventhub-owner"
  security_enabled = true
  members = [
    data.azurerm_client_config.current.object_id
  ]

}

resource "random_string" "unique" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_eventhub_namespace" "eventhub-ns" {
  name                = "siem-eventhub-${random_string.unique.result}-ns"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 2
}

resource "azurerm_eventhub" "activity-logs" {
  name                = "insights-activity-logs"
  namespace_name      = azurerm_eventhub_namespace.eventhub-ns.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 4
  message_retention   = 7
}

resource "azurerm_eventhub_namespace_authorization_rule" "listen-send" {
  name                = "RootListenSendSharedAccessKey"
  namespace_name      = azurerm_eventhub_namespace.eventhub-ns.name
  resource_group_name = azurerm_resource_group.rg.name

  listen = true
  send   = true
  manage = false
}

resource "azurerm_role_assignment" "eventhub-owner-authrule-scope" {
  principal_id         = azuread_group.aad-evh-owner.object_id
  scope                = azurerm_eventhub_namespace_authorization_rule.listen-send.id
  role_definition_name = "Azure Event Hubs Data Owner"
}

resource "azurerm_monitor_diagnostic_setting" "diag-setting" {
  name                           = "toEventHub"
  target_resource_id             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  eventhub_name                  = azurerm_eventhub.activity-logs.name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.listen-send.id

  log {
    category = "Administrative"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "Security"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "Alert"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "ServiceHealth"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "Recommendation"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "Policy"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "Autoscale"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "ResourceHealth"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
}
