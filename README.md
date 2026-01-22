# Azure AKS Infrastructure

Secure, cost-optimized AKS infrastructure for demos (January 2026).

## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

terraform init
terraform apply

# Deploy sample app
pip install pyyaml
python k8s/deploy.py app
```

## Architecture

```
Resource Group
├── AKS Cluster (1.31)
│   ├── System Node Pool (Linux)
│   └── Cilium CNI + Network Policies
├── Virtual Network (10.88.0.0/16)
├── User-Assigned Managed Identity
├── Workload Identity (OIDC)
└── Log Analytics Workspace
```

## Security Hardening

The sample application enforces:

- **Pod Security Standards**: `restricted` policy on namespace
- **securityContext**: runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities
- **NetworkPolicy**: Default-deny with explicit allow rules per service
- **Secrets**: Credentials via K8s Secrets (not hardcoded)
- **Image pinning**: Specific versions, no `:latest` tags
- **Seccomp**: RuntimeDefault profile on all pods

## Files

```
├── terraform/           # Infrastructure as Code
│   ├── main.tf          # AKS cluster, networking
│   ├── azure_ad.tf      # Workload Identity, RBAC
│   └── variables.tf     # Configuration
├── k8s/
│   ├── deploy.py        # Deployment CLI
│   ├── aks-store-demo.yaml  # Sample app (hardened)
│   └── datadog-values.yaml  # Monitoring config
├── .github/workflows/
│   └── ci.yml           # Lint, plan, deploy
└── Makefile             # Common operations
```

## CI/CD

Single workflow (`ci.yml`) handles:
- **PR**: Lint + Terraform plan
- **Push to main**: Terraform apply + deploy app

### Required Secrets

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | App registration client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID |

Uses OIDC for passwordless Azure authentication.

## Cost Optimization

- **AKS SKU**: Free tier (no uptime SLA) - saves ~$73/month
- **VM Size**: D2s_v5 (2 vCPU, 8GB) - half the cost of D4s_v5
- **Node Count**: Min 1, autoscales to 5 - single node for idle demo
- **Log Analytics**: 7-day retention, 1GB/day cap
- **Datadog**: Single cluster agent, reduced resource requests
- **App**: Single replica per service, minimal requests (50m CPU, 64Mi)
- **No Windows nodes** by default

**Estimated cost**: ~$150-200/month (vs ~$500 unoptimized)

## Observability (LETS'CS)

| Signal | Source | Dashboard |
|--------|--------|-----------|
| **L**atency | Datadog APM traces | APM > Services |
| **E**rrors | Container logs + APM errors | Logs > Explorer |
| **T**ransactions | APM spans + custom metrics | APM > Traces |
| **S**aturation | kube-state-metrics, process agent | Infra > Kubernetes |
| **C**osts | Azure Cost Management | Portal > Cost Analysis |
| **S**ecurity | Pod Security Standards, NetworkPolicy | (runtime agent disabled) |

## Development

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run linting
make lint

# Deploy to cluster
make deploy-all DD_API_KEY=xxx
```
