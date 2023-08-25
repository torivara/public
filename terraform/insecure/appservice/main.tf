provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tf-insecure-app-rg"
  location = "norwayeast"
}

resource "azurerm_service_plan" "plan" {
  location            = azurerm_resource_group.rg.location
  name                = "tf-insecure-app01-plan"
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "F1"

}

# Should support windows_app_service and not only the deprecated resource type
resource "azurerm_app_service" "app" {
  location            = azurerm_resource_group.rg.location
  name                = "tf-insecure-app01-as"
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  site_config {
  }

}
