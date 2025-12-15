#!/bin/bash
# =============================================================================
# KubeStock Complete Cluster Bootstrap Script
# =============================================================================
# Bootstraps a fresh Kubernetes cluster with KubeStock infrastructure from
# scratch, including ArgoCD installation.
#
# Prerequisites:
# - Kubernetes cluster running (via Kubespray or other)
# - kubectl configured with cluster-admin access
# - AWS CLI configured with credentials
# - jq installed
# - helm installed
#
# Required Secrets (will prompt if not provided):
# - GITHUB_PAT_TOKEN: GitHub Personal Access Token for gitops repo access
# - AWS_ACCESS_KEY_ID: AWS IAM access key for External Secrets Operator
# - AWS_SECRET_ACCESS_KEY: AWS IAM secret key for External Secrets Operator
#
# Usage: 
#   ./bootstrap-complete.sh
#
# Or with environment variables:
#   GITHUB_PAT_TOKEN=xxx AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx ./bootstrap-complete.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
ARGOCD_VERSION="v2.9.3"  # Pin specific version for reproducibility
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
EXTERNAL_SECRETS_VERSION="0.9.19"
GITOPS_REPO_URL="https://github.com/KubeStock-DevOps-project/kubestock-gitops.git"
GITOPS_REPO_BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is required but not installed. Please install it first."
        exit 1
    fi
}

wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    log_info "Waiting for deployment ${deployment} in namespace ${namespace} (timeout: ${timeout}s)..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/${deployment} -n ${namespace} 2>/dev/null; then
        log_success "Deployment ${deployment} is ready"
        return 0
    else
        log_warning "Deployment ${deployment} not ready within ${timeout}s, continuing anyway..."
        return 1
    fi
}

# Banner
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                KubeStock Complete Cluster Bootstrap                          ║"
echo "║                          Version: 2.0.0                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# STEP 0: Verify Prerequisites
# =============================================================================
log_info "Step 0/9: Verifying prerequisites..."

# Check required commands
check_command kubectl
check_command aws
check_command jq
check_command helm
check_command base64

# Verify cluster access
if ! kubectl cluster-info &> /dev/null; then
    log_error "kubectl is not configured or cannot access cluster"
    exit 1
fi

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI is not configured with valid credentials"
    exit 1
fi

CLUSTER_INFO=$(kubectl cluster-info | head -1)
log_success "Prerequisites verified"
log_info "Cluster: ${CLUSTER_INFO}"
echo ""

# =============================================================================
# STEP 1: Install ArgoCD
# =============================================================================
log_info "Step 1/9: Installing ArgoCD ${ARGOCD_VERSION}..."

# Create namespace
if kubectl get namespace argocd &> /dev/null; then
    log_warning "ArgoCD namespace already exists, skipping creation"
else
    kubectl create namespace argocd
    log_success "ArgoCD namespace created"
fi

# Install ArgoCD
if kubectl get deployment argocd-server -n argocd &> /dev/null; then
    log_warning "ArgoCD is already installed, skipping installation"
else
    log_info "Downloading and applying ArgoCD manifest..."
    kubectl apply -n argocd -f ${ARGOCD_MANIFEST}
    log_success "ArgoCD manifest applied"
fi

# Wait for ArgoCD to be ready
wait_for_deployment argocd argocd-server 300

# Expose ArgoCD server as NodePort
if kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}' | grep -q "NodePort"; then
    log_warning "ArgoCD server already exposed as NodePort"
else
    log_info "Exposing ArgoCD server as NodePort (32001)..."
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"name":"http","port": 80, "nodePort": 32001, "targetPort": 8080}, {"name":"https","port": 443, "nodePort": 30443, "targetPort": 8080}]}}'
    log_success "ArgoCD server exposed on NodePort 32001 (HTTP) and 30443 (HTTPS)"
fi

# Get initial admin password
log_info "Retrieving ArgoCD initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")

