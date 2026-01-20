# Outputs for Rig Infrastructure
# Modernized: January 2026

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rig.name
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.rig.name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.rig.id
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.rig.fqdn
}

output "kube_config" {
  description = "Kubernetes configuration (sensitive)"
  value       = azurerm_kubernetes_cluster.rig.kube_config_raw
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.rig.oidc_issuer_url
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.aks.client_id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.rig.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "kubectl_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rig.name} --name ${azurerm_kubernetes_cluster.rig.name}"
}
