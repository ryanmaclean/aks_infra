# Variables for AKS Infrastructure
# Modernized: January 2026

# ============================================================================
# Required Variables
# ============================================================================

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "us1-default-aks-dev"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "aks-infra-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team"
}

# ============================================================================
# Kubernetes Configuration
# ============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster (use 'az aks get-versions' for supported versions)"
  type        = string
  default     = "1.32" # LTS version with support until 2026
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "aks-dev"
}

variable "aks_sku_tier" {
  description = "SKU tier for AKS (Free, Standard, Premium). Free for demos, Standard for uptime SLA."
  type        = string
  default     = "Free" # No uptime SLA, saves ~$73/month
}

# ============================================================================
# Node Pool Configuration
# ============================================================================

variable "default_node_pool_vm_size" {
  description = "VM size for the default (system) node pool. D2s_v5 sufficient for demos."
  type        = string
  default     = "Standard_D2s_v5" # 2 vCPU, 8GB - half the cost of D4s_v5
}

variable "default_node_pool_min_count" {
  description = "Minimum number of nodes in the default pool. 1 for demos, 2+ for HA."
  type        = number
  default     = 1 # Single node for demo, autoscales up if needed
}

variable "default_node_pool_max_count" {
  description = "Maximum number of nodes in the default pool"
  type        = number
  default     = 5
}

# ============================================================================
# Windows Node Pool (Optional)
# ============================================================================

variable "enable_windows_node_pool" {
  description = "Whether to create a Windows node pool"
  type        = bool
  default     = false
}

variable "windows_node_pool_vm_size" {
  description = "VM size for Windows nodes"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "windows_node_pool_max_count" {
  description = "Maximum number of Windows nodes"
  type        = number
  default     = 3
}

# ============================================================================
# Workload Identity Configuration
# ============================================================================

variable "workload_namespace" {
  description = "Kubernetes namespace for workload identity"
  type        = string
  default     = "default"
}

variable "workload_service_account" {
  description = "Kubernetes service account for workload identity"
  type        = string
  default     = "workload-identity-sa"
}
