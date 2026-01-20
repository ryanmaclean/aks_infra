#!/usr/bin/env bash
# Datadog Helm installation script
# Modernized: January 2026

set -euo pipefail

# Configuration
NAMESPACE="datadog"
RELEASE_NAME="datadog"
CHART_VERSION="3.80.0"  # Pinned version for reproducibility

# Ensure DD_API_KEY is set
if [[ -z "${DD_API_KEY:-}" ]]; then
    echo "Error: DD_API_KEY environment variable is required"
    echo "Usage: DD_API_KEY=your-api-key ./helm_dd_install.sh"
    exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Create secret for API key
kubectl create secret generic datadog-secret \
    --namespace="${NAMESPACE}" \
    --from-literal=api-key="${DD_API_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade Datadog using Helm
echo "Installing/Upgrading Datadog agent..."
helm upgrade --install "${RELEASE_NAME}" datadog/datadog \
    --namespace "${NAMESPACE}" \
    --version "${CHART_VERSION}" \
    --values datadog-values.yaml \
    --set datadog.apiKey="${DD_API_KEY}" \
    --set datadog.site="datadoghq.com" \
    --set datadog.clusterName="aks-cluster" \
    --set agents.image.tag="7.60.0" \
    --set clusterAgent.enabled=true \
    --set clusterAgent.image.tag="7.60.0" \
    --wait \
    --timeout 10m

echo ""
echo "Datadog installation complete!"
echo "Verify with: kubectl get pods -n ${NAMESPACE}"
