provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "tf-insecure-role-rg"
  location = "norwayeast"
}

data "azurerm_subscription" "primary" {
}

resource "azurerm_role_definition" "example" {
  name        = "my-custom-role"
  scope       = data.azurerm_subscription.primary.id
  description = "This is a custom role created via Terraform"

  permissions {
    actions     = ["*"]
    not_actions = []
  }

  assignable_scopes = [
    "/"
  ]
}
