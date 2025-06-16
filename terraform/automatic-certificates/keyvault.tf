module "avm-res-keyvault-vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "~>0.10"

  location            = "norwayeast"
  name                = "kv-demo-${random_pet.unique.id}"
  resource_group_name = azurerm_resource_group.rg_demo.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  enable_telemetry = false
  sku_name         = "standard"

  # FOR DEMO PURPOSES ONLY
  # Do not use these settings in production
  purge_protection_enabled      = false
  soft_delete_retention_days    = null
  public_network_access_enabled = true
  network_acls = {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
  tags = local.tags
}
