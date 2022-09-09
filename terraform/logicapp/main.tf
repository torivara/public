terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

  }
}


#Configure the Azure Provider
provider "azurerm" {
  features {}
}


variable "environment_name" {
  type    = string
  default = "dev"
}

variable "context_prefix" {
  type    = string
  default = "ms"
}


data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "tf-test-logicapp-rg"
  location = "norwayeast"
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

#Create a storage account to be used by the logic apps
resource "azurerm_storage_account" "logicapp_std_storage" {
  name                     = "${var.context_prefix}${random_string.unique.result}${var.environment_name}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#Create a plan for the logic apps to run on
resource "azurerm_service_plan" "platform_logicapp_plan" {
  name                = "${var.context_prefix}-${random_string.unique.result}-${var.environment_name}-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  #kind                = "elastic"
  os_type  = "Windows"
  tags     = {}
  sku_name = "WS1"
}

#Create a log analytics workspace for use by logic apps and app insights in workspace mode
resource "azurerm_log_analytics_workspace" "platform_logicapp_logs" {
  name                = "${var.context_prefix}-${random_string.unique.result}-${var.environment_name}-ws"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#Create an app insights instance for the logic apps to send telemetry to
resource "azurerm_application_insights" "platform_logicapp_appinsights" {
  name                = "${var.context_prefix}-${random_string.unique.result}-${var.environment_name}-ai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.platform_logicapp_logs.id
}

#Create a Logic App on the plan
resource "azurerm_logic_app_standard" "helloworld" {
  name                       = "${var.context_prefix}-${random_string.unique.result}-helloworld-${var.environment_name}-la"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_service_plan.platform_logicapp_plan.id
  storage_account_name       = azurerm_storage_account.logicapp_std_storage.name
  storage_account_access_key = azurerm_storage_account.logicapp_std_storage.primary_access_key
  storage_account_share_name = "${var.context_prefix}-${random_string.unique.result}-helloworld-${var.environment_name}-la"

  https_only = true
  version    = "~3"

  site_config {
    always_on                 = false
    dotnet_framework_version  = "v4.0"
    ftps_state                = "Disabled"
    pre_warmed_instance_count = "0"
    app_scale_limit           = "1"
  }

  identity {
    type = "SystemAssigned"
  }
}
