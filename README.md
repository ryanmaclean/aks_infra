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

- Single replica per service (demo mode)
- Minimal resource requests (50m CPU, 64Mi memory)
- No traffic generator pod (virtual-customer removed)
- System node pool only (no Windows nodes by default)

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
