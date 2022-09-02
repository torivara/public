resource "azuread_application" "testapp1" {
  display_name = "tf-testing-deployment-secrets1"

}

resource "azuread_service_principal" "testapp1" {
  application_id = azuread_application.testapp1.application_id
}

resource "azuread_service_principal_password" "testapp1" {
  service_principal_id = azuread_service_principal.testapp1.id
  description          = "testdescription"
}

resource "azuread_application" "testapp2" {
  display_name = "tf-testing-deployment-secrets2"

}

resource "azuread_service_principal" "testapp2" {
  application_id = azuread_application.testapp2.application_id
}

resource "azuread_service_principal_password" "testapp2" {
  service_principal_id = azuread_service_principal.testapp2.id
  end_date_relative    = "200h"
  display_name         = "test"

}

# resource "azuread_application_password" "testapp1" {
#   application_object_id = azuread_application.testapp1.application_id

# }

# resource "azuread_application_password" "testapp2" {
#   application_object_id = azuread_application.testapp2.application_id
#   display_name          = "ClientSecret"
# }

output "password1" {
  value     = azuread_service_principal_password.testapp1.value
  sensitive = true
}

output "password2" {
  value     = azuread_service_principal_password.testapp2.value
  sensitive = true
}
