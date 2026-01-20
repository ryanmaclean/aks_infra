#!/usr/bin/env bash
# Destroy AKS Infrastructure
# Run this after 24 hours or when done testing
# Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AKS Infrastructure Destruction ==="
echo "This will destroy all resources in the resource group."
echo ""

# Check if resources exist
if ! tofu state list 2>/dev/null | grep -q .; then
    echo "No resources found in state. Nothing to destroy."
    exit 0
fi

echo "Resources to destroy:"
tofu state list

echo ""
read -p "Are you sure you want to destroy these resources? (yes/no): " confirm

if [[ "$confirm" == "yes" ]]; then
    export ARM_SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-448316c8-7dd5-437c-9875-40be1dbc4b9f}"
    echo "Destroying infrastructure..."
    tofu destroy -auto-approve
    echo ""
    echo "✅ Infrastructure destroyed successfully."
else
    echo "Destruction cancelled."
    exit 1
fi
