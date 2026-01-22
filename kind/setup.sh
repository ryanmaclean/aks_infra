#!/bin/bash
# Local development setup using Kind
# Prerequisites: kind, kubectl, docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="aks-store-local"

echo "=== Kind Local Development Setup ==="

# Check prerequisites
for cmd in kind kubectl docker; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: $cmd is required but not installed"
        exit 1
    fi
done

# Check if cluster exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' already exists"
    read -p "Delete and recreate? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo "Using existing cluster"
        kubectl cluster-info --context "kind-${CLUSTER_NAME}"
    fi
fi

# Create cluster if it doesn't exist
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Creating Kind cluster..."
    kind create cluster --config "${SCRIPT_DIR}/kind-config.yaml" --name "$CLUSTER_NAME"
fi

# Set context
kubectl config use-context "kind-${CLUSTER_NAME}"

# Deploy app using Kustomize overlay
echo "Deploying AKS Store Demo..."
kubectl apply -k "${SCRIPT_DIR}"

# Wait for deployments
echo "Waiting for deployments..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n pets

# Show status
echo ""
echo "=== Deployment Complete ==="
kubectl get pods -n pets
echo ""
echo "Store URL: http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n pets          # List pods"
echo "  kubectl logs -n pets -l app=X     # View logs"
echo "  kind delete cluster --name $CLUSTER_NAME  # Cleanup"
