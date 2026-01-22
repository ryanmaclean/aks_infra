#!/usr/bin/env bash
# Local development setup using Kind
# Creates cluster and deploys the AKS Store Demo application
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER_NAME="tahoe-local"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

check_prerequisites() {
    local missing=()
    command -v kind >/dev/null 2>&1 || missing+=("kind")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required tools: ${missing[*]}"
        echo "Install with:"
        echo "  brew install kind kubectl"
        exit 1
    fi
}

create_cluster() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log "Cluster '$CLUSTER_NAME' already exists"
        kind export kubeconfig --name "$CLUSTER_NAME"
        return 0
    fi

    log "Creating Kind cluster '$CLUSTER_NAME'..."
    kind create cluster --config "$SCRIPT_DIR/kind-config.yaml"
    log "Cluster created successfully"
}

deploy_app() {
    log "Deploying AKS Store Demo application..."

    # Apply the store demo manifests
    kubectl apply -f "$PROJECT_ROOT/k8s/aks-store-demo.yaml"

    # Patch store-front service for NodePort access
    kubectl patch svc store-front -n pets --type='json' -p='[
        {"op": "replace", "path": "/spec/type", "value": "NodePort"},
        {"op": "add", "path": "/spec/ports/0/nodePort", "value": 30080}
    ]' 2>/dev/null || true

    log "Application deployed"
}

wait_for_pods() {
    log "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=store-front -n pets --timeout=120s || true
    kubectl get pods -n pets
}

print_access_info() {
    echo ""
    echo "============================================"
    echo "Local development environment ready"
    echo "============================================"
    echo ""
    echo "Store Front:        http://localhost:8080"
    echo "RabbitMQ Management: http://localhost:15672"
    echo "  Username: rabbitmq"
    echo "  Password: changeme-in-production"
    echo ""
    echo "Useful commands:"
    echo "  kubectl get pods -n pets     # List pods"
    echo "  kubectl logs -f <pod> -n pets # View logs"
    echo "  kind delete cluster --name $CLUSTER_NAME  # Cleanup"
    echo ""
}

main() {
    local cmd="${1:-all}"

    case "$cmd" in
        prereq)
            check_prerequisites
            ;;
        cluster)
            check_prerequisites
            create_cluster
            ;;
        deploy)
            deploy_app
            wait_for_pods
            ;;
        all)
            check_prerequisites
            create_cluster
            deploy_app
            wait_for_pods
            print_access_info
            ;;
        delete)
            log "Deleting cluster '$CLUSTER_NAME'..."
            kind delete cluster --name "$CLUSTER_NAME"
            ;;
        *)
            echo "Usage: $0 {all|cluster|deploy|delete|prereq}"
            exit 1
            ;;
    esac
}

main "$@"
