# Configure the Microsoft Azure Active Directory Provider
provider "azuread" {
}

# Create an application
resource "azuread_application" "ad_app" {
  display_name = "us1-default-sp-dev"
}

# Create a service principal
resource "azuread_service_principal" "example" {
  client_id = azuread_application.ad_app.client_id
}
