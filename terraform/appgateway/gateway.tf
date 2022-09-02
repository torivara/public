locals {
  backend_probe_name = "${azurerm_virtual_network.example.name}-probe"
  http_setting_name  = "${azurerm_virtual_network.example.name}-be-htst"
  public_ip_name     = "${azurerm_virtual_network.example.name}-pip"
}

resource "azurerm_public_ip" "example" {
  name                = local.public_ip_name
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Dynamic"
}

resource "azurerm_application_gateway" "network" {
  depends_on          = [azurerm_public_ip.example]
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.example.0.id
  }

  dynamic "frontend_port" {
    for_each = azurerm_windows_web_app.example
    content {
      name = "${azurerm_virtual_network.example.name}-${frontend_port.value.name}-feport"
      port = "808${frontend_port.key}"
    }
  }

  frontend_ip_configuration {
    name                 = "${azurerm_virtual_network.example.name}-feip"
    public_ip_address_id = azurerm_public_ip.example.id
  }

  dynamic "backend_address_pool" {
    for_each = azurerm_windows_web_app.example
    content {
      name  = "${azurerm_virtual_network.example.name}-${backend_address_pool.value.name}-beap"
      fqdns = [backend_address_pool.value.default_hostname]
    }
  }

  probe {
    name                                      = local.backend_probe_name
    protocol                                  = "Http"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 120
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      body        = "Welcome"
      status_code = [200, 399]
    }
  }

  backend_http_settings {
    name                                = local.http_setting_name
    probe_name                          = local.backend_probe_name
    cookie_based_affinity               = "Disabled"
    path                                = "/"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 120
    pick_host_name_from_backend_address = true
  }

  dynamic "http_listener" {
    for_each = azurerm_windows_web_app.example
    content {
      name                           = "${azurerm_virtual_network.example.name}-${http_listener.value.name}-httplstn"
      frontend_ip_configuration_name = "${azurerm_virtual_network.example.name}-feip"
      frontend_port_name             = "${azurerm_virtual_network.example.name}-${http_listener.value.name}-feport"
      protocol                       = "Http"
    }
  }

  dynamic "request_routing_rule" {
    for_each = azurerm_windows_web_app.example
    content {
      name                       = "${azurerm_virtual_network.example.name}-${request_routing_rule.value.name}-rqrt"
      rule_type                  = "Basic"
      http_listener_name         = "${azurerm_virtual_network.example.name}-${request_routing_rule.value.name}-httplstn"
      backend_address_pool_name  = "${azurerm_virtual_network.example.name}-${request_routing_rule.value.name}-beap"
      backend_http_settings_name = local.http_setting_name
    }
  }
}
