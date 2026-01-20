#!/bin/bash
set -e

# Deploy AKS Store Demo Sample App
# This script deploys the Microsoft AKS Store Demo and verifies all services are healthy

NAMESPACE="${NAMESPACE:-pets}"
MANIFEST_URL="https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml"
TIMEOUT="${TIMEOUT:-300}"

echo "=== AKS Store Demo Deployment ==="
echo "Namespace: $NAMESPACE"
echo "Manifest: $MANIFEST_URL"
echo ""

# Check kubectl connectivity
echo "Checking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster. Ensure cluster is provisioned and kubectl is configured."
    exit 1
fi
echo "Cluster connection OK"
echo ""

# Create namespace if it doesn't exist
echo "Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo ""

# Deploy the AKS Store Demo
echo "Deploying AKS Store Demo..."
kubectl apply -f "$MANIFEST_URL" -n "$NAMESPACE"
echo ""

# Wait for all deployments to be ready
echo "Waiting for deployments to be ready (timeout: ${TIMEOUT}s)..."
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

for deployment in $DEPLOYMENTS; do
    echo "  Waiting for deployment/$deployment..."
    if ! kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
        echo "ERROR: Deployment $deployment failed to become ready"
        exit 1
    fi
done
echo ""

# Verify all pods are running
echo "Verifying pod health..."
NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -v "Running\|Completed" || true)
if [ -n "$NOT_RUNNING" ]; then
    echo "WARNING: Some pods are not in Running state:"
    echo "$NOT_RUNNING"
else
    echo "All pods are running"
fi
echo ""

# Display service endpoints
echo "=== Service Endpoints ==="
kubectl get services -n "$NAMESPACE"
echo ""

# Get external IP for store-front service if available
EXTERNAL_IP=$(kubectl get svc store-front -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -n "$EXTERNAL_IP" ]; then
    echo "Store Front URL: http://$EXTERNAL_IP"
else
    echo "Store Front external IP pending or not available (LoadBalancer may take a few minutes)"
    echo "Run: kubectl get svc store-front -n $NAMESPACE --watch"
fi
echo ""

# Final status summary
echo "=== Deployment Summary ==="
kubectl get all -n "$NAMESPACE"
echo ""
echo "AKS Store Demo deployment complete!"
