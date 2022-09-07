output "principal_id" {
  value = azurerm_windows_function_app.fa-app.identity[0].principal_id
}

output "kv_id" {
  value = azurerm_key_vault.fa-kv.id
}
