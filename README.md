# Azure AKS Infrastructure

Modern AKS infrastructure using current Azure best practices (January 2026).

## Deployment Options

### Terraform (Recommended)

Full-featured AKS deployment with:
- **AKS 1.31** with system and user node pools
- **Managed Identity** and **Workload Identity** for secure Azure resource access
- **Cilium CNI** with eBPF for networking and network policies
- **Node Auto-Provisioning (NAP)** for automatic scaling
- **ARM64 support** for cost-efficient workloads

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

### ARM Template (Quick Start)

Simpler deployment for getting started:
- Linux node pool with managed identity
- Standard Load Balancer
- Azure CNI networking

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fryanmaclean%2Faks_infra%2Fmaster%2Fazuredeploy.json)

## Architecture

The Terraform deployment creates:

```
Resource Group
├── AKS Cluster (1.32)
│   ├── System Node Pool (Linux)
│   ├── Windows Node Pool (optional, disabled by default)
│   └── Cilium CNI + Network Policies
├── Virtual Network
│   ├── AKS Subnet (10.88.0.0/22)
│   ├── Windows Subnet (10.88.88.0/24)
│   └── Service endpoints
├── User-Assigned Managed Identity
├── Azure AD Application (Workload Identity)
└── Log Analytics Workspace
```

To enable the Windows node pool, set `enable_windows_node_pool = true` in your `terraform.tfvars`.

## Kubernetes Deployments

### Sample Application

```bash
./k8s/deploy-sample-app.sh
```

Deploys the AKS Store Demo (microservices sample with AI integration).

### Datadog Monitoring

```bash
# Initialize Helm repos
./k8s/helm_repo_init.sh

# Install Datadog Operator
./k8s/helm_dd_install.sh
```

Uses the Datadog Operator for automated agent lifecycle management.

## Files

| Path | Description |
|------|-------------|
| `terraform/` | OpenTofu/Terraform configurations |
| `terraform/main.tf` | AKS cluster, networking, identity |
| `terraform/variables.tf` | Input variables |
| `terraform/outputs.tf` | Cluster outputs (kubeconfig, etc.) |
| `azuredeploy.json` | ARM template for quick deployment |
| `k8s/` | Kubernetes manifests and scripts |
| `k8s/datadog-values.yaml` | Datadog Operator Helm values |
| `k8s/aks-store-demo.yaml` | Sample microservices application |

## Requirements

- Azure CLI 2.50+
- OpenTofu 1.6+ or Terraform 1.6+
- kubectl
- Helm 3.x (for Datadog)

## Modernization Notes (2026)

This repo was updated from 2020-era configurations:

- **Identity**: Service Principal → Managed Identity + Workload Identity
- **Provider**: AzureRM 3.x → 4.x (breaking changes in resource attributes)
- **Networking**: Basic Azure CNI → Cilium with eBPF overlay
- **Nodes**: Static pools → Node Auto-Provisioning, ARM64 support
- **Observability**: Datadog DaemonSet → Datadog Operator
