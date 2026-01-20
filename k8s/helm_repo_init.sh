#!/usr/bin/env bash
# Helm repository initialization
# Modernized: January 2026

set -euo pipefail

echo "Adding Helm repositories..."

# Datadog Helm chart repository (official)
helm repo add datadog https://helm.datadoghq.com

# Bitnami charts (common dependencies)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Azure samples (for AKS Store Demo app)
helm repo add azure-samples https://azure-samples.github.io/helm-charts

# Ingress NGINX controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Cert-Manager for TLS certificates
helm repo add jetstack https://charts.jetstack.io

# Prometheus community charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update all repositories
echo "Updating Helm repositories..."
helm repo update

echo "Helm repositories configured successfully!"
echo ""
echo "Available repositories:"
helm repo list
