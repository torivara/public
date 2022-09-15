resource "azurerm_kubernetes_cluster" "k8s" {
  name                    = var.aks_name
  location                = azurerm_resource_group.rg.location
  dns_prefix              = var.aks_dns_prefix
  private_cluster_enabled = true

  resource_group_name = azurerm_resource_group.rg.name

  http_application_routing_enabled = false

  default_node_pool {
    name            = "agentpool"
    node_count      = var.aks_agent_count
    vm_size         = var.aks_agent_vm_size
    os_disk_size_gb = var.aks_agent_os_disk_size
    vnet_subnet_id  = resource.azurerm_subnet.kubesubnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = var.aks_dns_service_ip
    docker_bridge_cidr = var.aks_docker_bridge_cidr
    service_cidr       = var.aks_service_cidr
    load_balancer_sku  = "standard"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.network.id
  }

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  depends_on = [
    azurerm_virtual_network.test,
    azurerm_application_gateway.network
  ]
  tags = var.tags
}