if [ -n "$ARGOCD_PASSWORD" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         ArgoCD Access Information                            ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║ URL:      http://<node-ip>:32001                                            ║"
    echo "║ Username: admin                                                              ║"
    echo "║ Password: ${ARGOCD_PASSWORD}                                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
else
    log_warning "Could not retrieve ArgoCD password (might be already deleted)"
fi

log_success "ArgoCD installation complete"
echo ""

# =============================================================================
# STEP 2: Create ArgoCD Repository Secret
# =============================================================================
log_info "Step 2/9: Creating ArgoCD repository secret..."

# Check if secret exists
if kubectl get secret kubestock-gitops-repo -n argocd &> /dev/null; then
    log_warning "ArgoCD repository secret already exists"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret kubestock-gitops-repo -n argocd
    else
        log_info "Keeping existing secret"
        echo ""
        log_success "ArgoCD repository secret verified"
        echo ""
        # Skip to next step
        SKIP_REPO_SECRET=true
    fi
fi

if [ "$SKIP_REPO_SECRET" != "true" ]; then
    # Prompt for GitHub PAT if not provided
    if [ -z "$GITHUB_PAT_TOKEN" ]; then
        log_warning "GitHub Personal Access Token not provided via environment variable"
        echo "Please enter your GitHub PAT for repository access:"
        read -s GITHUB_PAT_TOKEN
        echo ""
    fi

    if [ -z "$GITHUB_PAT_TOKEN" ]; then
        log_error "GitHub PAT token is required"
        exit 1
    fi

    # Create repository secret
    kubectl create secret generic kubestock-gitops-repo -n argocd \
        --from-literal=url="${GITOPS_REPO_URL}" \
        --from-literal=password="${GITHUB_PAT_TOKEN}" \
        --from-literal=username=git \
        --from-literal=type=git

    log_success "ArgoCD repository secret created"
fi
echo ""

# =============================================================================
# STEP 3: Apply ArgoCD ConfigMap
# =============================================================================
log_info "Step 3/9: Applying ArgoCD configuration..."

if [ -f "${SCRIPT_DIR}/argocd/config/argocd-cm.yaml" ]; then
    kubectl apply -f "${SCRIPT_DIR}/argocd/config/argocd-cm.yaml"
    log_success "ArgoCD ConfigMap applied"
else
    log_warning "ArgoCD ConfigMap not found at ${SCRIPT_DIR}/argocd/config/argocd-cm.yaml"
fi
echo ""

# =============================================================================
# STEP 4: Install External Secrets Operator (Helm)
# =============================================================================
log_info "Step 4/9: Installing External Secrets Operator ${EXTERNAL_SECRETS_VERSION}..."

# Add Helm repository
if helm repo list | grep -q "external-secrets"; then
    log_info "External Secrets Helm repo already added"
else
    helm repo add external-secrets https://charts.external-secrets.io
    log_success "External Secrets Helm repo added"
fi

helm repo update
log_success "Helm repos updated"

# Create namespace
if kubectl get namespace external-secrets &> /dev/null; then
    log_warning "external-secrets namespace already exists"
else
    kubectl create namespace external-secrets
    log_success "external-secrets namespace created"
fi

# Install External Secrets Operator
if helm list -n external-secrets | grep -q "external-secrets"; then
    log_warning "External Secrets Operator already installed"
    CURRENT_VERSION=$(helm list -n external-secrets -o json | jq -r '.[] | select(.name=="external-secrets") | .chart' | sed 's/external-secrets-//')
    log_info "Current version: ${CURRENT_VERSION}"
    
    if [ "$CURRENT_VERSION" != "$EXTERNAL_SECRETS_VERSION" ]; then
        log_warning "Version mismatch! Current: ${CURRENT_VERSION}, Expected: ${EXTERNAL_SECRETS_VERSION}"
        read -p "Do you want to upgrade? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            helm upgrade external-secrets external-secrets/external-secrets \
                --namespace external-secrets \
                --version ${EXTERNAL_SECRETS_VERSION} \
                --wait
            log_success "External Secrets Operator upgraded to ${EXTERNAL_SECRETS_VERSION}"
        fi
    fi
else
    log_info "Installing External Secrets Operator..."
    helm install external-secrets external-secrets/external-secrets \
        --namespace external-secrets \
        --version ${EXTERNAL_SECRETS_VERSION} \
        --wait
    log_success "External Secrets Operator installed"
fi
echo ""

# =============================================================================
# STEP 5: Create AWS Credentials Secret for External Secrets
# =============================================================================
log_info "Step 5/9: Creating AWS credentials secret for External Secrets..."

# Check if secret exists
if kubectl get secret aws-external-secrets-creds -n external-secrets &> /dev/null; then
    log_warning "AWS credentials secret already exists"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret aws-external-secrets-creds -n external-secrets
    else
        log_info "Keeping existing secret"
        echo ""
        log_success "AWS credentials secret verified"
        echo ""
        # Skip to next step
        SKIP_AWS_SECRET=true
    fi
fi

if [ "$SKIP_AWS_SECRET" != "true" ]; then
    # Try to get credentials from IAM (for kubestock-external-secrets user)
    log_info "Checking for existing IAM access keys..."
    EXISTING_KEYS=$(aws iam list-access-keys --user-name kubestock-external-secrets --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")

    if [ -z "$EXISTING_KEYS" ]; then
        log_info "No existing access keys found"
        log_warning "Consider creating IAM user 'kubestock-external-secrets' with Secrets Manager permissions"
    else
        log_info "Existing access key found: ${EXISTING_KEYS}"
    fi

    # Prompt for credentials if not provided
    if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        echo "Please enter AWS Access Key ID for External Secrets:"
        read AWS_ACCESS_KEY_ID
    fi

    if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Please enter AWS Secret Access Key for External Secrets:"
        read -s AWS_SECRET_ACCESS_KEY
        echo ""
    fi

    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        log_error "AWS credentials are required"
        exit 1
    fi

    # Create secret
    kubectl create secret generic aws-external-secrets-creds \
        --from-literal=access-key-id="${AWS_ACCESS_KEY_ID}" \
        --from-literal=secret-access-key="${AWS_SECRET_ACCESS_KEY}" \
        --namespace=external-secrets

    log_success "AWS credentials secret created"
fi
echo ""

# =============================================================================
# STEP 6: Apply ArgoCD Projects
# =============================================================================
log_info "Step 6/9: Creating ArgoCD projects..."

PROJECT_FILES=(
    "${SCRIPT_DIR}/argocd/projects/infrastructure.yaml"
    "${SCRIPT_DIR}/argocd/projects/production.yaml"
    "${SCRIPT_DIR}/argocd/projects/staging.yaml"
)

for project_file in "${PROJECT_FILES[@]}"; do
    if [ -f "$project_file" ]; then
        kubectl apply -f "$project_file"
        log_success "Applied $(basename $project_file)"
    else
        log_warning "Project file not found: $project_file"
    fi
done

log_success "ArgoCD projects created"
echo ""

# =============================================================================
# STEP 7: Deploy Infrastructure Applications
# =============================================================================
log_info "Step 7/9: Deploying infrastructure applications..."

# Critical apps first (order matters)
CRITICAL_APPS=(
    "external-secrets.yaml"
    "shared-rbac.yaml"
)

log_info "Deploying critical applications first..."
for app in "${CRITICAL_APPS[@]}"; do
    if [ -f "${SCRIPT_DIR}/apps/${app}" ]; then
        kubectl apply -f "${SCRIPT_DIR}/apps/${app}"
        log_success "Applied ${app}"
    fi
done

# Wait a bit for critical apps to sync
log_info "Waiting for critical applications to sync..."
sleep 10

# Deploy remaining infrastructure apps
log_info "Deploying remaining infrastructure applications..."
for app_file in "${SCRIPT_DIR}/apps/"*.yaml; do
    if [ -f "$app_file" ]; then
        app_name=$(basename "$app_file")
        # Skip critical apps (already applied)
        if [[ ! " ${CRITICAL_APPS[@]} " =~ " ${app_name} " ]]; then
            kubectl apply -f "$app_file"
            log_success "Applied ${app_name}"
        fi
    fi
done

log_success "Infrastructure applications deployed"
echo ""

# =============================================================================
# STEP 8: Deploy Environment Applications
# =============================================================================
log_info "Step 8/9: Deploying environment-specific applications..."

# Production applications
if [ -d "${SCRIPT_DIR}/apps/production" ]; then
    log_info "Deploying production applications..."
    for app_file in "${SCRIPT_DIR}/apps/production/"*.yaml; do
        if [ -f "$app_file" ]; then
            kubectl apply -f "$app_file"
            log_success "Applied production/$(basename $app_file)"
        fi
    done
fi

# Staging applications
if [ -d "${SCRIPT_DIR}/apps/staging" ]; then
    log_info "Deploying staging applications..."
    for app_file in "${SCRIPT_DIR}/apps/staging/"*.yaml; do
        if [ -f "$app_file" ]; then
            kubectl apply -f "$app_file"
            log_success "Applied staging/$(basename $app_file)"
        fi
    done
fi

log_success "Environment applications deployed"
echo ""

# =============================================================================
# STEP 9: Verification
# =============================================================================
log_info "Step 9/9: Verifying deployment..."
echo ""

# Wait for sync
log_info "Waiting for applications to sync (30s)..."
sleep 30

# Check ArgoCD applications
log_info "ArgoCD Applications Status:"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,PROJECT:.spec.project

echo ""

# Check ClusterSecretStore
log_info "Checking ClusterSecretStore..."
if kubectl get clustersecretstore aws-secretsmanager &> /dev/null; then
    CSS_STATUS=$(kubectl get clustersecretstore aws-secretsmanager -o jsonpath='{.status.conditions[0].status}')
    if [ "$CSS_STATUS" = "True" ]; then
        log_success "ClusterSecretStore 'aws-secretsmanager' is Ready"
    else
        log_warning "ClusterSecretStore 'aws-secretsmanager' exists but not ready yet"
    fi
else
    log_warning "ClusterSecretStore not found yet (may still be syncing)"
fi

echo ""

# Check namespaces
log_info "Created Namespaces:"
kubectl get namespaces --sort-by=.metadata.creationTimestamp | grep -E "(argocd|kong|kubestock|external-secrets|istio|cluster-autoscaler|reloader|observability|test-runner)" || log_warning "Some namespaces not created yet"

echo ""

# Check for any failed apps
FAILED_APPS=$(kubectl get applications -n argocd -o json | jq -r '.items[] | select(.status.sync.status != "Synced" or .status.health.status != "Healthy") | .metadata.name' 2>/dev/null || echo "")

if [ -n "$FAILED_APPS" ]; then
    log_warning "Some applications are not yet synced or healthy:"
    echo "$FAILED_APPS"
    echo ""
    log_info "This is normal for a fresh bootstrap. Applications will sync over the next few minutes."
else
    log_success "All applications are synced and healthy!"
fi

# Final summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Bootstrap Complete!                                  ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
log_success "KubeStock cluster bootstrap completed successfully!"
echo ""
log_info "Next Steps:"
echo "  1. Access ArgoCD UI: http://<node-ip>:32001"
echo "     Username: admin"
echo "     Password: ${ARGOCD_PASSWORD:-<retrieve from secret>}"
echo ""
echo "  2. Monitor application sync status:"
echo "     kubectl get applications -n argocd -w"
echo ""
echo "  3. Verify all pods are running:"
echo "     kubectl get pods -A"
echo ""
echo "  4. Check external secrets are syncing:"
echo "     kubectl get externalsecrets -A"
echo ""
log_info "All application secrets will automatically sync from AWS Secrets Manager."
log_info "Documentation: ${SCRIPT_DIR}/docs/BOOTSTRAP.md"
echo ""
