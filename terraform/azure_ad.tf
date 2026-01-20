# Azure AD provider is configured in main.tf

# Create a User-Assigned Managed Identity for Workload Identity
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "workload-identity-test"
  resource_group_name = azurerm_resource_group.default_rg.name
  location            = azurerm_resource_group.default_rg.location

  tags = {
    env   = "dev"
    owner = "ryanmaclean"
  }
}

# Create Federated Identity Credential for Kubernetes Service Account
resource "azurerm_federated_identity_credential" "workload_identity_fed_cred" {
  name                = "workload-identity-fed-cred"
  resource_group_name = azurerm_resource_group.default_rg.name
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.default_aks.oidc_issuer_url
  subject             = "system:serviceaccount:${var.workload_identity_namespace}:${var.workload_identity_service_account}"
}

# Output the managed identity client ID for Kubernetes ServiceAccount annotation
output "workload_identity_client_id" {
  description = "Client ID of the User-Assigned Managed Identity for Workload Identity"
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}

output "workload_identity_tenant_id" {
  description = "Tenant ID for Azure AD"
  value       = azurerm_user_assigned_identity.workload_identity.tenant_id
}

output "workload_identity_principal_id" {
  description = "Principal ID of the User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.workload_identity.principal_id
}
