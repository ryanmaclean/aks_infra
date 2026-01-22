#!/usr/bin/env bash
# Local Kubernetes development environment using kind
set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-tahoe-dev}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/kind-config.yaml"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
    create      Create the kind cluster
    delete      Delete the kind cluster
    status      Show cluster status
    kubeconfig  Print kubeconfig path

Environment variables:
    KIND_CLUSTER_NAME   Cluster name (default: tahoe-dev)
EOF
}

create_cluster() {
    echo "Creating kind cluster: ${CLUSTER_NAME}"
    kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"

    echo "Installing Cilium CNI..."
    helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
    helm repo update cilium
    helm install cilium cilium/cilium --version 1.16.5 \
        --namespace kube-system \
        --set operator.replicas=1

    echo "Waiting for Cilium to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cilium-agent \
        -n kube-system --timeout=120s

    echo "Cluster ${CLUSTER_NAME} is ready"
}

delete_cluster() {
    echo "Deleting kind cluster: ${CLUSTER_NAME}"
    kind delete cluster --name "${CLUSTER_NAME}"
}

cluster_status() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        echo "Cluster ${CLUSTER_NAME}: running"
        kubectl cluster-info --context "kind-${CLUSTER_NAME}" 2>/dev/null || true
    else
        echo "Cluster ${CLUSTER_NAME}: not found"
        exit 1
    fi
}

print_kubeconfig() {
    kind get kubeconfig --name "${CLUSTER_NAME}"
}

case "${1:-}" in
    create)
        create_cluster
        ;;
    delete)
        delete_cluster
        ;;
    status)
        cluster_status
        ;;
    kubeconfig)
        print_kubeconfig
        ;;
    *)
        usage
        exit 1
        ;;
esac
