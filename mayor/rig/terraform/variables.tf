# Variables for Rig Infrastructure
# Modernized: January 2026

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "rig-aks"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rig-rg"
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

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.32"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "rig"
}

variable "node_pool_vm_size" {
  description = "VM size for the node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "node_pool_min_count" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_pool_max_count" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}
