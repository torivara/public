locals {
  app_services = [
    {
      kind = "Linux"
      sku = {
        tier = "Standard"
        size = "S1"
      }
    },
    {
      kind = "Windows"
      sku = {
        tier = "Basic"
        size = "B1"
      }
    }
  ]
}

resource "azurerm_service_plan" "example" {
  count               = length(local.app_services)
  name                = "${lower(local.app_services[count.index].kind)}-asp"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "B1"
  os_type             = "Windows"
}

resource "azurerm_windows_web_app" "example" {
  count               = length(local.app_services)
  name                = "${lower(local.app_services[count.index].kind)}-appservice"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  service_plan_id     = azurerm_service_plan.example[count.index].id

  site_config {}
}
