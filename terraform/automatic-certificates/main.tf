locals {
  tags = {
    env     = "development"
    purpose = "auto certificates demo"
  }
  dns_zone_name = "kverulant.no"
}

resource "random_pet" "unique" {
  length = 2
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg_demo" {
  location = "norwayeast"
  name     = "rg-demo-${random_pet.unique.id}"
}
