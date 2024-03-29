locals {
  name_prefix     = var.name_prefix
  app_name        = var.app_name
  resource_prefix = "${local.name_prefix}-${random_string.unique.result}${var.app_name}"
}

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "${local.resource_prefix}-rg"
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_service_plan" "asp" {
  location            = azurerm_resource_group.rg.location
  name                = "${local.resource_prefix}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = var.os_type
  sku_name            = var.sku_name
}

resource "azurerm_windows_function_app" "app" {
  location                   = azurerm_service_plan.asp.location
  name                       = "${local.resource_prefix}-app"
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.asp.id
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  storage_account_name       = azurerm_storage_account.sa.name

  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" && var.user_assigned_identity_resource_ids != [] ? var.user_assigned_identity_resource_ids : []
  }

  site_config {
    minimum_tls_version                    = "1.2"
    application_insights_key               = azurerm_application_insights.ai.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.ai.connection_string

    application_stack {
      powershell_core_version = "7.2"
    }
  }
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.ai.instrumentation_key
    "FUNCTIONS_WORKER_RUNTIME"       = "powershell"
    "WEBSITE_RUN_FROM_PACKAGE"       = "1"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["APPINSIGHTS_INSTRUMENTATIONKEY"],
      app_settings["SCM_DO_BUILD_DURING_DEPLOYMENT"],
      tags
    ]
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "app-integration" {
  count          = var.vnet_integration_enabled == true && var.vnet_integration_subnet_id == null ? 1 : 0
  app_service_id = azurerm_windows_function_app.app.id
  subnet_id      = var.vnet_integration_subnet_id == null ? azurerm_subnet.integration-subnet[0].id : var.vnet_integration_subnet_id
}

