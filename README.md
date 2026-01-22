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

### Deployment CLI

```bash
# Install dependencies
pip install -r k8s/requirements.txt

# Add Helm repositories
python k8s/deploy.py repos

# Install Datadog monitoring
python k8s/deploy.py datadog --api-key YOUR_KEY

# Deploy sample app (AKS Store Demo)
python k8s/deploy.py app

# Or run all steps at once
python k8s/deploy.py all --api-key YOUR_KEY
```

The deploy script is instrumented to send traces, metrics, and structured logs to Datadog:
- **Traces**: Each command creates a span in APM
- **Metrics**: `aks-deploy.*` metrics (duration, success/failure counts)
- **Logs**: JSON structured logs when `DD_LOGS_INJECTION=true`

## Files

| Path | Description |
|------|-------------|
| `terraform/` | OpenTofu/Terraform configurations |
| `terraform/main.tf` | AKS cluster, networking, identity |
| `terraform/variables.tf` | Input variables |
| `terraform/outputs.tf` | Cluster outputs (kubeconfig, etc.) |
| `azuredeploy.json` | ARM template for quick deployment |
| `k8s/` | Kubernetes manifests and deployment scripts |
| `k8s/deploy.py` | Deployment CLI with Datadog instrumentation |
| `k8s/requirements.txt` | Python dependencies |
| `k8s/datadog-values.yaml` | Datadog Helm values |
| `k8s/aks-store-demo.yaml` | Sample microservices application |

## Requirements

- Python 3.11+
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

## Development

### Pre-commit Hooks

This repo uses [pre-commit](https://pre-commit.com/) for code quality checks:

- **ruff**: Python linting and formatting
- **black**: Python code formatting
- **mypy**: Python type checking
- **terraform_fmt**: Terraform formatting

Setup:

```bash
pip install pre-commit
pre-commit install
```

Run manually on all files:

```bash
pre-commit run --all-files
```
