#!/usr/bin/env bash
# Deploy AKS Store Demo sample application
# Modernized: January 2026
# Source: https://github.com/Azure-Samples/aks-store-demo

set -euo pipefail

echo "Deploying AKS Store Demo application..."

# Option 1: Deploy from local manifest (customizable)
kubectl apply -f aks-store-demo.yaml

# Option 2: Deploy directly from GitHub (always latest)
# kubectl create namespace pets --dry-run=client -o yaml | kubectl apply -f -
# kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml -n pets

echo ""
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n pets

echo ""
echo "Deployment complete!"
echo ""
echo "Store Front External IP:"
kubectl get service store-front -n pets -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo ""
echo "Access the store at: http://\$(kubectl get service store-front -n pets -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo ""
echo "View all pods:"
kubectl get pods -n pets
