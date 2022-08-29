locals {
  name_prefix     = var.name_prefix
  app_name        = var.app_name
  resource_prefix = "${local.name_prefix}-${random_string.unique.result}${var.app_name}"
}

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "fa-rg" {
  location = var.location
  name     = "${local.resource_prefix}-rg"
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_service_plan" "fa-asp" {
  location            = azurerm_resource_group.fa-rg.location
  name                = "${local.resource_prefix}-asp"
  resource_group_name = azurerm_resource_group.fa-rg.name
  os_type             = var.os_type
  sku_name            = var.sku_name
}

resource "azurerm_windows_function_app" "fa-app" {
  location                    = azurerm_service_plan.fa-asp.location
  name                        = "${local.resource_prefix}-app"
  resource_group_name         = azurerm_resource_group.fa-rg.name
  service_plan_id             = azurerm_service_plan.fa-asp.id
  storage_account_access_key  = azurerm_storage_account.fa-sa.primary_access_key
  storage_account_name        = azurerm_storage_account.fa-sa.name
  functions_extension_version = "~4"

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version                    = "1.2"
    application_insights_key               = azurerm_application_insights.fa-ai.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.fa-ai.connection_string
  }
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.fa-ai.instrumentation_key
    "FUNCTIONS_WORKER_RUNTIME"       = "powershell"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["APPINSIGHTS_INSTRUMENTATIONKEY"],
    ]
  }
}
