# AKS Infrastructure Configuration
# Modernized: January 2026
# OpenTofu compatible - uses managed identity instead of service principal

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "default_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Virtual Network with separate subnet resources (modern pattern)
resource "azurerm_virtual_network" "default" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.default_rg.location
  resource_group_name = azurerm_resource_group.default_rg.name
  address_space       = ["10.88.0.0/16"]

  tags = local.common_tags
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.default_rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.88.0.0/22"]
}

resource "azurerm_subnet" "windows_subnet" {
  name                 = "windows-subnet"
  resource_group_name  = azurerm_resource_group.default_rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.88.88.0/24"]
}

# User Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "${var.cluster_name}-identity"
  resource_group_name = azurerm_resource_group.default_rg.name
  location            = azurerm_resource_group.default_rg.location

  tags = local.common_tags
}

# AKS Cluster with Managed Identity and modern configuration
resource "azurerm_kubernetes_cluster" "default_aks" {
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.default_rg.name
  location            = azurerm_resource_group.default_rg.location
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.aks_sku_tier

  # Use User Assigned Managed Identity (not service principal)
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  # Default Linux node pool with autoscaling
  default_node_pool {
    name                 = "system"
    vm_size              = var.default_node_pool_vm_size
    vnet_subnet_id       = azurerm_subnet.aks_subnet.id
    auto_scaling_enabled = true
    min_count            = var.default_node_pool_min_count
    max_count            = var.default_node_pool_max_count
    os_disk_size_gb      = 128
    os_disk_type         = "Managed"
    os_sku               = "AzureLinux"

    upgrade_settings {
      max_surge = "10%"
    }

    tags = local.common_tags
  }

  # Network configuration with Azure CNI Overlay (modern default)
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  # Azure AD RBAC integration (modern approach)
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Workload Identity for pod-level Azure authentication
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Key Vault secrets provider
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Auto-upgrade channel
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Maintenance window
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "03:00"
    utc_offset  = "+00:00"
  }

  # Azure Monitor integration
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  tags = local.common_tags
}

# Windows Node Pool (optional, with autoscaling)
resource "azurerm_kubernetes_cluster_node_pool" "windows" {
  count                 = var.enable_windows_node_pool ? 1 : 0
  name                  = "win"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.default_aks.id
  vm_size               = var.windows_node_pool_vm_size
  vnet_subnet_id        = azurerm_subnet.windows_subnet.id
  auto_scaling_enabled  = true
  min_count             = 0
  max_count             = var.windows_node_pool_max_count
  os_type               = "Windows"
  os_sku                = "Windows2022"

  upgrade_settings {
    max_surge = "10%"
  }

  tags = local.common_tags
}

# Log Analytics Workspace for AKS monitoring
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.default_rg.location
  resource_group_name = azurerm_resource_group.default_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

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
    Project     = "aks-infra"
  }
}
