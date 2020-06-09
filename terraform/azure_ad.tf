# Configure the Microsoft Azure Active Directory Provider
provider "azuread" {
  version = "=0.8.0"
}

# Create an application
resource "azuread_application" "ad_app" {
  name = "us1-default-sp-dev"
}

# Create a service principal
resource "azuread_service_principal" "example" {
  application_id = azuread_application.ad_app.application_id
}
