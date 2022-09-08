resource "azurerm_key_vault" "kv" {
  location                   = azurerm_resource_group.rg.location
  name                       = "${local.resource_prefix}-kv"
  resource_group_name        = azurerm_resource_group.rg.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization  = true
  soft_delete_retention_days = 90

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = azurerm_windows_function_app.app.outbound_ip_address_list
    virtual_network_subnet_ids = var.vnet_integration_enabled == false ? [] : [local.virtual_network_subnet_id]
  }

}
