#!/bin/bash
# Delete Kind cluster for local development
set -euo pipefail

CLUSTER_NAME="aks-store-local"

echo "Deleting Kind cluster '$CLUSTER_NAME'..."
kind delete cluster --name "$CLUSTER_NAME"
echo "Done"
