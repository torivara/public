resource "azurerm_storage_account" "fa-sa" {
  name                      = "${local.name_prefix}${random_string.unique.result}sa"
  location                  = azurerm_resource_group.fa-rg.location
  account_replication_type  = "LRS"
  account_tier              = "Standard"
  account_kind              = "StorageV2"
  min_tls_version           = "TLS1_2"
  enable_https_traffic_only = true
  resource_group_name       = azurerm_resource_group.fa-rg.name
}
