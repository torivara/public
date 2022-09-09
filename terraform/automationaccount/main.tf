provider "azurerm" {
  features {}
}

variable "prefix" {
  default = "tf-test"
}

variable "location" {
  default = "norwayeast"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_automation_account" "aa" {
  name                = "${var.prefix}-aa"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_automation_runbook" "runbook" {
  name                    = "Get-AzureVMTutorial"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "This is an example runbook"
  runbook_type            = "PowerShellWorkflow"

  publish_content_link {
    uri = "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/c4935ffb69246a6058eb24f54640f53f69d3ac9f/101-automation-runbook-getvms/Runbooks/Get-AzureVMTutorial.ps1"
  }
}

resource "azurerm_automation_schedule" "one-time" {
  name                    = "${var.prefix}-one-time"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  frequency               = "OneTime"

  // The start_time defaults to now + 7 min
}

resource "azurerm_automation_schedule" "hour" {
  name                    = "${var.prefix}-hour"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  frequency               = "Hour"
  interval                = 2
  timezone                = "Europe/Oslo"
}

// Schedules the example runbook to run on the hour schedule
resource "azurerm_automation_job_schedule" "example" {
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.aa.name
  runbook_name            = azurerm_automation_runbook.runbook.name
  schedule_name           = azurerm_automation_schedule.hour.name
}
