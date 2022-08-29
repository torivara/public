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
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {
  tenant_id = data.azurerm_client_config.current.tenant_id
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

locals {
  sub_eventhub_metrics = []
  sub_eventhub_logs = [
    {
      category = "Administrative"
      enabled  = true

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "Security"
      enabled  = true

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "Alert"
      enabled  = true

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "ServiceHealth"
      enabled  = true

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "Recommendation"
      enabled  = false

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "Policy"
      enabled  = false

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "Autoscale"
      enabled  = false

      retention_policy = {
        days    = 0
        enabled = false
      }
    },
    {
      category = "ResourceHealth"
      enabled  = false

      retention_policy = {
        days    = 0
        enabled = false
      }
    }
  ]
}

resource "azurerm_monitor_diagnostic_setting" "diag-setting-subscription" {
  name                           = "toEventHub"
  target_resource_id             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  eventhub_name                  = azurerm_eventhub.activity-logs.name
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.listen-send.id

  dynamic "log" {
    for_each = local.sub_eventhub_logs
    content {
      category = log.value.category
      enabled  = log.value.enabled

      retention_policy {
        enabled = log.value.retention_policy.enabled
        days    = log.value.retention_policy.days
      }
    }
  }

  # Define the metrics to be stored
  dynamic "metric" {
    for_each = local.sub_eventhub_metrics
    content {
      category = metric.value.category
      enabled  = metric.value.enabled
      retention_policy {
        enabled = metric.value.retention_policy.enabled
        days    = metric.value.retention_policy.days
      }
    }
  }

  lifecycle {
    ignore_changes = [
      log,
      metric
    ]
  }
}

resource "azapi_resource" "diag-setting-management-group" {
  type                    = "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
  name                    = "toEventHub"
  parent_id               = "/providers/Microsoft.Management/managementGroups/torivar-inc"
  ignore_missing_property = true
  body = jsonencode({
    properties = {
      eventHubAuthorizationRuleId = azurerm_eventhub_namespace_authorization_rule.listen-send.id
      eventHubName                = azurerm_eventhub.activity-logs.name
      logs = [
        {
          category = "Administrative"
          enabled  = true
          retentionPolicy = {
            days    = 0
            enabled = false
          }
        },
        {
          category = "Policy"
          enabled  = false
          retentionPolicy = {
            days    = 0
            enabled = false
          }
        }
      ]
    }
  })
}
