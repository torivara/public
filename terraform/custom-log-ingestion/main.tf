terraform {
  required_version = ">=1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

resource "random_pet" "pet" {
  length    = 2
  separator = "-"
}

resource "azurerm_resource_group" "rg" {
  location = "norwayeast"
  name     = "rg-lawtest-${random_pet.pet.id}"
}

resource "azurerm_log_analytics_workspace" "workspace" {
  location            = azurerm_resource_group.rg.location
  name                = "log-${random_pet.pet.id}"
  resource_group_name = azurerm_resource_group.rg.name
}

locals {
  custom_tables = [
    {
      name = "mytable_CL",
      schema = {
        name = "mytable_CL",
        columns = [
          {
            name        = "TimeGenerated",
            type        = "datetime",
            description = "The time at which the data was generated"
          },
          {
            name        = "column1",
            type        = "string",
            description = "Column 1"
          },
          {
            name        = "column2",
            type        = "string",
            description = "Column 2"
          }
        ]
      },
      retention_in_days       = 30,
      total_retention_in_days = 30
    }
  ]
}

resource "azapi_resource" "custom_tables" {
  for_each  = { for v in local.custom_tables : v.name => v }
  name      = each.key
  parent_id = azurerm_log_analytics_workspace.workspace.id
  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  body = jsonencode(
    {
      "properties" : {
        "schema" : each.value.schema,
        "retentionInDays" : each.value.retention_in_days,
        "totalRetentionInDays" : each.value.total_retention_in_days
      }
    }
  )
}

resource "azurerm_monitor_data_collection_endpoint" "custom_tables_dce" {
  location                      = azurerm_log_analytics_workspace.workspace.location
  name                          = "dce-${azurerm_log_analytics_workspace.workspace.name}"
  description                   = "Data Collection Endpoint for ingestion to custom tables in log analytics workspace."
  resource_group_name           = azurerm_log_analytics_workspace.workspace.resource_group_name
  public_network_access_enabled = true
}

resource "azurerm_monitor_data_collection_rule" "custom_log_ingestion_rules" {
  for_each                    = { for v in local.custom_tables : v.name => v }
  location                    = azurerm_log_analytics_workspace.workspace.location
  name                        = "dcr-${replace(lower(each.key), "_", "-")}-${azurerm_log_analytics_workspace.workspace.name}"
  resource_group_name         = azurerm_log_analytics_workspace.workspace.resource_group_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.custom_tables_dce[0].id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
      name                  = azurerm_log_analytics_workspace.workspace.name
    }
  }

  data_flow {
    streams       = ["Custom-${each.key}"]
    destinations  = [azurerm_log_analytics_workspace.workspace.name]
    transform_kql = "source | extend TimeGenerated = now()"
    output_stream = "Custom-${each.key}"
  }

  stream_declaration {
    stream_name = "Custom-${each.key}"
    dynamic "column" {
      for_each = each.value.schema.columns
      content {
        name = column.value.name
        type = column.value.type
      }
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "metrics_publisher" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Metrics Publisher"
}

output "log_ingestion_endpoints" {
  description = "Computed log ingestion endpoints pr. data collection rule with DCR immutable ID included"
  value       = { for v in azurerm_monitor_data_collection_rule.custom_log_ingestion_rules : "log_endpoint_${v.name}" => "${azurerm_monitor_data_collection_endpoint.custom_tables_dce.logs_ingestion_endpoint}/dataCollectionRules/${v.immutable_id}/streams/${v.data_flow[0].streams[0]}?api-version=2023-01-01" }
}
