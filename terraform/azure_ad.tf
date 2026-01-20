# Azure AD / Entra ID Configuration
# Modernized: January 2026
# Uses Workload Identity for AKS authentication

provider "azuread" {}

# Data source for current Azure AD configuration
data "azuread_client_config" "current" {}

# Application Registration for Workload Identity
resource "azuread_application" "aks_workload" {
  display_name = "${var.cluster_name}-workload-identity"
  owners       = [data.azuread_client_config.current.object_id]

  api {
    requested_access_token_version = 2
  }
}

# Service Principal for the application
resource "azuread_service_principal" "aks_workload" {
  client_id                    = azuread_application.aks_workload.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Federated Identity Credential for Kubernetes Service Account
resource "azuread_application_federated_identity_credential" "aks_workload" {
  application_id = azuread_application.aks_workload.id
  display_name   = "${var.cluster_name}-k8s-federation"
  description    = "Federated identity for AKS workload"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azurerm_kubernetes_cluster.default_aks.oidc_issuer_url
  subject        = "system:serviceaccount:${var.workload_namespace}:${var.workload_service_account}"
}

# Azure AD Group for AKS Admins
resource "azuread_group" "aks_admins" {
  display_name     = "${var.cluster_name}-admins"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

# Role Assignment: AKS Admin group gets Cluster Admin role
resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.default_aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_group.aks_admins.object_id
}
