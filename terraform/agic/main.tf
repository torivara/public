resource "random_pet" "rg-name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg-name.id
  location = var.resource_group_location
}

resource "azurerm_role_assignment" "aks_id_network_contributor_subnet" {
  scope                = resource.azurerm_subnet.kubesubnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.k8s.identity[0].principal_id

  depends_on = [azurerm_virtual_network.test]
}

resource "azurerm_role_assignment" "aks_id_contributor_agw" {
  scope                = azurerm_application_gateway.network.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.k8s.identity[0].principal_id
  depends_on           = [azurerm_application_gateway.network]
}

resource "azurerm_role_assignment" "aks_ingressid_contributor_on_agw" {
  scope                            = azurerm_application_gateway.network.id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_kubernetes_cluster.k8s.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  depends_on                       = [azurerm_application_gateway.network]
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_ingressid_contributor_on_uami" {
  scope                            = azurerm_user_assigned_identity.identity_uami.id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_kubernetes_cluster.k8s.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  depends_on                       = [azurerm_application_gateway.network]
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uami_contributor_on_agw" {
  scope                            = azurerm_application_gateway.network.id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_user_assigned_identity.identity_uami.principal_id
  depends_on                       = [azurerm_application_gateway.network]
  skip_service_principal_aad_check = true
}
