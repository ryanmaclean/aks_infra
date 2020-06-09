provider "azurerm" {
  version = "=2.10.0"
  features {}
}

resource "azurerm_resource_group" "default_rg" {
  name     = "default"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "default_aks" {
  name                = "us1-default-aks-dev"
  resource_group_name = azurerm_resource_group.default_rg.name
  location            = azurerm_resource_group.default_rg.location
  dns_prefix          = "default-dev"
  kubernetes_version  = "1.18.2"

  windows_profile {
    admin_username = var.win_user
    admin_password = var.win_pass
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  default_node_pool {
    name           = "us1defdev"
    node_count     = 1
    vm_size        = "Standard_D2_v3"
  }

  service_principal {
    client_id     = var.ad_sp_id
    client_secret = var.ad_sp_pass
  }

  tags = {
    env = "dev",
    owner = "ryanmaclean"
  }

}

resource "azurerm_kubernetes_cluster_node_pool" "win1" {
  name                  = "win1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.default_aks.id
  vm_size               = "Standard_DS2_v2"
  node_count            = 1
  os_type               = "Windows"
  tags = {
    env   = "Dev"
    owner = "ryanmaclean"
  }
}

resource "azurerm_virtual_network" "default" {
  name                = "virtualNetwork1"
  location            = azurerm_resource_group.default_rg.location
  resource_group_name = azurerm_resource_group.default_rg.name
  address_space       = ["10.88.0.0/16"]

  subnet {
    name           = "winsub"
    address_prefix = "10.88.88.0/24"
  }

  subnet {
    name           = "linsub"
    address_prefix = "10.88.87.0/24"
  }

  tags = {
    env = "dev"
    owner = "ryanmaclean"
  }
}
