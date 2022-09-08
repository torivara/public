resource "azurerm_log_analytics_workspace" "ai-ws" {
  count               = var.app_insights_workspace_id == null ? 1 : 0
  location            = azurerm_resource_group.rg.location
  name                = local.resource_prefix
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_application_insights" "ai" {
  application_type    = "other"
  location            = azurerm_resource_group.rg.location
  name                = "${local.resource_prefix}-ai"
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = var.app_insights_workspace_id == null ? azurerm_log_analytics_workspace.ai-ws[0].id : var.app_insights_workspace_id
}
