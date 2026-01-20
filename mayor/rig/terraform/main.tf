# Rig Infrastructure Configuration
# Modernized: January 2026
# OpenTofu compatible - lightweight AKS deployment module

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group for Rig
resource "azurerm_resource_group" "rig" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "rig" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.rig.location
  resource_group_name = azurerm_resource_group.rig.name
  address_space       = ["10.100.0.0/16"]

  tags = local.common_tags
}

# AKS Subnet
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rig.name
  virtual_network_name = azurerm_virtual_network.rig.name
  address_prefixes     = ["10.100.0.0/22"]
}

# User Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.cluster_name}-identity"
  resource_group_name = azurerm_resource_group.rig.name
  location            = azurerm_resource_group.rig.location

  tags = local.common_tags
}

# AKS Cluster with Managed Identity
resource "azurerm_kubernetes_cluster" "rig" {
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.rig.name
  location            = azurerm_resource_group.rig.location
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_pool_vm_size
    vnet_subnet_id       = azurerm_subnet.aks.id
    auto_scaling_enabled = true
    min_count            = var.node_pool_min_count
    max_count            = var.node_pool_max_count
    os_disk_size_gb      = 128
    os_sku               = "AzureLinux"

    upgrade_settings {
      max_surge = "10%"
    }

    tags = local.common_tags
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  tags = local.common_tags
}

# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# Local values for common tags
locals {
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "OpenTofu"
    Project     = "rig"
  }
}
