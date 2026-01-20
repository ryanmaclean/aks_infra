#!/bin/bash
#
# Test script for Azure Workload Identity authentication
# This script verifies that a pod can authenticate to Azure resources
# using federated credentials without storing secrets.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
K8S_DIR="$PROJECT_ROOT/k8s/workload-identity"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo " Azure Workload Identity Test"
    echo "=========================================="
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()

    command -v az >/dev/null 2>&1 || missing_tools+=("az")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the following tools before running this script:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi

    log_success "All prerequisites met"
}

get_terraform_outputs() {
    log_info "Getting Terraform outputs..."

    cd "$TERRAFORM_DIR"

    OIDC_ISSUER_URL=$(terraform output -raw oidc_issuer_url 2>/dev/null || echo "")
    WORKLOAD_IDENTITY_CLIENT_ID=$(terraform output -raw workload_identity_client_id 2>/dev/null || echo "")
    WORKLOAD_IDENTITY_TENANT_ID=$(terraform output -raw workload_identity_tenant_id 2>/dev/null || echo "")
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")

    if [ -z "$OIDC_ISSUER_URL" ] || [ -z "$WORKLOAD_IDENTITY_CLIENT_ID" ]; then
        log_error "Required Terraform outputs not found. Please run 'terraform apply' first."
        exit 1
    fi

    log_success "Terraform outputs retrieved successfully"
    log_info "  OIDC Issuer URL: $OIDC_ISSUER_URL"
    log_info "  Workload Identity Client ID: $WORKLOAD_IDENTITY_CLIENT_ID"
    log_info "  Cluster Name: $CLUSTER_NAME"
}

configure_kubectl() {
    log_info "Configuring kubectl to connect to AKS cluster..."

    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --overwrite-existing

    log_success "kubectl configured successfully"
}

deploy_workload_identity_manifests() {
    log_info "Deploying Workload Identity test manifests..."

    # Create namespace
    kubectl apply -f "$K8S_DIR/namespace.yaml"

    # Create service account with the correct client ID
    cat "$K8S_DIR/service-account.yaml" | \
        sed "s/\${WORKLOAD_IDENTITY_CLIENT_ID}/$WORKLOAD_IDENTITY_CLIENT_ID/g" | \
        kubectl apply -f -

    # Create test pod
    kubectl apply -f "$K8S_DIR/test-pod.yaml"

    log_success "Manifests deployed successfully"
}

