# Outputs for AKS Infrastructure
# Modernized: January 2026

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.default_rg.name
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.default_aks.name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.default_aks.id
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.default_aks.fqdn
}

output "kube_config" {
  description = "Kubernetes configuration (sensitive)"
  value       = azurerm_kubernetes_cluster.default_aks.kube_config_raw
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.default_aks.oidc_issuer_url
}

output "kubelet_identity" {
  description = "Kubelet identity object ID"
  value       = azurerm_kubernetes_cluster.default_aks.kubelet_identity[0].object_id
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.client_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks.id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.default.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.id
}

# Workload Identity outputs
output "workload_identity_client_id" {
  description = "Client ID for workload identity app"
  value       = azuread_application.aks_workload.client_id
}

output "aks_admins_group_id" {
  description = "Object ID of the AKS admins Azure AD group"
  value       = azuread_group.aks_admins.object_id
}

# Connection string for kubectl
output "kubectl_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.default_rg.name} --name ${azurerm_kubernetes_cluster.default_aks.name}"
}
