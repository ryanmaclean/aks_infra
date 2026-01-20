# Rig Infrastructure

Lightweight AKS deployment module for development and testing workloads.

## Components

- **terraform/** - OpenTofu/Terraform configuration for AKS cluster
- **k8s/** - Kubernetes deployment scripts and manifests
- **arm/** - Azure Resource Manager template for quick deployment

## Quick Start

### Option 1: Terraform/OpenTofu

```bash
cd terraform
tofu init
tofu plan
tofu apply
```

### Option 2: ARM Template

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fryanmaclean%2Faks_infra%2Fmaster%2Fmayor%2Frig%2Farm%2Fazuredeploy.json)

Or deploy via CLI:

```bash
az deployment group create \
  --resource-group rig-rg \
  --template-file arm/azuredeploy.json \
  --parameters clusterName=rig-aks
```

### Option 3: Deploy Sample App

After cluster provisioning, deploy the AKS Store Demo:

```bash
./k8s/deploy-sample-app.sh
```

## Architecture

- VNet with AKS subnet (10.100.0.0/16)
- AKS cluster with Azure CNI Overlay and Cilium
- User-assigned managed identity
- Workload identity enabled
- Automatic patch upgrades

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| cluster_name | rig-aks | AKS cluster name |
| location | eastus | Azure region |
| kubernetes_version | 1.32 | Kubernetes version |
| node_pool_vm_size | Standard_D4s_v5 | VM size for nodes |
| node_pool_min_count | 1 | Minimum nodes |
| node_pool_max_count | 3 | Maximum nodes |

## Post-Deployment

Configure kubectl:

```bash
az aks get-credentials --resource-group rig-rg --name rig-aks
kubectl get nodes
```