wait_for_pod() {
    log_info "Waiting for test pod to be ready..."

    local max_wait=120
    local waited=0

    while [ $waited -lt $max_wait ]; do
        POD_STATUS=$(kubectl get pod workload-identity-test-pod \
            -n workload-identity-test \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

        if [ "$POD_STATUS" = "Running" ] || [ "$POD_STATUS" = "Succeeded" ]; then
            log_success "Pod is running"
            return 0
        elif [ "$POD_STATUS" = "Failed" ]; then
            log_error "Pod failed to start"
            return 1
        fi

        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done

    echo ""
    log_error "Timeout waiting for pod to be ready"
    return 1
}

verify_workload_identity() {
    log_info "Verifying Workload Identity authentication..."

    # Check pod logs for authentication result
    local max_attempts=12
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        LOGS=$(kubectl logs workload-identity-test-pod \
            -n workload-identity-test 2>/dev/null || echo "")

        if echo "$LOGS" | grep -q "SUCCESS: Authentication to Azure successful"; then
            log_success "Workload Identity authentication verified!"
            echo ""
            echo "=== Pod Logs ==="
            echo "$LOGS"
            echo "================"
            return 0
        elif echo "$LOGS" | grep -q "FAILED: Could not authenticate"; then
            log_error "Authentication failed!"
            echo ""
            echo "=== Pod Logs ==="
            echo "$LOGS"
            echo "================"
            return 1
        fi

        log_info "Waiting for authentication to complete... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done

    log_error "Timeout waiting for authentication verification"
    echo ""
    echo "=== Current Pod Logs ==="
    kubectl logs workload-identity-test-pod -n workload-identity-test 2>/dev/null || echo "No logs available"
    echo "========================"
    return 1
}

check_environment_variables() {
    log_info "Checking Workload Identity environment variables in pod..."

    # Verify the webhook injected the required environment variables
    AZURE_CLIENT_ID=$(kubectl exec workload-identity-test-pod \
        -n workload-identity-test \
        -- printenv AZURE_CLIENT_ID 2>/dev/null || echo "")

    AZURE_TENANT_ID=$(kubectl exec workload-identity-test-pod \
        -n workload-identity-test \
        -- printenv AZURE_TENANT_ID 2>/dev/null || echo "")

    AZURE_FEDERATED_TOKEN_FILE=$(kubectl exec workload-identity-test-pod \
        -n workload-identity-test \
        -- printenv AZURE_FEDERATED_TOKEN_FILE 2>/dev/null || echo "")

    local all_set=true

    if [ -n "$AZURE_CLIENT_ID" ]; then
        log_success "AZURE_CLIENT_ID is set: $AZURE_CLIENT_ID"
    else
        log_error "AZURE_CLIENT_ID is not set"
        all_set=false
    fi

    if [ -n "$AZURE_TENANT_ID" ]; then
        log_success "AZURE_TENANT_ID is set: $AZURE_TENANT_ID"
    else
        log_error "AZURE_TENANT_ID is not set"
        all_set=false
    fi

    if [ -n "$AZURE_FEDERATED_TOKEN_FILE" ]; then
        log_success "AZURE_FEDERATED_TOKEN_FILE is set: $AZURE_FEDERATED_TOKEN_FILE"
    else
        log_error "AZURE_FEDERATED_TOKEN_FILE is not set"
        all_set=false
    fi

    if [ "$all_set" = false ]; then
        log_error "Workload Identity webhook may not have injected environment variables correctly"
        log_info "Ensure Azure Workload Identity is installed on the cluster"
        return 1
    fi

    return 0
}

cleanup() {
    log_info "Cleaning up test resources..."

    kubectl delete -f "$K8S_DIR/test-pod.yaml" --ignore-not-found=true 2>/dev/null || true

    log_success "Cleanup completed"
}

print_summary() {
    echo ""
    echo "=========================================="
    echo " Test Summary"
    echo "=========================================="
    echo ""
    echo "AKS Cluster: $CLUSTER_NAME"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "OIDC Issuer: $OIDC_ISSUER_URL"
    echo "Workload Identity Client ID: $WORKLOAD_IDENTITY_CLIENT_ID"
    echo ""
}

# Main execution
main() {
    print_header

    case "${1:-}" in
        --cleanup)
            cleanup
            exit 0
            ;;
        --check-only)
            check_prerequisites
            get_terraform_outputs
            configure_kubectl
            check_environment_variables
            exit $?
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cleanup     Remove test pod and clean up resources"
            echo "  --check-only  Only check environment variables (pod must be running)"
            echo "  --help        Show this help message"
            echo ""
            exit 0
            ;;
    esac

    check_prerequisites
    get_terraform_outputs
    configure_kubectl

    # Check if pod already exists
    POD_EXISTS=$(kubectl get pod workload-identity-test-pod \
        -n workload-identity-test \
        -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")

    if [ -n "$POD_EXISTS" ]; then
        log_warning "Test pod already exists. Deleting and recreating..."
        kubectl delete pod workload-identity-test-pod \
            -n workload-identity-test \
            --ignore-not-found=true
        sleep 5
    fi

    deploy_workload_identity_manifests

    if wait_for_pod; then
        check_environment_variables
        if verify_workload_identity; then
            print_summary
            log_success "All tests passed! Workload Identity is working correctly."
            exit 0
        else
            log_error "Workload Identity verification failed"
            exit 1
        fi
    else
        log_error "Pod failed to start"
        exit 1
    fi
}

main "$@"
